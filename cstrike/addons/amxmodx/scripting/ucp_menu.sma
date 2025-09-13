/* AMX Mod X script.
*
* ucp_menu.sma
* UCP Menu - Menu for Ultra Core Protector anti-cheat.
*/

#include <amxmodx>
#include <amxmisc>
#include <ucp>

#define PLUGIN "UCP Menu"
#define VERSION "2.1"
#define AUTHOR "STEVE"

#define MAX_REASONS 32

new g_menuPosition[33]
new g_menuPlayers[33][32]
new g_menuPlayersNum[33]
new g_menuOption[33]
new g_menuSettings[33]
new g_bannedPlayer[33]
new g_izUserMenuAction[33] = {0, ...}
new Array:g_bantimes
new Array:g_reasonName
new g_reasonNums
new g_coloredMenus

new ucp_mode

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_dictionary("ucpmenu.txt")
	
	register_concmd("ucp_ctrl", "ucp_ctrl", ADMIN_CVAR, "Enable/Disable")
	register_clcmd("ucp_menu", "cmdMainMenu", ADMIN_MENU, "UCP Menu")
	register_clcmd("ucp_screenmenu", "cmdScreenMenu", ADMIN_MENU, "Screenshot Menu")
	register_clcmd("ucp_banmenu", "cmdBanMenu", ADMIN_BAN, "Ban Menu")
	register_clcmd("ucp_banreason", "cmdBanReason", ADMIN_BAN, "Configures custom ban message")

	register_menucmd(register_menuid("Ban Menu"), 1023, "actionBanMenu")
	register_menucmd(register_menuid("Ban reason"), 1023, "actionReasonsMenu")
	register_menucmd(register_menuid("Screenshot Menu"), 1023, "actionScreenMenu")
	
	ucp_mode = get_cvar_pointer("ucp_mode")
	
	g_bantimes = ArrayCreate()
	g_reasonName = ArrayCreate(32)
	
	ArrayPushCell(g_bantimes, 0)
	ArrayPushCell(g_bantimes, 5)
	ArrayPushCell(g_bantimes, 10)
	ArrayPushCell(g_bantimes, 15)
	ArrayPushCell(g_bantimes, 30)
	ArrayPushCell(g_bantimes, 45)
	ArrayPushCell(g_bantimes, 60)
	
	register_srvcmd("ucp_menu_bantimes", "ucpmenu_setbantimes")

	g_coloredMenus = colored_menus()
	
	new temp[64], cfgdir[64]
		
	get_configsdir(cfgdir, 63)	
	format(temp, 63, "%s/ucpmenu.cfg", cfgdir)
		
	if (file_exists(temp)) 
	{
		server_cmd("exec %s", temp)
		server_exec()
	}
	
	format(temp, 63, "%s/reasons.txt", cfgdir)

	if (!file_exists(temp))
	{
		log_amx("Error: Could not find file %s", temp)
	} else {
		load_reasons(temp)
	}

	set_task(5.0, "addMenu")
}

public addMenu()
{
	AddMenuItem("UCP Menu", "ucp_menu", ADMIN_MENU, "UCP Menu")
}

public cmdMainMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	new menuname[64]
	formatex(menuname, 63, "%L", id, "MENU_MAIN_UCP")
	new menu = menu_create(menuname, "mainMenu")
	new callback = menu_makecallback("mcb_mainMenu")
	
	formatex(menuname, 63, "%L", id, !get_pcvar_num(ucp_mode) ?  "MENU_MAIN_ENABLE" : "MENU_MAIN_DISABLE")
	menu_additem(menu, menuname, "ucp_ctrl", ADMIN_CVAR)
	formatex(menuname, 63, "%L", id, "MENU_MAIN_BAN")
	menu_additem(menu, menuname, "ucp_banmenu", ADMIN_BAN, callback)
	formatex(menuname, 63, "%L", id, "MENU_MAIN_SCREENSHOT")
	menu_additem(menu, menuname, "ucp_screenmenu", ADMIN_MENU, callback)
	
	formatex(menuname, 63, "%L", id, "MENU_EXIT")
	menu_setprop(menu, MPROP_EXITNAME, menuname)
	
	menu_display(id, menu, 0)
	
	return PLUGIN_HANDLED
}

