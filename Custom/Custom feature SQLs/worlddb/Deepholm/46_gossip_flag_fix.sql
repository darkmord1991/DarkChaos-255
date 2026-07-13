-- ---------------------------------------------------------------------------
-- gossip npcflag fix (Deepholm, map 646)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): 3 NPCs have a gossip_menu_id
-- assigned but npcflag is missing UNIT_NPC_FLAG_GOSSIP (1), so right-clicking
-- them never opens the gossip window ("has assigned gossip menu N, but
-- npcflag does not include UNIT_NPC_FLAG_GOSSIP" boot warning).
--   44352 Tawn Winterbluff (menu 11948), 44353 Stormcaller Mylra (menu 11950),
--   49956 Pebble (menu 12541).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `npcflag` = `npcflag` | 1
WHERE `entry` IN (44352,44353,49956) AND (`npcflag` & 1) = 0;
