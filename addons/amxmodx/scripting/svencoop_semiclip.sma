#include <amxmodx>

#include <orpheu>
#include <orpheu_advanced>
#include <fakemeta>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
// ** COMPILER OPTIONS **

// Adjust as needed
// Enable if you want to use an alternative Ham entry to trick AMXX into hooking the desired virtual constant
// You must provide an UNUSED Ham entry, and it must be properly defined in your hamdata.ini file
// This compiler option has no effect on newer AMXX version (1.9+) due to these virtual constants actually existing
#define HAM_SWAP_TRICK   			true

// Ham defines, change as needed.
#define Ham_SC_GetClassification    Ham_TS_ShouldCollide
#define Ham_SC_Player_IsConnected   Ham_TS_OnFreeEntPrivateData
#endif

// ** COMPILER OPTIONS END HERE **

#pragma dynamic                     32768
#pragma semicolon                   1

#define PLUGIN_NAME                 "Sven Co-op Semiclip"
#define PLUGIN_VERSION              "1.3.0-25w23a"
#define PLUGIN_AUTHOR               "szGabu"

#define CLOCK_TASKID                22222

#define CALLIBRATION                1 //do not change this unless you know what are you doing

#define SC_CLASS_NONE               0
#define SC_CLASS_MACHINE            1
#define SC_CLASS_PLAYER             2
#define SC_CLASS_PLAYER_ALLY        3
#define SC_CLASS_HUMAN_PASSIVE      4
#define SC_CLASS_HUMAN_MILITARY     5
#define SC_CLASS_ALIEN_PASSIVE      6
#define SC_CLASS_ALIEN_MILITARY     7
#define SC_CLASS_ALIEN_MONSTER      8
#define SC_CLASS_ALIEN_PREY         9
#define SC_CLASS_ALIEN_PREDATOR     10
#define SC_CLASS_INSECT             11
#define SC_CLASS_PLAYER_BIOWEAPON   12
#define SC_CLASS_ALIEN_BIOWEAPON    13
#define SC_CLASS_RACE_X_PITDRONE    14
#define SC_CLASS_RACE_X_SHOCKTR     15
#define SC_CLASS_TEAM_A             16
#define SC_CLASS_TEAM_B             17
#define SC_CLASS_TEAM_C             18
#define SC_CLASS_TEAM_D             19

#if AMXX_VERSION_NUM < 183
#define MAX_PLAYERS                 32
#define MaxClients                  get_maxplayers()
#define __BINARY__                  "svencoop_semiclip.amxx"
#define get_pcvar_bool(%1) 	        (get_pcvar_num(%1) == 1)
#endif

#define IsValidUserIndex(%1)        (1 <= (%1) <= MaxClients)

//functions
new OrpheuFunction:g_hShouldBypassEntityFunction, OrpheuFunction:g_hPlayerMoveFunction, OrpheuFunction:g_hTestEntityPositionFunction;
new OrpheuHook:g_hookShouldBypassEntityPre, OrpheuHook:g_hookTestEntityPositionPre, OrpheuHook:g_hookTestEntityPositionPost;
new g_cvarEnabled, g_cvarPassthroughSpeed;

//declare these as globals, to avoid creating new variables in performance critical functions
new bool:g_bValidUser[MAX_PLAYERS+1] = { false, ... };
new g_iOriginalGroupInfo[MAX_PLAYERS+1] = { -1, ... };
new g_iPluginFlags;

new Float:g_fPassthroughSpeed;

//this should work?
const OrpheuStruct:InvalidOrpheuStruct = OrpheuStruct:0;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_semiclip_enabled", "1");
    g_cvarPassthroughSpeed = register_cvar("amx_semiclip_passthrough_speed", "500.0");
    register_cvar("amx_semiclip_version", PLUGIN_VERSION, FCVAR_SERVER);

    g_iPluginFlags = plugin_flags();
}

