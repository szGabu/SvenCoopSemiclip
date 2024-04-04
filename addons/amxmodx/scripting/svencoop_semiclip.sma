#include <amxmodx>
#include <orpheu>
#include <orpheu_advanced>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_NAME             "Sven Co-op Semiclip"
#define PLUGIN_VERSION          "1.3-23w05b"
#define PLUGIN_AUTHOR           "gabuch2"

#define ENSURE_TASK_ID          22222

#define CALLIBRATION            2 //do not change this unless you know what are you doing

#if AMXX_VERSION_NUM < 183
#define MAX_PLAYERS             32
#endif

#define SC_CLASS_NONE              0
#define SC_CLASS_MACHINE           1
#define SC_CLASS_PLAYER            2
#define SC_CLASS_PLAYER_ALLY       3
#define SC_CLASS_HUMAN_PASSIVE     4
#define SC_CLASS_HUMAN_MILITARY    5
#define SC_CLASS_ALIEN_PASSIVE     6
#define SC_CLASS_ALIEN_MILITARY    7
#define SC_CLASS_ALIEN_MONSTER     8
#define SC_CLASS_ALIEN_PREY        9
#define SC_CLASS_ALIEN_PREDATOR    10
#define SC_CLASS_INSECT            11
#define SC_CLASS_PLAYER_BIOWEAPON  12
#define SC_CLASS_ALIEN_BIOWEAPON   13
#define SC_CLASS_RACE_X_PITDRONE   14
#define SC_CLASS_RACE_X_SHOCKTR    15
#define SC_CLASS_TEAM_A            16
#define SC_CLASS_TEAM_B            17
#define SC_CLASS_TEAM_C            18
#define SC_CLASS_TEAM_D            19

#pragma dynamic     32768
#pragma semicolon   1

//functions
new OrpheuFunction:g_hShouldBypassEntityFunction, OrpheuFunction:g_hPlayerMoveFunction, OrpheuFunction:g_hTestEntityPositionFunction;
new OrpheuHook:g_hookShouldBypassEntityPre, OrpheuHook:g_hookTestEntityPositionPre, OrpheuHook:g_hookTestEntityPositionPost;
new g_cvarEnabled, g_cvarPassthroughSpeed;

//utils
new g_iOriginalGroupInfo[MAX_PLAYERS+1] = { -1, ... };
new g_bUserFullyConnected[MAX_PLAYERS+1] = { false, ... };
new g_iUserClassification[MAX_PLAYERS+1] = { SC_CLASS_PLAYER, ... };
new g_iPluginFlags;

//declare these as globals, to avoid creating new variables in performance critical functions
new Float:g_fClientAbsMin[3], Float:g_fClientAbsMax[3];
new Float:g_fOtherAbsMin[3], Float:g_fOtherAbsMax[3];
new Float:g_fClientVelocity[3];
new Float:g_fPassthroughSpeed;

//this should work?
const OrpheuStruct:InvalidOrpheuStruct = OrpheuStruct:0;

#if AMXX_VERSION_NUM < 183
#define MaxClients              get_maxplayers()
#endif

#define is_user_valid(%1) (1 <= (%1) <= MaxClients)

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_cvarEnabled = register_cvar("amx_semiclip_enabled", "1");
    g_cvarPassthroughSpeed = register_cvar("amx_semiclip_passthrough_speed", "500.0");
    register_cvar("amx_semiclip_version", PLUGIN_VERSION, FCVAR_SERVER);

    register_event("MOTD", "ClientMOTD", "b");

    RegisterHam(Ham_SC_SetClassification, "player", "SetClassificationPost", true);

    g_iPluginFlags = plugin_flags();
}

public SetClassificationPost(iClient, iClassification)
{
    g_iUserClassification[iClient] = iClassification;
}

public plugin_end()
{
    for(new iClient=1; iClient <= MaxClients; iClient++)
        g_bUserFullyConnected[iClient] = false;

    OrpheuUnregisterHook(g_hookShouldBypassEntityPre);
    OrpheuUnregisterHook(g_hookTestEntityPositionPre);
    OrpheuUnregisterHook(g_hookTestEntityPositionPost);
}

public plugin_cfg()
{
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[Sven Co-op Semiclip Debug] Going through plugin_cfg().");
    g_hShouldBypassEntityFunction = OrpheuGetFunction("SC_ShouldBypassEntity");
    g_hTestEntityPositionFunction = OrpheuGetFunction("SV_TestEntityPosition");
    g_hPlayerMoveFunction = OrpheuGetFunction("PM_GetPlayerMove");

    if(get_pcvar_bool(g_cvarEnabled))
        semiclip_enable();
}

