//Author: CLAENG
//Date: 07.03.2021
//
//Functionality: 
// send a message over IM or DlG
///////////////////////////////////////////////////////////////////////////


//Constants and variables
///////////////////////////////////////////////////////////////////////////
integer debug_out  = FALSE; //switch to activate or deactivate debug output
integer TestMode   = FALSE; //switch to change between test mode and productive mode
integer sendIMs    = FALSE; //if not activated, not IM's with information will be send
integer showDLG    = FALSE; //if not activated, no message dialog will be shown
integer DLGChannel = 0;
integer DLGHandle  = 0;

key testUUID1 = "3947643a-63dc-40e4-84ec-5cf213771618"; //Marty
key testUUID2 = "b3c3ea7e-76fa-4ec7-8b72-d28b0fd1c2c8"; //Annita
key testUUID3 = "1582932f-3f48-4cd5-8af9-6629019f20f1"; //claeng

//configurations 
//should be later brought to nc
integer sendOverIM = TRUE;

// The UUID / Key of the scripted agent.
string CORRADE = ""; //"4e4c0d3f-e3e8-4e13-a002-b1e1e78a21fe";
// The name of the group to invite to.
string GROUP = ""; //"2e40dcaf-3673-1f37-a2b6-05add2c2cc12";
//string GROUP = "cbc820cb-5754-fb55-df7f-26dfa412216c"; Lilith group
// The password for that group in Corrade.ini.
string PASSWORD = ""; //"lili123456";

//Message numbers:
integer MESSAGE_NEW_HEADER          = 1000;
integer MESSAGE_NEW_IM_MSG          = 1001;
integer MESSAGE_NEW_DLG_HEADER      = 1002;
integer MESSAGE_NEW_DLG_MSG         = 1003;
integer MESSAGE_SCAN_CONFIG         = 1004;
integer MESSAGE_CREDENTIALS         = 1005;
integer MESSAGE_SEND_TO_USER        = 1006;
integer MESSAGE_START_SCANNING      = 1007;
integer MESSAGE_SEND_IM             = 1008;
integer MESSAGE_SHOW_DLG            = 1009;
integer MESSAGE_OPEN_DLG_FOR_USER   = 1010;

string g_headerMsg = "";
string g_msgToSend = "";

string g_headerMsgDLG = "";
string g_msgToSendDLG = "";

//Functions
///////////////////////////////////////////////////////////////////////////
DEBUG_OUT(string msg)
{
    if( debug_out == TRUE )
    {   
        llOwnerSay(msg);
    }
}

//parse the header and put in the correct displayname
string parseHeader(string msg, key avi)
{
   integer posName = llSubStringIndex(msg, "\%DISPLAY_NAME\%");
   
   DEBUG_OUT("pos to replace: " + (string)posName);
   if( posName != -1 )
   {
        msg = llDeleteSubString(msg, posName, posName+llStringLength("\%DISPLAY_NAME\%")-1);
        msg = llInsertString(msg, posName, llGetDisplayName(avi));

        DEBUG_OUT("new Header: " + msg);
   }

   return msg;
}

// escapes a string in conformance with RFC1738
string wasURLEscape(string i) {
    string o = "";
    do {
        string c = llGetSubString(i, 0, 0);
        i = llDeleteSubString(i, 0, 0);
        if(c == "") jump continue;
        if(c == " ") {
            o += "+";
            jump continue;
        }
        if(c == "\n") {
            o += "%0D" + llEscapeURL(c);
            jump continue;
        }
        o += llEscapeURL(c);
@continue;
    } while(i != "");
    return o;
}

string wasKeyValueEncode(list kvp) {
    if(llGetListLength(kvp) < 2) return "";
    string k = llList2String(kvp, 0);
    kvp = llDeleteSubList(kvp, 0, 0);
    string v = llList2String(kvp, 0);
    kvp = llDeleteSubList(kvp, 0, 0);
    if(llGetListLength(kvp) < 2) return k + "=" + v;
    return k + "=" + v + "&" + wasKeyValueEncode(kvp);
}

//send an instant message to a given helper
sendIM(string strAgent, string message)
{
    if( sendOverIM == 0 ) return;
    
    llInstantMessage(CORRADE, 
        wasKeyValueEncode(
            [
                "command", "tell",
                "group", wasURLEscape(GROUP),
                "password", PASSWORD,
                "agent", strAgent,
                "entity", "avatar",
                "message", message//wasURLEscape(is)
                // "callback", wasURLEscape(URL)
            ]
        )
    );//end of block
}

