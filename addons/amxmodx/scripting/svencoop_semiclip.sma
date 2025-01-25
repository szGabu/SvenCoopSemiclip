#include <amxmodx>

#if AMXX_VERSION_NUM < 183
#assert "AMX Mod X versions 1.8.2 and below are not supported."
#endif

#include <orpheu>
#include <orpheu_advanced>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_NAME                 "Sven Co-op Semiclip"
#define PLUGIN_VERSION              "1.3-25w4a"
#define PLUGIN_AUTHOR               "szGabu"

#define CLOCK_TASKID                22222

#define CALLIBRATION                2 //do not change this unless you know what are you doing

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

#pragma dynamic                     32768
#pragma semicolon                   1

#define IsValidUserIndex(%1) (1 <= (%1) <= MaxClients)

//functions
new OrpheuFunction:g_hShouldBypassEntityFunction, OrpheuFunction:g_hPlayerMoveFunction, OrpheuFunction:g_hTestEntityPositionFunction;
new OrpheuHook:g_hookShouldBypassEntityPre, OrpheuHook:g_hookTestEntityPositionPre, OrpheuHook:g_hookTestEntityPositionPost;
new g_cvarEnabled, g_cvarCacheSpeed, g_cvarPassthroughSpeed;

//declare these as globals, to avoid creating new variables in performance critical functions
new g_iOriginalGroupInfo[MAX_PLAYERS+1] = { -1, ... };
new bool:g_bClientValid[MAX_PLAYERS+1] = { false, ...};
new bool:g_bClientAlive[MAX_PLAYERS+1] = { false, ...};
new g_iClientButton[MAX_PLAYERS+1] = { 0, ... };
new g_iClientFlags[MAX_PLAYERS+1] = { 0, ... };
new g_iClientMoveType[MAX_PLAYERS+1] = { 0, ... };
new g_iClientClassification[MAX_PLAYERS+1] = { SC_CLASS_PLAYER, ... };

new Float:g_fClientAbsMin[MAX_PLAYERS+1][3] = { 
    {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}
};

new Float:g_fClientAbsMax[MAX_PLAYERS+1][3] = { 
    {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}
};

new Float:g_fClientVelocity[MAX_PLAYERS+1][3] = { 
    {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}
};

new g_iPluginFlags;

new Float:g_fCacheSpeed;
new Float:g_fPassthroughSpeed;

//this should work?
const OrpheuStruct:InvalidOrpheuStruct = OrpheuStruct:0;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_semiclip_enabled", "1");
    g_cvarCacheSpeed = register_cvar("amx_semiclip_cache_speed", "0.1");
    g_cvarPassthroughSpeed = register_cvar("amx_semiclip_passthrough_speed", "500.0");
    register_cvar("amx_semiclip_version", PLUGIN_VERSION, FCVAR_SERVER);

    g_iPluginFlags = plugin_flags();
}

public plugin_end()
{
    if(task_exists(CLOCK_TASKID))
        remove_task(CLOCK_TASKID);

    for(new iClient=1; iClient <= MaxClients; iClient++)
        g_bClientValid[iClient] = false;

    if(g_hookShouldBypassEntityPre)
        OrpheuUnregisterHook(g_hookShouldBypassEntityPre);

    if(g_hookTestEntityPositionPre)
        OrpheuUnregisterHook(g_hookTestEntityPositionPre);

    if(g_hookTestEntityPositionPost)
        OrpheuUnregisterHook(g_hookTestEntityPositionPost);
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
        g_fCacheSpeed = get_pcvar_float(g_cvarCacheSpeed);

        set_task(g_fCacheSpeed, "Task_Clock", CLOCK_TASKID, _, _, "b");
    }
}

public Task_Clock()
{
    for(new iClient=1; iClient <= MaxClients; iClient++)
    {
        if(is_user_connected(iClient) && pev_valid(iClient) == 2)
        {
            g_bClientValid[iClient] = true;
            g_iClientFlags[iClient] = pev(iClient, pev_flags);
            g_iClientButton[iClient] = pev(iClient, pev_button);
            //Ham (Or maybe SC) incorrectly asks for a second parameter, it doesn't matter the value you pass
            g_iClientClassification[iClient] = ExecuteHam(Ham_SC_GetClassification, iClient, SC_CLASS_NONE);
            g_bClientAlive[iClient] = is_user_alive(iClient) == 1;
            g_iClientMoveType[iClient] = pev(iClient, pev_movetype);
            pev(iClient, pev_absmin, g_fClientAbsMin[iClient]);
            pev(iClient, pev_absmax, g_fClientAbsMax[iClient]);
            pev(iClient, pev_velocity, g_fClientVelocity[iClient]);
        }
        else
        {
            g_bClientValid[iClient] = false;
            g_iClientFlags[iClient] = 0;
            g_iClientButton[iClient] = 0;
            g_iClientClassification[iClient] = 0;
            g_bClientAlive[iClient] = false;
            g_iClientMoveType[iClient] = 0;
            g_fClientAbsMin[iClient][0] = 0.0;
            g_fClientAbsMin[iClient][1] = 0.0;
            g_fClientAbsMin[iClient][2] = 0.0;
            g_fClientAbsMax[iClient][0] = 0.0;
            g_fClientAbsMax[iClient][1] = 0.0;
            g_fClientAbsMax[iClient][2] = 0.0;
            g_fClientVelocity[iClient][0] = 0.0;
            g_fClientVelocity[iClient][1] = 0.0;
            g_fClientVelocity[iClient][2] = 0.0;
        }
    }
}

