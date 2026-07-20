-- ---------------------------------------------------------------------------
-- 18  Non-combat trigger/environmental/RP-standin lootid cleanup
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-14): "Table 'creature_loot_template'
-- Entry N does not exist but it is used by Creature N" for ~40 Castle
-- Nathria entries that were never meant to drop loot at all:
--  - Pure environmental/mechanical trigger markers (Stalker x7, Rock,
--    Rubble Pile x7, Generic Bunny, Soul Pedestal, Crystal of Phantasms,
--    Anima Canister, Right/Left Hand Chains, Fight/Dance Controller,
--    Sinstone Marker, Pillar/Aerial Bombardment Stalker, Ravage [DNT],
--    Edge of Annihilation, Waltzing Venthyr, Dancing Fools, March of the
--    Penitent base/player vehicles).
--  - "Container of X"/"Anima Container"/"Sins of the Past" (x2) -- these are
--    Shadowlands anima/borrowed-power system dispensers; matches the
--    already-documented [[castle-nathria-item-loot-coverage]] decision to
--    NOT downport SL-system rewards (conduits/anima/runecarver memories are
--    non-functional on 3.3.5) -- these containers' real drops are 100% of
--    that non-functional category, so lootid=0 is the correct outcome here,
--    not a shortcut.
--  - 2 confirmed RP/cutscene stand-in duplicates: Sire Denathrius (172930,
--    rank=0, no ScriptName) and Sludgefist (174733, rank=0, no ScriptName)
--    -- verified against 10_loot.sql, which already authors real loot for
--    the ACTUAL fightable bosses at DIFFERENT entries (167406 "boss_sire_
--    denathrius" rank=3; 164407 "boss_sludgefist" rank=3).
-- Real scripted mid-fight NPCs (Remornia 168156, Root of Extinction 169267,
-- Prince Renathal's Stone Legion phase 172652, Reverberating Eruption
-- Stalker 175102 -- all rank>=1 with real ScriptNames) are NOT included
-- here; they're left for the trash-loot authoring pass (18_).
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `lootid` = 0 WHERE `entry` IN (
    165788,166766,167294,168138,168366,168367,168368,168369,168512,168569,
    168687,168688,168870,169062,169470,170083,170544,171763,171764,172316,
    172659,172660,172661,172930,172944,172976,172989,173012,173175,173382,
    173622,174733,176016,176026,176283,176284,176362,176363,176364,176365,
    176366,176544
) AND `lootid` <> 0;