public semiclip_enable()
{
    g_hookShouldBypassEntityPre = OrpheuRegisterHook(g_hShouldBypassEntityFunction,"SC_ShouldBypassEntityPre");
    g_hookTestEntityPositionPre = OrpheuRegisterHook(g_hTestEntityPositionFunction,"EntityPositionPre");
    g_hookTestEntityPositionPost = OrpheuRegisterHook(g_hTestEntityPositionFunction,"EntityPositionPost", OrpheuHookPost);

    register_forward(FM_AddToFullPack, "AddToFullPack_Post", true);
    register_forward(FM_PlayerPreThink, "Player_PreThink");
    register_forward(FM_PlayerPostThink, "Player_PostThink");

    g_fPassthroughSpeed = get_pcvar_float(g_cvarPassthroughSpeed);
}

public ClientMOTD(iClient)
{
	if(!g_bUserFullyConnected[iClient] && !task_exists(ENSURE_TASK_ID+get_user_userid(iClient)))
        set_task(5.0, "EnsurePlayerSpawn", ENSURE_TASK_ID+get_user_userid(iClient));
}

public EnsurePlayerSpawn(iTaskId)
{
    new iUserId = iTaskId-ENSURE_TASK_ID;
    if(g_iPluginFlags & AMX_FLAG_DEBUG)
        server_print("[Sven Co-op Semiclip Debug] Called EnsurePlayerSpawn() on %d", iUserId);

    new iClient = find_player("k", iUserId);
    if(iClient)
    {
        if(is_user_connected(iClient))
        {
            if(g_iPluginFlags & AMX_FLAG_DEBUG)
                server_print("[Sven Co-op Semiclip Debug] %n is now fully connected.", iClient);
            g_bUserFullyConnected[iClient] = true;
        }
        else
            set_task(5.0, "EnsurePlayerSpawn", ENSURE_TASK_ID+get_user_userid(iClient));
    }
}

public client_connect(iClient)
{
    g_bUserFullyConnected[iClient] = false;
    g_iOriginalGroupInfo[iClient] = -1;
    g_iUserClassification[iClient] = SC_CLASS_PLAYER;
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
        if(g_bUserFullyConnected[iClient])
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
        if(g_bUserFullyConnected[iClient])
        {
            set_pev(iClient, pev_groupinfo, g_iOriginalGroupInfo[iClient]);
            g_iOriginalGroupInfo[iClient] = -1;
        }
    }

    return OrpheuIgnored;
}

