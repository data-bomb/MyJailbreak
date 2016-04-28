//includes
#include <cstrike>
#include <sourcemod>
#include <colors>
#include <sdktools>
#include <smartjaildoors>
#include <sdkhooks>
#include <wardn>
#include <emitsoundany>
#include <autoexecconfig>
#include <clientprefs>
#include <myjailbreak>

//Compiler Options
#pragma semicolon 1
#pragma newdecls required

//Defines
#define IsSprintUsing   (1<<0)
#define IsSprintCoolDown  (1<<1)
#define IsBombing  (1<<2)

//Booleans
bool IsJiHad;
bool StartJiHad;
bool BombActive;

//ConVars
ConVar gc_bPlugin;
ConVar gc_bSetW;
ConVar gc_bSetA;
ConVar gc_bVote;
ConVar gc_iKey;
ConVar gc_bStandStill;
ConVar gc_fBombRadius;
ConVar gc_bSounds;
ConVar gc_bOverlays;
ConVar gc_iCooldownDay;
ConVar gc_iCooldownStart;
ConVar gc_iRoundTime;
ConVar gc_iFreezeTime;
ConVar gc_sOverlayStartPath;
ConVar gc_bSprintUse;
ConVar gc_fSprintCooldown;
ConVar gc_bSprint;
ConVar gc_fSprintSpeed;
ConVar gc_fSprintTime;
ConVar gc_sSoundStartPath;
ConVar gc_sSoundJihadPath;
ConVar gc_sSoundBoomPath;
ConVar g_iSetRoundTime;

//Integers
int g_iVoteCount;
int g_iOldRoundTime;
int g_iCoolDown;
int g_iFreezeTime;
int JiHadRound;
int ClientSprintStatus[MAXPLAYERS+1];

//Handles
Handle SprintTimer[MAXPLAYERS+1];
Handle JiHadMenu;
Handle FreezeTimer;

//Strings
char g_sSoundBoomPath[256];
char g_sSoundJihadPath[256];
char g_sHasVoted[1500];
char g_sSoundStartPath[256];


public Plugin myinfo = {
	name = "MyJailbreak - JiHad & Freeze",
	author = "shanapu",
	description = "Event Day for Jailbreak Server",
	version = PLUGIN_VERSION,
	url = "shanapu.de"
};

