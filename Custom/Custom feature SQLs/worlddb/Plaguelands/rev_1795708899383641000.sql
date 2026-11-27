-- DarkChaos: thin the Scarlet caster packs at Tyr's Hand (map 751 zone 4924 "Eastern Plaguelands (152-158)").
-- Level 157 bots died in 49% of their fights with Scarlet Curates and 41% with Scarlet Archmages (11-25/26): these
-- casters stand two to four to a pack beside Praetorians and Warders, and a pull brings them all. Every pack (spawns
-- within 12 yd of each other) now keeps one caster, the least dangerous one (Enchanter, Cleric, Archmage,
-- Curate in that order); the melee Praetorians and Warders stay. Removed: 18 of 25 Curates, 4 of 18 Archmages,
-- 11 of 23 Clerics, 6 of 20 Enchanters.
-- No formations, pools, linked respawns or game events reference these spawns; their creature_addon rows go too.
-- Quest 27460 Soft Landing needs Scarlet Warders only. Revert:
-- Custom/Custom feature SQLs/worlddb/Plaguelands/tyrs_hand_casters_revert_1795708899383641000.sql
DELETE FROM `creature_addon` WHERE `guid` IN (
    13066576, 13066577, 13066578, 13066580, 13066581, 13066583, 13066586, 13066589, 13066593, 13066595, 13066596,
    13066598, 13066599, 13066600, 13066601, 13066604, 13066605, 13066606, 13066607, 13066608, 13066610, 13066612,
    13066613, 13066614, 13066615, 13066616, 13066618, 13066619, 13066620, 13066631, 13066636, 13066637, 13066638,
    13066641, 13066648, 13066649, 13066650, 13066652, 13066655);
DELETE FROM `creature` WHERE `id` IN (3609449, 3609450, 3609451, 3609452) AND `guid` IN (
    13066576, 13066577, 13066578, 13066580, 13066581, 13066583, 13066586, 13066589, 13066593, 13066595, 13066596,
    13066598, 13066599, 13066600, 13066601, 13066604, 13066605, 13066606, 13066607, 13066608, 13066610, 13066612,
    13066613, 13066614, 13066615, 13066616, 13066618, 13066619, 13066620, 13066631, 13066636, 13066637, 13066638,
    13066641, 13066648, 13066649, 13066650, 13066652, 13066655);