parseCredentials(string credentials)
{
    list lstCreds = llParseString2List(credentials, [":",";"],[]);

    integer count = 0;
    for( ;count < llGetListLength(lstCreds); count++ )
    {
       if( llList2String(lstCreds, count) == "CORRADE" )
       {
           count += 1;
           CORRADE = llList2String(lstCreds, count);
       } else if( llList2String(lstCreds, count) == "GROUP" )
       {
           count += 1;
           GROUP = llList2String(lstCreds, count);
       } else if( llList2String(lstCreds, count) == "PASSWORD" )
       {
            count += 1;
            PASSWORD = llList2String(lstCreds, count);
       } else
       {
           count += 2;
       }
    }
}

//check for agents who receive message in the test mode
integer TestModeSendingAllowed(key avi_id)
{
    return ((string)avi_id == testUUID1 || (string)avi_id == testUUID2 || (string)avi_id == testUUID3);
}


//LSL States
//////////////////////////////////////////////////////////////

default
{
    state_entry()
    {
        if( llGetInventoryKey("debug") != NULL_KEY ) debug_out = TRUE;
        if( llGetInventoryKey("testmode") != NULL_KEY ) TestMode = TRUE;
    }
    
    link_message( integer sender_num, integer num, string str, key id )
    {
        if( num == MESSAGE_NEW_HEADER )
        {
            g_headerMsg = str;
            DEBUG_OUT("rcv new header: " + str);

        } else if( num == MESSAGE_NEW_IM_MSG )
        {
            g_msgToSend = str;
            DEBUG_OUT("rcv new msg: " + str);

        } else if( num == MESSAGE_NEW_DLG_MSG )
        {
            g_msgToSendDLG = str;
            DEBUG_OUT("received a message which will be send to new user over Dlg");

        }else if( num == MESSAGE_NEW_DLG_HEADER )
        {
            g_headerMsgDLG = str;
            DEBUG_OUT("received a header for a dialog message");
        }else if( num == MESSAGE_CREDENTIALS ) 
        {
            DEBUG_OUT("New credentials received");
            parseCredentials(str);
        } else if( num == MESSAGE_START_SCANNING )
        {
            state start_sending;
        } else if( num == MESSAGE_SEND_TO_USER )
        {
            DEBUG_OUT(" --> NOTHING todo!!");
        } else if( num == MESSAGE_SEND_IM )
        {
            DEBUG_OUT("--> activate sending IM's");
            sendIMs = TRUE;
        } else if( num == MESSAGE_SHOW_DLG )
        {
            DEBUG_OUT("--> activate showing a dialog message");
            showDLG = TRUE;
        } else
        {
            DEBUG_OUT("Received a not nown message with number: " + (string)num);
        }
    }

    changed( integer change )
    {
        if( change == CHANGED_INVENTORY )
        {
            DEBUG_OUT("reset: send message script");
            llResetScript();
        }
    }
}

state start_sending
{
    state_entry()
    {
        DEBUG_OUT("start sending messages...");
    }

    link_message( integer sender_num, integer num, string str, key id )
    {
       if( num == MESSAGE_SEND_TO_USER && sendIMs == TRUE )
        {
            if( TestMode == FALSE ||
                TestModeSendingAllowed(id) == TRUE ) 
            {
                string strMsg = parseHeader(g_headerMsg, id) + "\n\n" + g_msgToSend;
                sendIM(id, strMsg);
            }

        } else if( num == MESSAGE_OPEN_DLG_FOR_USER && showDLG = TRUE )
        {
             if( TestMode == FALSE ||
                 TestModeSendingAllowed(id) == TRUE ) 
             {
                 DEBUG_OUT("Show a message dialog with options to: " + (string)id);
                 
                 // Create random channel within range [-1000000000,-2000000000]
                 DLGChannel = (integer)(llFrand(-1000000000.0) - 1000000000.0);
                
                 //open a listener
                 DLGHandle = llListen(DLGChannel, "", "", "");
                 
                 //start the dialog
                 string strMsg = parseHeader(g_headerMsgDLG, id) + "\n\n" + g_msgToSendDLG;
                 llDialog(id, strMsg, ["ACCEPT","DECLINE"], DLGChannel);
             }
             
        } else 
        {
            DEBUG_OUT("Received a not nown message with number: " + (string)num);
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        DEBUG_OUT("message rcved:" + message);
        
        if( message != "ACCEPT" )
        {
            DEBUG_OUT("wrong answer!");
            llTeleportAgentHome(id);
        }
        
        llListenRemove(DLGHandle);
        
    }

    changed( integer change )
    {
        if( change == CHANGED_INVENTORY )
        {
            DEBUG_OUT("reset: send message script");
            llResetScript();
        }
    }
}