public mainMenu(id, menu, item)
{
	if (item < 0)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	new command[24], paccess, call
	menu_item_getinfo(menu, item, paccess, command, 23, _, 0, call)
	
	if (paccess && !(get_user_flags(id) & paccess))
	{
		client_print(id, print_chat, "%L", id, "MENU_NO_ACCESS")
		return PLUGIN_HANDLED
	}
	
	client_cmd(id, command)
	
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public ucpmenu_setbantimes()
{
	new buff[32]
	new args = read_argc()
	
	if (args <= 1)
	{
		server_print("usage: ucp_menu_bantimes <time1> [time2] [time3] ...")
		server_print("   use time of 0 for permanent.")
		
		return;
	}
	
	ArrayClear(g_bantimes)
	
	for (new i = 1; i < args; i++)
	{
		read_argv(i, buff, charsmax(buff))
		
		ArrayPushCell(g_bantimes, str_to_num(buff))
		
	}
	
}

public actionBanMenu(id, key)
{
	switch (key)
	{
		case 7:
		{
			++g_menuOption[id]
			g_menuOption[id] %= ArraySize(g_bantimes)

			g_menuSettings[id] = ArrayGetCell(g_bantimes, g_menuOption[id])

			displayBanMenu(id, g_menuPosition[id])
		}
		case 8: displayBanMenu(id, ++g_menuPosition[id])
		case 9: displayBanMenu(id, --g_menuPosition[id])
		default:
		{
			g_bannedPlayer[id] = g_menuPlayers[id][g_menuPosition[id] * 7 + key]
			
			displayReasonsMenu(id, g_menuPosition[id] = 0)
		}
	}
	
	return PLUGIN_HANDLED
}

displayBanMenu(id, pos)
{
	if (pos < 0)
		return

	get_players(g_menuPlayers[id], g_menuPlayersNum[id])

	new menuBody[512]
	new b = 0
	new i
	new name[32]
	new start = pos * 7

	if (start >= g_menuPlayersNum[id])
		start = pos = g_menuPosition[id] = 0

	new len = format(menuBody, 511, "\y%L\R%d/%d^n\w^n", id, "MENU_BAN_MENU", pos + 1, (g_menuPlayersNum[id] / 7 + ((g_menuPlayersNum[id] % 7) ? 1 : 0)))
	new end = start + 7
	new keys = MENU_KEY_0|MENU_KEY_8

	if (end > g_menuPlayersNum[id])
		end = g_menuPlayersNum[id]

	for (new a = start; a < end; ++a)
	{
		i = g_menuPlayers[id][a]
		get_user_name(i, name, 31)

		if (is_user_bot(i) || (access(i, ADMIN_IMMUNITY) && i != id) || !get_pcvar_num(ucp_mode) || !is_user_ucp(i))
		{
			++b
			
			if (g_coloredMenus)
				len += format(menuBody[len], 511-len, "\d%d. %s^n\w", b, name)
			else
				len += format(menuBody[len], 511-len, "#. %s^n", name)
		} else {
			keys |= (1<<b)
				
			if (is_user_admin(i))
				len += format(menuBody[len], 511-len, g_coloredMenus ? "\r%d. \w%s \r*^n\w" : "%d. %s *^n", ++b, name)
			else
				len += format(menuBody[len], 511-len, "\r%d. \w%s^n", ++b, name)
		}
	}

	if (g_menuSettings[id])
		len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\r8. \w%L^n" : "^n8. %L^n", id, "MENU_BAN_FOR_MIN", g_menuSettings[id])
	else
		len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\r8. \w%L^n" : "^n8. %L^n", id, "MENU_BAN_PERM")

	if (end != g_menuPlayersNum[id])
	{
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r9. \w%L...^n\r0. \w%L" : "^n9. %L...^n0. %L", id, "MENU_MORE", id, pos ? "MENU_BACK" : "MENU_EXIT")
		keys |= MENU_KEY_9
	}
	else
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r0. \w%L" : "^n0. %L", id, pos ? "MENU_BACK" : "MENU_EXIT")

	show_menu(id, keys, menuBody, -1, "Ban Menu")
}

public actionReasonsMenu(id, key)
{
	switch (key)
	{
		case 7:
		{
			client_cmd(id, "messagemode ucp_banreason")
			
			client_print(id, print_chat, "%L", id, "MENU_REASON_MESSAGE")
			
			return PLUGIN_HANDLED
		}
		case 8: displayReasonsMenu(id, ++g_menuPosition[id])
		case 9: displayReasonsMenu(id, --g_menuPosition[id])
		default:
		{
			new a = g_menuPosition[id] * 8 + key

			new tempReason[32]
			ArrayGetString(g_reasonName, a, tempReason, charsmax(tempReason))
			
			banUser(id, tempReason)
		}
	}
	
	return PLUGIN_HANDLED
}

displayReasonsMenu(id, pos)
{
	if (pos < 0)
		return

	new menuBody[512]
	new tempReason[32]
	new start = pos * 7
	new b = 0

	if (start >= g_reasonNums)
		start = pos = g_menuPosition[id] = 0

	new len = format(menuBody, 511, g_coloredMenus ? "\y%L\R%d/%d^n\w^n" : "%L %d/%d^n^n", id, "MENU_REASON_MENU", pos + 1, (g_reasonNums / 7 + ((g_reasonNums % 7) ? 1 : 0)))
	new end = start + 7
	new keys = MENU_KEY_0|MENU_KEY_8

	if (end > g_reasonNums)
		end = g_reasonNums

	for (new a = start; a < end; ++a)
	{
		keys |= (1<<b)
		ArrayGetString(g_reasonName, a, tempReason, charsmax(tempReason));
		len += format(menuBody[len], 511-len, g_coloredMenus ? "\r%d. \w%s^n" : "%d. %s^n", ++b, tempReason)
	}

	len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\r8. \w%L^n" : "^n8. %L^n", id, "MENU_CUSTOM_REASON")
	
	if (end != g_reasonNums)
	{
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r9. \w%L...^n\r0. \w%L" : "^n9. %L...^n0. %L", id, "MENU_MORE", id, pos ? "MENU_BACK" : "MENU_EXIT")
		keys |= MENU_KEY_9
	}
	else
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r0. \w%L" : "^n0. %L", id, pos ? "MENU_BACK" : "MENU_EXIT")

	show_menu(id, keys, menuBody, -1, "Ban reason")
}

load_reasons(filename[])
{
	if (!file_exists(filename)) 
		return 0
		
	new text[256]
	new a, pos = 0
	
	while (g_reasonNums < MAX_REASONS && read_file(filename, pos++, text, 255, a))
	{
		if (a < 1 || text[0] == ';' || (text[0] == '/' && text[1] == '/'))
		{
			continue
		}
		
		ArrayPushString(g_reasonName, text)
		g_reasonNums++
	}

	return 1
}

public cmdBanReason(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	new reason[128]
	read_args(reason, sizeof(reason) - 1)
	remove_quotes(reason)
	
	banUser(id, reason)

	return PLUGIN_HANDLED
}

banUser(id, const reason[])
{
	new player = g_bannedPlayer[id]
	new name[32], name2[32], authid[32], authid2[32]
		
	get_user_name(player, name2, 31)
	get_user_authid(id, authid, 31)
	get_user_authid(player, authid2, 31)
	get_user_name(id, name, 31)
		
	new userid2 = get_user_userid(player)

	log_amx("Ban: ^"%s<%d><%s><>^" ban and kick ^"%s<%d><%s><>^" (minutes ^"%d^")", name, get_user_userid(id), authid, name2, userid2, authid2, g_menuSettings[id])

	if (g_menuSettings[id]==0) 
	{
		new maxpl = get_maxplayers()
		for (new i = 1; i <= maxpl; i++)
		{
			if (strlen(reason) > 0)
			{
				show_activity_id(i, id, name, "%L %s %L (%L: %s)", i, "MENU_BAN", name2, i, "MENU_PERM", i, "MENU_REASON", reason)
			}
			else
			{
				show_activity_id(i, id, name, "%L %s %L", i, "MENU_BAN", name2, i, "MENU_PERM")
			}
		}
	}
	else
	{
		new tempTime[32]
		formatex(tempTime,sizeof(tempTime)-1,"%d",g_menuSettings[id])
		new maxpl = get_maxplayers()
		for (new i = 1; i <= maxpl; i++)
		{
			if (strlen(reason) > 0)
			{
				show_activity_id(i, id, name, "%L %s %L (%L: %s)", i, "MENU_BAN", name2, i, "MENU_FOR_MIN", tempTime, i, "MENU_REASON", reason)
			}
			else
			{
				show_activity_id(i, id, name, "%L %s %L", i, "MENU_BAN", name2, i, "MENU_FOR_MIN", tempTime)
			}
		}
	}
	
	console_cmd(id, "ucp_ban #%d %d ^"%s^"", userid2, g_menuSettings[id], reason)

	g_bannedPlayer[id] = 0

	displayBanMenu(id, g_menuPosition[id])
}

public cmdBanMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED

	g_menuOption[id] = 0
	
	if (ArraySize(g_bantimes) > 0)
	{
		g_menuSettings[id] = ArrayGetCell(g_bantimes, g_menuOption[id])
	}
	else
	{
		g_menuSettings[id] = 0
	}
	displayBanMenu(id, g_menuPosition[id] = 0)

	return PLUGIN_HANDLED
}

