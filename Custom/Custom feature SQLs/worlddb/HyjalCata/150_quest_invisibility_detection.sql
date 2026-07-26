-- ---------------------------------------------------------------------------
-- 150  Hyjal round-23 -- the quest-invisibility detection that was never ported
-- ---------------------------------------------------------------------------
-- THIS ONE REPORTS NOTHING IN THE BOOT LOG.  It was found by auditing rather
-- than by reading Errors.log, and it is the most damaging single gap the
-- downport still had.
--
-- SYMPTOM
--   Nine Hyjal NPCs -- 16 spawns, all phaseMask 1 -- are permanently invisible
--   to every player.  Between them they are most of the zone's spine:
--
--     3639858 / 3652838  Arch Druid Hamuul Runetotem   (2 + 6 spawns)
--     3639933            Tyrus Blackhorn
--     3640619            Commander Jarod Shadowsong
--     3640863            Image of Goldrinn
--     3640864            Image of Aviana
--     3640865            Image of Cenarius
--     3641006            Thisalee Crow                 (2 spawns)
--     3641300            Aviana's Egg
--
-- CAUSE
--   Their creature_template_addon carries Cata's quest-invisibility auras
--   (49414 / 49415 / 89304).  In Cata the matching DETECTION aura is handed to
--   the player by `spell_area` rows scoped to Hyjal's sub-areas.  DC has ZERO
--   spell_area rows for area 4923 -- the whole table was skipped when the zone
--   was ported -- and nothing in zone_mount_hyjal.cpp / zone_molten_front.cpp
--   grants a detection aura either (they only ever call SetPhaseMask).  So the
--   invisibility is applied and nothing anywhere removes it.
--
-- THE TYPE PAIRING MATTERS -- DO NOT COPY nelt's ROWS BLIND
--   AC matches invisibility by EffectMiscValue (the "type"), and only reveals
--   when the detect amount >= the invisibility amount.  Read out of the built
--   Custom/DBCs/Spell.dbc (NOT out of spell_dbc, which is an additive override
--   table and does not contain these at all):
--
--     49414 Generic Quest Invisibility 1    type  7  amount 100
--     49415 Generic Quest Invisibility 2    type  8  amount 100
--     89304 Generic Quest Invisibility 29   type 37  amount 101
--
--     49416 ...Detection 1                  type  7  amount 1000   <= covers 49414
--     60197 See Invisibility                type  8  amount 1000   <= covers 49415
--     49417 ...Detection 2                  type  8  amount  100
--     60922 ...Detection 3                  type  9  amount 1000   <= covers NOTHING here
--
--   nelt_world.spell_area grants 49416 and 60197, which is correct, and 60922,
--   which detects type 9 and is useless for this NPC set.  Only the two that
--   actually pair are taken.
--
-- WHY NO QUEST GATING
--   Cata gates these on quests 25316 / 25317 and scopes them to sub-areas
--   5034-5041.  Neither applies here: DC collapsed all of Hyjal into the single
--   zone 4923 (AreaTable: parent 0, so it IS the zone and covers every point on
--   map 750), and every one of the 16 spawns sits in phaseMask 1 because the
--   Cata phase set was never ported (same root cause as round 21's base-phase
--   finding).  A quest-gated grant would therefore hide the NPCs from anyone
--   not mid-chain -- including the questgivers who START the chain, which is a
--   deadlock.  Flat, ungated, autocast is what matches how DC actually built
--   the zone.
--
-- Idempotent (spell_area's PK is spell+area+quest_start+aura_spell+racemask+
-- gender, so INSERT IGNORE cannot double-insert).
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO `spell_area`
(`spell`,`area`,`quest_start`,`quest_end`,`aura_spell`,`racemask`,`gender`,`autocast`,`quest_start_status`,`quest_end_status`) VALUES
(49416, 4923, 0, 0, 0, 0, 2, 1, 64, 11),
(60197, 4923, 0, 0, 0, 0, 2, 1, 64, 11);

-- ---------------------------------------------------------------------------
-- Thisalee Crow -- the one aura that has no answer in 3.3.5
-- ---------------------------------------------------------------------------
-- 89304 is invisibility TYPE 37.  Scanning all 53,134 rows of the built
-- Spell.dbc for an aura-19 (MOD_INVISIBILITY_DETECT) effect with miscvalue 37
-- returns nothing: 89304 is the only spell in the client that uses type 37 at
-- all, and Cata's detector for it was never a 3.3.5 spell.  So there is no
-- spell_area row that can reveal her while she carries it.
--
-- She already carries 49414 as well, which the row above now handles, so the
-- 89304 layer is redundant for visibility and only serves the Cata phase
-- bookkeeping that DC did not port.  Dropping it from her addon is the whole
-- fix; inventing a type-37 detection spell would add a Spell.dbc row that
-- changes nothing else in the world (verified: 89304 is referenced by exactly
-- one creature_template_addon and nothing else in the DB).
--
-- 76701 (Sitting) and the 49414 she keeps are left untouched.
UPDATE `creature_template_addon`
SET `auras` = '76701 49414'
WHERE `entry` = 3641006 AND `auras` = '89304 76701 49414';
