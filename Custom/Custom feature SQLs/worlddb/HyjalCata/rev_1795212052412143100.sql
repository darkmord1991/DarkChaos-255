-- Living Obsidium Chip (gameobject 208803, Molten Front map 861). Obsidium Punisher 3652107 cross-casts Execution
-- (98959) on its victim, and the spell's first effect summons this object, but the template was never imported: each
-- cast logged "not created: non-existing entry in `gameobject_template`" (13 times on 2026-11-20 21:05-21:52).
-- Cata row: chest (type 3), lock 43 (Open Kneeling, the stock quest-pickup lock of 478 chests), loot 39726 = the
-- quest item Living Obsidium Chip 69860 for 29295 "The Bigger They Are" (10 chips), consumable.
-- Changes from Cata: display 10609 is not in the 3.3.5 GameObjectDisplayInfo.dbc, so it uses 6650
-- (Obsidian_Miningnode_01, the stock "Small Obsidian Chunk" 181068) at that object's size 0.2; Data14 (Cata openTextID
-- 19676, a BroadcastText id) is left 0. The Punisher also drops the chip itself (100%, quest-required), so 29295 was
-- completable before; this adds the pickups the encounter was built with and stops the errors.
REPLACE INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
    `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`,
    `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`,
    `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(208803, 3, 6650, 'Living Obsidium Chip', '', 'Collecting', '', 0.2,
    43, 39726, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, '', '', 0);

DELETE FROM `gameobject_loot_template` WHERE `Entry` = 39726;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`,
    `MinCount`, `MaxCount`, `Comment`) VALUES
(39726, 69860, 0, 100, 1, 1, 0, 1, 1, 'Living Obsidium Chip - quest 29295');
