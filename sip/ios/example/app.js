// This is a test harness for your module
// You should do something interesting in this harness
// to test out the module and to provide instructions
// to users on how to use it by example.


// open a single window
var win = Ti.UI.createWindow({
    backgroundColor:'gray'
});

var sipConnected  =false;

// TODO: write your module tests here
var akylas_sip = require('akylas.sip');
Ti.API.info("module is => " + akylas_sip);
akylas_sip.addEventListener('register.done', sipRegistered);
akylas_sip.addEventListener('register.failure', sipFailure);
akylas_sip.addEventListener('unregister.done', sipUnregistered);


var sipConnectedView = Ti.UI.createView({backgroundColor:'gray', top:0, height:40});
var sipConnectedLabel = Ti.UI.createLabel({right:0, text:"disconnected"});
var sipConnectButton = Ti.UI.createButton({title: 'connect', top:0, left:0, width:100, height:50});
sipConnectButton.addEventListener('singletap', register);

var sipCallerTextField = Ti.UI.createTextField({borderStyle: Ti.UI.INPUT_BORDERSTYLE_ROUNDED,top:60, left:0, right: 120, height:40});

var sipCallButton = Ti.UI.createButton({title: 'call', top:60, right:0, width:100, height:50});
sipCallButton.addEventListener('singletap', startAudioCall);

var sipLoggerLabel = Ti.UI.createLabel({height:50});

var sipHangupButton = Ti.UI.createButton({title: 'hangup', bottom:50, right:0, width:100, height:50});
sipHangupButton.addEventListener('singletap', function(){
    akylas_sip.hangUpCall();
    sipHangupButton.enabled = false;
    sipLoggerLabel.text = "hanging up...";
});
var sipIncomingView = Ti.UI.createView({height:140, bottom:0});
var sipAcceptCallButton = Ti.UI.createButton({title:'accept', backgroundColor:'green', left:0, width:100, height:50});
sipAcceptCallButton.addEventListener('singletap', function(){
    akylas_sip.acceptCall();
    sipHangupButton.enabled = true;
    sipHangupButton.show();
    sipIncomingView.hide();
    sipLoggerLabel.text = "";
});
var sipRefuseCallButton = Ti.UI.createButton({title:'accept', backgroundColor:'red', right:0, width:100, height:50});
sipRefuseCallButton.addEventListener('singletap', function(){
    akylas_sip.hangUpCall();
    sipHangupButton.hide();
    sipIncomingView.hide();
    sipCallButton.show();
    sipLoggerLabel.text = "";
});

var sipInCallView = Ti.UI.createView({height:140, bottom:0});
var sipInCallIndicator = Ti.UI.createLabel({title:"IN CALL", right:0});


var sipMuteButton = Ti.UI.createButton({title:'mute', left:0, width:100, height:50});
sipMuteButton.addEventListener('singletap', function(){
    var newValue = !akylas_sip.muted;
    akylas_sip.setMuted(newValue);
    if (newValue)
        sipMuteButton.title = 'unmute';
    else
        sipMuteButton.title = 'mute';
});

var sipSpeakerButton = Ti.UI.createButton({title:'enable speakers', left:110, width:100, height:50});
sipSpeakerButton.addEventListener('singletap', function(){
    var newValue = !akylas_sip.speakerEnabled;
    akylas_sip.setSpeakerEnabled(newValue);
    if (newValue)
        sipSpeakerButton.title = 'disable speakers';
    else
        sipSpeakerButton.title = 'enable speakers';
});

var callEvents = ['call.incoming', 'call.ended', 'call.started', 'call.calling'];
function sipRegistered()
{
    // Ti.API.info('sipConnected');
    sipConnectButton.hide();
    sipconnected = true;
    sipConnectedView.backgroundColor = 'green';
    sipConnectedLabel.text = "connected";
    for(var i=0,j=callEvents.length; i<j; i++){
        akylas_sip.addEventListener(callEvents[i], onSipEvent);
    }
    
    sipHangupButton.hide();
    sipIncomingView.hide();
    sipInCallView.hide();
    sipCallButton.show();

}