public plugin_end()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s.amxx::plugin_end() - Called", __BINARY__);

    if(task_exists(CLOCK_TASKID))
        remove_task(CLOCK_TASKID);
        
    if(g_hookShouldBypassEntityPre)
        OrpheuUnregisterHook(g_hookShouldBypassEntityPre);

    if(g_hookTestEntityPositionPre)
        OrpheuUnregisterHook(g_hookTestEntityPositionPre);

    if(g_hookTestEntityPositionPost)
        OrpheuUnregisterHook(g_hookTestEntityPositionPost);

    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] %s.amxx::plugin_end() - Unhooked", __BINARY__);
}

public plugin_cfg()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[DEBUG] svencoop_semiclip.amxx::plugin_cfg() - Called");

    g_hShouldBypassEntityFunction = OrpheuGetFunction("SC_ShouldBypassEntity");
    g_hPlayerMoveFunction = OrpheuGetFunction("PM_GetPlayerMove");
    g_hTestEntityPositionFunction = OrpheuGetFunction("SV_TestEntityPosition");

    if(get_pcvar_bool(g_cvarEnabled))
    {
        g_hookShouldBypassEntityPre = OrpheuRegisterHook(g_hShouldBypassEntityFunction,"SC_ShouldBypassEntityPre");
        g_hookTestEntityPositionPre = OrpheuRegisterHook(g_hTestEntityPositionFunction,"EntityPositionPre");
        g_hookTestEntityPositionPost = OrpheuRegisterHook(g_hTestEntityPositionFunction,"EntityPositionPost", OrpheuHookPost);

        register_forward(FM_AddToFullPack, "AddToFullPack_Post", true);
        register_forward(FM_PlayerPreThink, "Player_PreThink");
        register_forward(FM_PlayerPostThink, "Player_PostThink");

        g_fPassthroughSpeed = get_pcvar_float(g_cvarPassthroughSpeed);
    }
}

public client_disconnect(iClient)
{
    g_bValidUser[iClient] = false;
}

public client_putinserver(iClient)
{
    g_bValidUser[iClient] = true;
}

public Player_PreThink(iClient)
{
    // we need to make the player not solid on a player prethink to fix a bug 
    // where a player isn't able to stand up if they're crouched inside another player
    // unfortunately, this is needed, there's no way around it
    if(g_bValidUser[iClient] && is_user_connected2(iClient) && is_user_alive(iClient))
    {
        new iFlags = pev(iClient, pev_flags);
        new iClientButton = pev(iClient, pev_button);
        if(iFlags & FL_DUCKING && ((iClientButton & IN_DUCK) == 0)/*  && pev(id, pev_oldbuttons) & IN_DUCK */)
        {
            for(new iOther=1; iOther <= MaxClients; iOther++)
            {
                if(iClient == iOther || !g_bValidUser[iOther] || !is_user_connected2(iOther) || !is_user_alive(iOther))
                    continue;

                if(IsColliding(iClient, iOther))
                {
                    new Float:fClientAbsMin[3], Float:fClientAbsMax[3];
                    new Float:fOtherAbsMin[3], Float:fOtherAbsMax[3];
                    new Float:fClientVelocity[3];
                    pev(iClient, pev_velocity, fClientVelocity);
                    pev(iClient, pev_absmin, fClientAbsMin);
                    pev(iClient, pev_absmax, fClientAbsMax);
                    pev(iOther, pev_absmin, fOtherAbsMin);
                    pev(iOther, pev_absmax, fOtherAbsMax);

                    if((fClientAbsMin[2]+CALLIBRATION >= fOtherAbsMax[2] && fClientVelocity[2] < g_fPassthroughSpeed) || (fOtherAbsMin[2]+CALLIBRATION >= fClientAbsMax[2]))
                        continue;
                    else
                        set_pev(iOther, pev_solid, SOLID_NOT);
                }
            }
        }
    }
}

public Player_PostThink(iClient)
{
    // continuation of previous function
    if(g_bValidUser[iClient] && is_user_connected2(iClient) && is_user_alive(iClient))
    {
        for(new iOther=1; iOther <= MaxClients;iOther++)
        {
            if(iClient == iOther || !g_bValidUser[iOther] || !is_user_connected2(iOther) || !is_user_alive(iOther))
                continue;

            if(pev(iOther, pev_solid) == SOLID_NOT)
                set_pev(iOther, pev_solid, SOLID_SLIDEBOX);
        }
    }
}

