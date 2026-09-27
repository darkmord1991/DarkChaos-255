-- DarkChaos collection vendors: page the roster behind a gossip menu.
-- A 3.3.5 vendor window holds at most 150 items; the mount and pet vendors hold
-- well over a thousand. npc_dc_paged_collection_vendor splits each vendor's
-- npc_vendor rows into alphabetical pages at runtime, so the rows stay here
-- on the base entries and future batches keep inserting into them as before.
-- UNIT_NPC_FLAG_GOSSIP (1) makes the client send GOSSIP_HELLO instead of
-- LIST_INVENTORY; UNIT_NPC_FLAG_VENDOR (128) stays for buying.

UPDATE `creature_template`
SET `npcflag` = `npcflag` | 1 | 128,
    `ScriptName` = 'npc_dc_paged_collection_vendor'
WHERE `entry` IN (3461020, 3461229);
