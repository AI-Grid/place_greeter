# place_greeter
some scripts which could be configured to greet new avis on a place or resend messages after a specified time
<br>
Functional description:<br>
When a new agent arrivs at a place first a dialog message pop's up.<br>
The information within this Dialog message could be configured in a NC with the name: Greetings_DLG<br>
<br>
To resend information or give further information after a specified time the script can send messages over a bot.<br>
The message which should be send could be confiugred in a NC with the name: Greetings<br>
<br>
The structure of the NC "Greetings" is:<br>
SEND_IM:YES<br>
HEADER:Welcome to ..., %DISPLAY_NAME%!<br>
MESSAGE:Entering this Sim means ...<br>
<br>
The structure of the NC "Greetings_DLG" is:<br>
SHOW_DLG:YES<br>
HEADER:<-- Welcome to ..., %DISPLAY_NAME%! --><br>
MESSAGE:Entering this Sim means ...<br>
<br>
The Header is only one line, this is important and with the option before it's possible to actvate or deactivate one or both of the functionalities.<br>
<br>
Other configurations are:<br>
The NC ScannerConfig:<br>
ScanTime:10<br>
Scope:AGENT_LIST_RANGE<br>
ScanRange:10<br>
ScanAngle:PI<br>
ReSendNotice: 12<br>
<br>
ScanTime is measureed in seconds.<br>
Scope could have the following parameter: AGENT_LIST_PARCEL, AGENT_LIST_REGION and AGENT_LIST_RANGE<br>
ScanRange is valid between 1 and 96. The parameter is only used when the Scope is AGENT_LIST_RANGE.<br>
ScanAngle is the Angle within new agent will be detected. The parameter is only used when the Scope is AGENT_LIST_RANGE.<br>
ReSendNotice sets the number of hours when resending new information are wanted. 0 means no resend will be done.<br>
<br>
To configure the corrade IM messenger pls use a NC with the name: Credentials<br>
CORRADE:UUID<br>
GROUP:UUID<br>
PASSWORD:1234<br>
<br>
if you want the the settings with debug output, add a nc with the name debug into the object, but make sure that it's saved at least once.<br>
To start within a test mode add a nc with the name testmode into the object, but also make sure, that it's saved a least once.<br>
<br>
If you find bugs or want a bit another behaviour, feel free to write me a message :)<br>