public OrpheuHookReturn:SC_ShouldBypassEntityPre(hPtr, hPhys)
{
    new iOther = OrpheuGetParamStructMember(2, "player"); //2 = hPhys
    if(IsValidUserIndex(iOther) && g_bValidUser[iOther] && is_user_connected2(iOther))
    {
        new OrpheuStruct:hPpMove = OrpheuGetStructFromAddress(OrpheuStructPlayerMove, OrpheuCall(g_hPlayerMoveFunction));
        if(hPpMove != InvalidOrpheuStruct)
        {
            new iClient = OrpheuGetStructMember(hPpMove, "player_index") + 1;
        
            if(IsValidUserIndex(iClient) && g_bValidUser[iClient] && is_user_connected2(iClient) && ArePlayersAllied(iClient, iOther))
            {
                new iClientFlags = pev(iClient, pev_flags);
                new iOtherFlags = pev(iOther, pev_flags);
                new iClientMoveType = pev(iClient, pev_movetype);
                new iOtherMoveType = pev(iOther, pev_movetype);

                if((iOtherFlags & FL_DORMANT) > 0 || 
                    iOtherMoveType == MOVETYPE_FLY || 
                    (iClientFlags & FL_DORMANT) > 0 || 
                    iClientMoveType == MOVETYPE_FLY)
                {
                    // MOVETYPE_FLY refers to people being in ladders while FL_DORMANT provides support 
                    // for my Sven Co-op Nextmapper & Anti-Rush plugin
                    OrpheuSetReturn(true);
                    return OrpheuSupercede;
                }

                new Float:fClientAbsMin[3], Float:fClientAbsMax[3];
                new Float:fOtherAbsMin[3], Float:fOtherAbsMax[3];
                new Float:fOtherVelocity[3];
                pev(iClient, pev_absmin, fClientAbsMin);
                pev(iClient, pev_absmax, fClientAbsMax);
                pev(iOther, pev_velocity, fOtherVelocity);
                pev(iOther, pev_absmin, fOtherAbsMin);
                pev(iOther, pev_absmax, fOtherAbsMax);

                if((fClientAbsMin[2]+CALLIBRATION >= fOtherAbsMax[2] && 
                    fOtherVelocity[2] < g_fPassthroughSpeed) || 
                    (fOtherAbsMin[2]+CALLIBRATION >= fClientAbsMax[2]))
                    return OrpheuIgnored;

                OrpheuSetReturn(true);
                return OrpheuSupercede;
            }
        }
    }

    return OrpheuIgnored;
}

public OrpheuHookReturn:EntityPositionPre(iOther)
{
    // proto
    // it should be more efficient
    // but sadly, when applying this only to
    // iOther doesn't work, you're welcome to try to fix it!
    // pull requests are open
    for(new iClient=1; iClient <= MaxClients; iClient++)
    {
        if(g_bValidUser[iClient] && is_user_connected2(iClient) && is_user_alive(iClient))
        {
            // we need to save the player's original groupinfo 
            // in cases where a custom map might be also manipulating it
            // for example: they hunger cutscenes
            g_iOriginalGroupInfo[iClient] = pev(iClient, pev_groupinfo); 
            set_pev(iClient, pev_groupinfo, PlayerIdToBit(iClient));
        }
    }

    return OrpheuIgnored;
}

public OrpheuHookReturn:EntityPositionPost(iOther)
{ 
    // ditto
    for(new iClient=1; iClient <= MaxClients; iClient++)
    {
        if(g_bValidUser[iClient] && is_user_connected2(iClient) && is_user_alive(iClient))
        {
            set_pev(iClient, pev_groupinfo, g_iOriginalGroupInfo[iClient]);
            g_iOriginalGroupInfo[iClient] = -1;
        }
    }

    return OrpheuIgnored;
}

