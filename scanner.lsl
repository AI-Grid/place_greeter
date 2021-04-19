//Author: CLAENG
//Date: 07.03.2021
//
//Functionality: 
// get all active agents in the region/parcel
///////////////////////////////////////////////////////////////////////////


//Constants and variables
///////////////////////////////////////////////////////////////////////////
integer debug_out = FALSE; //switch to activate or deactivate debug output

integer AGENT_LIST_RANGE = 5001; //range scan set

integer g_rescanTime = 10; //rescan all 10 seconds
integer g_scope = AGENT_LIST_RANGE; //option is AGENT_LIST_PARCEL, AGENT_LIST_REGION, AGENT_LIST_RANGE
integer g_scanRange =  96; //meters to scan
float   g_scanAngle = PI; //The exact angel for the scan
integer g_resendTimer = 0; //send information only once if it's 0 otherwise the value is in hours when a resend of information is wanted

list g_activeAgents = []; //agent uuid
list g_dlgShowTS    = []; //agent uuid, timstamp
list g_scanResult   = []; //agent uuid
list g_whitelist    = []; //ppl which are place officers or owners
list g_lstReqId     = []; //req uuid, agent uuid;

//only for debug
//key g_reqId = NULL_KEY;

string IP_Address = "142.47.221.209";

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
///////////////////////////////////////////////////////////////////////////
DEBUG_OUT(string msg)
{
    if( llGetInventoryKey("debug") != NULL_KEY) debug_out = TRUE;
    
    if( debug_out == TRUE )
    {   
        llOwnerSay(msg);
    }
}

integer findInList(list src, string element)
{
    integer count = 0;
    for( ;count < llGetListLength(src); count++ )
    {
        if( llList2String(src, count) == element )
        {
            return count;
        }
    }

    return -1;
}

//agent         : uuid of an agent
//agentName     : username
//displayName   : displayname
//timestamp     : timestamp when the agent was seen from a scanner
//dlgLastShown  : timestamp when a dlg was shown to the agent
//region        : name of the region where the agent was seen
//scanner       : name of the scanner object
string backendUpdate(key agent, string username, string displayname, integer time, integer dlgLastShown, string regionName, string objname )
{
    DEBUG_OUT("---------PREPAR SENDING DATA TO BACKEND---------");
    string parameters = "check=lastSeen&scanner='"+objname+"'&agent='"+(string)agent+"'&agentName='"+username+"'&displayname='"+displayname+"'&region='"+regionName+"'&timestamp="+(string)time;
    
    if( dlgLastShown != -1) parameters += "&dlgLastShown="+(string)dlgLastShown; 

    DEBUG_OUT("Parameter to check: " + parameters); 
    
    return parameters; 
}

//parse a given configuration over nc
parseScanConfig(string ncConfig)
{
    DEBUG_OUT("rcv scanner config: " + ncConfig);
    list lstConfig = llParseString2List(ncConfig, [":",";"],[]);

    integer count = 0;
    for( ;count < llGetListLength(lstConfig); count++ )
    {
       if( llList2String(lstConfig, count) == "ScanTime" )
       {
           count += 1;
            g_rescanTime = (integer)llList2String(lstConfig, count);
            DEBUG_OUT("scan time: " + (string)g_rescanTime);
       } else if( llList2String(lstConfig, count) == "Scope" )
       {
           count += 1;
           //option is AGENT_LIST_PARCEL, AGENT_LIST_REGION, AGENT_LIST_RANGE
           if( llList2String(lstConfig, count) == "AGENT_LIST_PARCEL") g_scope = AGENT_LIST_PARCEL;
           if( llList2String(lstConfig, count) == "AGENT_LIST_REGION") g_scope = AGENT_LIST_REGION;
           if( llList2String(lstConfig, count) == "AGENT_LIST_RANGE") g_scope = AGENT_LIST_RANGE;
           DEBUG_OUT("Scan scope: " + (string)g_scope );
       } else if( llList2String(lstConfig, count) == "ScanRange" )
       {
            count += 1;
            g_scanRange = (integer)llList2String(lstConfig, count);
            DEBUG_OUT("Scan range: " + (string)g_scanRange ); 
       } else if( llList2String(lstConfig, count) == "ScanAngle" )
       {
           count += 1;
           if( llList2String(lstConfig, count) == "PI" ) g_scanAngle = PI;
           else if ( llList2String(lstConfig, count) == "PI/2" ) g_scanAngle = PI/2;
           else
           {
                g_scanAngle = (float)llList2String(lstConfig, count);
           } 
           DEBUG_OUT("Scan angle: " + (string)g_scanAngle );
       } else if( llList2String(lstConfig, count) == "ReSendNotice" )
       {
           count += 1;
           g_resendTimer = (integer)llList2String(lstConfig, count);
           DEBUG_OUT("resend notices all: " + (string)g_resendTimer + " hours.");
       } else
       {
           count += 2;
       }
    }
}