public void OnPluginStart()
{
	// Translation
	LoadTranslations("MyJailbreak.Warden.phrases");
	LoadTranslations("MyJailbreak.JiHad.phrases");
	
	//Client Commands
	RegConsoleCmd("sm_setjihad", SetJiHad, "Allows the Admin or Warden to set jihad as next round");
	RegConsoleCmd("sm_jihad", VoteJiHad, "Allows players to vote for a duckhunt");
	RegConsoleCmd("sm_sprint", Command_StartSprint, "Starts the sprint");
	RegConsoleCmd("sm_makeboom", Command_BombJihad, "Suicide with bomb");
	
	//AutoExecConfig
	AutoExecConfig_SetFile("MyJailbreak.JiHad");
	AutoExecConfig_SetCreateFile(true);
	
	AutoExecConfig_CreateConVar("sm_jihad_version", PLUGIN_VERSION, "The version of this MyJailBreak SourceMod plugin", FCVAR_SPONLY|FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_jihad_enable", "1", "0 - disabled, 1 - enable this MyJailBreak SourceMod plugin", _, true,  0.0, true, 1.0);
	gc_bSetW = AutoExecConfig_CreateConVar("sm_jihad_warden", "1", "0 - disabled, 1 - allow warden to set jihad round", _, true,  0.0, true, 1.0);
	gc_bSetA = AutoExecConfig_CreateConVar("sm_jihad_admin", "1", "0 - disabled, 1 - allow admin to set jihad round", _, true,  0.0, true, 1.0);
	gc_bVote = AutoExecConfig_CreateConVar("sm_jihad_vote", "1", "0 - disabled, 1 - allow player to vote for jihad", _, true,  0.0, true, 1.0);
	gc_iKey = AutoExecConfig_CreateConVar("sm_jihad_key", "1", "1 - Inspect(look) weapon / 2 - walk / 3 - Secondary Attack", _, true,  1.0, true, 3.0);
	gc_bStandStill = AutoExecConfig_CreateConVar("sm_jihad_standstill", "1", "0 - disabled, 1 - standstill(cant move) on Activate bomb", _, true,  0.0, true, 1.0);
	gc_fBombRadius = AutoExecConfig_CreateConVar("sm_jihad_bomb_radius", "200.0","Radius for bomb damage", _, true, 10.0, true, 999.0);
	gc_iFreezeTime = AutoExecConfig_CreateConVar("sm_jihad_hidetime", "20", "Time to hide for CTs", _, true,  0.0);
	gc_iRoundTime = AutoExecConfig_CreateConVar("sm_jihad_roundtime", "5", "Round time in minutes for a single jihad round", _, true, 1.0);
	gc_iCooldownDay = AutoExecConfig_CreateConVar("sm_jihad_cooldown_day", "3", "Rounds cooldown after a event until event can be start again", _, true, 0.0);
	gc_iCooldownStart = AutoExecConfig_CreateConVar("sm_jihad_cooldown_start", "3", "Rounds until event can be start after mapchange.", _, true, 0.0);
	gc_bOverlays = AutoExecConfig_CreateConVar("sm_jihad_overlays_enable", "1", "0 - disabled, 1 - enable overlays", _, true,  0.0, true, 1.0);
	gc_sOverlayStartPath = AutoExecConfig_CreateConVar("sm_jihad_overlays_start", "overlays/MyJailbreak/start" , "Path to the start Overlay DONT TYPE .vmt or .vft");
	gc_bSounds = AutoExecConfig_CreateConVar("sm_jihad_sounds_enable", "1", "0 - disabled, 1 - enable sounds ", _, true,  0.0, true, 1.0);
	gc_sSoundStartPath = AutoExecConfig_CreateConVar("sm_jihad_sounds_start", "music/myjailbreak/start.mp3", "Path to the soundfile which should be played for start.");
	gc_sSoundJihadPath = AutoExecConfig_CreateConVar("sm_jihad_sounds_jihad", "music/myjailbreak/jihad.mp3", "Path to the soundfile which should be played on activatebomb.");
	gc_sSoundBoomPath = AutoExecConfig_CreateConVar("sm_jihad_sounds_boom", "music/myjailbreak/boom.mp3", "Path to the soundfile which should be played on detonation.");
	gc_bSprintUse = AutoExecConfig_CreateConVar("sm_jihad_sprint_button", "1", "0 - disabled, 1 - enable +use button for sprint", _, true,  0.0, true, 1.0);
	gc_fSprintCooldown = AutoExecConfig_CreateConVar("sm_jihad_sprint_cooldown", "10","Time in seconds the player must wait for the next sprint", _, true,  0.0);
	gc_bSprint = AutoExecConfig_CreateConVar("sm_jihad_sprint_enable", "1", "0 - disabled, 1 - enable ShortSprint", _, true,  0.0, true, 1.0);
	gc_fSprintSpeed = AutoExecConfig_CreateConVar("sm_jihad_sprint_speed", "1.25","Ratio for how fast the player will sprint", _, true, 1.01, true, 5.00);
	gc_fSprintTime = AutoExecConfig_CreateConVar("sm_jihad_sprint_time", "1.0", "Time in seconds the player will sprint", _, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	//Hooks
	HookEvent("round_start", RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", RoundEnd);
	HookConVarChange(gc_sSoundStartPath, OnSettingChanged);
	
	HookConVarChange(gc_sOverlayStartPath, OnSettingChanged);
	HookConVarChange(gc_sSoundJihadPath, OnSettingChanged);
	HookConVarChange(gc_sSoundBoomPath, OnSettingChanged);
	
	//FindConVar
	g_iSetRoundTime = FindConVar("mp_roundtime");
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iFreezeTime = gc_iFreezeTime.IntValue;
	gc_sSoundJihadPath.GetString(g_sSoundJihadPath, sizeof(g_sSoundJihadPath));
	gc_sSoundBoomPath.GetString(g_sSoundBoomPath, sizeof(g_sSoundBoomPath));
	gc_sOverlayStartPath.GetString(g_sOverlayStart , sizeof(g_sOverlayStart));
	gc_sSoundStartPath.GetString(g_sSoundStartPath, sizeof(g_sSoundStartPath));

	AddCommandListener(Command_LAW, "+lookatweapon");
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i)) OnClientPutInServer(i);
}

public int OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(convar == gc_sSoundJihadPath)
	{
		strcopy(g_sSoundJihadPath, sizeof(g_sSoundJihadPath), newValue);
		if(gc_bSounds.BoolValue) PrecacheSoundAnyDownload(g_sSoundJihadPath);
	}
	else if(convar == gc_sSoundBoomPath)
	{
		strcopy(g_sSoundBoomPath, sizeof(g_sSoundBoomPath), newValue);
		if(gc_bSounds.BoolValue) PrecacheSoundAnyDownload(g_sSoundBoomPath);
	}
	
	else if(convar == gc_sOverlayStartPath)
	{
		strcopy(g_sOverlayStart, sizeof(g_sOverlayStart), newValue);
		if(gc_bOverlays.BoolValue) PrecacheOverlayAnyDownload(g_sOverlayStart);
	}
	else if(convar == gc_sSoundStartPath)
	{
		strcopy(g_sSoundStartPath, sizeof(g_sSoundStartPath), newValue);
		if(gc_bSounds.BoolValue) PrecacheSoundAnyDownload(g_sSoundStartPath);
	}
}

