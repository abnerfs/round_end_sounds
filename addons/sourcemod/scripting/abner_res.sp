/*
	Thank you bro for downloading my plugin, it is a honor help you with your server.
	Plugin by AbNeR_CSS @2015
	
	Plugin Features:
	- CSS/CS:GO support.
	- Sounds load automatically.
	- Stops standard CSGO round end sound.
	- Stops map musics to prevent play of two songs at the same time. (Thanks to GoD-Tony).
	- Type !res to choose if you want or not listen the sounds.
	- Play the sounds to the end.

	Se você é brasileiro acesse o forum do meu clan:
	www.tecnohardclan.com/forum e receba suporte em português.

*/


#include <sourcemod>
#include <sdktools>
#include <colors>
#include <clientprefs>
#include <cstrike>

//SoundLib Now Optional Bros!!
#undef REQUIRE_EXTENSIONS
#include <soundlib>
new bool:soundLib;


#pragma semicolon 1

#define ABNER_ADMINFLAG ADMFLAG_SLAY
#define PLUGIN_VERSION "3.2"

#define MAX_EDICTS		2048
#define MAX_SOUNDS		1024

new g_iSoundEnts[MAX_EDICTS];
new g_iNumSounds;

new Handle:g_hCTPath;
new Handle:g_hTRPath;
new Handle:g_hPlayType;
new Handle:g_AbNeRCookie;
new Handle:g_hStop;
new Handle:g_playToTheEnd;
new Handle:g_roundDrawPlay;

new bool:g_bClientPreference[MAXPLAYERS+1];
new bool:SoundsTRSucess = false;
new bool:SoundsCTSucess = false;
new bool:SamePath = false;
new bool:CSGO;
new Float:CurrentSoundLenght = 0.0;
new bool:lenghtStored = false;

new g_SoundsTR = 0;
new g_SoundsCT = 0;

new String:soundct[MAX_SOUNDS][PLATFORM_MAX_PATH];
new String:soundtr[MAX_SOUNDS][PLATFORM_MAX_PATH];

new String:sCookieValue[11];




public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("GetSoundLengthFloat");
	MarkNativeAsOptional("OpenSoundFile");
	return APLRes_Success;
}


public Plugin:myinfo =
{
	name = "[CS:GO/CSS] AbNeR Round End Sounds",
	author = "AbNeR_CSS",
	description = "Play cool musics when round ends!",
	version = PLUGIN_VERSION,
	url = "http://www.tecnohardclan.com/forum/"
}

public OnPluginStart()
{  
	if (GetFeatureStatus(FeatureType_Native, "GetSoundLengthFloat") == FeatureStatus_Available)
	{
		soundLib = true;
	}  
	else
	{
		soundLib = false;
	}
	
	//Cvars
	CreateConVar("abner_res_version", PLUGIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hTRPath = CreateConVar("res_tr_path", "misc/tecnohard", "Path off tr sounds in /cstrike/sound");
	g_hCTPath = CreateConVar("res_ct_path", "misc/tecnohard", "Path off ct sounds in /cstrike/sound");
	g_hPlayType = CreateConVar("res_play_type", "1", "1 - Random, 2- Play in queue");
	g_hStop = CreateConVar("res_stop_map_music", "1", "Stop map musics");	
	g_playToTheEnd = CreateConVar("res_play_to_the_end", "1", "Play sounds to the end.");
	g_roundDrawPlay = CreateConVar("res_rounddraw_play", "0", "0 - Don´t play sounds, 1 - Play TR sounds, 2 - Play CT sounds.");
	
	
	//ClientPrefs
	g_AbNeRCookie = RegClientCookie("AbNeR Round End Sounds", "", CookieAccess_Private);
	new info;
	SetCookieMenuItem(SoundCookieHandler, any:info, "AbNeR Round End Sounds");
	
	for (new i = MaxClients; i > 0; --i)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        OnClientCookiesCached(i);
    }
	
	LoadTranslations("common.phrases");
	LoadTranslations("abner_res.phrases");
		
	AutoExecConfig(true, "abner_res");

	RegAdminCmd("res_refresh", CommandLoad, ABNER_ADMINFLAG);
	RegConsoleCmd("res", abnermenu);
	
	HookConVarChange(g_hTRPath, PathChange);
	HookConVarChange(g_hCTPath, PathChange);
	HookConVarChange(g_hPlayType, PathChange);
	
	decl String:theFolder[40];
	GetGameFolderName(theFolder, sizeof(theFolder));
	if(StrEqual(theFolder, "csgo"))
	{
		CSGO = true;
	}
	else
	{
		CSGO = false;
	}
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}


