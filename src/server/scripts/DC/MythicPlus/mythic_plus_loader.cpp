/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license
 * Copyright (C) 2025+ DarkChaos-255 Custom Scripts
 * 
 * Mythic+ System Script Loader
 */

// Add all Mythic+ scripts
void AddSC_mythic_plus_core_scripts();
void AddSC_dungeon_portal_selector();
void AddSC_go_mythic_plus_font_of_power();
void AddSC_npc_great_vault();
void AddSC_npc_mythic_token_vendor();
void AddSC_mythic_plus_commands();
void AddSC_npc_keystone_vendor();
void AddSC_item_mythic_keystone();

void AddMythicPlusScripts()
{
    AddSC_mythic_plus_core_scripts();
    AddSC_dungeon_portal_selector();
    AddSC_go_mythic_plus_font_of_power();
    AddSC_npc_great_vault();
    AddSC_npc_mythic_token_vendor();
    AddSC_mythic_plus_commands();
    AddSC_npc_keystone_vendor();
    AddSC_item_mythic_keystone();
}