public AddToFullPack_Post(hEntState, iEnt, iEdictEnt, iEdictHost, iHostFlags, iPlayer, pSet) 
{	
    if(iEdictHost != iEdictEnt && 
        IsValidUserIndex(iEdictEnt) &&
        IsValidUserIndex(iEdictHost) &&
        g_bValidUser[iEdictEnt] &&
        g_bValidUser[iEdictHost] &&
        is_user_connected2(iEdictEnt) && 
        is_user_connected2(iEdictHost) && 
        is_user_alive(iEdictHost) &&
        is_user_alive(iEdictEnt) && 
        ArePlayersAllied(iEdictHost, iEdictEnt))
    {
        new iClientFlags = pev(iEdictHost, pev_flags);
        new iOtherFlags = pev(iEdictEnt, pev_flags);
        new iClientMoveType = pev(iEdictHost, pev_movetype);
        new iOtherMoveType = pev(iEdictEnt, pev_movetype);
        
        if((iOtherFlags & FL_DORMANT) > 0 || 
            iOtherMoveType == MOVETYPE_FLY || 
            (iClientFlags & FL_DORMANT) > 0 || 
            iClientMoveType == MOVETYPE_FLY)
            return FMRES_IGNORED;

        new Float:fClientAbsMin[3], Float:fClientAbsMax[3];
        new Float:fOtherAbsMin[3], Float:fOtherAbsMax[3];
        new Float:fClientVelocity[3];
        pev(iEdictHost, pev_velocity, fClientVelocity);
        pev(iEdictHost, pev_absmin, fClientAbsMin);
        pev(iEdictHost, pev_absmax, fClientAbsMax);
        pev(iEdictEnt, pev_absmin, fOtherAbsMin);
        pev(iEdictEnt, pev_absmax, fOtherAbsMax);

        if((fClientAbsMin[2]+CALLIBRATION >= fOtherAbsMax[2] && 
            fClientVelocity[2] < g_fPassthroughSpeed) || 
            (fOtherAbsMin[2]+CALLIBRATION >= fClientAbsMax[2]))
            set_es(hEntState, ES_Solid, 1);
        else
            set_es(hEntState, ES_Solid, 0);

        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

stock bool:IsColliding(iThis, iOther)
{
    new Float:cMin[3], Float:cMax[3], Float:oMin[3], Float:oMax[3];
    pev(iThis, pev_absmin, cMin);
    pev(iThis, pev_absmax, cMax);
    pev(iOther, pev_absmin, oMin);
    pev(iOther, pev_absmax, oMax);

    // if *any* axis doesn’t overlap, there’s no collision
    if (cMax[0] < oMin[0] || cMin[0] > oMax[0]) return false; // x‐axis gap
    if (cMax[1] < oMin[1] || cMin[1] > oMax[1]) return false; // y‐axis
    if (cMax[2] < oMin[2] || cMin[2] > oMax[2]) return false; // z‐axis

    return true;  // all axes overlap
}

stock bool:ArePlayersAllied(const iClient1, const iClient2)
{
    #if AMXX_VERSION_NUM < 183
    // sadly Ham_SC_GetClassification is only available in later AMXX versions
    // for this case we can only return true and no support for bm_sts or similar
    #pragma unused iClient1
    #pragma unused iClient2
    return true;
    #else
    if(is_user_connected2(iClient1) && is_user_connected2(iClient2))
    {
        //Ham (Or maybe SC) incorrectly asks for a second parameter, it doesn't matter the value you pass
        return ExecuteHam(Ham_SC_GetClassification, iClient1, SC_CLASS_NONE) == ExecuteHam(Ham_SC_GetClassification, iClient2, SC_CLASS_NONE);
    }
    else
        return false;
    #endif
}

stock PlayerIdToBit(const iClient)
{
    //thanks anggaranothing
	return ( 1<<( iClient & 31 ) );
}

stock bool:is_user_connected2(iClient)
{
    #if AMXX_VERSION_NUM < 183 
    //ditto
    return is_user_connected(iClient) == 1;
    #else
    if(IsValidUserIndex(iClient) && pev_valid(iClient) == 2)
        return ExecuteHam(Ham_SC_Player_IsConnected, iClient) == 1;
    else
        return false;
    #endif
}