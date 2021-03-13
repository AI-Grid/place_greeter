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

list g_activeAgents = [];
list g_scanResult = [];
list g_whitelist = []; //ppl which are place officers or owners

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
    DEBUG_OUT("results: " + llDumpList2String(g_scanResult, "; ") );

    for( ; count < llGetListLength(g_activeAgents); count+=2 )
    {
       string element = llList2String(g_activeAgents, count);
       DEBUG_OUT("search in results: " + element);
    
       integer listPos = findInList(g_scanResult, element); //llListFindList( g_scanResult, [element] );
       DEBUG_OUT("Found at pos: " + (string)listPos);

       if( listPos == -1 )
       {
           //delete the agent if it's not longer found
           DEBUG_OUT("Delte from active agents entry nr:" + (string)count + "ListCount: " + (string)llGetListLength(g_activeAgents));
           
       } else 
       {
           //if it's int the active agent list, delte it from the results
           tempResultsDeleted += llList2String(g_scanResult, listPos);

          if( llGetListLength(tempActiveAgents) <= 99 ) //don't get out of bounce;
          {
           tempActiveAgents += llList2String(g_activeAgents, count);
           tempActiveAgents += llList2Integer(g_activeAgents, count+1);
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
            //add a time, when the agent was seen the first time
            integer unixTime = 0;
            string avi_uuid = llList2String(g_scanResult, count);

            DEBUG_OUT("add entry: uuid: " + avi_uuid + " time stamp: " + (string)unixTime);
            tempActiveAgents += llList2String(g_scanResult, count);
            tempActiveAgents += llList2Integer(g_scanResult, count+1);

            DEBUG_OUT("ListCount: " + (string)llGetListLength(g_activeAgents));
        }
    }

    DEBUG_OUT("ListCount temp active agents: " + (string)llGetListLength(tempActiveAgents));

    g_activeAgents = tempActiveAgents;

    DEBUG_OUT("ListCount active agents: " + (string)llGetListLength(g_activeAgents));
    DEBUG_OUT("ListCount scan results: " + (string)llGetListLength(g_scanResult));
}

//send message to new avi's or avis longer on the place then 2 hours
sendMessage()
{
    integer count = 0;
    list tempActiveAgents = [];

    for( ; count < llGetListLength(g_activeAgents); count+=2 )
    {
        key avi = llList2String(g_activeAgents, count);
        integer timeStamp = llList2Integer(g_activeAgents, count+1);

        tempActiveAgents += avi;

        if( timeStamp == 0 ||
            ( g_resendTimer > 0 && 
            (timeStamp - llGetUnixTime()) >= (g_resendTimer * 3600) ) )
        {
            //for new arrived agents show a dlg box
            if(timeStamp == 0)
            {
               //for new agents show a dialog
               llMessageLinked(LINK_THIS, MESSAGE_OPEN_DLG_FOR_USER, "", avi);
            } else
            {
                //send a message to the agent after the resend time is over
                DEBUG_OUT("send a message to: " + (string)avi);
                llMessageLinked(LINK_THIS, MESSAGE_SEND_TO_USER, "", avi);
            }
            
            //reset time
            timeStamp = llGetUnixTime();        
        } 
        //write back time
        tempActiveAgents += timeStamp;
    }

    g_activeAgents = tempActiveAgents;
    DEBUG_OUT("ListCount active agents: " + (string)llGetListLength(g_activeAgents));
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

}
