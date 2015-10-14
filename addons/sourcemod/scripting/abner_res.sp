#include <sourcemod>
#include <sdktools>
#include <colors>
#include <clientprefs>
#include <cstrike>

//SoundLib Optional
#undef REQUIRE_EXTENSIONS
#include <soundlib>
bool soundLib;

#pragma newdecls required // 2015 rules 
#pragma semicolon 1
#define PLUGIN_VERSION "3.3"

//MapSounds Stuff
int g_iSoundEnts[2048];
int g_iNumSounds;

//Cvars
Handle g_hCTPath;
Handle g_hTRPath;
Handle g_hPlayType;
Handle g_AbNeRCookie;
Handle g_hStop;
Handle g_playToTheEnd;
Handle g_roundDrawPlay;

bool SoundsTRSucess = false;
bool SoundsCTSucess = false;
bool SamePath = false;
bool CSGO;
ArrayList ctSound;
ArrayList trSound;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("GetSoundLengthFloat");
	MarkNativeAsOptional("OpenSoundFile");
	return APLRes_Success;
}


public Plugin myinfo =
{
	name = "[CS:GO/CSS] AbNeR Round End Sounds",
	author = "AbNeR_CSS",
	description = "Play cool musics when round ends!",
	version = PLUGIN_VERSION,
	url = "http://www.tecnohardclan.com/forum/"
}

public void OnPluginStart()
{  
	soundLib = (GetFeatureStatus(FeatureType_Native, "GetSoundLengthFloat") == FeatureStatus_Available);
	
	//Cvars
	CreateConVar("abner_res_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hTRPath = CreateConVar("res_tr_path", "misc/tecnohard", "Path off tr sounds in /cstrike/sound");
	g_hCTPath = CreateConVar("res_ct_path", "misc/tecnohard", "Path off ct sounds in /cstrike/sound");
	g_hPlayType = CreateConVar("res_play_type", "1", "1 - Random, 2- Play in queue");
	g_hStop = CreateConVar("res_stop_map_music", "1", "Stop map musics");	
	g_playToTheEnd = CreateConVar("res_play_to_the_end", "0", "Play sounds to the end.");
	g_roundDrawPlay = CreateConVar("res_rounddraw_play", "0", "0 - Don´t play sounds, 1 - Play TR sounds, 2 - Play CT sounds.");
		
	//ClientPrefs
	g_AbNeRCookie = RegClientCookie("AbNeR Round End Sounds", "", CookieAccess_Private);
	SetCookieMenuItem(SoundCookieHandler, 0, "AbNeR Round End Sounds");
	
	LoadTranslations("common.phrases");
	LoadTranslations("abner_res.phrases");
		
	AutoExecConfig(true, "abner_res");

	RegAdminCmd("res_refresh", CommandLoad, ADMFLAG_SLAY);
	RegConsoleCmd("res", abnermenu);
	
	HookConVarChange(g_hTRPath, PathChange);
	HookConVarChange(g_hCTPath, PathChange);
	HookConVarChange(g_hPlayType, PathChange);
	
	char theFolder[40];
	GetGameFolderName(theFolder, sizeof(theFolder));
	CSGO = StrEqual(theFolder, "csgo");
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	ctSound = new ArrayList(128);
	trSound = new ArrayList(128);
}


stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

public void StopMapMusic()
{
	char sSound[PLATFORM_MAX_PATH];
	int entity = INVALID_ENT_REFERENCE;
	for(int i=1;i<=MaxClients;i++){
		if(!IsClientInGame(i)){ continue; }
		for (int u=0; u<g_iNumSounds; u++){
			entity = EntRefToEntIndex(g_iSoundEnts[u]);
			if (entity != INVALID_ENT_REFERENCE){
				GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
				Client_StopSound(i, entity, SNDCHAN_STATIC, sSound);
			}
		}
	}
}

stock void Client_StopSound(int client, int entity, int channel, const char[] name)
{
	EmitSoundToClient(client, name, entity, channel, SNDLEVEL_NONE, SND_STOP, 0.0, SNDPITCH_NORMAL, _, _, _, true);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(g_hStop) == 1)
	{
		// Ents are recreated every round.
		g_iNumSounds = 0;
		
		// Find all ambient sounds played by the map.
		char sSound[PLATFORM_MAX_PATH];
		int entity = INVALID_ENT_REFERENCE;
		
		while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
		{
			GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
			
			int len = strlen(sSound);
			if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				g_iSoundEnts[g_iNumSounds++] = EntIndexToEntRef(entity);
			}
		}
	}
}

