#include <amxmodx>
#include <amxmisc>

const ADMIN_FLAG = ADMIN_BAN

public plugin_init()
{
	register_plugin("sXe Screenshot", "1.0", "payas")
	register_concmd("amx_sxe_screen", "cmd_screen", ADMIN_FLAG, "<name>")
}

public cmd_screen(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;

	new arg[32]
	read_argv(1, arg, 31)
	new target = cmd_target(id, arg, 0)

	//client_print(id, print_chat, "TEST %d", get_user_userid(id))

	if (!is_user_connected(target))
		return PLUGIN_HANDLED;

	if (is_user_bot(target))
	{
		client_print(id, print_chat, "[AMXX] %L", id, "BOT_MESSAGE")
		return PLUGIN_HANDLED;
	}

/****
	if (is_user_admin(target))
	{
		client_print(id, print_chat, "[AMXX] %L", id, "ADMIN_MESSAGE")
		return PLUGIN_HANDLED;
	}
***/
	server_cmd("sxe_screen #%d #%d", get_user_userid(target), get_user_userid(id))


	new nick1[32], nick2[32]
	get_user_name(id, nick1, 31)
	get_user_name(target, nick2, 31)

	//client_print(0, print_chat, "ADMIN %L", LANG_PLAYER, "LOCALBAN_MESSAGE", nick1, nick2)

	log_amx("ADMIN %L", LANG_SERVER, "ScreenShot for player [%s] to [%s]", nick1, nick2)

	return PLUGIN_HANDLED;
}