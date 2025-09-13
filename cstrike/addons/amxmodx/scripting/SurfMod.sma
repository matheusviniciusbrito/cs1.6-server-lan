/*
Copyright 2011 m0skVi4a ;]

Plugin created in Bulgaria


Plugin thread 1
http://www.amxmodxbg.org/forum/viewtopic.php?t=35879

Plugin thread 2
http://forums.alliedmods.net/showthread.php?t=168274

Original posted by m0skVi4a ;]



Description:

This plugin change the Counter - Strike 1.6 classic style to Surf. The plugin have help, respawn, spawn protection, semiclip system and timer.
 

Commands:

say /surfhelp
say_team /surfhelp
to show the Surf Mod help MOTD

say /respawn
say_team /respawn
to respawn you

say /surftimer
say_team /surftimer
to open surf timer menu


CVARS:

"surf_on"		 - 	Is the plugin on(1) or off(0).   Default: 1
"surf_help"		 - 	Is the surf help on(1) or off(0).   Default: 1
"surf_help_mes"  	 - 	In how many seconds to display the surf help message.   Default: 120.0
"surf_respawn" 		 - 	Is the respawning on(1) or off(0).   Default: 1
"surf_respawn_command"	 -	Is the say /respawn command on(1) or off(0).   Default: 1
"surf_respawn_time"  	 - 	Time in seconds after dead to respawn.   Default: 1.0
"surf_sp"	 	 - 	Is the spawn protection on(1) or off(0)   Default: 1
"surf_sp_time"	 	 - 	How many seconds is the protection.   Default: 5.0
"surf_semi"	 	 - 	Is the semiclip on(1) or off(0).   Default: 1
"surf_timer"	 	 - 	Is the surf timer on(1) or off(0).   Default: 1
"surf_timer_hud" 	 -      Time in seconds after Stop timer to stop timers hud.   Default: 10.0

All CVARS are without quotes


Credits:

m0skVi4a ;]    	-	for the idea and making the plugin
ConnorMcLeod 	- 	for his Semiclip plugin
SpeeD	    	-	for his Spawn Protection plugin and testing the plugin
L@m3r40 =]  	- 	for ideas and testing the plugin
SGT		-	for ideas for the plugin


Changelog:

August 11, 2011   -  v1.0  -  First Release
August 21, 2011   -  v1.1  -  Changed semiclip method, added Universal Timer, added code styling, small optimization.
September 26, 2011  -  v1.2  -  Fixed some bugs
October 1, 2011   -  v1.3  -  Litle optimization, added multilingual file, SurfMod Help MOTD is in CSTRIKE dir, Fixed bug that don't spawns you when connect, added "surf_respawn_command" cvar.
October 2, 2011   -  v1.3 FIX 1 - Fixed bug respawn on connect when plugin is off, there are merge some features in the semiclip
October 2, 2011   -  v1.3 FIX 2 - Fixed bug that don't spawns you when connect
November 8, 2011   -  v1.3 FIX 3 - Fixed bug that don't spawns you when connect
November 27, 2011   -  v1.4 - Changed somethings in the plugin for more functional work, Surf Timer is mainly changed, Changed respawn on connect method



Visit www.amxmodxbg.org 
Visit www.forums.alliedmods.net 
*/


#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>

#define MarkUserAlive(%1) g_bAlive |= 1<<(%1 & 31)
#define ClearUserAlive(%1) g_bAlive &= ~(1<<(%1 & 31))
#define IsAlive(%1) g_bAlive & 1<<(%1 & 31)

#define TASK_RES 2213
#define TASK_PROT 1123
#define TASK_TIMER 2133
#define TASK_HUD 3312
#define TASK_STOP 1132

new g_on, g_help, g_helpint, g_res, g_res_com, g_restime, g_spenabled, g_sptime, g_semi, g_timer, g_hud;
new bool:is_started[33], bool:is_pauseed[33];

new g_hour[33], g_min[33], g_sec[33];

new SPTimer[33];
new g_sync_hud1, g_sync_hud2, SayTxT;
new const prefix[]="[SURF MOD]";
new g_bAlive;
const MAX_PLAYERS = 32;
new g_iTeam[MAX_PLAYERS+1];

new const g_szTeams[][] =
{
    "",
    "TERRORIST",
    "CT"
}

enum {
    _T = 1,
    _CT
}
new g_iTeamSemiclip = _T | _CT