public actionScreenMenu(id, key)
{
	switch (key)
	{
		case 7:
		{
			g_izUserMenuAction[id]++
			
			if (g_izUserMenuAction[id] >= 2)
				g_izUserMenuAction[id] = 0

			displayScreenMenu(id, g_menuPosition[id])
		}
		case 8: displayScreenMenu(id, ++g_menuPosition[id])
		case 9: displayScreenMenu(id, --g_menuPosition[id])
		default:
		{
			new player = g_menuPlayers[id][g_menuPosition[id] * 7 + key]
			new authid[32], authid2[32], name[32], name2[32]
			
			get_user_authid(id, authid, 31)
			get_user_authid(player, authid2, 31)
			get_user_name(id, name, 31)
			get_user_name(player, name2, 31)
			
			new userid2 = get_user_userid(player)

			log_amx("Screenshot: ^"%s<%d><%s><>^" screenshot ^"%s<%d><%s><>^"", name, get_user_userid(id), authid, name2, userid2, authid2)

			client_print(id, print_chat, "%L", LANG_PLAYER, "MENU_SCREEN", name2)
			
			console_cmd(id, "ucp_screen #%d %s", userid2, g_izUserMenuAction[id] ? "1" : "")

			displayScreenMenu(id, g_menuPosition[id])
		}
	}

	return PLUGIN_HANDLED
}