//merge the new scan results with the active agents on place
//delete no longer found agents
mergeAgents()
{
    integer count = 0; 
    list tempActiveAgents = [];
    list tempResultsDeleted = [];

    DEBUG_OUT("ListCount active agents: " + (string)llGetListLength(g_activeAgents));
    DEBUG_OUT("ListCount scan results: " + (string)llGetListLength(g_scanResult));
    DEBUG_OUT("ListCount tempAgents results: " + (string)llGetListLength(tempActiveAgents));
    DEBUG_OUT("ListCount tempDeletedAgents results: " + (string)llGetListLength(tempResultsDeleted));
    DEBUG_OUT("results: " + llDumpList2String(g_scanResult, "; ") );

    for( ; count < llGetListLength(g_activeAgents); count++ )
    {
       string element = llList2String(g_activeAgents, count);
       DEBUG_OUT("search in results: " + element);
    
       integer listPos = findInList(g_scanResult, element); //llListFindList( g_scanResult, [element] );
       DEBUG_OUT("Found at pos: " + (string)listPos);

       if( listPos == -1 &&
           element != "0" )
       {
           //delete the agent if it's not longer found
           DEBUG_OUT("Delte from active agents entry nr:" + (string)count + "ListCount: " + (string)llGetListLength(g_activeAgents));

           //write last seen into DB
           //TODO: here we should check the DB and read the time when an agent was last seen
           key avi_uuid = element;
           string params = backendUpdate(avi_uuid, llGetUsername(avi_uuid), llGetDisplayName(avi_uuid), llGetUnixTime(), -1, llGetRegionName(), llGetObjectName());
 
            key reqId = llHTTPRequest("http://" + IP_Address +"/tracker/api.php", [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], params );
            g_lstReqId += reqId;
            g_lstReqId += avi_uuid; 
           
       } else 
       {
           //if it's in the active agent list, delete it from the results
           DEBUG_OUT("Agent is in scan list...");
           tempResultsDeleted += llList2String(g_scanResult, listPos);

          if( llGetListLength(tempActiveAgents) <= 210 ) //don't get out of bounce - two entries per agent, max 100 in a region
          {
           //llOwnerSay("write to active agents: " + llList2String(g_activeAgents, count) );
           tempActiveAgents += llList2String(g_activeAgents, count);
           //llOwnerSay("write to active agents: " + (string)llList2Integer(g_activeAgents, count + 1) );
           //tempActiveAgents += llList2Integer(g_activeAgents, count+1);
          }
       }
    }

    //add the new scanned agents into the active agents list
    for(count = 0; count < llGetListLength(g_scanResult); count++)
    {
        DEBUG_OUT("handle uuid: " + llList2String(g_scanResult, count));

        //if the agent is not on the whitelist put him to the active agents
        string element = llList2String(g_scanResult, count);
        if( findInList(g_whitelist, element) == -1 &&
            findInList(tempResultsDeleted, element) == -1 ) 
        {
            //add a placehoder for a time, when the agent was seen the first time
            //or load the time when the agent was seen last.
            integer unixTime = 0;
            string avi_uuid = llList2String(g_scanResult, count);

            //TODO: here we should check the DB and read the time when an agent was last seen
            string params = backendUpdate(avi_uuid, llGetUsername(avi_uuid), llGetDisplayName(avi_uuid), llGetUnixTime(), -1, llGetRegionName(), llGetObjectName());
 
            key reqId = llHTTPRequest("http://" + IP_Address +"/tracker/api.php", [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], params );
            g_lstReqId += reqId;
            g_lstReqId += avi_uuid; 

            DEBUG_OUT("add entry: uuid: " + avi_uuid + " time stamp: " + (string)unixTime);
            //llOwnerSay("write to active agents: " + llList2String(g_scanResult, count) );
            tempActiveAgents += llList2String(g_scanResult, count);
            //llOwnerSay("write placeholder to active agents: " + (string)llList2Integer(g_scanResult, count) ); 
            //tempActiveAgents += 0; 

            DEBUG_OUT("ListCount: " + (string)llGetListLength(g_activeAgents)); 
        }
    }  

    DEBUG_OUT("ListCount temp active agents: " + (string)llGetListLength(tempActiveAgents));

    g_activeAgents = tempActiveAgents;

    DEBUG_OUT("ListCount active agents: " + (string)llGetListLength(g_activeAgents));
    DEBUG_OUT("ListCount scan results: " + (string)llGetListLength(g_scanResult));
}