public plugin_init()
{
	register_plugin("Surf Mod", "1.4", "m0skVi4a ;]")
	
	g_on = register_cvar("surf_on", "1")
	g_help = register_cvar("surf_help", "1")
	g_helpint = register_cvar("surf_help_mes", "120.0")
	g_res = register_cvar("surf_respawn", "1")
	g_res_com = register_cvar("surf_respawn_command", "1")
	g_restime = register_cvar("surf_respawn_time", "1.0")
	g_spenabled = register_cvar("surf_sp","1")
	g_sptime = register_cvar("surf_sp_time", "5")
	g_semi = register_cvar("surf_semi", "1")
	g_timer = register_cvar("surf_timer", "1")
	g_hud = register_cvar("Surf_timer_hud", "10.0")
	
	register_dictionary("surfmod.txt");
	
	register_menucmd(register_menuid("Timer Menu"), 1023, "TimerMenuHandler")
	register_clcmd("say /surfhelp","SurfHelpMOTD")
	register_clcmd("say_team /surfhelp","SurfHelpMOTD")
	register_clcmd("say /respawn", "RespawnComand")
	register_clcmd("say_team /respawn", "RespawnComand")
	register_clcmd("say /surftimer", "TimerMenu")
	register_clcmd("say_team /surftimer", "TimerMenu")

	register_event("DeathMsg", "DeathMsg","a")
	register_forward(FM_AddToFullPack, "AddToFullPack", 1)
	RegisterHam(Ham_Spawn, "player", "PlayerSpawn", 1)
	RegisterHam(Ham_Player_PreThink, "player", "PreThink", 1)
	
	g_sync_hud1 = CreateHudSyncObj()
	g_sync_hud2 = CreateHudSyncObj()
	SayTxT = get_user_msgid("SayText")
	
	new MapName[64]
	get_mapname(MapName, charsmax(MapName))
	
	if(contain(MapName, "surf_") != -1)
	{
		set_pcvar_num(g_on, 1)
	}
	else
	{
		set_pcvar_num(g_on, 0)
	}
}

public plugin_cfg()
{
	if(get_pcvar_num(g_on))
	{
		set_cvar_num("sv_airaccelerate", 100)

		new ConfDir[32], File[192];
		
		get_configsdir(ConfDir, charsmax(ConfDir));
		formatex(File, charsmax( File ), "%s/surfmod.cfg", ConfDir);
		
		if(!file_exists(File))
		{
			server_print("%L", LANG_SERVER, "CSF_ERROR", File);
		}
		else
		{
			server_cmd("exec %s", File);
			server_print("%L", LANG_SERVER, "CFG_EXEC", File);
		}
	}
}

public client_connect(id)
{
	is_started[id] = false
	is_pauseed[id] = false
	remove_task(id+TASK_RES)
	remove_task(id+TASK_PROT)
	remove_task(id+TASK_TIMER)
	remove_task(id+TASK_HUD)
	remove_task(id+TASK_STOP)
}

public client_disconnect(id)
{
	is_started[id] = false
	is_pauseed[id] = false
	remove_task(id+TASK_RES)
	remove_task(id+TASK_PROT)
	remove_task(id+TASK_TIMER)
	remove_task(id+TASK_HUD)
	remove_task(id+TASK_STOP)
	ClearUserAlive(id)
}

public client_putinserver(id)
{
	if(!get_pcvar_num(g_on))
		return
		
	set_task(5.0, "CheckUser", id)
	set_task(get_pcvar_float(g_helpint), "SurfCommands", id)
}

public CheckUser(id)
{	
	if(is_user_connected(id))
	{
		if(!is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T || cs_get_user_team(id) == CS_TEAM_CT)
		{
			Respawning(id+TASK_RES)
		}
		else
		{
			set_task(5.0, "CheckUser", id)
		}
	}
}

public DeathMsg(id)
{
	if(!get_pcvar_num(g_on))
		return

	id = read_data(2)

	if(get_pcvar_num(g_res))
	{
		set_task(get_pcvar_float(g_restime), "Respawning", id+TASK_RES)
	}

	if(get_pcvar_num(g_semi))
	{
		if(is_user_alive(id))
		{
			MarkUserAlive(id)
		}
		else
		{
			ClearUserAlive(id)
		}
	}

	if(get_pcvar_num(g_timer))
	{
		remove_task(id+TASK_TIMER)
		set_task(get_pcvar_float(g_hud), "StopHud", id)
	}
}

public PlayerSpawn(id)
{
	if(!get_pcvar_num(g_on))
		return

	if(get_pcvar_num(g_spenabled) && is_user_alive(id))
	{
		remove_task(id+TASK_PROT)
		set_user_godmode(id)
		set_user_rendering(id)
		Glowing(id)
		Protection(id+TASK_PROT)
	}

	if(get_pcvar_num(g_semi))
	{
		if(is_user_alive(id))
		{
			MarkUserAlive(id)
			const XTRA_OFS_PLAYER = 5
			const m_iTeam = 114
			g_iTeam[id] = get_pdata_int(id, m_iTeam, XTRA_OFS_PLAYER)
		}
		else
		{
			ClearUserAlive(id)
		}
	}
}