public Action CS_OnTerminateRound( float &delay, CSRoundEndReason &reason)
{
	if (IsJiHad)
	{
		if (reason == CSRoundEnd_Draw)
		{
			reason = CSRoundEnd_CTWin;
			return Plugin_Changed;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	g_iVoteCount = 0;
	JiHadRound = 0;
	IsJiHad = false;
	StartJiHad = false;
	BombActive = false;
	
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iFreezeTime = gc_iFreezeTime.IntValue;
	
	if(gc_bOverlays.BoolValue) PrecacheOverlayAnyDownload(g_sOverlayStart);
	if(gc_bSounds.BoolValue)	
	{
		PrecacheSoundAnyDownload(g_sSoundJihadPath);
		PrecacheSoundAnyDownload(g_sSoundBoomPath);
		PrecacheSoundAnyDownload(g_sSoundStartPath);
	}
	PrecacheSound("player/suit_sprint.wav", true);
}

public void OnConfigsExecuted()
{
	g_iCoolDown = gc_iCooldownStart.IntValue + 1;
	g_iFreezeTime = gc_iFreezeTime.IntValue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action SetJiHad(int client,int args)
{
	if (gc_bPlugin.BoolValue)
	{
		if (warden_iswarden(client))
		{
			if (gc_bSetW.BoolValue)
			{
				char EventDay[64];
				GetEventDay(EventDay);
				
				if(StrEqual(EventDay, "none", false))
				{
					if (g_iCoolDown == 0)
					{
						StartNextRound();
					}
					else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_wait", g_iCoolDown);
				}
				else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_progress" , EventDay);
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "jihad_setbywarden");
		}
		else if (CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP, true))
			{
				if (gc_bSetA.BoolValue)
				{
					char EventDay[64];
					GetEventDay(EventDay);
					
					if(StrEqual(EventDay, "none", false))
					{
						if (g_iCoolDown == 0)
						{
							StartNextRound();
						}
						else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_wait", g_iCoolDown);
					}
					else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_progress" , EventDay);
				}
				else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_setbyadmin");
			}
			else CPrintToChat(client, "%t %t", "warden_tag" , "warden_notwarden");
	}
	else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_disabled");
}

public Action VoteJiHad(int client,int args)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (gc_bPlugin.BoolValue)
	{
		if (gc_bVote.BoolValue)
		{	
			if (GetTeamClientCount(CS_TEAM_CT) > 0)
			{
				char EventDay[64];
				GetEventDay(EventDay);
				
				if(StrEqual(EventDay, "none", false))
				{	
					if (g_iCoolDown == 0)
					{
						if (StrContains(g_sHasVoted, steamid, true) == -1)
						{
							int playercount = (GetClientCount(true) / 2);
							g_iVoteCount++;
							int Missing = playercount - g_iVoteCount + 1;
							Format(g_sHasVoted, sizeof(g_sHasVoted), "%s,%s", g_sHasVoted, steamid);
							
							if (g_iVoteCount > playercount)
							{
								StartNextRound();
							}
							else CPrintToChatAll("%t %t", "jihad_tag" , "jihad_need", Missing, client);
						}
						else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_voted");
					}
					else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_wait", g_iCoolDown);
				}
				else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_progress" , EventDay);
			}
			else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_minct");
		}
		else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_voting");
	}
	else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_disabled");
}

void StartNextRound()
{
	StartJiHad = true;
	g_iCoolDown = gc_iCooldownDay.IntValue + 1;
	g_iVoteCount = 0;
	SetEventDay("jihad");
	
	CPrintToChatAll("%t %t", "jihad_tag" , "jihad_next");
	PrintHintTextToAll("%t", "jihad_next_nc");
}

public void RoundStart(Handle event, char[] name, bool dontBroadcast)
{
	if (StartJiHad)
	{
		char info1[255], info2[255], info3[255], info4[255], info5[255], info6[255], info7[255], info8[255];
		
		
		SetCvar("sm_hosties_lr", 0);
		SetCvar("sm_warden_enable", 0);
		SetCvar("sm_menu_enable", 0);
		SetCvar("sm_weapons_enable", 0);
		
		IsJiHad = true;
		JiHadRound++;
		StartJiHad = false;
		JiHadMenu = CreatePanel();
		Format(info1, sizeof(info1), "%T", "jihad_info_Title", LANG_SERVER);
		SetPanelTitle(JiHadMenu, info1);
		DrawPanelText(JiHadMenu, "                                   ");
		Format(info2, sizeof(info2), "%T", "jihad_info_Line1", LANG_SERVER);
		DrawPanelText(JiHadMenu, info2);
		DrawPanelText(JiHadMenu, "-----------------------------------");
		Format(info3, sizeof(info3), "%T", "jihad_info_Line2", LANG_SERVER);
		DrawPanelText(JiHadMenu, info3);
		Format(info4, sizeof(info4), "%T", "jihad_info_Line3", LANG_SERVER);
		DrawPanelText(JiHadMenu, info4);
		Format(info5, sizeof(info5), "%T", "jihad_info_Line4", LANG_SERVER);
		DrawPanelText(JiHadMenu, info5);
		Format(info6, sizeof(info6), "%T", "jihad_info_Line5", LANG_SERVER);
		DrawPanelText(JiHadMenu, info6);
		Format(info7, sizeof(info7), "%T", "jihad_info_Line6", LANG_SERVER);
		DrawPanelText(JiHadMenu, info7);
		Format(info8, sizeof(info8), "%T", "jihad_info_Line7", LANG_SERVER);
		DrawPanelText(JiHadMenu, info8);
		DrawPanelText(JiHadMenu, "-----------------------------------");
		
		if (JiHadRound > 0)
			{
				for(int client=1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client))
					{
						StripAllWeapons(client);
						ClientSprintStatus[client] = 0;
						SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 2, 4, true);
						SendPanelToClient(JiHadMenu, client, Pass, 15);
						
						if (GetClientTeam(client) == CS_TEAM_T)
						{
							GivePlayerItem(client, "weapon_c4");
						}
						if (GetClientTeam(client) == CS_TEAM_CT)
						{
							GivePlayerItem(client, "weapon_knife");
						}
					}
				}
				g_iFreezeTime--;
				FreezeTimer = CreateTimer(1.0, JiHad, _, TIMER_REPEAT);
				
			}
	}
	else
	{
		char EventDay[64];
		GetEventDay(EventDay);
		
		if(!StrEqual(EventDay, "none", false))
		{
			g_iCoolDown = gc_iCooldownDay.IntValue + 1;
		}
		else if (g_iCoolDown > 0) g_iCoolDown--;
	}
}