function sipUnregistered()
{
    sipConnectButton.show();
    // Ti.API.info('sipUnregistered');
    sipConnectedView.backgroundColor = 'gray';
    sipConnectedLabel.text = "disconnected";
    sipconnected = false;
    for(var i=0,j=callEvents.length; i<j; i++){
        akylas_sip.removeEventListener(callEvents[i], onSipEvent);
    }
    
    sipCallButton.hide();
}
// var incomingSound = Ti.UI.createSound({url:'incoming.wav'});
// var outgoingSound = Ti.UI.createSound({url:'outgoing.wav'});
function startAudioCall()
{
    sipCallerTextField.blur();
    // outgoingSound.play();
    akylas_sip.call(sipCallerTextField.value);
}

function sipFailure()
{
    alert("Could not register to the SIP server.VOIP wo't be accessible. Check Settings/Connection and start a new call");
}

function onSipEvent(_event)
{
    Ti.API.info('onSipCall ' + JSON.stringify(_event));
    var caller = '';
    if (_event.caller)
    {
        var match =_event.caller.match(/sip:(.*)(?=@\w+\.\w{2,6})/g);
        if (match && match.length > 0)
            caller = match[0].replace(/sip:/i, '');
        else
            caller = _event.caller;
    }
    if (_event.type === "call.incoming")
    {
        // outgoingSound.stop();
        // incomingSound.play();
        sipIncomingView.show();
        sipHangupButton.hide();
        sipCallButton.hide();
        sipLoggerLabel.text = caller + " calling ...";
    }
    else if (_event.type === "call.calling")
    {
        // outgoingSound.play();
        // incomingSound.stop();
        sipHangupButton.show();
        sipCallButton.hide();
        sipLoggerLabel.text =  " calling " + caller;
    }
    else if (_event.type === "call.started")
    {
        // outgoingSound.stop();
        // incomingSound.stop();
        if (akylas_sip.muted)
            sipMuteButton.title = 'unmute';
        else
            sipMuteButton.title = 'mute';
        
        if (akylas_sip.speakerEnabled)
            sipSpeakerButton.title = 'disable speakers';
        else
            sipSpeakerButton.title = 'enable speakers';

        sipIncomingView.hide();
        sipCallButton.hide();
        sipInCallView.show();
        sipLoggerLabel.text = "in call with " + caller;
    }
    else if (_event.type === "call.ended")
    {
        // outgoingSound.stop();
        // incomingSound.stop();
        sipCallButton.show();
        sipHangupButton.hide();
        sipInCallView.hide();
        sipLoggerLabel.text = "";
    }
}

function register(){
    akylas_sip.registerId({
        proxyhost:'proxy.sipthor.net',
        proxyport:5060,
        realm:'sip2sip.info',
        password:'ns677jnn4p',
        publicid:'sip:martinipad@sip2sip.info',
        privateid:'martinipad',
        keepawake:true,
        networktransport:akylas_sip.TRANSPORT_TCP,
        mediaprofile:akylas_sip.MEDIA_PROFILE_RTCWEB
    });
}

Ti.App.addEventListener('resume', function(){
    Ti.API.info('resuming');
    register();
});


sipConnectedView.add(sipConnectedLabel);
sipConnectedView.add(sipConnectButton);
win.add(sipConnectedView);
win.add(sipCallerTextField);
win.add(sipCallButton);
sipHangupButton.hide();
win.add(sipHangupButton);
win.add(sipLoggerLabel);

sipInCallView.hide();
sipInCallView.add(sipMuteButton);

// if (!app.info.isTablet) //tablet dont have 2 speakers
sipInCallView.add(sipSpeakerButton);
sipInCallView.add(sipInCallIndicator);

sipIncomingView.hide();
sipIncomingView.add(sipAcceptCallButton);
sipIncomingView.add(sipRefuseCallButton);

win.add(sipIncomingView);
win.add(sipInCallView);

win.open();