public SurfHelpMOTD(id)
{
	if(get_pcvar_num(g_on) && get_pcvar_num(g_help) && is_user_connected(id))
	{
		show_motd(id, "surfmodhelp.txt", "Surf Mod Help");
	}
}

public SurfCommands(id)
{
	if(get_pcvar_num(g_on) && get_pcvar_num(g_help) && is_user_connected(id))
	{
		client_printcolor(id, "%L", LANG_SERVER, "HELP_MESS", prefix)
		set_task(get_pcvar_float(g_helpint),"SurfCommands")
	}
}

public RespawnComand(id)
{
	if(!get_pcvar_num(g_on) || !is_user_connected(id))
		return
	
	if(!get_pcvar_num(g_res))
	{
		client_printcolor(id, "%L", LANG_SERVER, "RES_DIS", prefix)
		return
	}
	
	if(!get_pcvar_num(g_res_com))
	{
		client_printcolor(id, "%L", LANG_SERVER, "RES_COM", prefix)
		return
	}
	
	new CsTeams:team = cs_get_user_team(id)
			
	if(team == CS_TEAM_T || team == CS_TEAM_CT)
	{
		if(!task_exists(id+TASK_RES))
		{
			set_task(get_pcvar_float(g_restime),"Respawning",id+TASK_RES)
		}
	}
	else
	{
		client_printcolor(id, "%L", LANG_SERVER, "RES_TEAM", prefix)
		return		
	}
}

public Respawning(id)
{
	id -= TASK_RES
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR || cs_get_user_team(id) == CS_TEAM_UNASSIGNED)
		return
		
	ExecuteHamB(Ham_CS_RoundRespawn,id)
	remove_task(id+TASK_TIMER)
	remove_task(id+TASK_HUD)
	client_printcolor(id, "%L", LANG_SERVER, "RESPAWN", prefix)
	give_item(id, "weapon_knife")
} 

public Glowing(id)  
{  	
	new CsTeams:team = cs_get_user_team(id)
	
	if(team == CS_TEAM_T)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 10)
	}
	else if(team == CS_TEAM_CT)
	{
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 10)
	}
	SPTimer[id] = get_pcvar_num(g_sptime)
}  

public Protection(id)
{
	id -= TASK_PROT
	set_user_godmode(id, 1)
	
	if(SPTimer[id] == 0)
	{
		set_hudmessage(255, 0, 0, -1.0, 0.65, 1, 0.02, 3.0,_,_,-1)
		ShowSyncHudMsg(id, g_sync_hud1, "%L", LANG_SERVER, "PROT_OFF")
	}
	else
	{
		set_hudmessage(0, 255, 0, -1.0, 0.65, 0, 0.02, 1.0,_,_,-1)
		ShowSyncHudMsg(id, g_sync_hud1, "%L", LANG_SERVER, "PROT_ON", SPTimer[id], SPTimer[id] > 1 ? "s" : "")
	}
	
	--SPTimer[id]
	
	if(SPTimer[id] >= 0)
	{
		set_task(1.0, "Protection", id+TASK_PROT)
	}
	else
	{
		set_user_godmode(id)
		set_user_rendering(id)
	}
}

public AddToFullPack(es, e, iEnt, id, hostflags, player, pSet)
{
	if(get_pcvar_num(g_on) && get_pcvar_num(g_semi) && player && id != iEnt && IsAlive(id) && g_iTeamSemiclip & g_iTeam[id] && IsAlive(iEnt) && g_iTeam[id] == g_iTeam[iEnt] && get_orig_retval())
	{ 
		set_es(es, ES_Solid, SOLID_NOT)
	}
} 

public PreThink(id)
{
	if(!get_pcvar_num(g_on) || !get_pcvar_num(g_semi) || IsAlive(id) == 0 || !(g_iTeamSemiclip & g_iTeam[id]))
	{ 
		return
	}
	
	new iPlayers[MAX_PLAYERS], iNum, iPlayer;
	get_players(iPlayers, iNum, "ae", g_szTeams[g_iTeam[id]])
	
	for(new i; i<iNum; i++)
	{
		iPlayer = iPlayers[i]
		if(id != iPlayer)
		{
			entity_set_int(iPlayer, EV_INT_solid, SOLID_NOT)
		}
	}
}

