
//Author: CLAENG
//Date: 07.03.2021
//
//Functionality: 
// initialise messages from NC for IM and Dialog output
///////////////////////////////////////////////////////////////////////////

//Constants and Variables
//////////////////////////////////////////////////////////////////////////
integer debug_out = FALSE; //switch to activate or deactivate debug output

string g_nc_name                = "Greetings";
integer g_nc_lineNumber         = 0;
key g_nc_message_handle         = NULL_KEY;

string g_nc_dlg_name            = "Greetings_DLG";
integer g_nc_dlg_lineNumber     = 0;
key g_nc_dlg_message_handle     = NULL_KEY;

string g_nc_scan_config         = "ScannerConfig";
integer g_nc_scan_lineNumber    = 0;
key g_nc_scan_handle            = NULL_KEY;

string g_nc_credentials_name    = "Credentials";
integer g_nc_cred_lineNumber    = 0;
key g_nc_cred_handle            = NULL_KEY;

string g_headerMsg      = "";
string g_username       = "";
string g_msgToSend      = ""; 
string g_headerMsgDLG   = "";
string g_msgDlgToSend   = "";
string g_credentials    = "";
string g_scanConfig     = ""; 

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

//Functions
//////////////////////////////////////////////////////////////////////////
DEBUG_OUT(string msg)
{
    if( debug_out == TRUE )
    {   
        llOwnerSay(msg);
    }
}

checkAndReadNotecard(string nc_name)
{
    DEBUG_OUT("Start reading nc: " + nc_name);

    if( llGetInventoryKey(nc_name) == NULL_KEY )
    {
        if( nc_name == "g_nc_credentials_name" ) 
        {
            DEBUG_OUT("NOW");
            llMessageLinked(LINK_THIS, MESSAGE_START_SCANNING,"",NULL_KEY);
        }

        DEBUG_OUT("No nc found with name: " + nc_name);
        return;
    } 

    if( nc_name == g_nc_name )
    {
        g_nc_message_handle = llGetNotecardLine(g_nc_name, g_nc_lineNumber);
    } else if( nc_name == g_nc_dlg_name )
    {
        g_nc_dlg_message_handle = llGetNotecardLine(g_nc_dlg_name, g_nc_dlg_lineNumber);
    } else if( nc_name == g_nc_scan_config )
    {
        g_nc_scan_handle = llGetNotecardLine(g_nc_scan_config, g_nc_scan_lineNumber);
    } else if( nc_name == g_nc_credentials_name )
    {
        g_nc_cred_handle = llGetNotecardLine(g_nc_credentials_name, g_nc_cred_lineNumber);
    }
}

//LSL Runtime States
///////////////////////////////////////////////////////////////////////////

