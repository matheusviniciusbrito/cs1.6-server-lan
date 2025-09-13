/**
 * ucp_menu.sp
 * Menu for Ultra Core Protector anti-cheat.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#pragma semicolon 1

#include <sourcemod>
#include <ucp>
#undef REQUIRE_PLUGIN
#include <adminmenu>

new g_BanTarget[MAXPLAYERS+1];
new g_BanTargetUserId[MAXPLAYERS+1];
new g_BanTime[MAXPLAYERS+1];

new Handle:hTopMenu = INVALID_HANDLE;
new Handle:g_MainMenu = INVALID_HANDLE;

new g_LineCount = 0;
new String:g_FileLine[256][256];

public Plugin:myinfo = 
{
	name = "UCP Menu",
	author = "STEVE",
	description = "Administration Menu",
	version = "1.7",
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");

	RegAdminCmd("ucp_menu", Command_DisplayMenu, ADMFLAG_CHANGEMAP, "Displays the ucp menu");
	
	/* Account for late loading */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnMapStart()
{
	g_MainMenu = BuildMainMenu();
}
 
public OnMapEnd()
{
	if (g_MainMenu != INVALID_HANDLE)
	{
		CloseHandle(g_MainMenu);
		g_MainMenu = INVALID_HANDLE;
	}
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;

	new TopMenuObject:server_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_SERVERCOMMANDS);

	if (server_commands != INVALID_TOPMENUOBJECT)
	{	
		AddToTopMenu(hTopMenu,
			"ucp_menu",
			TopMenuObject_Item,
			AdminMenu_Main,
			server_commands,
			"ucp_menu",
			ADMFLAG_CHANGEMAP);	
	}
}

public AdminMenu_Main(Handle:topmenu, 
							  TopMenuAction:action,
							  TopMenuObject:object_id,
							  param,
							  String:buffer[],
							  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "UCP Menu");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayMenu(g_MainMenu, param, MENU_TIME_FOREVER);
	}
}

Handle:BuildMainMenu()
{
	new Handle:menu = CreateMenu(Menu_UCP, MenuAction_DrawItem|MenuAction_DisplayItem);

	SetMenuTitle(menu, "UCP Menu");
	AddMenuItem(menu, "enable", "Enable");
	AddMenuItem(menu, "disable", "Disable");
	AddMenuItem(menu, "ban", "Ban player");
	AddMenuItem(menu, "screen", "Screenshot player");
	SetMenuExitButton(menu, true);

	return menu;
}

public Menu_UCP(Handle:menu, MenuAction:action, param1, param2)
{
	new Handle:ucp_mode = FindConVar("ucp_mode");
	
	if (action == MenuAction_DrawItem)
	{
		if (GetConVarInt(ucp_mode))
		{
			if (param2 == 0)
			{
				return ITEMDRAW_DISABLED;
			}
		}
		else 
		{
			if (param2 == 1 || param2 == 2 || param2 == 3)
			{
				return ITEMDRAW_DISABLED;
			}
		}
	
		return ITEMDRAW_DEFAULT;
	}
	else if (action == MenuAction_Select)
	{
		if (param2 == 0)
		{
			SetConVarString(ucp_mode, "1");

			if (OpenConfig())
			{
				WriteConfig();
			}
		} else if (param2 == 1) {
			SetConVarString(ucp_mode, "0");

			if (OpenConfig())
			{
				WriteConfig();
			}
		} else if (param2 == 2) {
			DisplayBanTargetMenu(param1);
		} else if (param2 == 3) {
			DisplayScreenMenu(param1);
		}
	}

	return 0;
}

bool:OpenConfig()
{
	new String:path[255];
	Format(path, sizeof(path), "cfg/ucp/config.cfg");
	
	g_LineCount = 0;
	
	new Handle:file = OpenFile(path, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("Could not find file \"%s\"", path);
		return false;
	}
	
	new String:buffer[255];
	while (!IsEndOfFile(file) && ReadFileLine(file, buffer, sizeof(buffer)))
	{
		TrimString(buffer);
		g_FileLine[g_LineCount] = buffer;
		g_LineCount++;
	}
	
	CloseHandle(file);
	
	return true;
}

