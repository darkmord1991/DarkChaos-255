-- =====================================================================
-- Blackwing Descent Downport  --  29  npc_spellclick_spells (Pincer/Wyvern)
-- ---------------------------------------------------------------------
-- Follow-up to 23_spellclick.sql, which explicitly left 41620/41789
-- "Magmaw's Pincer" and 45004/45024 "Wyvern" alone pending confirmation --
-- neither had a spawn on any of the 5 custom maps via `creature`,
-- creature_summon_groups, or smart_scripts SUMMON_CREATURE at the time.
-- Still true (more-db-errors audit pass, 2026-07-13) -- no spawn found by
-- any of those mechanisms -- but real cata_world.npc_spellclick_spells data
-- exists for both regardless (summon-only vehicle-interaction props, same
-- class as the Molten Front summon-only creatures in HyjalCata/74_), so
-- wiring them up now rather than leaving the flag to be silently stripped
-- at every boot. Spells 41020/46598 are both stock WotLK, already compiled
-- into the client and already in this fork's own Spell.csv -- server-side
-- spell_dbc row only, see HyjalCata/80_spellclick_spell_dbc_additions.sql
-- (kept there since that file already batches every spellclick-related
-- spell_dbc gap from this same audit pass, Hyjal or not).
-- =====================================================================
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (41620,41789,45004,45024);

INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`) VALUES
(41620,41020,1,0),
(41789,41020,1,0),
(45004,46598,1,0),
(45024,46598,1,0);