public client_PostThink(id)
{
	if(!get_pcvar_num(g_on) || !get_pcvar_num(g_semi) || IsAlive(id) == 0 || !(g_iTeamSemiclip & g_iTeam[id]))
	{
		return
	}
	
	new iPlayers[MAX_PLAYERS], iNum, iPlayer;
	get_players(iPlayers, iNum, "ae", g_szTeams[g_iTeam[id]])
	
	for(new i; i<iNum; i++)
	{
		iPlayer = iPlayers[i]
		if(id != iPlayer)
		{
			entity_set_int(iPlayer, EV_INT_solid, SOLID_SLIDEBOX)
		}
	}
}

public TimerMenu(id)
{
	if(!get_pcvar_num(g_on) || !get_pcvar_num(g_timer))
		return
	
	static menu[512];
	new lenght, keys;
	lenght = 0

	lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_TITLE")
	
	if(!is_started[id])
	{
		lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_START")
		keys = MENU_KEY_1|MENU_KEY_0;
	}
	else
	{
		lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_RESTART")
		
		if(!is_pauseed[id])
		{
			lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_PAUSE")
		}
		else
		{
			lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_UNPAUSE")
		}
		lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_STOP")
		keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0;
	}
	
	lenght += formatex(menu[lenght], charsmax(menu), "%L", LANG_SERVER, "TIMER_MENU_EXIT")

	show_menu(id, keys, menu, -1, "Timer Menu")
}

public TimerMenuHandler(id, key)
{
	switch(key)
	{
		case 0:
		{
			is_started[id] = true
			reStartTimer(id)
		}
		case 1:
		{
			if(!is_pauseed[id])
			{
				is_pauseed[id] = true
			}
			else
			{
				is_pauseed[id] = false
			}
			unPauseTimer(id)
		}
		case 2:
		{
			StopTimer(id)
		}
		case 9:
		{
			return PLUGIN_HANDLED
		}
	}
	TimerMenu(id)
	return PLUGIN_HANDLED
}

public reStartTimer(id)
{
	if(is_user_alive(id))
	{
		remove_task(id+TASK_TIMER)
		g_hour[id] = 0
		g_min[id] = 0
		g_sec[id] = 0
		set_task(1.0,"TimerMain",id+TASK_TIMER)
		if(task_exists(id+TASK_STOP))
		{
			remove_task(id+TASK_STOP)
		}
		if(!task_exists(id+TASK_HUD))
		{
			TimerHud(id+TASK_HUD)
		}
	}
}

public TimerMain(id)
{
	id -= TASK_TIMER
	
	if(is_user_connected(id))
	{		
		g_sec[id]++
		
		if(g_sec[id] >= 60)
		{
			g_min[id]++
			g_sec[id] = 0
		}
		
		if(g_min[id] >= 60)
		{
			g_hour[id]++
			if(g_hour[id] >= 24)
			{
				g_hour[id] = 0
			}
			g_min[id] = 0
		}
         
		set_task(1.0, "TimerMain", id+TASK_TIMER)
	}
	else
	{
		remove_task(id+TASK_TIMER)
	}
}   

public TimerHud(id)
{
	id -= TASK_HUD
	
	if(is_user_connected(id))
	{
		set_hudmessage(0, 255, 0, -1.0, 0.90, 0, 0.0, 0.3, 0.0, 0.0, -1)
		ShowSyncHudMsg(id, g_sync_hud2, "%L", LANG_SERVER, "TIMER_HUD", g_hour[id] < 10 ? "0" : "", g_hour[id], g_min[id] < 10 ? "0" : "", g_min[id], g_sec[id] < 10 ? "0" : "", g_sec[id])
		
		set_task(0.1,"TimerHud",id+TASK_HUD)
	}
}

public unPauseTimer(id)
{
	if(is_user_alive(id))
	{
		if(!is_pauseed[id])
		{
			TimerMain(id+TASK_TIMER)
		}
		else
		{
			remove_task(id+TASK_TIMER)
		}
	}
}

public StopTimer(id)
{
	if(is_user_alive(id) && is_started[id])
	{
		remove_task(id+TASK_TIMER)
		set_task(get_pcvar_float(g_hud), "StopHud", id+TASK_STOP)
		is_started[id] = false
	}
}

public StopHud(id)
{
	id -= TASK_STOP
	
	if(is_user_alive(id))
	{
		remove_task(id+TASK_HUD)
	}
}

stock client_printcolor(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg,190,input,3);
	replace_all(msg,190,"!g","^4");
	replace_all(msg,190,"!n","^1");
	replace_all(msg,190,"!t","^3");
	replace_all(msg,190,"!w","^0");
	if(id) players[0] = id; else get_players(players,count,"ch");
	for (new i = 0; i < count; i++)
		if(is_user_connected(players[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, SayTxT,_, players[i]);
			write_byte(players[i]);
			write_string(msg);
			message_end();
		}
}

