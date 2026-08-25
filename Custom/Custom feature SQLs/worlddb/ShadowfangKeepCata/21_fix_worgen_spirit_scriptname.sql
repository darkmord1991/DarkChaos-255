-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, fix: npc_sfk_worgen_spirit is bound to the
-- wrong four creatures.
--
-- 06_scriptnames.sql attaches `npc_sfk_worgen_spirit` to the four "Worgen Spirit"
-- entries (51047 / 50934 / 51080 / 51085 + 5,000,000) on the stated reasoning that the
-- AI "resolves which ghost to summon from the creature entry at runtime". It does not.
-- Reading the C++ end to end, the chain is:
--
--   1. Silverlaine casts SPELL_SUMMON_WORGEN_SPIRIT (93857) and a *Worgen Spirit*
--      appears.
--   2. boss_baron_silverlaine::JustSummoned switches on the SPIRIT entry and makes the
--      spirit cast SPELL_SUMMON_SPIRIT_OF_<name>_SUMMON. That is where the ghost choice
--      is made -- in Silverlaine's AI, not in the spirit's.
--   3. That spell summons the NAMED GHOST -- Wolf Master Nandos, Odo the Blindwatcher,
--      Razorclaw the Butcher or Rethilgore -- and the ghost is what actually fights.
--
-- `npc_sfk_worgen_spirit` is the ghost's AI, and the code says so in three places:
--   * its entry switch schedules Claw / Howling Rage + Blinding Shadows / Spectral Rush
--     / Soul Drain, keyed on NPC_WOLF_MASTER_NANDOS, NPC_ODO_THE_BLINDWATCHER,
--     NPC_RAZORCLAW_THE_BUTCHER, NPC_RETHILGORE -- the ghost entries;
--   * it registers ITSELF with Silverlaine (`silverlaine->AI()->JustSummoned(me)`),
--     which is the only reason a ghost summoned by the spirit ends up in Silverlaine's
--     summon list at all;
--   * boss_baron_silverlaine::DespawnWorgenSpirits() then addresses exactly those four
--     ghost entries with ACTION_DESPAWN, an action only this AI handles.
--
-- Bound to the spirits, every one of those paths is dead: no case in the switch can
-- match, the ghosts have no AI, and nothing answers ACTION_DESPAWN on evade.
--
-- The spirit itself needs no AI -- it is driven entirely by Silverlaine's JustSummoned --
-- so the binding is MOVED rather than duplicated.
--
-- ---------------------------------------------------------------------------------
-- THIS IS NOT THE ONLY THING BLOCKING THE MECHANIC -- see the note at the bottom.
-- ---------------------------------------------------------------------------------
--
-- Scoped to `entry BETWEEN 5000000 AND 5099999` like every other statement in 06, so it
-- can never touch classic Shadowfang Keep's own 834 / 851 / 857 / 869 on map 33.
-- 06_scriptnames.sql has been corrected too, so a fresh apply does not need this file.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Unbind the four Worgen Spirit entries
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = ''
WHERE `entry` IN (51047 + 5000000, 50934 + 5000000, 51080 + 5000000, 51085 + 5000000)
  AND `entry` BETWEEN 5000000 AND 5099999
  AND `ScriptName` = 'npc_sfk_worgen_spirit';

-- -------------------------------------------------------------------------------------
-- 2. Bind the four named ghosts
--
-- `AIName` is cleared as well: a creature carrying both SmartAI and a ScriptName loads
-- the SmartAI and the C++ AI never runs.
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_sfk_worgen_spirit', `AIName` = ''
WHERE `entry` IN (50851 + 5000000,   -- Wolf Master Nandos
                  50857 + 5000000,   -- Odo the Blindwatcher
                  50869 + 5000000,   -- Razorclaw the Butcher
                  50834 + 5000000)   -- Rethilgore
  AND `entry` BETWEEN 5000000 AND 5099999;

