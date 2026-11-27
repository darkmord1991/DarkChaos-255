# Plaguelands (DCPlaguelands, map 751)

Server-DB (acore_world) content for the downported zone. Cloned NPCs+GOs use **dc_entry = 3,600,000 + original** (isolated/tunable). Source: cata_world (TDB 434) + acore_world (stock). Cross-DB INSERT...SELECT — run on the world-DB host. All columns backticked (MySQL 8 reserves `rank`).

**`01_creature_templates.sql` also needs `nelt_world`** (Project Neltharion 4.3.4, the reference DB with a real `InhabitType` column) present at import time: `cata_world.creature_template_movement` has no `Ground`/`Swim`/`Flight`/`Rooted` columns at all (only `CreatureId`/`HoverInitiallyEnabled`/`Random`), so `creature_template_movement` for cloned flyers is derived from `nelt_world`'s `InhabitType` (bit `0x4` = air-capable; falls back to the acore-stock original's row when one already exists). Without `nelt_world`, every airborne clone in the zone silently gets zero flight config and falls to the ground.

## Apply order
01 creature_templates -> 02 gameobject_templates -> 04 spawns (creature+GO) -> 07 creature_text -> 08 loot -> 09 gossip -> 11 quests (incl. RequiredNpcOrGo remap) -> 12 smart_scripts -> 13 areas -> 14 graveyard

## Client side (separate)
Append to Custom/CSV DBC + repack: Map(751), AreaTable(4924), LoadingScreens, Light, WorldSafelocs, WorldMapArea, FactionTemplate, CreatureModelData/DisplayInfo/DisplayInfoExtra, GameObjectDisplayInfo; pack the baked map dir + display models.
