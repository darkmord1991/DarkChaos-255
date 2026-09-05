-- Hinterland BG (maps 1411 + 1412): give every combat NPC a weapon.
--
-- Audit findings this fixes:
--   * 9 of the 15 battleground NPC types had equipment_id = 0, i.e. no weapon at
--     all - including BOTH faction bosses. That is 50 of the 54 combat spawns
--     per map fighting bare-handed.
--   * Of the 6 that did have equipment, 4 used item 12749 ("Monster - Item,
--     Scepter - Gold Offhand", class 4 / InventoryType 23) as their MAIN HAND,
--     and 3 put item 12651 ("Blackcrow", a crossbow, InventoryType 26) in the
--     OFF HAND slot. Both render in the wrong hand.
--   * 810008 (Revantusk Spiritmender, a Horde troll) carried 12584 "Grand
--     Marshal's Longsword" - an Alliance PvP sword.
--
-- Slot semantics: ItemID1 = main hand, ItemID2 = off hand, ItemID3 = ranged.
-- Two-handers (InventoryType 17) occupy the main hand and leave the off hand
-- empty. Items are drawn from the "Monster - ..." range, which is the stock
-- convention for creature-visible gear, preferring the "... PvP" set that
-- exists for exactly this purpose.
--
-- Creature weapons are cosmetic in AzerothCore - damage comes from
-- creature_template - so this changes appearance and attack animation, not
-- balance.
--
-- VerifiedBuild is 0, not the 12340 the pre-existing 810006-810011 rows carry:
-- these are custom creatures and the gear was chosen by hand, not taken from a
-- retail sniff, so claiming a verified build would be false. Those six rows are
-- re-inserted here too, which makes the whole set consistent.

DELETE FROM `creature_equip_template` WHERE `CreatureID` IN
    (810000, 810001, 810002, 810003, 810006, 810007, 810008, 810009, 810010,
     810011, 810012, 810013, 810014, 810015, 810016, 810017, 810018, 810019,
     810020, 810021, 810022, 810023) AND `ID` = 1;

INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
-- Alliance / Wildhammer -------------------------------------------------------
(810001, 1, 21573, 21572,     0, 0),  -- Hinterland Alliance guard: 1H sword + Alliance PvP shield
(810009, 1, 10591, 21572,     0, 0),  -- Battlewarden: Stormhammer + shield
(810010, 1, 21573, 21572, 42776, 0),  -- Sentry: sword + shield + Alliance PvP gun
(810011, 1, 21573,     0,  5260, 0),  -- Scout: sword + bow
(810013, 1, 20412,     0,     0, 0),  -- Gryphon Herald: Alliance PvP polearm (two-handed)
(810015, 1, 20412,     0,     0, 0),  -- Banner-Bearer: polearm as banner haft (two-handed)
(810017, 1, 21553, 21572,     0, 0),  -- Watch Captain: greatsword model + shield
(810021, 1, 21573,     0, 42776, 0),  -- Marksman (no spawns yet): sword + gun
(810022, 1,  1905,     0,  5260, 0),  -- Pathfinder (no spawns yet): axe + bow
(810023, 1, 10591, 21572,     0, 0),  -- Roost Tender (no spawns yet): hammer + shield
(810003, 1, 21553,     0,     0, 0),  -- King Varian Wrynn: Alliance PvP greatsword
-- Horde / Revantusk -----------------------------------------------------------
(810000, 1, 10611, 13318,     0, 0),  -- Revantusk Watcher: Horde axe + Horde shield
(810006, 1, 10612, 13318,     0, 0),  -- Warcaller: Horde axe + shield
(810007, 1, 10611, 13318,     0, 0),  -- Watchblade: Horde axe + shield
(810008, 1, 12786, 13318,     0, 0),  -- Spiritmender: Horde skull club + shield
(810012, 1, 13631,     0,     0, 0),  -- Banner-Singer: spear (two-handed)
(810014, 1,  2695,     0,     0, 0),  -- Drumkeeper (no spawns yet): spiked club
(810016, 1, 12787, 13318,     0, 0),  -- Fireside Shaman: bone claw hammer + shield
(810018, 1, 10611,     0,  5262, 0),  -- Headhunter (no spawns yet): axe + bow
(810019, 1, 12788,     0,     0, 0),  -- Ritespeaker (no spawns yet): bone spike hammer
(810020, 1,  2695,     0,     0, 0),  -- Bonfire Tender (no spawns yet): spiked club
(810002, 1, 12183,     0,     0, 0);  -- Thrall Warchief: "Monster - Mace, Thrall's Hammer"

-- Point every battleground spawn at the equipment set above. Scoped to maps
-- 1411/1412 on purpose: creature 810003 also has an open-world spawn on map 0
-- (guid 3111617) which is left untouched.
UPDATE `creature` SET `equipment_id` = 1
WHERE `map` IN (1411, 1412)
  AND `id` IN (810000, 810001, 810002, 810003, 810006, 810007, 810008, 810009,
               810010, 810011, 810012, 810013, 810014, 810015, 810016, 810017,
               810018, 810019, 810020, 810021, 810022, 810023);
