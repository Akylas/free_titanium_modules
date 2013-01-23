/**
 * Your Copyright Here
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import "AkylasSipModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

#import "iOSNgnStack.h"
#import "services/impl/NgnSoundService.h"

@interface NgnSoundService (TrickForWavPath)
-(BOOL) playKeepAwakeSoundLooping: (BOOL)looping;
@end

@implementation NgnSoundService(TrickForWavPath)
-(BOOL) playKeepAwakeSoundLooping: (BOOL)looping
{
//	NSLog(@"overloading playKeepAwakeSoundLooping");
	if(!playerKeepAwake){
		playerKeepAwake = [[NgnSoundService initPlayerWithPath:@"modules/akylas.sip/keepawake.wav"] retain];
	}
	if(playerKeepAwake){
		UInt32 doSetProperty = TRUE;
		[[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: nil];
		AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof(doSetProperty), &doSetProperty);
		
		playerKeepAwake.numberOfLoops = looping ? -1 : +1;
		[playerKeepAwake play];
		return YES;
	}
	return NO;
}
@end

//
//	sip callback events implementation
//
@implementation AkylasSipModule(SipCallbackEvents)



@end

@implementation AkylasSipModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"d394ce53-adfc-40b7-b95a-39ac575f94a6";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"akylas.sip";
}

#pragma mark Lifecycle
static UIBackgroundTaskIdentifier sBackgroundTask = UIBackgroundTaskInvalid;
static dispatch_block_t sExpirationHandler = nil;

- (void)applicationWillEnterForeground:(UIApplication *)application{
	ConnectionState_t registrationState = [mSipService getRegistrationState];
//	NSLog(@"applicationWillEnterForeground and RegistrationState=%d", registrationState);
	
	switch (registrationState) {
		case CONN_STATE_NONE:
		case CONN_STATE_TERMINATED:
            if (connected) [self fireEvent:@"disconnected" withObject:nil];
            connected  = false;
			if (shouldBeConnected) [mSipService registerIdentity];
			break;
		case CONN_STATE_CONNECTING:
		case CONN_STATE_TERMINATING:
			mScheduleRegistration = shouldBeConnected;
			[mSipService unRegisterIdentity];
			break;
		case CONN_STATE_CONNECTED:
            if (!connected) [self fireEvent:@"connected" withObject:nil];
            connected  =true;
			break;
	}
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// application.idleTimerDisabled = YES;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
	if(multitaskingSupported && mEngine){
		ConnectionState_t registrationState = [mEngine.sipService getRegistrationState];
		if(registrationState == CONN_STATE_CONNECTING || registrationState == CONN_STATE_CONNECTED){
//			NSLog(@"applicationDidEnterBackground (Registered or Registering)");
            UIApplication* app = [UIApplication sharedApplication];
           
            if (sExpirationHandler != nil)
            {
                //if(registrationState == CONN_STATE_CONNECTING){
                // request for 10min to complete the work (registration, computation ...)
                sBackgroundTask = [app beginBackgroundTaskWithExpirationHandler:sExpirationHandler];
                //}
                if(registrationState == CONN_STATE_CONNECTED){
                    if([[NgnEngine sharedInstance].configurationService getBoolWithKey:NETWORK_USE_KEEPAWAKE]){
                        if(![NgnAVSession hasActiveSession]){
                            [[NgnEngine sharedInstance] startKeepAwake];
                        }
                    }
                }
                
                [app setKeepAliveTimeout:600 handler: ^{
//                    NSLog(@"applicationDidEnterBackground:: setKeepAliveTimeout:handler^");
                }];
            }
		}
	}
#endif /* __IPHONE_OS_VERSION_MIN_REQUIRED */
}


-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
    
    connected = false;
    
    multitaskingSupported = [[UIDevice currentDevice] respondsToSelector:@selector(isMultitaskingSupported)] && [[UIDevice currentDevice] isMultitaskingSupported];
    
    sBackgroundTask = UIBackgroundTaskInvalid;