stock bool:IsValidClient(client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

public StopMapMusic()
{
	decl String:sSound[PLATFORM_MAX_PATH];
	new entity = INVALID_ENT_REFERENCE;
	for(new i=1;i<=MaxClients;i++){
		if(!IsClientInGame(i)){ continue; }
		for (new u=0; u<g_iNumSounds; u++){
			entity = EntRefToEntIndex(g_iSoundEnts[u]);
			if (entity != INVALID_ENT_REFERENCE){
				GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
				Client_StopSound(i, entity, SNDCHAN_STATIC, sSound);
			}
		}
	}
}



stock Client_StopSound(client, entity, channel, const String:name[])
{
	EmitSoundToClient(client, name, entity, channel, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
}


public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	lenghtStored = false;
	CurrentSoundLenght = 0.0;
	if(GetConVarInt(g_hStop) == 1)
	{
		// Ents are recreated every round.
		g_iNumSounds = 0;
		
		// Find all ambient sounds played by the map.
		decl String:sSound[PLATFORM_MAX_PATH];
		new entity = INVALID_ENT_REFERENCE;
		
		while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
			
			new len = strlen(sSound);
			if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
			}
		}
	}
}



public SoundCookieHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	OnClientCookiesCached(client);
	abnermenu(client, 0);
} 

public OnClientPutInServer(client)
{
	CreateTimer(3.0, msg, client);
}

public Action:msg(Handle:timer, any:client)
{
	if(IsValidClient(client))
	{
		CPrintToChat(client, "{default}{green}[AbNeR RES] {default}%t", "JoinMsg");
	}
}

public Action:abnermenu(client, args)
{
	GetClientCookie(client, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
	new cookievalue = StringToInt(sCookieValue);
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_AbNeRMenu, "Round End Sounds by AbNeR_CSS");
	decl String:Item[128];
	if(cookievalue == 0)
	{
		Format(Item, sizeof(Item), "%t %t", "RES_ON", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t", "RES_OFF"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "%t", "RES_ON");
		AddMenuItem(g_AbNeRMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t %t", "RES_OFF", "Selected"); 
		AddMenuItem(g_AbNeRMenu, "OFF", Item);
	}
	SetMenuExitBackButton(g_AbNeRMenu, true);
	SetMenuExitButton(g_AbNeRMenu, true);
	DisplayMenu(g_AbNeRMenu, client, 30);
}

public AbNeRMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new Handle:g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(param1);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(param1, g_AbNeRCookie, "0");
				abnermenu(param1, 0);
			}
			case 1:
			{
				SetClientCookie(param1, g_AbNeRCookie, "1");
				abnermenu(param1, 0);
			}
		}
		CloseHandle(g_AbNeRMenu);
	}
	return 0;
}



public OnClientCookiesCached(client)
{
    decl String:sValue[8];
    GetClientCookie(client, g_AbNeRCookie, sValue, sizeof(sValue));
    
    g_bClientPreference[client] = (sValue[0] != '\0' && StringToInt(sValue));
} 


public PathChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{       
	OnMapStart();
}

