-- Isle of Giants (map 1405) now carries the retail MoP area layout instead of the Island-Project subzone grid.
-- The open-water fishing tables were keyed on the old subzone 5017 (the beach), which no longer exists.
-- Open water is now Misty Shores (5007, the coastal ring) and South Seas (5011, the ocean around it).
-- Zone 5006 keeps its own fallback rows (areas without rows fall back to the zone).

DELETE FROM `fishing_loot_template` WHERE `Entry` IN (5007, 5011, 5017);
INSERT INTO `fishing_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(5007, 900100, 0, 55,  0, 1, 1, 1, 3, 'Titan-Scale Lungfish'),
(5007, 900102, 0, 35,  0, 1, 1, 1, 2, 'Epoch Eel'),
(5007, 900101, 0, 10,  0, 1, 1, 1, 1, 'Primordial Thunderfin'),
(5007, 900110, 0, 0.1, 0, 1, 0, 1, 1, 'Spine of the First Age -- rare pole discovery'),
(5007, 37705,  0, 5,   0, 1, 0, 1, 2, 'Crystallized Water -- primal remnant'),
(5007, 6265,   0, 20,  0, 1, 0, 1, 2, 'Firefin Snapper -- bonus fire-school fish'),
(5011, 900100, 0, 55,  0, 1, 1, 1, 3, 'Titan-Scale Lungfish'),
(5011, 900102, 0, 35,  0, 1, 1, 1, 2, 'Epoch Eel'),
(5011, 900101, 0, 10,  0, 1, 1, 1, 1, 'Primordial Thunderfin'),
(5011, 900110, 0, 0.1, 0, 1, 0, 1, 1, 'Spine of the First Age -- rare pole discovery'),
(5011, 37705,  0, 5,   0, 1, 0, 1, 2, 'Crystallized Water -- primal remnant'),
(5011, 6265,   0, 20,  0, 1, 0, 1, 2, 'Firefin Snapper -- bonus fire-school fish');

DELETE FROM `skill_fishing_base_level` WHERE `entry` IN (5007, 5011, 5017);
INSERT INTO `skill_fishing_base_level` (`entry`, `skill`) VALUES
(5007, 375),
(5011, 375);