public Player_PreThink(iClient)
{
    // we need to make the player not solid on a player prethink to fix a bug 
    // where a player isn't able to stand up if they're crouched inside another player
    // unfortunately, this is needed, there's no way around it
    if(g_bClientValid[iClient] && g_bClientAlive[iClient])
    {
        if(g_iClientFlags[iClient] & FL_DUCKING && ((g_iClientButton[iClient] & IN_DUCK) == 0)/*  && pev(id, pev_oldbuttons) & IN_DUCK */)
        {
            for(new iOther=1; iOther <= MaxClients; iOther++)
            {
                if(!g_bClientValid[iOther] || iClient == iOther || !g_bClientAlive[iOther])
                    continue;

                if(IsColliding(iClient, iOther))
                {
                    if((g_fClientAbsMin[iClient][2]+CALLIBRATION >= g_fClientAbsMax[iOther][2] && g_fClientVelocity[iClient][2] < g_fPassthroughSpeed) || (g_fClientAbsMin[iOther][2]+CALLIBRATION >= g_fClientAbsMax[iClient][2]))
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
    if(g_bClientValid[iClient] && g_bClientAlive[iClient])
    {
        for(new iOther=1;iOther <= MaxClients;iOther++)
        {
            if(!g_bClientValid[iOther] || iClient == iOther || !g_bClientAlive[iOther])
                continue;

            if(pev(iOther, pev_solid) == SOLID_NOT)
                set_pev(iOther, pev_solid, SOLID_SLIDEBOX);
        }
    }
}

public OrpheuHookReturn:SC_ShouldBypassEntityPre(hPtr, hPhys)
{
    new iOther = OrpheuGetParamStructMember(2, "player"); //2 = hPhys
    if(IsValidUserIndex(iOther) && g_bClientValid[iOther])
    {
        new OrpheuStruct:hPpMove = OrpheuGetStructFromAddress(OrpheuStructPlayerMove, OrpheuCall(g_hPlayerMoveFunction));
        if(hPpMove != InvalidOrpheuStruct)
        {
            new iClient = OrpheuGetStructMember(hPpMove, "player_index") + 1;
        
            if(IsValidUserIndex(iClient) && g_bClientValid[iClient] && ArePlayersAllied(iClient, iOther))
            {
                if((g_iClientFlags[iOther] & FL_DORMANT) > 0 || 
                    g_iClientMoveType[iOther] == MOVETYPE_FLY || 
                    (g_iClientFlags[iClient] & FL_DORMANT) > 0 || 
                    g_iClientMoveType[iClient] == MOVETYPE_FLY)
                {
                    // MOVETYPE_FLY refers to people being in ladders while FL_DORMANT provides support 
                    // for my Sven Co-op Nextmapper & Anti-Rush plugin
                    OrpheuSetReturn(true);
                    return OrpheuSupercede;
                }

                if((g_fClientAbsMin[iClient][2]+CALLIBRATION >= g_fClientAbsMax[iOther][2] && 
                    g_fClientVelocity[iOther][2] < g_fPassthroughSpeed) || 
                    (g_fClientAbsMin[iOther][2]+CALLIBRATION >= g_fClientAbsMax[iClient][2]))
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
        if(is_user_alive(iClient) && pev_valid(iClient) == 2)
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
        if(is_user_alive(iClient) && pev_valid(iClient) == 2)
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
        g_bClientValid[iEdictEnt] && 
        g_bClientValid[iEdictHost] && 
        g_bClientAlive[iEdictHost] &&
        g_bClientAlive[iEdictEnt] && 
        ArePlayersAllied(iEdictHost, iEdictEnt))
    {
        if((g_iClientFlags[iEdictEnt] & FL_DORMANT) > 0 || 
            g_iClientMoveType[iEdictEnt] == MOVETYPE_FLY || 
            (g_iClientFlags[iEdictHost] & FL_DORMANT) > 0 || 
            g_iClientMoveType[iEdictHost] == MOVETYPE_FLY)
            return FMRES_IGNORED;

        if((g_fClientAbsMin[iEdictHost][2]+CALLIBRATION >= g_fClientAbsMax[iEdictEnt][2] && 
            g_fClientVelocity[iEdictHost][2] < g_fPassthroughSpeed) || 
            (g_fClientAbsMin[iEdictEnt][2]+CALLIBRATION >= g_fClientAbsMax[iEdictHost][2]))
            set_es(hEntState, ES_Solid, 1);
        else
            set_es(hEntState, ES_Solid, 0);

        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

stock IsColliding(iThis, iOther)
{
    //thanks xPaw
    if(g_fClientAbsMin[iThis][0] > g_fClientAbsMax[iOther][0] ||
        g_fClientAbsMin[iThis][1] > g_fClientAbsMax[iOther][1] ||
        g_fClientAbsMin[iThis][2] > g_fClientAbsMax[iOther][2] ||
        g_fClientAbsMax[iThis][0] < g_fClientAbsMin[iOther][0] ||
        g_fClientAbsMax[iThis][1] < g_fClientAbsMin[iOther][1] ||
        g_fClientAbsMax[iThis][2] < g_fClientAbsMin[iOther][2])
        return 0;
    
    return 1;
}

stock ArePlayersAllied(const iClient1, const iClient2)
{
    return g_iClientClassification[iClient1] == g_iClientClassification[iClient2];
}

stock PlayerIdToBit(const iClient)
{
    //thanks anggaranothing
	return (1<<( iClient&31));
}