#include <sourcemod>
#include <sdktools>
#include <colors>
#include <clientprefs>
#include <cstrike>

bool soundLib;

#include <abnersound>

#pragma newdecls required
#pragma semicolon 1
#define PLUGIN_VERSION "4.0.2"

ConVar	  g_hCTPath;
ConVar	  g_hTRPath;
ConVar	  g_hDrawPath;
ConVar	  g_hPlayType;
ConVar	  g_hStop;
ConVar	  g_PlayPrint;
ConVar	  g_SoundVolume;
ConVar	  g_playToTheEnd;

bool	  SamePath = false;
Handle	  g_ResPlayCookie;
Handle	  g_ResVolumeCookie;

ArrayList ctSoundsArray;
ArrayList trSoundsArray;
ArrayList drawSoundsArray;
StringMap soundNames;

public Plugin myinfo =
{
	name		= "AbNeR Round End Sounds",
	author		= "abnerfs",
	description = "Play cool musics when round ends!",
	version		= PLUGIN_VERSION,
	url			= "https://github.com/abnerfs/round_end_sounds"


}

public void
	OnPluginStart()
{
	CreateConVar("abner_res_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_REPLICATED);

	g_hTRPath		  = CreateConVar("res_tr_path", "misc/abner_res", "Path of sounds played when Ts wins");
	g_hCTPath		  = CreateConVar("res_ct_path", "misc/abner_res", "Path of sounds played when CTs wins");
	g_hDrawPath		  = CreateConVar("res_draw_path", "0", "Path of sounds played when the round draws: 0 - No sounds, 1 - T Sounds, 2 - CT Sounds");

	g_hPlayType		  = CreateConVar("res_play_type", "1", "1 - Random, 2 - Play in order");
	g_hStop			  = CreateConVar("res_stop_map_music", "1", "Stop map musics");

	g_PlayPrint		  = CreateConVar("res_print_to_chat_sound_name", "1", "Print mp3 name in chat");
	g_SoundVolume	  = CreateConVar("res_default_volume", "0.75", "Default volume.");
	g_playToTheEnd	  = CreateConVar("res_play_to_the_end", "0", "Play sounds to the end (requires soundlib)");

	g_ResPlayCookie	  = RegClientCookie("AbNeR Round End Sounds", "", CookieAccess_Private);
	g_ResVolumeCookie = RegClientCookie("abner_res_volume", "Round end sound volume", CookieAccess_Private);

	SetCookieMenuItem(SoundCookieHandler, 0, "AbNeR Round End Sounds");

	LoadTranslations("common.phrases");
	LoadTranslations("abner_res.phrases");
	AutoExecConfig(true, "abner_res");

	RegAdminCmd("res_refresh", CommandLoad, ADMFLAG_SLAY, "Refresh sounds");
	RegConsoleCmd("res", abnermenu, "Open Config Menu");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	soundLib		= (GetFeatureStatus(FeatureType_Native, "GetSoundLengthFloat") == FeatureStatus_Available);

	ctSoundsArray	= new ArrayList(512);
	trSoundsArray	= new ArrayList(512);
	drawSoundsArray = new ArrayList(512);
	soundNames		= new StringMap();
}

stock bool IsValidClient(int client)
{
	if (client <= 0) return false;
	if (client > MaxClients) return false;
	if (!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}

int	 TRWIN[] = { 0, 3, 8, 12, 17, 18 };
int	 CTWIN[] = { 4, 5, 6, 7, 10, 11, 13, 16, 19 };

bool IsCTReason(int reason)
{
	for (int i = 0; i < sizeof(CTWIN); i++)
		if (CTWIN[i] == reason) return true;

	return false;
}

bool IsTRReason(int reason)
{
	for (int i = 0; i < sizeof(TRWIN); i++)
		if (TRWIN[i] == reason) return true;

	return false;
}

int GetWinner(int reason)
{
	if (IsTRReason(reason))
		return 2;

	if (IsCTReason(reason))
		return 3;

	return 0;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	int	 winner = GetWinner(view_as<int>(reason));
	bool random = GetConVarInt(g_hPlayType) == 1;

	char szSound[128];

	bool Success = false;
	if ((winner == CS_TEAM_CT && SamePath) || winner == CS_TEAM_T)
		Success = GetSound(trSoundsArray, g_hTRPath, random, szSound, sizeof(szSound));
	else if (winner == CS_TEAM_CT)
		Success = GetSound(ctSoundsArray, g_hCTPath, random, szSound, sizeof(szSound));
	else
		Success = GetSound(drawSoundsArray, g_hDrawPath, random, szSound, sizeof(szSound));

	if (Success)
	{
		PlayMusicAll(szSound);

		if (GetConVarInt(g_hStop) == 1)
			StopMapMusic();

		if (GetConVarBool(g_playToTheEnd) && soundLib)
		{
			float length = soundLenght(szSound);
			delay		 = length;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

void PlayMusicAll(char[] szSound)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetIntCookie(i, g_ResPlayCookie) == 0)
		{
			float selectedVolume = GetClientVolume(i);
			PlaySoundClient(i, szSound, selectedVolume);
		}
	}

	if (GetConVarInt(g_PlayPrint) == 1)
	{
		char soundKey[100];
		char soundPrint[512];
		char buffer[20][255];

		int	 numberRetrieved = ExplodeString(szSound, "/", buffer, sizeof(buffer), sizeof(buffer[]), false);
		if (numberRetrieved > 0)
			Format(soundKey, sizeof(soundKey), buffer[numberRetrieved - 1]);

		PrintToChatAll(soundKey);
		soundNames.GetString(soundKey, soundPrint, sizeof(soundPrint));

		CPrintToChatAll("%t%t", "prefix", "mp3 print", !StrEqual(soundPrint, "") ? soundPrint : szSound);
	}
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(g_hStop) == 1)
	{
		MapSounds();
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
	if (IsValidClient(client))
	{
		CPrintToChat(client, "%t%t", "prefix", "JoinMsg");
	}
	return Plugin_Continue;
}

public Action abnermenu(int client, int args)
{
	int	   cookievalue	= GetIntCookie(client, g_ResPlayCookie);
	Handle g_CookieMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_CookieMenu, "Round End Sounds by github.com/abnerfs");
	char Item[128];
	if (cookievalue == 0)
	{
		Format(Item, sizeof(Item), "%t %t", "RES_ON", "Selected");
		AddMenuItem(g_CookieMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t", "RES_OFF");
		AddMenuItem(g_CookieMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "%t", "RES_ON");
		AddMenuItem(g_CookieMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t %t", "RES_OFF", "Selected");
		AddMenuItem(g_CookieMenu, "OFF", Item);
	}

	Format(Item, sizeof(Item), "%t", "VOLUME");
	AddMenuItem(g_CookieMenu, "volume", Item);

	SetMenuExitBackButton(g_CookieMenu, true);
	SetMenuExitButton(g_CookieMenu, true);
	DisplayMenu(g_CookieMenu, client, 30);
	return Plugin_Continue;
}

public int AbNeRMenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	Handle g_CookieMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if (param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(client);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(client, g_ResPlayCookie, "0");
				abnermenu(client, 0);
			}
			case 1:
			{
				SetClientCookie(client, g_ResPlayCookie, "1");
				abnermenu(client, 0);
			}
			case 2:
			{
				VolumeMenu(client);
			}
		}
		CloseHandle(g_CookieMenu);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void VolumeMenu(int client)
{
	float volumeArray[]	 = { 1.0, 0.75, 0.50, 0.25, 0.10 };
	float selectedVolume = GetClientVolume(client);

	Menu  volumeMenu	 = new Menu(VolumeMenuHandler);
	volumeMenu.SetTitle("%t", "Sound Menu Title");
	volumeMenu.ExitBackButton = true;

	for (int i = 0; i < sizeof(volumeArray); i++)
	{
		char strInfo[10];
		Format(strInfo, sizeof(strInfo), "%0.2f", volumeArray[i]);

		char display[20], selected[5];
		if (volumeArray[i] == selectedVolume)
			Format(selected, sizeof(selected), "%t", "Selected");

		Format(display, sizeof(display), "%s %s", strInfo, selected);

		volumeMenu.AddItem(strInfo, display);
	}

	volumeMenu.Display(client, MENU_TIME_FOREVER);
}

public int VolumeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[10];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		SetClientCookie(client, g_ResVolumeCookie, sInfo);
		VolumeMenu(client);
	}
	else if (param2 == MenuCancel_ExitBack)
	{
		abnermenu(client, 0);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

public void OnMapStart()
{
	RefreshSounds(0);
}

void RefreshSounds(int client)
{
	char trSoundPath[PLATFORM_MAX_PATH];
	char ctSoundPath[PLATFORM_MAX_PATH];
	char drawSoundPath[PLATFORM_MAX_PATH];

	GetConVarString(g_hTRPath, trSoundPath, sizeof(trSoundPath));
	GetConVarString(g_hCTPath, ctSoundPath, sizeof(ctSoundPath));
	GetConVarString(g_hDrawPath, drawSoundPath, sizeof(drawSoundPath));

	SamePath = StrEqual(trSoundPath, ctSoundPath);

	if (SamePath)
	{
		CReplyToCommand(client, "%t SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", LoadSounds(trSoundsArray, g_hTRPath), trSoundPath);
	}
	else
	{
		ReplyToCommand(client, "%t CT SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", LoadSounds(ctSoundsArray, g_hCTPath), ctSoundPath);
		ReplyToCommand(client, "%t TR SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", LoadSounds(trSoundsArray, g_hTRPath), trSoundPath);
	}

	int RoundDrawOption = GetConVarInt(g_hDrawPath);
	if (RoundDrawOption != 0)
		switch (RoundDrawOption)
		{
			case 1:
			{
				drawSoundsArray = trSoundsArray;
				g_hDrawPath		= g_hTRPath;
				ReplyToCommand(client, "%t DRAW SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", trSoundsArray.Length, trSoundPath);
			}
			case 2:
			{
				drawSoundsArray = ctSoundsArray;
				g_hDrawPath		= g_hCTPath;
				ReplyToCommand(client, "%t DRAW SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", ctSoundsArray.Length, ctSoundPath);
			}
			default:
			{
				char drawSoundsPath[PLATFORM_MAX_PATH];
				GetConVarString(g_hDrawPath, drawSoundsPath, sizeof(drawSoundsPath));

				if (!StrEqual(drawSoundsPath, ""))
					ReplyToCommand(client, "%t DRAW SOUNDS: %d sounds loaded from \"sound/%s\"", "prefix", LoadSounds(drawSoundsArray, g_hDrawPath), drawSoundsPath);
			}
		}

	ParseSongNameKvFile();
}

public void ParseSongNameKvFile()
{
	soundNames.Clear();

	char sPath[PLATFORM_MAX_PATH];
	Format(sPath, sizeof(sPath), "configs/abner_res.txt");
	BuildPath(Path_SM, sPath, sizeof(sPath), sPath);

	if (!FileExists(sPath))
		return;

	KeyValues hKeyValues = CreateKeyValues("Abner Res");
	if (!hKeyValues.ImportFromFile(sPath))
		return;

	if (hKeyValues.GotoFirstSubKey())
	{
		do
		{
			char sSectionName[255];
			char sSongName[255];

			hKeyValues.GetSectionName(sSectionName, sizeof(sSectionName));
			hKeyValues.GetString("songname", sSongName, sizeof(sSongName));
			soundNames.SetString(sSectionName, sSongName);
		}
		while (hKeyValues.GotoNextKey(false));
	}
	hKeyValues.Close();
}

public Action CommandLoad(int client, int args)
{
	RefreshSounds(client);
	return Plugin_Handled;
}

float GetClientVolume(int client)
{
	float defaultVolume = GetConVarFloat(g_SoundVolume);

	char  sCookieValue[11];
	GetClientCookie(client, g_ResVolumeCookie, sCookieValue, sizeof(sCookieValue));

	if (StrEqual(sCookieValue, "") || StrEqual(sCookieValue, "0"))
		Format(sCookieValue, sizeof(sCookieValue), "%0.2f", defaultVolume);

	return StringToFloat(sCookieValue);
}

int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[11];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}
