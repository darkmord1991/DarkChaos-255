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

void AddMythicPlusScripts()
{
    AddSC_mythic_plus_core_scripts();
    AddSC_dungeon_portal_selector();
    AddSC_go_mythic_plus_font_of_power();
}
