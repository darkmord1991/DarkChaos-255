-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- restore missing quest giver / turn-in links
-- ---------------------------------------------------------------------------
-- Completability audit 2026-09-11 against the live world DB: 72 of 115 crater
-- quests (300100-300966) could be completed. This file fixes the ones that were
-- blocked ONLY by a missing creature_queststarter / creature_questender row --
-- quests whose objectives and NPCs already exist and are spawned on map 37.
-- Result: 72 -> 79 completable.
--
--   300950 Stirrings in the Drowned City  no giver     -> Arcanist Melia 300010
--   300951 Corruption in the Deep         no giver     -> Pathfinder Gor'nash 300020
--   300607 Killers in the Dark            no giver/end -> Felsworn Kael'thos 300050
--   300608 Fires That Walk                no giver/end -> Felsworn Kael'thos 300050
--   300609 Bounty: Lethtendris            no giver/end -> Felsworn Kael'thos 300050
--   300610 Bounty: Obsidion               no giver/end -> Felsworn Kael'thos 300050
--   300955 The Priestess of Elune         no turn-in   -> Priestess Lunara 300085
--
-- 300955 was the worst case: Seryth offers it, nobody accepts it back, so it sat
-- in the player's log forever.
--
-- Pre-flight (all verified live before writing this):
--   * every NPC above is spawned on map 37, phaseMask 1, npcflag 3;
--   * the enders of 300950/300951 (Magister Idona 300081, Elder Brownpaw 300082)
--     are already in place, and the quests those NPCs hand out are completable;
--   * 300607-300610 kill targets are spawned on map 37 in Kael'thos's band:
--     Jadefire Felsworn 7109 x3, Jadefire Rogue 7106 x6, Burning Felhound 10261 x6,
--     Lethtendris 14327 x1, The Ravenian 10507 x1 (all respawn 300s);
--   * no conditions, disables or quest_template_addon rows gate any of them.
--
-- WHY THE ROWS WERE MISSING -- the source SQL deletes its own work:
--   * 2026_01_10_00_..._zones_4_8.sql ran `DELETE ... WHERE id = 300085` near the
--     end of the file, after it had already linked Lunara to 300940-300946 and
--     made her the ender of 300955 -> both wiped.
--   * 2026_01_09_00_..._zones_1_3.sql ran `DELETE ... WHERE id IN (300010, 300020, ...)`,
--     so re-applying it after zones_4_8 wiped the 300950/300951 starters.
--   * 300607-300610 were simply never listed in the Kael'thos relation block.
--   The DELETEs in both source files were scoped in the same change, but DO NOT
--   re-import those files: they predate this schema and wipe NPC templates when
--   re-run (see 2026_09_11_01_dc_azshara_crater_zones_1_3_rerun_repair.sql).
--
-- Apply AFTER 2026_09_11_01_dc_azshara_crater_zones_1_3_rerun_repair.sql if that
-- repair is pending -- the givers linked below must have templates to load.
--
-- DELIBERATELY NOT RESTORED: Lunara's Temple of Elune quests 300940-300946.
-- Every one of the seven has at least one kill target with no spawn on map 37
-- (Priestess Delrissa, Twilight Lord Kelris, Arcane Watchman, High Priestess
-- Arlokk, Highborne Summoner, Omen + Yauj Brood, Eldreth Sorcerer + Seether).
-- Offering them would let players accept quests they can never finish, which is
-- worse than not offering them. They are kept unlinked below; re-link them once
-- the targets are spawned.
--
-- Text mismatch on two of these (does not block completion): 300607 named Jadefire
-- Betrayers / Shadowstalkers instead of Felsworn / Rogue, and 300610 named Obsidion
-- instead of The Ravenian. Fixed in 2026_09_11_02_dc_azshara_crater_300607_300610_text_fix.sql
-- (300610 is retitled "Bounty: The Ravenian").
--
-- Apply, then either restart the worldserver or run:
--   .reload creature_queststarter
--   .reload creature_questender
--
-- Verify (expect 7 starters on 300607-300610/300950/300951 and 5 enders on
-- 300607-300610/300955; expect 0 rows for 300940-300946):
--   SELECT 'start', id, quest FROM creature_queststarter
--    WHERE quest BETWEEN 300607 AND 300610 OR quest IN (300950, 300951)
--   UNION ALL SELECT 'end', id, quest FROM creature_questender
--    WHERE quest BETWEEN 300607 AND 300610 OR quest = 300955;
-- ---------------------------------------------------------------------------

-- Breadcrumbs from the zone givers to the dungeon quest givers
DELETE FROM `creature_queststarter` WHERE `quest` IN (300950, 300951);
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300010, 300950), -- Arcanist Melia -> Magister Idona
(300020, 300951); -- Pathfinder Gor'nash -> Elder Brownpaw

-- Zone 6: Felsworn Kael'thos gives and takes back 300607-300610
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 300607 AND 300610;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300050, 300607), -- Killers in the Dark
(300050, 300608), -- Fires That Walk
(300050, 300609), -- Bounty: Lethtendris
(300050, 300610); -- Bounty: The Ravenian (titled "Bounty: Obsidion" until 2026_09_11_02)

DELETE FROM `creature_questender` WHERE `quest` BETWEEN 300607 AND 300610;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300050, 300607),
(300050, 300608),
(300050, 300609),
(300050, 300610);

-- Breadcrumb from Dragonbinder Seryth: turned in at Priestess Lunara
DELETE FROM `creature_questender` WHERE `quest` = 300955;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(300085, 300955);

-- Temple of Elune 300940-300946: keep unlinked until their targets are spawned
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 300940 AND 300946;
DELETE FROM `creature_questender` WHERE `quest` BETWEEN 300940 AND 300946;