//    NSLog(@"startup");
	sExpirationHandler = ^{
//		NSLog(@"Background task completed");
		// keep awake
		if([[NgnEngine sharedInstance].sipService isRegistered]){
			if([[NgnEngine sharedInstance].configurationService getBoolWithKey:NETWORK_USE_KEEPAWAKE])
            {
				[[NgnEngine sharedInstance] startKeepAwake];
			}
		}
		[[UIApplication sharedApplication] endBackgroundTask:sBackgroundTask];
		sBackgroundTask = UIBackgroundTaskInvalid;
    };
    
    // add observers
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(onRegistrationEvent:) name:kNgnRegistrationEventArgs_Name object:nil];
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(onInviteEvent:) name:kNgnInviteEventArgs_Name object:nil];
    [[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(onMessagingEvent:) name:kNgnMessagingEventArgs_Name object:nil];
    [[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(onStackEvent:) name:kNgnStackEventArgs_Name object:nil];
    [[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(applicationWillEnterForeground:) name:kTiResumeNotification object:nil];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(applicationDidEnterBackground:) name:kTiPausedNotification object:nil];
	
	// take an instance of the engine
	[NgnEngine initialize];
	mEngine = [[NgnEngine sharedInstance] retain];
	
	// take needed services from the engine
	mSipService = [mEngine.sipService retain];
	mConfigurationService = [mEngine.configurationService retain];
	
	// start the engine
	[mEngine start];
	
//	NSLog(@"[INFO] %@ loaded",self);
}

-(void)shutdown:(id)sender
{
	// this method is called when the module is being unloaded
	// typically this is during shutdown. make sure you don't do too
	// much processing here or the app will be quit forceably
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [mEngine stop];
	
	[mCurrentAVSession release];
	[mEngine release];
	[mSipService release];
	[mConfigurationService release];
	
	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup 

-(void)dealloc
{
	// release any resources that have been retained by the module
	[super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
	if (count == 1 && [type isEqualToString:@"my_event"])
	{
		// the first (of potentially many) listener is being added 
		// for event named 'my_event'
	}
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
	if (count == 0 && [type isEqualToString:@"my_event"])
	{
		// the last listener called for event named 'my_event' has
		// been removed, we can optionally clean up any resources
		// since no body is listening at this point for that event
	}
}

#pragma Public APIs


-(void)registerId:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSDictionary);
    
    NSString* kProxyHost = [TiUtils stringValue:@"proxyhost" properties:args def:@"proxy.sipthor.net"];
    int kProxyPort = [TiUtils intValue:@"proxyport" properties:args def:5060];
    NSString* kRealm = [TiUtils stringValue:@"realm" properties:args def:@"sip2sip.info"];
    NSString* kPassword = [TiUtils stringValue:@"password" properties:args def:@"d3sb7j4fb8"];
    NSString* kPrivateIdentity = [TiUtils stringValue:@"privateid" properties:args def:@"2233392625"];
    NSString* kPublicIdentity = [TiUtils stringValue:@"publicid" properties:args def:@"sip:2233392625@sip2sip.info"];
    BOOL kUseKeepAwake = [TiUtils boolValue:@"keepawake" properties:args def:false];
    BOOL kEnableEarlyIMS = [TiUtils boolValue:@"earlyims" properties:args def:false];
    NSString* kNetworkTransport = [TiUtils stringValue:@"networktransport" properties:args def:@"UDP"];
    BOOL kUseWIFI = [TiUtils boolValue:@"usewifi" properties:args def:true];
    BOOL kUse3G = [TiUtils boolValue:@"use3g" properties:args def:false];
    int kMediaProfile = [TiUtils intValue:@"mediaprofile" properties:args def:0];

	// set credentials
	[mConfigurationService setStringWithKey: IDENTITY_IMPI andValue: kPrivateIdentity];
	[mConfigurationService setStringWithKey: IDENTITY_IMPU andValue: kPublicIdentity];
	[mConfigurationService setStringWithKey: IDENTITY_PASSWORD andValue: kPassword];
	[mConfigurationService setStringWithKey: NETWORK_REALM andValue: kRealm];
	[mConfigurationService setStringWithKey: NETWORK_PCSCF_HOST andValue:kProxyHost];
	[mConfigurationService setIntWithKey: NETWORK_PCSCF_PORT andValue: kProxyPort];
	[mConfigurationService setBoolWithKey: NETWORK_USE_EARLY_IMS andValue: kEnableEarlyIMS];
	[mConfigurationService setBoolWithKey: NETWORK_USE_KEEPAWAKE andValue: kUseKeepAwake];
	[mConfigurationService setStringWithKey: NETWORK_TRANSPORT andValue:kNetworkTransport];
	[mConfigurationService setBoolWithKey: NETWORK_USE_WIFI andValue: kUseWIFI];
	[mConfigurationService setBoolWithKey: NETWORK_USE_3G andValue: kUse3G];
	[mConfigurationService setIntWithKey: MEDIA_PROFILE andValue: kMediaProfile];
	
	// Try to register the default identity
[mSipService registerIdentity];
    shouldBeConnected = true;
}

-(void)unregisterId:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
	[mSipService unRegisterIdentity];
    shouldBeConnected = false;
}