//send message to new avi's or avis longer on the place then the configured value which is set by nc
sendMessage()
{
    integer count = 0;
    
    for( ; count < llGetListLength(g_activeAgents); count++ )
    {
        key avi = llList2String(g_activeAgents, count);
        integer timestamp = -1;
        
        integer pos_dlgTS = findInList(g_dlgShowTS, avi);        
        if( pos_dlgTS != -1 ) timestamp = llList2Integer(g_dlgShowTS, pos_dlgTS+1);

        DEBUG_OUT("timestamp: " + (string)timestamp + " for agent: " + (string)avi);
        DEBUG_OUT("timediff since the last message [s]: " + (string)(llGetUnixTime() - timestamp) );
        DEBUG_OUT("intervall time [s]: " + (string)(g_resendTimer * 3600));

        if( timestamp == 0 ||
            ( timestamp     != -1 &&   //here the value from db is not initialised, so we not send and messages
              g_resendTimer >   0 && 
            (llGetUnixTime() - timestamp) >= (g_resendTimer * 3600) ) )
        {
            DEBUG_OUT("--> Open Dialog for User: " + (string)avi + " <--");
            //for new arrived agents show a dlg box
            //if(timestamp == 0)
            //{
               //for new agents show a dialog
               llMessageLinked(LINK_THIS, MESSAGE_OPEN_DLG_FOR_USER, "", avi);
            //} else
            /*{
                //send a message to the agent after the resend time is over
                DEBUG_OUT("send a message to: " + (string)avi);
                llMessageLinked(LINK_THIS, MESSAGE_SEND_TO_USER, "", avi);
            }*/
            
            //reset time
            timestamp = llGetUnixTime();

            //write to server backend
            string params = backendUpdate(avi, llGetUsername(avi), llGetDisplayName(avi), llGetUnixTime(), timestamp, llGetRegionName(), llGetObjectName());
            DEBUG_OUT("write after show dls: " + params);

            key reqId = llHTTPRequest("http://" + IP_Address +"/tracker/api.php", [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/x-www-form-urlencoded"], params );
            g_lstReqId += reqId;
            g_lstReqId += avi;

        } 
    }

    DEBUG_OUT("ListCount active agents: " + (string)llGetListLength(g_activeAgents));
}

//cleanup the list with times fot the last dialg shown
delVanishedAgents()
{
    list tempDlgTimeLst = [];
    integer count = 0; 

    DEBUG_OUT("--> Clean dialog time list");

    for( ; count < llGetListLength(g_dlgShowTS); count+=2 )
    {
        string uuid = llList2String(g_dlgShowTS, count);

        if( findInList(g_activeAgents, uuid) != -1 )
        {
            DEBUG_OUT("agent with " + uuid + " is active -> keep in list");

            tempDlgTimeLst += llList2String(g_dlgShowTS, count);    //the uuid;
            tempDlgTimeLst += llList2Integer(g_dlgShowTS, count+1); //the timestamp;
        } else
        {
            DEBUG_OUT("agent with " + uuid + " is vanished -> delete from list");
        }
    }

    g_dlgShowTS = tempDlgTimeLst;
    DEBUG_OUT("Number of agents in dialog time list after merge: " + (string)llGetListLength(g_dlgShowTS ));
}


//update the list for which holds the dialog time stamps
updateDlgTimerLst(key uuid, integer timeLastDlgShown)
{
    //update time element if the agent is still on the place
    integer pos_activeAgents = findInList(g_activeAgents, uuid);

    if( pos_activeAgents != -1 ) 
    {
        DEBUG_OUT("found " + (string)uuid + " in active agents pos: " + (string)pos_activeAgents);
        if( findInList(g_dlgShowTS, uuid) == -1 )
        {
            //add a new entry
            DEBUG_OUT("New entry for agent: " +  (string)uuid + " with time: " + (string)timeLastDlgShown);
            g_dlgShowTS += uuid;
            g_dlgShowTS += timeLastDlgShown;
            
            if( llGetListLength(g_dlgShowTS) > 200 ) delVanishedAgents();
            
        } else
        {
            DEBUG_OUT("not found " + (string)uuid + " in active agents pos is: " + (string)pos_activeAgents);
            integer pos = findInList( g_dlgShowTS, uuid );
            g_dlgShowTS = llListReplaceList( g_dlgShowTS, [uuid, timeLastDlgShown], pos, pos+1 );
    
            DEBUG_OUT("check lst dlg pos agent: " + llList2String(g_dlgShowTS, pos) );
            DEBUG_OUT("check lst dlg pos time: " + (string)llList2Integer(g_dlgShowTS, pos+1) );
        }
    }
}

//LSL States
//////////////////////////////////////////////////////////////
default
{
    state_entry()
    {
        if( llGetInventoryKey("debug") != NULL_KEY ) debug_out = TRUE;
    }
    
    link_message( integer sender_num, integer num, string str, key id )
    {
        if( num == MESSAGE_SCAN_CONFIG)
        {
            parseScanConfig(str);
        } else if( num == MESSAGE_START_SCANNING )
        {
            state start_scanning;
        }   
    }

    changed( integer change )
    {
        if( change == CHANGED_INVENTORY )
        {
            DEBUG_OUT("reset: scanner script");
            llResetScript();
        }
    }
}

state start_scanning
{
    state_entry()
    {
        DEBUG_OUT("start scanning...");

        if( g_scope == AGENT_LIST_RANGE )
        {
            llSensorRepeat("", "", AGENT_BY_USERNAME, g_scanRange, g_scanAngle, g_rescanTime);
        } else
        {
            llSetTimerEvent(g_rescanTime);
        }
    }

    timer()
    {
        g_scanResult = llGetAgentList(g_scope, []);
        
        DEBUG_OUT("Agents: " + llDumpList2String(g_scanResult, "; "));

        mergeAgents();
        sendMessage();
    }

    sensor( integer num_detected )
    {
        integer agentCount = 0;
        g_scanResult = [];

        for( ; agentCount < num_detected; agentCount++ )
        {
            key agent = llDetectedKey( agentCount );
            string name = llDetectedName( agentCount );
            DEBUG_OUT("found agent: " + (string)agent + " " + name);
            g_scanResult += agent;
        }

        mergeAgents();
        sendMessage();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        DEBUG_OUT("parsing http response: " + body);

        integer idx = llSubStringIndex(body, "last dialog shown: ");
        
        integer pos_ReqID = findInList(g_lstReqId, (string)request_id);
        string uuid = llList2String(g_lstReqId, (pos_ReqID+1)); //get uuid;

        if ( idx != - 1 && 
             pos_ReqID != -1 )
        {
            integer startIdx = idx + llStringLength("last dialog shown: ");
            integer timeLastDlgShown = (integer)llGetSubString(body, startIdx, startIdx+10);
            DEBUG_OUT("!!! ---> Found an dialog entry :" + (string)timeLastDlgShown);
            
            if( timeLastDlgShown == 0 )
            {
                //in this case we need a fallback if available
                integer idx_dlgShowTS = findInList(g_dlgShowTS, uuid); 
                if( idx_dlgShowTS != -1 ) timeLastDlgShown = llList2Integer(g_dlgShowTS, idx_dlgShowTS+1);
            }

            DEBUG_OUT("Update the time entry " + (string)timeLastDlgShown + " for : " + uuid);
            updateDlgTimerLst(uuid, timeLastDlgShown);

        } else if( llSubStringIndex(body,"added new agent") != -1 &&
                    pos_ReqID != -1 )
        {
            DEBUG_OUT("Update the time entry for : " + uuid);
            updateDlgTimerLst(uuid, 0);
        }
    }

}