public Action Command_LAW(int client, const char[] command, int argc)
{
	if(IsJiHad)
	{
		if(gc_iKey.IntValue == 1)
		{
			Command_BombJihad(client, 0);
		}
	}
	
	return Plugin_Continue;
}

public Action JiHad(Handle timer)
{
	if (g_iFreezeTime > 1)
	{
		g_iFreezeTime--;
		for (int client=1; client <= MaxClients; client++)
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			if (GetClientTeam(client) == CS_TEAM_CT)
			{
				PrintCenterText(client,"%t", "jihad_timetojihad_nc", g_iFreezeTime);
			}
			if (GetClientTeam(client) == CS_TEAM_T)
			{
				PrintCenterText(client,"%t", "jihad_timetoopen_nc", g_iFreezeTime);
			}
		}
		return Plugin_Continue;
	}
	
	g_iFreezeTime = gc_iFreezeTime.IntValue;
	
	if (JiHadRound > 0)
	{
		for (int client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
						
			}
			if(gc_bOverlays.BoolValue) CreateTimer( 0.0, ShowOverlayStart, client);
			if(gc_bSounds.BoolValue)
			{
				EmitSoundToAllAny(g_sSoundStartPath);
			}
		}
	}
	SJD_OpenDoors();
	
	PrintHintTextToAll("%t", "jihad_start_nc");
	CPrintToChatAll("%t %t", "jihad_tag" , "jihad_start");
	FreezeTimer = null;
	BombActive = true;
	
	return Plugin_Stop;
}