bool:WriteConfig()
{
	new String:path[255];
	Format(path, sizeof(path), "cfg/ucp/config.cfg");
	
	new Handle:file = OpenFile(path, "wt");
	if (file == INVALID_HANDLE)
	{
		LogError("Could not open file \"%s\" for writing.", path);
		return false;
	}
	
	new Handle:ucp_mode = FindConVar("ucp_mode");
	
	for (new i=0; i<g_LineCount; i++)
	{
		if (StrContains(g_FileLine[i], "ucp_mode") != -1)
		{
			if (GetConVarInt(ucp_mode))
			{
				WriteFileLine(file, "ucp_mode \"1\"");
			}
			else
			{
				WriteFileLine(file, "ucp_mode \"0\"");
			}
		}
		else
		{
			WriteFileLine(file, "%s", g_FileLine[i]);
		}
	}
	
	CloseHandle(file);
	
	return true;
}

public Action:Command_DisplayMenu(client, args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}
 
	DisplayMenu(g_MainMenu, client, MENU_TIME_FOREVER);
 
	return Plugin_Handled;
}

PrepareBan(client, target, time, const String:reason[])
{
	new originalTarget = GetClientOfUserId(g_BanTargetUserId[client]);

	if (originalTarget != target)
	{
		if (client == 0)
		{
			PrintToServer("[SM] %t", "Player no longer available");
		}
		else
		{
			PrintToChat(client, "[SM] %t", "Player no longer available");
		}

		return;
	}

	decl String:authid[64], String:name[32];
	GetClientAuthString(target, authid, sizeof(authid));
	GetClientName(target, name, sizeof(name));

	if (!time)
	{
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Permabanned player", name);
		} else {
			ShowActivity(client, "%t", "Permabanned player reason", name, reason);
		}
	} else {
		if (reason[0] == '\0')
		{
			ShowActivity(client, "%t", "Banned player", name, time);
		} else {
			ShowActivity(client, "%t", "Banned player reason", name, time, reason);
		}
	}

	LogAction(client, target, "\"%L\" banned \"%L\" (minutes \"%d\") (reason \"%s\")", client, target, time, reason);
}

DisplayBanTargetMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_BanPlayerList);

	new max_clients = GetMaxClients();
	decl String:user_id[12];
	decl String:name[MAX_NAME_LENGTH];
	decl String:display[MAX_NAME_LENGTH+12];
	decl String:title[100];
	new num_clients;

	Format(title, sizeof(title), "%T:", "Ban player", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);

	for (new i = 1; i <= max_clients; i++)
	{
		if (!IsClientConnected(i) || IsClientInKickQueue(i))
		{
			continue;
		}
		
		if (IsFakeClient(i))
		{
			continue;
		}
		
		if (!IsClientInGame(i))
		{
			continue;
		}

		if (!IsUcpClient(i))
		{
			continue;
		}

		IntToString(GetClientUserId(i), user_id, sizeof(user_id));
		GetClientName(i, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, user_id);
		AddMenuItem(menu, user_id, display);
		num_clients++;
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayBanTimeMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_BanTimeList);

	decl String:title[100];
	Format(title, sizeof(title), "%T: %N", "Ban player", client, g_BanTarget[client]);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);

	AddMenuItem(menu, "0", "Permanent");
	AddMenuItem(menu, "10", "10 Minutes");
	AddMenuItem(menu, "30", "30 Minutes");
	AddMenuItem(menu, "60", "1 Hour");
	AddMenuItem(menu, "240", "4 Hours");
	AddMenuItem(menu, "1440", "1 Day");
	AddMenuItem(menu, "10080", "1 Week");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayBanReasonMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_BanReasonList);

	decl String:title[100];
	Format(title, sizeof(title), "%T: %N", "Ban reason", client, g_BanTarget[client]);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);

	/* :TODO: we should either remove this or make it configurable */

	AddMenuItem(menu, "Abusive", "Abusive");
	AddMenuItem(menu, "Racism", "Racism");
	AddMenuItem(menu, "General cheating/exploits", "General cheating/exploits");
	AddMenuItem(menu, "Wallhack", "Wallhack");
	AddMenuItem(menu, "Aimbot", "Aimbot");
	AddMenuItem(menu, "Speedhacking", "Speedhacking");
	AddMenuItem(menu, "Mic spamming", "Mic spamming");
	AddMenuItem(menu, "Admin disrepect", "Admin disrepect");
	AddMenuItem(menu, "Camping", "Camping");
	AddMenuItem(menu, "Team killing", "Team killing");
	AddMenuItem(menu, "Unacceptable Spray", "Unacceptable Spray");
	AddMenuItem(menu, "Breaking Server Rules", "Breaking Server Rules");
	AddMenuItem(menu, "Other", "Other");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_BanReasonList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_MainMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[64];

		GetMenuItem(menu, param2, info, sizeof(info));

		PrepareBan(param1, g_BanTarget[param1], g_BanTime[param1], info);
		ClientCommand(param1, "ucp_ban #%d %d \"%s\"", g_BanTargetUserId[param1], g_BanTime[param1], info);
	}
}

