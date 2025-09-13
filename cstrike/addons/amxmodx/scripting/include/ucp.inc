/* Ultra Core Protector Anti-Cheat System Functions
*
* Copyright © 2008-2010, UCP Team
*
* This file is provided as is (no warranties).
*
*/

// Get UCP ID (8 bytes)
native ucp_id(index,outbuffer[])

// Get UCP ID (8 bytes)
native get_user_authid2(index,outbuffer[],len)

// Get Client Build Number (4 bytes)
native get_user_build(index,outbuffer[])

// Get Client OS (11 bytes)
native get_user_os(index,outbuffer[])

// UCP Forward
forward ucp_id_forward (id,ucp,ucpID[])