displayScreenMenu(id, pos)
{
	if (pos < 0)
		return

	get_players(g_menuPlayers[id], g_menuPlayersNum[id])

	new menuBody[512]
	new b = 0
	new i
	new name[32]
	new start = pos * 7

	if (start >= g_menuPlayersNum[id])
		start = pos = g_menuPosition[id] = 0

	new len = format(menuBody, 511, "\y%L\R%d/%d^n\w^n", id, "MENU_SCREEN_MENU", pos + 1, (g_menuPlayersNum[id] / 7 + ((g_menuPlayersNum[id] % 7) ? 1 : 0)))
	new end = start + 7
	new keys = MENU_KEY_0|MENU_KEY_8

	if (end > g_menuPlayersNum[id])
		end = g_menuPlayersNum[id]

	for (new a = start; a < end; ++a)
	{
		i = g_menuPlayers[id][a]
		get_user_name(i, name, 31)

		if (is_user_bot(i) || (access(i, ADMIN_IMMUNITY) && i != id) || !get_pcvar_num(ucp_mode) || !is_user_ucp(i))
		{
			++b
		
			if (g_coloredMenus)
				len += format(menuBody[len], 511-len, "\d%d. %s^n\w", b, name)
			else
				len += format(menuBody[len], 511-len, "#. %s^n", name)
		} else {
			keys |= (1<<b)
				
			if (is_user_admin(i))
				len += format(menuBody[len], 511-len, g_coloredMenus ? "\r%d. \w%s \r*^n\w" : "%d. %s *^n", ++b, name)
			else
				len += format(menuBody[len], 511-len, "\r%d. \w%s^n", ++b, name)
		}
	}

	new ucp_upload_mode[32]
	get_cvar_string("ucp_upload_mode", ucp_upload_mode, 31)
	
	if (equal(ucp_upload_mode, "HTTP"))
	{
		if (g_izUserMenuAction[id])
			len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\r8. \w%L^n" : "^n8. %L^n", id, "MENU_SHOWSCREEN", g_menuSettings[id])
		else
			len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\r8. \w%L^n" : "^n8. %L^n", id, "MENU_NOSHOW")
	}
	else
	{
		len += format(menuBody[len], 511-len, g_coloredMenus ? "^n\d8. %L^n" : "^n#. %L^n", id, "MENU_NOSHOW")
	}
		
	if (end != g_menuPlayersNum[id])
	{
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r9. \w%L...^n\r0. \w%L" : "^n9. %L...^n0. %L", id, "MENU_MORE", id, pos ? "MENU_BACK" : "MENU_EXIT")
		keys |= MENU_KEY_9
	}
	else
		format(menuBody[len], 511-len, g_coloredMenus ? "^n\r0. \w%L" : "^n0. %L", id, pos ? "MENU_BACK" : "MENU_EXIT")

	show_menu(id, keys, menuBody, -1, "Screenshot Menu")
}