-(void)call:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSString);
    mCurrentAVSession = [[NgnAVSession makeAudioCallWithRemoteParty:
                          [NSString stringWithFormat: @"sip:%@@%@", args, [mConfigurationService getStringWithKey:NETWORK_REALM]]
                                                        andSipStack: [mSipService getSipStack]] retain];
}

-(void)sendMessage:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSDictionary);
    
    ActionConfig* actionConfig = new ActionConfig();
    
    NSString* kPrivateIdentity = [TiUtils stringValue:@"privateid" properties:args def:@"2233392625"];
    NSString* kMessage = [TiUtils stringValue:@"message" properties:args def:@"Hello!"];
    NSString* kSubject = [TiUtils stringValue:@"subject" properties:args def:@""];
    NSString* kOrganization = [TiUtils stringValue:@"organization" properties:args def:@""];
    
    if(actionConfig)
    {
        if (![kSubject isEqualToString:@""])
            actionConfig->addHeader("Subject", [kSubject UTF8String]);
        if (![kOrganization isEqualToString:@""])
            actionConfig->addHeader("Organization", [kOrganization UTF8String]);
    }
    NgnMessagingSession* imSession = [[NgnMessagingSession sendTextMessageWithSipStack: [mSipService getSipStack]
                                                                              andToUri: [NSString stringWithFormat: @"sip:%@@%@", kPrivateIdentity, [mConfigurationService getStringWithKey:NETWORK_REALM]]
                                                                            andMessage: kMessage
                                                                        andContentType: kContentTypePlainText
                                                                       andActionConfig: actionConfig
									   ] retain]; // Do not retain the session if you don't want it
                                                  // do whatever you want with the session
	if(actionConfig){
		delete actionConfig, actionConfig = tsk_null;
	}
	[NgnMessagingSession releaseSession: &imSession];
}

-(id)MEDIA_PROFILE_DEFAULT
{
    return NUMINT(0);
}

-(id)MEDIA_PROFILE_RTCWEB
{
    return NUMINT(1);
}

-(id)TRANSPORT_UDP
{
	// example property getter
	return @"UDP";
}

-(id)TRANSPORT_TCP
{
	// example property getter
	return @"TCP";
}

-(void)acceptCall:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
	if(mCurrentAVSession){
        [mCurrentAVSession acceptCall];
	}
}

-(void)holdCall:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
	if(mCurrentAVSession){
        [mCurrentAVSession holdCall];
	}
}

-(void)resumeCall:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
	if(mCurrentAVSession){
        [mCurrentAVSession resumeCall];
	}
}

-(void)hangUpCall:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
	if(mCurrentAVSession){
        [mCurrentAVSession hangUpCall];
	}
}

-(void)setMuted:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSNumber);
	if(mCurrentAVSession){
        [mCurrentAVSession setMute:[args boolValue]];
	}
}