-- -------------------------------------------------------------------------------------
-- 3. Clear the heroic variants  -- CORRECTED 2026-08-23, this block did the opposite
--
-- It used to re-run 06's propagation onto 5050852 / 5051086 / 5051034 / 5050835, saying
-- "without this they stay plain melee dummies on heroic and mythic". That is not how the
-- core works, and the four rows it wrote were the last four of the eleven
--     ... lists difficulty 1 mode entry Y with `ScriptName` filled in.
--     `ScriptName` of difficulty 0 mode creature is always used instead.
-- lines in the boot log. (298_ cleared the other seven; these four came back because this
-- file runs after it.)
--
-- Creature::UpdateEntry loads the heroic template into m_creatureInfo but then calls
-- `SetEntry(Entry);  // normal entry always` (Creature.cpp:509), and Creature::GetScriptId
-- (Creature.cpp:3187) resolves `GetCreatureTemplate(GetEntry())->ScriptID` -- the
-- difficulty-0 entry's. The variant's ScriptName is therefore unreadable on every
-- difficulty; the ghosts get `npc_sfk_worgen_spirit` from their parent on heroic just as
-- they do on normal, which is what section 2 above sets. Nothing is lost by clearing.
--
-- `AIName` is deliberately NOT touched here: 06 already clears it on these rows, and the
-- AIName warning is a separate check with the same difficulty-0 rule.
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` d
JOIN `creature_template` n ON n.`difficulty_entry_1` = d.`entry`
SET d.`ScriptName` = ''
WHERE d.`entry` BETWEEN 5000000 AND 5099999
  AND n.`entry` IN (50851 + 5000000, 50857 + 5000000, 50869 + 5000000, 50834 + 5000000)
  AND d.`ScriptName` <> '';

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'ghosts bound to npc_sfk_worgen_spirit (want 4)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template`
    WHERE `entry` IN (50851 + 5000000, 50857 + 5000000, 50869 + 5000000, 50834 + 5000000)
      AND `ScriptName` = 'npc_sfk_worgen_spirit'
UNION ALL SELECT 'heroic variants bound (want 0 -- see section 3)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (50852 + 5000000, 51086 + 5000000, 51034 + 5000000, 50835 + 5000000)
      AND `ScriptName` = 'npc_sfk_worgen_spirit'
UNION ALL SELECT 'spirits still bound (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (51047 + 5000000, 50934 + 5000000, 51080 + 5000000, 51085 + 5000000)
      AND `ScriptName` = 'npc_sfk_worgen_spirit'
UNION ALL SELECT 'classic SFK entries touched (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template`
    WHERE `entry` IN (834, 851, 857, 869, 51047, 50934, 51080, 51085)
      AND `ScriptName` = 'npc_sfk_worgen_spirit'
UNION ALL SELECT 'summon-chain spells still missing from spell_dbc (want 0, is 8)', CAST(8 - COUNT(*) AS CHAR)
    FROM `spell_dbc` WHERE `ID` IN (93858, 93895, 93860, 93897, 93922, 93923, 93926, 93929);

-- =====================================================================================
-- STILL BLOCKED AFTER THIS FILE -- the spell data was never downported
-- =====================================================================================
-- This fixes the binding. It does NOT make worgen spirits appear, because the summon
-- chain dies in spell_dbc two links before it reaches a summon effect:
--
--   93857 Summon Worgen Spirit   present, SCRIPT_EFFECT -> spell_sfk_summon_worgen_spirit
--                               casts the *_DUMMY id passed in as base point 0
--   93896 / 93859 / 93921 / 93925 (the DUMMY ids)   present, but their only effect is
--                               TRIGGER_MISSILE -> 93895 / 93858 / 93922 / 93926
--   93895 / 93858 / 93922 / 93926                   ABSENT from spell_dbc
--   93899 / 93864 / 93924 / 93927 (the SUMMON ids)  present, but their only effect is a
--                               periodic-trigger aura -> 93897 / 93860 / 93923 / 93929
--   93897 / 93860 / 93923 / 93929                   ABSENT from spell_dbc
--
-- So no effect anywhere in the chain has SPELL_EFFECT_SUMMON, and no creature is ever
-- created. Separately, SPELL_SUMMON_LUPINE_SPECTRE (94199) IS a real summon but its
-- EffectMiscValue is 50923 -- the retail entry. Neither 50923 nor 5050923 exists in
-- `creature_template` on this realm, so Nandos' three spectres summon nothing either.
--
-- Fixing that is a Spell.dbc downport (8 missing rows + one MiscValue remap to the
-- +5,000,000 band), not a scriptname change. Use spell-dbc-append.py -- this fork's
-- Spell.dbc is the 234-field layout and a csv2wdbc rebuild would destroy it.
-- =====================================================================================