public void SoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	abnermenu(client, 0);
} 

public void OnClientPutInServer(int client)
{
	CreateTimer(3.0, msg, client);
}

public Action msg(Handle timer, any client)
{
	if(IsValidClient(client))
	{
		CPrintToChat(client, "{default}{green}[AbNeR RES] {default}%t", "JoinMsg");
	}
}

public Action abnermenu(int client, int args)
{
	int cookievalue = GetIntCookie(client, g_AbNeRCookie);
	Handle g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_AbNeRMenu, "Round End Sounds by AbNeR_CSS");
	char Item[128];
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

public int AbNeRMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	Handle g_AbNeRMenu = CreateMenu(AbNeRMenuHandler);
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

public void PathChange(Handle cvar, const char[] oldVal, const char[] newVal)
{       
	RefreshSounds(0);
}

public void OnMapStart()
{
	RefreshSounds(0);
}

void RefreshSounds(int client)
{
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	GetConVarString(g_hCTPath, soundpath2, sizeof(soundpath2));
	SamePath = StrEqual(soundpath, soundpath2);
	int size;
	if(SamePath)
	{
		size = LoadSoundsTR();
		SoundsTRSucess = (size > 0);
		if(SoundsTRSucess)
			ReplyToCommand(client, "[AbNeR RES] SOUNDS: %d sounds loaded.", size);
		else
			ReplyToCommand(client, "[AbNeR RES] INVALID TR SOUND PATH.");
	}
	else
	{
		size = LoadSoundsTR();
		SoundsTRSucess = (size > 0);
		if(SoundsTRSucess)
			ReplyToCommand(client, "[AbNeR RES] TR_SOUNDS: %d sounds loaded.", size);
		else
			ReplyToCommand(client, "[AbNeR RES] INVALID TR SOUND PATH.");
		
		size = LoadSoundsCT();
		SoundsCTSucess = (size > 0);
		if(SoundsCTSucess)
			ReplyToCommand(client, "[AbNeR RES] CT_SOUNDS: %d sounds loaded.", size);
		else
			ReplyToCommand(client, "[AbNeR RES] INVALID CT SOUND PATH.");
	}
}
 
int LoadSoundsCT()
{
	ctSound.Clear();
	char name[64];
	char soundname[64];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hCTPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle pluginsdir = OpenDirectory(soundpath2);
	SoundsCTSucess = (pluginsdir != INVALID_HANDLE);
	if(SoundsCTSucess)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				ctSound.PushString(soundname);
			}
		}
	}
	return ctSound.Length;
}

int LoadSoundsTR()
{
	trSound.Clear();
	char name[64];
	char soundname[64];
	char soundpath[PLATFORM_MAX_PATH];
	char soundpath2[PLATFORM_MAX_PATH];
	GetConVarString(g_hTRPath, soundpath, sizeof(soundpath));
	Format(soundpath2, sizeof(soundpath2), "sound/%s/", soundpath);
	Handle pluginsdir = OpenDirectory(soundpath2);
	SoundsCTSucess = (pluginsdir != INVALID_HANDLE);
	if(SoundsCTSucess)
	{
		while(ReadDirEntry(pluginsdir,name,sizeof(name)))
		{
			int namelen = strlen(name) - 4;
			if(StrContains(name,".mp3",false) == namelen)
			{
				Format(soundname, sizeof(soundname), "sound/%s/%s", soundpath, name);
				AddFileToDownloadsTable(soundname);
				Format(soundname, sizeof(soundname), "%s/%s", soundpath, name);
				trSound.PushString(soundname);
			}
		}
	}
	return trSound.Length;
}

float PlaySoundCT()
{
	int soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, ctSound.Length-1);
	}
	else
	{
		soundToPlay = 0;
	}
	
	char szSound[128];
	ctSound.GetString(soundToPlay, szSound, sizeof(szSound));
	ctSound.Erase(soundToPlay);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && GetIntCookie(i, g_AbNeRCookie) == 0)
		{
			if(CSGO)
			{
				ClientCommand(i, "playgamesound Music.StopAllMusic");
				ClientCommand(i, "play *%s", szSound);
			}
			else
				ClientCommand(i, "play %s", szSound);
		}
	}
	if(ctSound.Length == 0)
		LoadSoundsCT();
	return soundLenght(szSound);
}