-(id)muted
{
	if(mCurrentAVSession){
        return NUMBOOL([mCurrentAVSession isMuted]);
	}
    return false;
}

-(void)setSpeakerEnabled:(id)args
{
    ENSURE_UI_THREAD_1_ARG(args);
    ENSURE_SINGLE_ARG(args, NSNumber);
    
    if(mCurrentAVSession){
        [mCurrentAVSession setSpeakerEnabled:[args boolValue]];
        [mEngine.soundService setSpeakerEnabled:[mCurrentAVSession isSpeakerEnabled]];
	}
}

-(id)speakerEnabled{
	if(mCurrentAVSession){
        return NUMBOOL([mCurrentAVSession isSpeakerEnabled]);
	}
    return false;
}

-(id)vibrate:(id)args{
    [mEngine.soundService vibrate];
}

//== REGISTER events == //
-(void) onRegistrationEvent:(NSNotification*)notification {
    NgnRegistrationEventArgs* eargs = [notification object];
    NSLog(@"onRegistrationEvent: %d", eargs.eventType);
	
// Current event triggered the callback
// to get the current registration state you should use "mSipService::getRegistrationState"
    switch (eargs.eventType) {
			// provisional responses
		case REGISTRATION_INPROGRESS:
            [self fireEvent:@"register.progress" withObject:nil];
			break;
		case UNREGISTRATION_INPROGRESS:
			[self fireEvent:@"unregister.progress" withObject:nil];
			break;
			// final responses
		case REGISTRATION_NOK:
            [self fireEvent:@"register.failure" withObject:nil];
			break;
		case UNREGISTRATION_NOK:
            [self fireEvent:@"unregister.failure" withObject:nil];
			break;
		case REGISTRATION_OK:
		case UNREGISTRATION_OK:
		default:
//			[activityIndicator stopAnimating];
			break;
	}
	
    //	labelDebugInfo.text = [NSString stringWithFormat: @"onRegistrationEvent: %@", eargs.sipPhrase];
//    if (connected != [mSipService isRegistered])
//    {
//        if([mSipService isRegistered]){
//            [self fireEvent:@"connected" withObject:nil];
//        }
//        else {
//            [self fireEvent:@"disconnected" withObject:nil];
//        }
//    }
	
	// gets the new registration state
	ConnectionState_t registrationState = [mSipService getRegistrationState];
	switch (registrationState) {
		case CONN_STATE_NONE:
		case CONN_STATE_TERMINATED:
			if(mScheduleRegistration){
				mScheduleRegistration = FALSE;
				[mSipService registerIdentity];
			}
            if (connected) [self fireEvent:@"unregister.done" withObject:nil];
            connected = false;
			break;
		case CONN_STATE_CONNECTING:
		case CONN_STATE_TERMINATING:
			break;
		case CONN_STATE_CONNECTED:
            if (!connected) [self fireEvent:@"register.done" withObject:nil];
            connected = true;
			break;
	}
}

