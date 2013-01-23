/**
 * Your Copyright Here
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import "TiModule.h"
#import "iOSNgnStack.h"

@interface AkylasSipModule : TiModule<UIApplicationDelegate>
{
    NgnEngine* mEngine;
	NgnBaseService<INgnSipService>* mSipService;
	NgnBaseService<INgnConfigurationService>* mConfigurationService;
	NgnAVSession* mCurrentAVSession;
    BOOL connected;
    BOOL shouldBeConnected;
	BOOL mScheduleRegistration;
	BOOL multitaskingSupported;
}

@end