float PlaySoundTR()
{
	int soundToPlay;
	if(GetConVarInt(g_hPlayType) == 1)
	{
		soundToPlay = GetRandomInt(0, trSound.Length-1);
	}
	else
	{
		soundToPlay = 0;
	}
	
	char szSound[128];
	trSound.GetString(soundToPlay, szSound, sizeof(szSound));
	trSound.Erase(soundToPlay);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && GetIntCookie(i, g_AbNeRCookie) == 0)
		{
			if(CSGO)
			{
				ClientCommand(i, "playgamesound Music.StopAllMusic");
				ClientCommand(i, "play *%s", szSound);
			}
			else
				ClientCommand(i, "play %s", szSound);
		}
	}
	if(trSound.Length == 0)
		LoadSoundsTR();
	return soundLenght(szSound);
}


float soundLenght(char[] sound)
{
	float CurrentSoundLenght = 0.0;
	if(soundLib)
	{
		Handle Sound = OpenSoundFile(sound);
		if(Sound != INVALID_HANDLE)
			CurrentSoundLenght = GetSoundLengthFloat(Sound);
	}
	return CurrentSoundLenght;
}

//Round End Reasons
//TRWIN 0 2 3 8 12 14 17 19
//CTWIN 4 5 6 7 10 11 13 16
//DRAW 9 15

int TRWIN[] = {0, 2, 3, 8, 12, 14, 17, 19};
int CTWIN[] = {4, 5, 6, 7, 10, 11, 13, 16};

bool IsCTReason(int reason)
{
	for(int i = 0;i<sizeof(CTWIN);i++)
	{
		if(CTWIN[i] == reason) return true;
	}
	return false;
}

bool IsTRReason(int reason)
{
	for(int i = 0;i<sizeof(TRWIN);i++)
	{
		if(TRWIN[i] == reason) return true;
	}
	return false;
}

int GetWinner(int reason)
{
	if(IsTRReason(reason))
	{
		//PrintToChatAll("TR WIN");
		return 2;
	}
	if(IsCTReason(reason))
	{
		//PrintToChatAll("CT WIN");
		return 3;
	}
	//PrintToChatAll("DRAW");
	return 0;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	char szReason[5];
	Format(szReason, sizeof(szReason), "%d", reason);
	int reason2 = StringToInt(szReason);
	int winner = GetWinner(reason2);
	float CurrentSoundLenght;
	
	if(winner == 0)
	{
		if(GetConVarInt(g_roundDrawPlay) == 1) winner = 2;
		else if(GetConVarInt(g_roundDrawPlay) == 2) winner = 3;
	}
	else if(winner == 3 && SamePath)
	{
		winner = 2;
	}
	
	switch(winner)
	{
		case 0:
		{
			return Plugin_Continue;
		}
		case 2:
		{
			if(SoundsTRSucess)
			{
				CurrentSoundLenght = PlaySoundTR();
			}
			else
			{
				if(!SamePath) PrintToServer("[AbNeR RES] TR_SOUNDS ERROR: Sounds not loaded.");
				else PrintToServer("[AbNeR RES] SOUNDS ERROR: Sounds not loaded.");
				return Plugin_Continue;
			}
		}	
		case 3:
		{
			if(SoundsCTSucess)
			{
				CurrentSoundLenght = PlaySoundCT();
			}
			else
			{
				PrintToServer("[AbNeR RES] CT_SOUNDS ERROR: Sounds not loaded.");
				return Plugin_Continue;
			}
		}
	}
	
	if(GetConVarInt(g_hStop) == 1)
		StopMapMusic();
	
	if(GetConVarInt(g_playToTheEnd) == 1 && soundLib && CurrentSoundLenght > 0.0)
	{
		CS_TerminateRound(CurrentSoundLenght, reason, true);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}


public Action CommandLoad(int client, int args)
{   
	RefreshSounds(client);
	return Plugin_Handled;
}


int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[11];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}