//== INVITE (audio/video, file transfer, chat, ...) events == //
-(void) onInviteEvent:(NSNotification*)notification {
	NgnInviteEventArgs* eargs = [notification object];
    NSLog(@"onInviteEvent: %d", eargs.eventType);
	
	switch (eargs.eventType) {
        case INVITE_EVENT_INCOMING:
		{
			if(mCurrentAVSession){
				TSK_DEBUG_ERROR("This is a test application and we only support ONE audio/video call at time!");
				[mCurrentAVSession hangUpCall];
				return;
			}
			
			mCurrentAVSession = [[NgnAVSession getSessionWithId: eargs.sessionId] retain];
//            [self setSpeakerEnabled:NUMBOOL(YES)];
//			if ([UIApplication sharedApplication].applicationState ==  UIApplicationStateBackground) {
//				UILocalNotification* localNotif = [[[UILocalNotification alloc] init] autorelease];
//				if (localNotif){
//					localNotif.alertBody =[NSString  stringWithFormat:@"Call from %@", [mCurrentAVSession getRemotePartyUri]];
//					localNotif.soundName = UILocalNotificationDefaultSoundName;
//					localNotif.applicationIconBadgeNumber = 1;
//					localNotif.repeatInterval = 0;
//                    
//					[[UIApplication sharedApplication]  presentLocalNotificationNow:localNotif];
//				}
//			}
//			else {
                [self fireEvent:@"call.incoming" withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              [mCurrentAVSession getRemotePartyUri],@"caller",
                                                                NUMINT(eargs.sessionId),@"sessionid",
                                                              nil]];
//			}
			break;
		}
            
        case INVITE_EVENT_CONNECTED:
		{
            [self fireEvent:@"call.started" withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [mCurrentAVSession getRemotePartyUri],@"caller",
                                                        NUMINT(eargs.sessionId),@"sessionid",
                                                        nil]];
			break;
		}
            
		case INVITE_EVENT_INPROGRESS:
		{
            [self fireEvent:@"call.calling" withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [mCurrentAVSession getRemotePartyUri],@"caller",
                                                         NUMINT(eargs.sessionId),@"sessionid",
                                                        nil]];
			break;
		}
			
		case INVITE_EVENT_TERMINATED:
		case INVITE_EVENT_TERMWAIT:
		{
			if(mCurrentAVSession && (mCurrentAVSession.id == eargs.sessionId)){
				[NgnAVSession releaseSession: &mCurrentAVSession];
                [self fireEvent:@"call.ended" withObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        NUMINT(eargs.sessionId),@"sessionid",
                                                         nil]];
			}
			break;
		}
			
		default:
			break;
	}
	
    //	labelDebugInfo.text = [NSString stringWithFormat: @"onInviteEvent: %@", eargs.sipPhrase];
    //	[buttonMakeAudioCall setTitle: mCurrentAVSession ? @"End Call" : @"Audio Call" forState: UIControlStateNormal];
}

//== PagerMode IM (MESSAGE) events == //
-(void) onMessagingEvent:(NSNotification*)notification {
	NgnMessagingEventArgs* eargs = [notification object];
	
	switch (eargs.eventType) {
		case MESSAGING_EVENT_CONNECTING:
		case MESSAGING_EVENT_CONNECTED:
		case MESSAGING_EVENT_TERMINATING:
		case MESSAGING_EVENT_TERMINATED:
        default:
            break;
		case MESSAGING_EVENT_FAILURE:
		case MESSAGING_EVENT_INCOMING:
		case MESSAGING_EVENT_SUCCESS:
		case MESSAGING_EVENT_OUTGOING:
		{
            NSMutableDictionary* args = [NSMutableDictionary dictionary];
            
            if(eargs.payload){
				NSString* contentType = [eargs getExtraWithKey: kExtraMessagingEventArgsContentType];
				NSString* from = [eargs getExtraWithKey: kExtraMessagingEventArgsFrom];
				NSString* content = [NSString stringWithUTF8String: (const char*)[eargs.payload bytes]];
                
                [args setObject:content forKey:@"content"];
                [args setObject:contentType forKey:@"type"];
                [args setObject:from forKey:@"from"];
            }
                
            NSString* message;
            if(eargs.eventType == MESSAGING_EVENT_FAILURE)
            {
                message = @"message.failure";
            }
            else if(eargs.eventType == MESSAGING_EVENT_INCOMING)
            {
                message = @"message.incoming";
            }
            else if(eargs.eventType == MESSAGING_EVENT_SUCCESS)
            {
                message = @"message.success";
            }
            else if(eargs.eventType == MESSAGING_EVENT_OUTGOING)
            {
                message = @"message.sending";
            }
            
            [self fireEvent:message withObject:args];
        }
        break;
		
	}
}

-(void) onStackEvent:(NSNotification*)notification {
	NgnStackEventArgs * eargs = [notification object];
	switch (eargs.eventType) {
		case STACK_STATE_STARTING:
		{
			// this is the only place where we can be sure that the audio system is up
//			[[NgnEngine sharedInstance].soundService setSpeakerEnabled:YES];
			
			break;
		}
		default:
			break;
	}
}

@end