public OnMapStart()
{
	decl String:soundpath[PLATFORM_MAX_PATH];
	decl String:soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	GetConVarString(g_hCTPath, soundpath2, sizeof(soundpath2));
	
	if(StrEqual(soundpath, soundpath2))
	{
		LoadSoundsTR(0);
		SamePath = true;
	}
	else
	{
		LoadSoundsTR(0);
		LoadSoundsCT(0);
		SamePath = false;
	}
}

 
LoadSoundsTR(client)
{
	new namelen;
	new FileType:type;
	new String:name[64];
	new String:soundname[64];
	new String:soundname2[64];
	decl String:soundpath[PLATFORM_MAX_PATH];
	decl String:soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	new Handle:pluginsdir = OpenDirectory(soundpath2);
	g_SoundsTR = 0;
	SoundsTRSucess = (pluginsdir != INVALID_HANDLE);
	if(SoundsTRSucess)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name),type))
		{
			namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname2, sizeof(soundname2), "%s/%s", soundpath, name);
				if(g_SoundsTR < MAX_SOUNDS-1)
					soundtr[g_SoundsTR++] = soundname2;
			}
		}
		SoundsTRSucess = g_SoundsTR > 0;
		if(!SamePath)
		{
			if(IsValidClient(client))
				ReplyToCommand(client, "[AbNeR RES] TR_SOUNDS: %d sounds loaded.", g_SoundsTR);
			PrintToServer("[AbNeR RES] TR_SOUNDS: %d sounds loaded.", g_SoundsTR);
		}
		else
		{
			if(IsValidClient(client))
				ReplyToCommand(client, "[AbNeR RES] SOUNDS: %d sounds loaded.", g_SoundsTR);
			PrintToServer("[AbNeR RES] SOUNDS: %d sounds loaded.", g_SoundsTR);
		}
	}
	else
	{
		if(IsValidClient(client))
			ReplyToCommand(client, "[AbNeR RES] ERROR: Invalid \"res_tr_path\".");
		PrintToServer("[AbNeR RES] ERROR: Invalid \"res_tr_path\".");
	}
}

LoadSoundsCT(client)
{
	new namelen;
	new FileType:type;
	new String:name[64];
	new String:soundname[64];
	new String:soundname2[64];
	decl String:soundpath[PLATFORM_MAX_PATH];
	decl String:soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hCTPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	new Handle:pluginsdir = OpenDirectory(soundpath2);
	g_SoundsCT = 0;
	SoundsCTSucess = (pluginsdir != INVALID_HANDLE);
	if(SoundsCTSucess)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name),type))
		{
			namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname2, sizeof(soundname2), "%s/%s", soundpath, name);
				if(g_SoundsCT < MAX_SOUNDS-1)
					soundct[g_SoundsCT++] = soundname2;
			}
		}
		SoundsCTSucess = g_SoundsCT > 0;
		if(IsValidClient(client))
			ReplyToCommand(client, "[AbNeR RES] CT_SOUNDS: %d sounds loaded.", g_SoundsCT);
		PrintToServer("[AbNeR RES] CT_SOUNDS: %d sounds loaded.", g_SoundsCT);
	}
	else
	{
		if(IsValidClient(client))
			ReplyToCommand(client, "[AbNeR RES] ERROR: Invalid \"res_ct_path\".");
		PrintToServer("[AbNeR RES] ERROR: Invalid \"res_ct_path\".");
	}
}


DeleteTRSound(rnd_sound)
{
	for (new i = 0; i < g_SoundsTR; i++)
	{
		if(i >= rnd_sound)
			soundtr[i] = soundtr[i+1];
	}
	if(--g_SoundsTR == 0)
		LoadSoundsTR(0);
}

DeleteCTSound(rnd_sound)
{
	for (new i = 0; i < g_SoundsCT; i++)
	{
		if(i >= rnd_sound)
			soundct[i] = soundct[i+1];
	}
	if(--g_SoundsCT == 0)
		LoadSoundsCT(0);
}


PlaySoundTRCSGO()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_SoundsTR-1);
	}
	else
	{
		soundToPlay = 0;
	}
	soundLenght(soundtr[soundToPlay]);
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "playgamesound Music.StopAllMusic");
			ClientCommand(i, "play *%s", soundtr[soundToPlay]);
		}
	}
	DeleteTRSound(soundToPlay);
}



PlaySoundCTCSGO()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_SoundsCT-1);
	}
	else
	{
		soundToPlay = 0;
	}
	soundLenght(soundct[soundToPlay]);
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "playgamesound Music.StopAllMusic");
			ClientCommand(i, "play *%s", soundct[soundToPlay]);
		}
	}
	DeleteCTSound(soundToPlay);
}