default
{
    state_entry()
    {  
        if( llGetInventoryKey("debug") != NULL_KEY ) debug_out = TRUE;
        
        DEBUG_OUT("Start reading nc's");
        checkAndReadNotecard(g_nc_name);
    }
    
    dataserver(key query_id, string data)
    {
        if (query_id == g_nc_message_handle)
        {
            if (data == EOF)
            {
                DEBUG_OUT("No more lines in notecard, read " + (string) g_nc_lineNumber + " lines.");
                //inform the other scripts
                DEBUG_OUT("send message: " + g_msgToSend);
                llMessageLinked(LINK_THIS, MESSAGE_NEW_IM_MSG, g_msgToSend, NULL_KEY);
                checkAndReadNotecard(g_nc_dlg_name);
            }
            else
            {
                DEBUG_OUT("Line " + (string) g_nc_lineNumber + ": " + data);
                if( llSubStringIndex(data,"SEND_IM") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("SEND_IM"));
                    if( data == "YES" ) llMessageLinked(LINK_THIS, MESSAGE_SEND_IM, "", NULL_KEY);
                    
                } else if( llSubStringIndex(data,"HEADER") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("HEADER"));
                    //read the Header from the first line in the nc
                    g_headerMsg += data;

                    DEBUG_OUT("send header: " + g_headerMsg);
                    llMessageLinked(LINK_THIS, MESSAGE_NEW_HEADER, g_headerMsg, NULL_KEY);
                } else if( llSubStringIndex(data,"MESSAGE") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("MESSAGE"));
                    g_msgToSend += data + "\n";
                                        
                } else
                {
                    //add the data to the message which should be send at the end
                    g_msgToSend += data + "\n";
                }

                //increment line index first, both for line number reporting, and for reading the next line
                ++g_nc_lineNumber;
                
                g_nc_message_handle = llGetNotecardLine(g_nc_name, g_nc_lineNumber);
            }
        } else if( query_id == g_nc_dlg_message_handle )
        {
            if (data == EOF)
            {
                DEBUG_OUT("No more lines in notecard, read " + (string) g_nc_dlg_lineNumber + " lines.");
                //inform the other scripts
                DEBUG_OUT("send message for dialog: " + g_msgDlgToSend);
                llMessageLinked(LINK_THIS, MESSAGE_NEW_DLG_MSG, g_msgDlgToSend, NULL_KEY);
                checkAndReadNotecard(g_nc_scan_config);
            }
            else
            {
                DEBUG_OUT("Line " + (string) g_nc_dlg_lineNumber + ": " + data);
                if( llSubStringIndex(data,"SHOW_DLG") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("SEND_IM"));
                    if( data == "YES" ) llMessageLinked(LINK_THIS, MESSAGE_SHOW_DLG, "", NULL_KEY);
                    
                } else if( llSubStringIndex(data,"HEADER") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("HEADER"));
                    //read the Header from the first line in the nc
                    g_headerMsgDLG += data;

                    DEBUG_OUT("send header: " + g_headerMsgDLG);
                    llMessageLinked(LINK_THIS, MESSAGE_NEW_DLG_HEADER, g_headerMsgDLG, NULL_KEY);
                } else if( llSubStringIndex(data,"MESSAGE") != -1 )
                {
                    data = llDeleteSubString(data, 0, llStringLength("MESSAGE"));
                    g_msgDlgToSend += data + "\n";
                                        
                } else
                {
                    //add the data to the message which should be send at the end
                    g_msgDlgToSend += data + "\n";
                }

                //increment line index first, both for line number reporting, and for reading the next line
                ++g_nc_dlg_lineNumber;
                
                g_nc_dlg_message_handle = llGetNotecardLine(g_nc_dlg_name, g_nc_dlg_lineNumber);
            }

        } else if( query_id == g_nc_scan_handle )
        {
            if (data == EOF)
            {     
                DEBUG_OUT("No more lines in notecard, read " + (string) g_nc_scan_lineNumber + " lines.");
                DEBUG_OUT("Send following objetc: " + g_scanConfig);
                //inform the other scripts
                llMessageLinked(LINK_THIS, MESSAGE_SCAN_CONFIG, g_scanConfig, NULL_KEY);
                checkAndReadNotecard(g_nc_credentials_name);
            }
            else
            {
                DEBUG_OUT("Line " + (string) g_nc_scan_config + ": " + data);

                //increment line index first, both for line number reporting, and for reading the next line
                ++g_nc_scan_lineNumber;
                
                //add the data to the message which should be send at the end
                g_scanConfig += data;
                g_scanConfig += ";";
                
                g_nc_scan_handle = llGetNotecardLine(g_nc_scan_config, g_nc_scan_lineNumber);
            }

        } else if( query_id == g_nc_cred_handle )
        {
            if (data == EOF)
            {     
                DEBUG_OUT("No more lines in notecard, read " + (string) g_nc_cred_lineNumber + " lines.");
                //DEBUG_OUT("Send following objetc: " + g_credentials);
                //inform the other scripts
                llMessageLinked(LINK_THIS, MESSAGE_CREDENTIALS, g_credentials, NULL_KEY);
                //DEBUG_OUT("NOW");
                llMessageLinked(LINK_THIS, MESSAGE_START_SCANNING,"",NULL_KEY);
            }
            else
            {
                //DEBUG_OUT("Line " + (string) g_nc_cred_lineNumber + ": " + data);

                //increment line index first, both for line number reporting, and for reading the next line
                ++g_nc_cred_lineNumber;
                
                //add the data to the message which should be send at the end
                g_credentials += data;
                g_credentials += ";";
                
                g_nc_cred_handle = llGetNotecardLine(g_nc_credentials_name, g_nc_cred_lineNumber);
            }
        }
    }

    changed( integer change ) 
    {
        DEBUG_OUT("nc init script ");
        if( change == CHANGED_INVENTORY )
        {
            DEBUG_OUT("reset: nc init script");
            llResetScript();
        }
    }
    
    on_rez(integer start_param)
    {
        // Restarts all scripts when the object is rezzed
        llResetOtherScript("scan_area");
        llResetOtherScript("sendMessage");
        llResetScript(); 
    }
}