public Player_PreThink(iClient)
{
    // we need to make the player not solid on a player prethink
    // to fix a bug where a player isn't able to stand up if they're crouched
    // inside another player
    if(g_bUserFullyConnected[iClient])
    {
        if(pev(iClient, pev_flags) & FL_DUCKING && ((pev(iClient, pev_button) & IN_DUCK) == 0)/*  && pev(id, pev_oldbuttons) & IN_DUCK */)
        {
            for(new iOther=1; iOther <= MaxClients; iOther++)
            {
                if(!g_bUserFullyConnected[iOther] || iClient == iOther || !is_user_alive(iOther))
                    continue;

                if(IsColliding(iClient, iOther))
                {
                    pev(iClient, pev_absmin, g_fClientAbsMin);
                    pev(iClient, pev_absmax, g_fClientAbsMax);
                    pev(iOther, pev_absmin, g_fOtherAbsMin);
                    pev(iOther, pev_absmax, g_fOtherAbsMax);
                    if((g_fClientAbsMin[2]+CALLIBRATION >= g_fOtherAbsMax[2] && g_fClientVelocity[2] < g_fPassthroughSpeed) || (g_fOtherAbsMin[2]+CALLIBRATION >= g_fClientAbsMax[2]))
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
    if(g_bUserFullyConnected[iClient])
    {
        for(new iOther=1;iOther <= MaxClients;iOther++)
        {
            if(!g_bUserFullyConnected[iOther] || iClient == iOther || !is_user_alive(iOther))
                continue;

            if(pev(iOther, pev_solid) == SOLID_NOT)
                set_pev(iOther, pev_solid, SOLID_SLIDEBOX);
        }
    }
}

public OrpheuHookReturn:SC_ShouldBypassEntityPre(hPtr, hPhys)
{
    new iOther = OrpheuGetParamStructMember(2, "player"); //2 = hPhys
    if(is_user_valid(iOther) && g_bUserFullyConnected[iOther])
    {
        new OrpheuStruct:hPpMove = OrpheuGetStructFromAddress(OrpheuStructPlayerMove, OrpheuCall(g_hPlayerMoveFunction));
        if(hPpMove != InvalidOrpheuStruct)
        {
            new iClient = OrpheuGetStructMember(hPpMove, "player_index") + 1;
        
            if(is_user_valid(iClient) && g_bUserFullyConnected[iClient])
            {
                if(!ArePlayersAllied(iClient, iOther))
                    return OrpheuIgnored;

                if(!(pev(iOther, pev_flags) & FL_DORMANT == 0) && !(pev(iOther, pev_movetype) & MOVETYPE_FLY == 0) )
                {
                    // MOVETYPE_FLY refers to people being in ladders while FL_DORMANT provides support 
                    // for my Sven Co-op Nextmapper & Anti-Rush plugin
                    OrpheuSetReturn(true);
                    return OrpheuSupercede;
                }

                pev(iClient, pev_velocity, g_fClientVelocity);
                pev(iClient, pev_absmin, g_fClientAbsMin);
                pev(iClient, pev_absmax, g_fClientAbsMax);
                pev(iOther, pev_absmin, g_fOtherAbsMin);
                pev(iOther, pev_absmax, g_fOtherAbsMax);

                if((g_fClientAbsMin[2]+CALLIBRATION >= g_fOtherAbsMax[2] && g_fClientVelocity[2] < g_fPassthroughSpeed) || (g_fOtherAbsMin[2]+CALLIBRATION >= g_fClientAbsMax[2]))
                    return OrpheuIgnored;

                OrpheuSetReturn(true);
                return OrpheuSupercede;
            }
        }
    }

    return OrpheuIgnored;
}

public AddToFullPack_Post(hEntState, iEnt, iEdictEnt, iEdictHost, iHostFlags, iPlayer, pSet) 
{	
    if(iEdictHost != iEdictEnt && is_user_valid(iEdictEnt) && g_bUserFullyConnected[iEdictEnt] && g_bUserFullyConnected[iEdictHost])
    {
        if(!ArePlayersAllied(iEdictHost, iEdictEnt))
            return FMRES_IGNORED;

        pev(iEdictHost, pev_velocity, g_fClientVelocity);
        pev(iEdictHost, pev_absmin, g_fClientAbsMin);
        pev(iEdictHost, pev_absmax, g_fClientAbsMax);
        pev(iEdictEnt, pev_absmin, g_fOtherAbsMin);
        pev(iEdictEnt, pev_absmax, g_fOtherAbsMax);

        if((g_fClientAbsMin[2]+CALLIBRATION >= g_fOtherAbsMax[2] && g_fClientVelocity[2] < g_fPassthroughSpeed) || (g_fOtherAbsMin[2]+CALLIBRATION >= g_fClientAbsMax[2]))
            set_es(hEntState, ES_Solid, 1);
        else
            set_es(hEntState, ES_Solid, 0);

        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

stock IsColliding(iEntity1, iEntity2)
{
    //thanks xPaw
    pev(iEntity1, pev_absmin, g_fClientAbsMin);
    pev(iEntity1, pev_absmax, g_fClientAbsMax);
    pev(iEntity2, pev_absmin, g_fOtherAbsMin);
    pev(iEntity2, pev_absmax, g_fOtherAbsMax);
    
    if(g_fClientAbsMin[0] > g_fOtherAbsMax[0] ||
        g_fClientAbsMin[1] > g_fOtherAbsMax[1] ||
        g_fClientAbsMin[2] > g_fOtherAbsMax[2] ||
        g_fClientAbsMax[0] < g_fOtherAbsMin[0] ||
        g_fClientAbsMax[1] < g_fOtherAbsMin[1] ||
        g_fClientAbsMax[2] < g_fOtherAbsMin[2])
        return 0;
    
    return 1;
}

stock PlayerIdToBit(const iClient)
{
    //thanks anggaranothing
	return (1<<(iClient&31));
}

stock ArePlayersAllied(const iClient1, const iClient2)
{
    return g_iUserClassification[iClient1] == g_iUserClassification[iClient2];
}

#if AMXX_VERSION_NUM < 183
stock get_pcvar_bool(const iHandle)
{
	return get_pcvar_num(iHandle) != 0;
}
#endif