PlaySoundTR()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_SoundsTR-1);
	}
	else
	{
		soundToPlay = 0;
	}
	
	soundLenght(soundtr[soundToPlay]);
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "play %s", soundtr[soundToPlay]);
		}
	}
	DeleteTRSound(soundToPlay);
	
}

PlaySoundCT()
{
	new soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, g_SoundsCT-1);
	}
	else
	{
		soundToPlay = 0;
	}
	soundLenght(soundct[soundToPlay]);
	for (new i = 1; i <= MaxClients; i++)
	{
		GetClientCookie(i, g_AbNeRCookie, sCookieValue, sizeof(sCookieValue));
		new cookievalue = StringToInt(sCookieValue);
		if(IsValidClient(i) && cookievalue == 0)
		{
			ClientCommand(i, "play %s", soundct[soundToPlay]);
		}
	}
	DeleteCTSound(soundToPlay);
}


soundLenght(String:sound[])
{
	if(soundLib)
	{
		new Handle:Sound = OpenSoundFile(sound);
		if(Sound != INVALID_HANDLE)
			CurrentSoundLenght = GetSoundLengthFloat(Sound);
		else
			CurrentSoundLenght = 0.0;
	}
	lenghtStored = true;
}

//Round End Reasons
//TRWIN 0 2 3 8 12 14 17 19
//CTWIN 4 5 6 7 10 11 13 16
//DRAW 9 15

int GetWinner(CSRoundEndReason:reason)
{
	if(reason == CSRoundEndReason:0 
	|| reason == CSRoundEndReason:2 
	|| reason == CSRoundEndReason:3	
	|| reason == CSRoundEndReason:8 
	|| reason == CSRoundEndReason:12 
	|| reason == CSRoundEndReason:14
	|| reason == CSRoundEndReason:19 //Added v3.2
	)
		return 2;
		
	else if(reason != CSRoundEndReason:9
			&& reason != CSRoundEndReason:15)
		return 3;
	
	return 0;
}

public Action:CS_OnTerminateRound(&Float:delay, &CSRoundEndReason:reason)
{
	new winner = GetWinner(CSRoundEndReason:reason);
	
	if(winner == 0)
	{
		if(GetConVarInt(g_roundDrawPlay) == 1) winner = 2;
		else if(GetConVarInt(g_roundDrawPlay) == 2) winner = 3;
	}
	
	if(GetConVarInt(g_hStop) == 1)
	{
		StopMapMusic();
	}
	if((SamePath && winner >= 2) || winner == 2)
	{
		if(SoundsTRSucess)
		{
			if(CSGO) PlaySoundTRCSGO();
			else PlaySoundTR();
		}
		else
		{
			if(!SamePath) PrintToServer("[AbNeR RES] TR_SOUNDS ERROR: Sounds not loaded.");
			else PrintToServer("[AbNeR RES] SOUNDS ERROR: Sounds not loaded.");
			winner = 0;
		}
	}
	else if (winner == 3)
	{
		if(SoundsCTSucess)
		{
			if(CSGO) PlaySoundCTCSGO();
			else PlaySoundCT();
		}
		else
		{
			PrintToServer("[AbNeR RES] CT_SOUNDS ERROR: Sounds not loaded.");
			winner = 0;
		}
	}
	
	if(GetConVarInt(g_playToTheEnd) == 1 && winner > 0 && soundLib)
	{
		while(!lenghtStored){} //Do Nothing just wait...
		if(CurrentSoundLenght > 0.0)
		{
			CS_TerminateRound(CurrentSoundLenght, CSRoundEndReason:reason, true);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
 

public Action:CommandLoad(client, args)
{   
	decl String:soundpath[PLATFORM_MAX_PATH];
	decl String:soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	GetConVarString(g_hCTPath, soundpath2, sizeof(soundpath2));
	if(StrEqual(soundpath, soundpath2))
	{
		LoadSoundsTR(client);
		SamePath = true;
	}
	else
	{
		LoadSoundsTR(client);
		LoadSoundsCT(client);
		SamePath = false;
	}
	return Plugin_Handled;
}








