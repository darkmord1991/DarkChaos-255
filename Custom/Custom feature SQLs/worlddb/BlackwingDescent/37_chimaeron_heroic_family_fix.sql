-- ---------------------------------------------------------------------------
-- Chimaeron heroic-mode clone (47774) missing `family`
-- ---------------------------------------------------------------------------
-- "Creature (Entry: 43296, family 38) has different `family` in difficulty 1
-- mode (Entry: 47774, family 0)." Base entry 43296 "Chimaeron" correctly has
-- family=38 (Chimaera); its own difficulty_entry_1 heroic clone (47774,
-- same name) was left at the default family=0 -- an authoring oversight, not
-- a downport gap (both entries already exist, this is a single wrong field).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `family` = 38 WHERE `entry` = 47774 AND `family` = 0;
