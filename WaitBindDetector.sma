#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN_NAME "WaitBindDetector"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR "Reavap"

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined MAX_PLAYERS
	#define MAX_PLAYERS 32
#endif

#if !defined PLATFORM_MAX_PATH
	#define PLATFORM_MAX_PATH 256
#endif

#define PLUGIN_ACCESS_LEVEL ADMIN_KICK
#define CONSECUTIVE_WARNING_COUNT 50

#pragma semicolon 1

new g_sLogFile[PLATFORM_MAX_PATH];
new const g_sAdminNotificationSpk[] = "spk ^"buttons/blip2^"";

new wbd_punishment;
new wbd_log_detection;

enum _:
{
	SLAY = 1,
	KICK
};

enum _:g_iTypes
{
	JUMP_WAIT_JUMP,
	DUCK_WAIT_DUCK
};

new const g_iCommandTypes[g_iTypes] =
{
	IN_JUMP,
	IN_DUCK
};

new const g_sCommandStrings[g_iTypes][] =
{
	"jump wait jump",
	"duck wait duck"
};

new bool:g_bAlive[MAX_PLAYERS + 1];

new g_iPreviousOldButtons[MAX_PLAYERS + 1];
new g_iOldButtons[MAX_PLAYERS + 1];
new g_iButtons[MAX_PLAYERS + 1];

new bool:g_bPrevCommandLastedOneFrame[MAX_PLAYERS + 1][g_iTypes];
new g_iConsecutiveDelayedButtons[MAX_PLAYERS + 1][g_iTypes];

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	RegisterHam(Ham_Spawn, "player", "fwdHamSpawn",	1);
	RegisterHam(Ham_Killed, "player", "fwdHamKilled", 0);
	
	register_forward(FM_CmdStart, "fwdCmdStart");
	
	wbd_punishment = register_cvar("wbd_punishment", "1");
	wbd_log_detection = register_cvar("wbd_log_detection", "1");
	
	new iLen = get_localinfo("amxx_logs", g_sLogFile, charsmax(g_sLogFile));
	formatex(g_sLogFile[iLen], (charsmax(g_sLogFile) - iLen), "/waitbinds.log");
}

public client_disconnected(id)
{
	g_bAlive[id] = false;
	
	for (new iTypeIndex = 0; iTypeIndex < g_iTypes; iTypeIndex++)
	{
		resetStats(id, iTypeIndex);
	}
}

resetStats(const id, const iTypeIndex)
{
	g_iConsecutiveDelayedButtons[id][iTypeIndex] = 0;
	g_bPrevCommandLastedOneFrame[id][iTypeIndex] = false;
}

public fwdHamSpawn(id)
{
	if (is_user_alive(id))
	{
		g_iPreviousOldButtons[id] = 0;
		g_iOldButtons[id] = 0;
		g_iButtons[id] = 0;
		
		g_bAlive[id] = true;
	}
	
	return HAM_IGNORED;
}

public fwdHamKilled(iVictim, iAttacker, bShouldGib)
{
	g_bAlive[iVictim] = false;
	
	return HAM_IGNORED;
}

public fwdCmdStart(id, uc_handle)
{
	if (g_bAlive[id])
	{
		g_iButtons[id] = get_uc(uc_handle, UC_Buttons);
		
		performCheck(id, JUMP_WAIT_JUMP);
		performCheck(id, DUCK_WAIT_DUCK);
		
		g_iPreviousOldButtons[id] = g_iOldButtons[id];
		g_iOldButtons[id] = g_iButtons[id];
	}
	
	return FMRES_IGNORED;
}

performCheck(const id, const iTypeIndex)
{
	new iCommandButton = g_iCommandTypes[iTypeIndex];
	new bool:bPrevCommandLastedOneFrame = g_bPrevCommandLastedOneFrame[id][iTypeIndex];
	
	new iButtons = g_iButtons[id];
	new iOldButtons = g_iOldButtons[id];
	new iPreviousOldButtons = g_iPreviousOldButtons[id];
	
	new iButtonDifferences = iOldButtons ^ iButtons;
	new iReleasedAndPressedButtons = (iButtonDifferences & iOldButtons & iPreviousOldButtons) | (iButtonDifferences &~ (iOldButtons | iPreviousOldButtons));
	
	if (bPrevCommandLastedOneFrame && iReleasedAndPressedButtons)
	{
		g_iConsecutiveDelayedButtons[id][iTypeIndex] += countSetBits(iReleasedAndPressedButtons);
		
		if (g_iConsecutiveDelayedButtons[id][iTypeIndex] >= CONSECUTIVE_WARNING_COUNT)
		{
			resetStats(id, iTypeIndex);
			handleViolation(id, iTypeIndex);
		}
	}

	bPrevCommandLastedOneFrame = !(iPreviousOldButtons & iCommandButton) && (iOldButtons & iCommandButton) && !(iButtons & iCommandButton);
	g_bPrevCommandLastedOneFrame[id][iTypeIndex] = bPrevCommandLastedOneFrame;
	
	if (bPrevCommandLastedOneFrame && iReleasedAndPressedButtons)
	{
		g_iConsecutiveDelayedButtons[id][iTypeIndex] = 0;
	}
}

handleViolation(const id, const iTypeIndex)
{
	switch (get_pcvar_num(wbd_punishment))
	{
		case SLAY:
		{
			user_kill(id);
		
			client_cmd(id, g_sAdminNotificationSpk);
			client_print(id, print_chat, "[WBD] You have been slayed for using %s bind", g_sCommandStrings[iTypeIndex]);
		}
		case KICK:
		{
			server_cmd("kick #%d  ^"You have been kicked for using %s bind^"", get_user_userid(id), g_sCommandStrings[iTypeIndex]);
		}
	}
	
	static szAdminMessage[128], szPlayerName[32];
	
	get_user_name(id, szPlayerName, charsmax(szPlayerName));
	formatex(szAdminMessage, charsmax(szAdminMessage), "[WBD] Detected usage of %s on player %s", g_sCommandStrings[iTypeIndex], szPlayerName);
	
	static aPlayers[MAX_PLAYERS], iPlayerCount;
	get_players(aPlayers, iPlayerCount, "ch");
	
	for (new i = 0; i < iPlayerCount; i++)
	{
		new playerId = aPlayers[i];
		
		if ((get_user_flags(playerId) & PLUGIN_ACCESS_LEVEL) && playerId != id)
		{
			client_cmd(playerId, g_sAdminNotificationSpk);
			client_print(playerId, print_chat, szAdminMessage);
		}
	}
	
	if (get_pcvar_num(wbd_log_detection) == 1)
	{
		static szSteamID[32];
		get_user_authid(id, szSteamID, charsmax(szSteamID));
		
		logViolation("<%s> - '%s' - %s", szSteamID, szPlayerName, g_sCommandStrings[iTypeIndex]);
	}
}

countSetBits(x)
{
	x = x - ((x >> 1) & 0x55555555);
	x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
	x = (x + (x >> 4)) & 0x0F0F0F0F;
	x = x + (x >> 8);
	x = x + (x >> 16);
	return x & 0x0000003F;
}

logViolation(const sMsg[], any:...)
{
	static szWrite[256];
	get_time("^n%Y-%m-%d - %H:%M:%S ", szWrite, charsmax(szWrite));
	
	vformat(szWrite[23], (charsmax(szWrite) - 23), sMsg, 2);
	
	new hFile = fopen(g_sLogFile, "at");
	
	if (hFile)
	{
		fputs(hFile, szWrite);
		fclose(hFile);
	}
}