public Action Command_BombJihad(int client, int args)
{
	if (IsJiHad && BombActive)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		char weaponName[64];
		
		GetEdictClassname(weapon, weaponName, sizeof(weaponName));
		
		if (IsValidEdict(weapon) && IsClientInGame(client) && IsPlayerAlive(client) && (GetClientTeam(client) == CS_TEAM_T))
		{
			if(StrEqual(weaponName, "weapon_c4"))
			{
				EmitSoundToAllAny(g_sSoundJihadPath);
				CreateTimer( 1.0, DoDaBomb, client);
				if (gc_bStandStill.BoolValue)
				{
					SetEntityMoveType(client, MOVETYPE_NONE);
				}
			}
			//else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_needc4");
		}
		else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_needc4");
	}
}

public Action DoDaBomb( Handle timer, any client ) 
{
	EmitSoundToAllAny(g_sSoundBoomPath);
	
	float suicide_bomber_vec[3];
	GetClientAbsOrigin(client, suicide_bomber_vec);
	
	int iMaxClients = GetMaxClients();
	int deathList[MAXPLAYERS+1]; //store players that this bomb kills
	int numKilledPlayers = 0;
	
	for (int i = 1; i <= iMaxClients; ++i)
	
	{
		//Check that client is a real player who is alive and is a CT
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			float ct_vec[3];
			GetClientAbsOrigin(i, ct_vec);
			
			float distance = GetVectorDistance(ct_vec, suicide_bomber_vec, false);
			
			//If CT was in explosion radius, damage or kill them
			//Formula used: damage = 200 - (d/2)
			int damage = RoundToFloor(gc_fBombRadius.FloatValue - (distance / 2.0));
			
			if (damage <= 0) //this player was not damaged 
			continue;
			
			//Damage the surrounding players
			int curHP = GetClientHealth(i);
			if (curHP - damage <= 0) 
			{
				deathList[numKilledPlayers] = i;
				numKilledPlayers++;
			}
			else
			{ //Survivor
				SetEntityHealth(i, curHP - damage);
				IgniteEntity(i, 2.0);
			}
		}
	}
	if (numKilledPlayers > 0) 
	{
		for (int i = 0; i < numKilledPlayers; ++i)
		{
			ForcePlayerSuicide(deathList[i]);
		}
	}
	ForcePlayerSuicide(client);
	int number = 0;
	for (int i = 1; i <= MaxClients; i++)
	if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT) number++;
	if(number == 0)
	{
	CPrintToChatAll("%t %t", "jihad_tag" , "jihad_win");
	CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
	}
}

public Action OnWeaponCanUse(int client, int weapon)
{
	char sWeapon[32];
	GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if((GetClientTeam(client) == CS_TEAM_T && !StrEqual(sWeapon, "weapon_c4")) || (GetClientTeam(client) == CS_TEAM_CT && !StrEqual(sWeapon, "weapon_knife")))
		{
			if (IsClientInGame(client) && IsPlayerAlive(client))
			{
				if(IsJiHad == true)
				{
					return Plugin_Handled;
				}
			}
		}
	return Plugin_Continue;
}