public MenuHandler_BanPlayerList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_MainMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32], String:name[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_BanTarget[param1] = target;
			g_BanTargetUserId[param1] = userid;
			DisplayBanTimeMenu(param1);
		}
	}
}

public MenuHandler_BanTimeList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_MainMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];

		GetMenuItem(menu, param2, info, sizeof(info));
		g_BanTime[param1] = StringToInt(info);

		DisplayBanReasonMenu(param1);
	}
}

DisplayScreenMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_ScreenPlayerList);
	
	new max_clients = GetMaxClients();
	decl String:user_id[12];
	decl String:name[MAX_NAME_LENGTH];
	decl String:display[MAX_NAME_LENGTH+12];
	new num_clients;

	SetMenuTitle(menu, "Screenshot player");
	SetMenuExitBackButton(menu, true);

	for (new i = 1; i <= max_clients; i++)
	{
		if (!IsClientConnected(i) || IsClientInKickQueue(i))
		{
			continue;
		}
		
		if (IsFakeClient(i))
		{
			continue;
		}
		
		if (!IsClientInGame(i))
		{
			continue;
		}

		if (!IsUcpClient(i))
		{
			continue;
		}

		IntToString(GetClientUserId(i), user_id, sizeof(user_id));
		GetClientName(i, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, user_id);
		AddMenuItem(menu, user_id, display);
		num_clients++;
	}

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

DisplayScreenModeMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_ScreenMode);

	SetMenuTitle(menu, "Show screenshot?");
	SetMenuExitBackButton(menu, true);

	AddMenuItem(menu, "1", "Yes");
	AddMenuItem(menu, "", "No");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ScreenPlayerList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_MainMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32], String:name[32];
		new userid, target;

		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_BanTarget[param1] = target;
			g_BanTargetUserId[param1] = userid;

			new String:ucp_upload[32];
			new Handle:ucp_upload_mode = FindConVar("ucp_upload_mode");
			GetConVarString(ucp_upload_mode, ucp_upload, sizeof(ucp_upload));

			if (StrEqual(ucp_upload, "HTTP"))
			{
				DisplayScreenModeMenu(param1);
			}
			else
			{
				decl String:name2[32];
				GetClientName(target, name2, sizeof(name2));

				ClientCommand(param1, "ucp_screen #%d", userid);
				PrintToChat(param1, "Screenshot of the player %s is made.", name2);
			}
		}
	}
}

public MenuHandler_ScreenMode(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenu(g_MainMenu, param1, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32], String:name[32];

		GetMenuItem(menu, param2, info, sizeof(info));
		new target = g_BanTarget[param1];
		GetClientName(target, name, sizeof(name));
		
		ClientCommand(param1, "ucp_screen #%d %s", g_BanTargetUserId[param1], info);
		PrintToChat(param1, "Screenshot of the player %s is made.", name);
	}
}

bool:IsUcpClient(client)
{
	new String:ucpid[32];
	ucp_id(client, ucpid);
	
	if (ucpid[0])
		return true;
		
	return false;
}