public cmdScreenMenu(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		displayScreenMenu(id, g_menuPosition[id] = 0)

	return PLUGIN_HANDLED
}

public ucp_ctrl(id, level, cid) 
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	get_pcvar_num(ucp_mode) ? set_cvar_num("ucp_mode", 0) : set_cvar_num("ucp_mode", 1)

	if (SaveSettingsToFile())
		server_cmd("restart")
	
	return PLUGIN_HANDLED
}

public mcb_mainMenu(id, menu, item) 
{
	new paccess, command[24], call
	
	menu_item_getinfo(menu, item, paccess, command, 23, _, 0, call)
	
	if (!get_pcvar_num(ucp_mode))
	{
		return ITEM_DISABLED
	} else {
		return ITEM_ENABLED
	}
	
	return PLUGIN_HANDLED
}

SaveSettingsToFile()
{
	static szFilename[128], szTempFilename[128]

	if (!szFilename[0])
	{
		get_configsdir(szFilename, 127)
		formatex(szTempFilename, 127, "%s/rewrite_config.cfg", szFilename)
		add(szFilename, 127, "/ucp/config.cfg")
	}
	
	new iFile = fopen(szFilename, "rt")

	if (!iFile)
	{
		return 0
	}
	
	new iTemp = fopen(szTempFilename, "wt")
	
	static szData[1024], szCvar[32]
	new bool:bmode

	while(!feof(iFile))
	{
		fgets(iFile, szData, 1023)

		if (szData[0] && szData[0] != '^n' && szData[0] != '/' && szData[1] != '/')
		{
			parse(szData, szCvar, 31)
			
			if (equal(szCvar, "ucp_mode"))
			{
				if (!bmode)
				{
					bmode = true
					
					get_pcvar_string(ucp_mode, szCvar, 31)
					
					fprintf(iTemp, "ucp_mode ^"%s^"%s", szCvar, szData[strlen(szData) - 1] == '^n' ? "^n" : "")
				}
				
				continue
			}
		}
		
		fputs(iTemp, szData)
	}
	
	fclose(iFile)
	fclose(iTemp)
	
	delete_file(szFilename)

	while(!rename_file(szTempFilename, szFilename, 1)) { }
	
	return 1
}

bool:is_user_ucp(id)
{
	new ucpid[32]
	ucp_id(id, ucpid)
	
	if (ucpid[0])
		return true
		
	return false
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