public void RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	int winner = GetEventInt(event, "winner");
	
	if (IsJiHad)
	{
		for(int client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client)) SetEntData(client, FindSendPropInfo("CBaseEntity", "m_CollisionGroup"), 0, 4, true);
			ClientSprintStatus[client] = 0;
		}
		if (FreezeTimer != null) KillTimer(FreezeTimer);
		
		if (winner == 2) PrintHintTextToAll("%t", "jihad_twin_nc");
		if (winner == 3) PrintHintTextToAll("%t", "jihad_ctwin_nc");
		IsJiHad = false;
		StartJiHad = false;
		BombActive = false;
		JiHadRound = 0;
		
		Format(g_sHasVoted, sizeof(g_sHasVoted), "");
		SetCvar("sm_hosties_lr", 1);
		SetCvar("sm_weapons_enable", 1);
		SetCvar("sv_infinite_ammo", 0);
		SetCvar("sm_warden_enable", 1);
		SetCvar("sm_menu_enable", 1);
		g_iSetRoundTime.IntValue = g_iOldRoundTime;
		SetEventDay("none");
		CPrintToChatAll("%t %t", "jihad_tag" , "jihad_end");
	}
	if (StartJiHad)
	{
		g_iOldRoundTime = g_iSetRoundTime.IntValue;
		g_iSetRoundTime.IntValue = gc_iRoundTime.IntValue;
	}
}

public Action Command_StartSprint(int client, int args)
{
	if (IsJiHad)
	{
		if(gc_bSprint.BoolValue && client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) > 1 && !(ClientSprintStatus[client] & IsSprintUsing) && !(ClientSprintStatus[client] & IsSprintCoolDown))
		{
			ClientSprintStatus[client] |= IsSprintUsing | IsSprintCoolDown;
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", gc_fSprintSpeed.FloatValue);
			EmitSoundToClient(client, "player/suit_sprint.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
			CPrintToChat(client, "%t %t", "jihad_tag" ,"jihad_sprint");
			SprintTimer[client] = CreateTimer(gc_fSprintTime.FloatValue, Timer_SprintEnd, client);
		}
		return(Plugin_Handled);
	}
	else CPrintToChat(client, "%t %t", "jihad_tag" , "jihad_disabled");
	return(Plugin_Handled);
}

public void OnGameFrame()
{
	if (IsJiHad)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(gc_iKey.IntValue == 2)
			{
				if(IsClientInGame(i) && (GetClientButtons(i) & IN_SPEED))
				{
					Command_BombJihad(i, 0);
				}
			}
			else if(gc_iKey.IntValue == 3)
			{
				if(IsClientInGame(i) && (GetClientButtons(i) & IN_ATTACK2))
				{
					Command_BombJihad(i, 0);
				}
			}
			if(gc_bSprintUse.BoolValue)
			{
				if(IsClientInGame(i) && (GetClientButtons(i) & IN_USE))
				{
					Command_StartSprint(i, 0);
				}
			}
		}
	}
	return;
}

public Action ResetSprint(int client)
{
	if(SprintTimer[client] != null)
	{
		KillTimer(SprintTimer[client]);
		SprintTimer[client] = null;
	}
	if(GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != 1)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
	}
	
	if(ClientSprintStatus[client] & IsSprintUsing)
	{
		ClientSprintStatus[client] &= ~ IsSprintUsing;
	}
	return;
}

public Action Timer_SprintEnd(Handle timer, any client)
{
	SprintTimer[client] = null;
	
	
	if(IsClientInGame(client) && (ClientSprintStatus[client] & IsSprintUsing))
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		ClientSprintStatus[client] &= ~ IsSprintUsing;
		if(IsPlayerAlive(client) && GetClientTeam(client) > 1)
		{
			SprintTimer[client] = CreateTimer(gc_fSprintCooldown.FloatValue, Timer_SprintCooldown, client);
		}
	}
	return;
}

public Action Timer_SprintCooldown(Handle timer, any client)
{
	SprintTimer[client] = null;
	if(IsClientInGame(client) && (ClientSprintStatus[client] & IsSprintCoolDown))
	{
		ClientSprintStatus[client] &= ~ IsSprintCoolDown;
	}
	return;
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetSprint(iClient);
	ClientSprintStatus[iClient] &= ~ IsSprintCoolDown;
	return;
}

public void OnMapEnd()
{
	IsJiHad = false;
	StartJiHad = false;
	BombActive = false;
	g_iVoteCount = 0;
	JiHadRound = 0;
	g_sHasVoted[0] = '\0';
	SetEventDay("none");
}