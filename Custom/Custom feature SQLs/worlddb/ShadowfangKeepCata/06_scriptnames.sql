-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 6: ScriptName bindings
--
-- Binds the 18 ScriptNames registered by src/server/scripts/DC/ShadowfangKeepCata.
-- Until this runs the worldserver logs, once per script at boot:
--     Script named 'boss_baron_ashbury' is not assigned in the database.
-- That is EXPECTED between the rebuild and this file, and is not an error.
--
-- REQUIRES 03_templates.sql FIRST (the offset creature_template rows must exist).
--
-- ---------------------------------------------------------------------------------
-- THE WHOLE POINT OF THE +5,000,000 OFFSET
-- ---------------------------------------------------------------------------------
-- Two of these five bosses are STOCK entries that classic Shadowfang Keep on map 33
-- also spawns and drives with SmartAI:
--     3887  Baron Silverlaine
--     4278  Commander Springvale
-- Every UPDATE below is scoped to `entry BETWEEN 5000000 AND 5099999`, so it lands on
-- the clone's 5003887 / 5004278 and never on 3887 / 4278. Do not "simplify" these into
-- `WHERE entry = 3887` -- that single change would rewrite classic SFK.
--
-- Also note the C++ side deliberately does NOT reuse core's names: the instance script
-- is `instance_sfk_cata` (not `instance_shadowfang_keep`), because ScriptMgr silently
-- DELETES the older script on a name clash rather than reporting one.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Bosses and encounter adds -- creature_template.ScriptName
--
--   AIName is cleared on the same rows: a creature cannot be driven by SmartAI and a
--   C++ CreatureAI at once, and AC picks AIName first, which would leave the C++ script
--   registered but never instantiated. 03 carried AIName='SmartAI' across for these.
-- -------------------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'boss_baron_ashbury',        `AIName` = '' WHERE `entry` = 46962 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'boss_baron_silverlaine',    `AIName` = '' WHERE `entry` =  3887 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'boss_commander_springvale', `AIName` = '' WHERE `entry` =  4278 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'boss_lord_walden',          `AIName` = '' WHERE `entry` = 46963 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'boss_lord_godfrey',         `AIName` = '' WHERE `entry` = 46964 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;

-- Encounter adds with their own AI.
--
-- npc_sfk_worgen_spirit belongs on the four NAMED GHOSTS, not on the "Worgen Spirit"
-- entries the name suggests (51047 / 50934 / 51080 / 51085). Silverlaine summons a
-- spirit, HIS JustSummoned makes it cast SPELL_SUMMON_SPIRIT_OF_<name>_SUMMON, and the
-- ghost that spell creates is what fights -- so the ghost is what needs the AI. The
-- AI's own entry switch, its ACTION_DESPAWN handler and DespawnWorgenSpirits() all key
-- on these four entries. See 21_fix_worgen_spirit_scriptname.sql for the full trace and
-- for the spell-data gap that still blocks the mechanic downstream of this binding.
UPDATE `creature_template` SET `ScriptName` = 'npc_sfk_worgen_spirit',  `AIName` = '' WHERE `entry` IN (50851 + 5000000, 50857 + 5000000, 50869 + 5000000, 50834 + 5000000) AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'npc_wailing_guardsman',  `AIName` = '' WHERE `entry` = 50613 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;
UPDATE `creature_template` SET `ScriptName` = 'npc_tormented_officer',  `AIName` = '' WHERE `entry` = 50615 + 5000000 AND `entry` BETWEEN 5000000 AND 5099999;

-- CORRECTED 2026-08-23 -- this block used to PROPAGATE the ScriptName onto the heroic
-- difficulty variants, on the reasoning that "the heroic difficulty variants need the
-- same AI as the entry they shadow, otherwise the boss is a plain melee dummy on heroic
-- and mythic." That reasoning is wrong, and the propagation was the source of all eleven
--     Creature (Entry: X) lists difficulty 1 mode entry Y with `ScriptName` filled in.
--     `ScriptName` of difficulty 0 mode creature is always used instead.
-- lines in the boot log.
--
-- Read end to end, a heroic creature never carries the variant's entry:
--   * Creature::UpdateEntry picks the heroic template into `cinfo`, then does
--     `SetEntry(Entry);  // normal entry always` (Creature.cpp:509) and stores the heroic
--     template only in m_creatureInfo -- so stats, model and flags come from the variant,
--     but GetEntry() stays the difficulty-0 entry.
--   * Creature::GetScriptId (Creature.cpp:3187) resolves
--     `GetCreatureTemplate(GetEntry())->ScriptID`, i.e. the difficulty-0 template's.
-- So the variant's ScriptName can never be read, on any difficulty. The boss gets its AI
-- from the parent entry on heroic exactly as it does on normal, and setting it on the
-- variant only tripped ObjectMgr's warning.
--
-- The AI is NOT lost by clearing this -- verified against the four worgen ghosts, whose
-- parents keep `npc_sfk_worgen_spirit`. Clearing rather than leaving it also matters
-- because ObjectMgr::CheckCreatureTemplate `continue`s past its difficulty bookkeeping
-- when the variant has a ScriptID, which suppresses the rest of its validation for that
-- creature (the runtime difficulty swap itself is unaffected -- it reads DifficultyEntry
-- directly).
--
-- So the statement is inverted: variants are CLEARED, never filled.
UPDATE `creature_template` d
JOIN `creature_template` n ON n.difficulty_entry_1 = d.entry
SET d.ScriptName = ''
WHERE d.entry BETWEEN 5000000 AND 5099999
  AND n.entry BETWEEN 5000000 AND 5099999
  AND d.ScriptName <> '';

-- -------------------------------------------------------------------------------------
-- 2. Spell scripts -- spell_script_names
--
-- Every id below was read back out of the C++ (the `enum Spells` block plus each script's
-- Validate()/Register() body) rather than inferred from the script name -- several do not
-- match what the name suggests. Spell ids are global and are NOT offset.
--
-- REQUIRES 01_sfk_cata_spells.sql AND 01c_sfk_ashbury_missing_spells.sql.
-- 01c exists because Ashbury's two signature abilities are declared as
--     #define SPELL_STAY_OF_EXECUTION  DUNGEON_MODE<uint32>(93468, 93705)
--     #define SPELL_PAIN_AND_SUFFERING DUNGEON_MODE<uint32>(93581, 93712)
-- i.e. as macros, not as `enum Spells` members -- so the original 56-id extraction never
-- saw them and all four were missing from spell_dbc.
--
-- Where an ability has separate normal and heroic ids, BOTH are bound: the script is one
-- class and AC dispatches on the cast spell id.
-- -------------------------------------------------------------------------------------
DELETE FROM `spell_script_names` WHERE `ScriptName` IN (
    'spell_ashbury_asphyxiate', 'spell_ashbury_pain_and_suffering',
    'spell_ashbury_dark_archangel_form', 'spell_sfk_summon_worgen_spirit',
    'spell_sfk_forsaken_ability', 'spell_sfk_unholy_power', 'spell_sfk_unholy_empowerment',
    'spell_godfrey_summon_bloodthirsty_ghouls', 'spell_godfrey_pistol_barrage',
    'spell_godfrey_pistol_barrage_aoe', 'spell_godfrey_cursed_bullets',
    'spell_walden_toxic_coagulent', 'spell_walden_conjure_poisonous_mixture',
    'spell_walden_ice_shards', 'spell_walden_conjure_mystery_toxin',
    'spell_walden_toxic_catalyst');

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
    -- Baron Ashbury
    (93423, 'spell_ashbury_asphyxiate'),                 -- SPELL_ASPHYXIATE (the aura itself; 93422 is its root, 93424 the damage)
    (93581, 'spell_ashbury_pain_and_suffering'),         -- SPELL_PAIN_AND_SUFFERING normal (93605 is the DUMMY it casts, not the aura)
    (93712, 'spell_ashbury_pain_and_suffering'),         -- ... heroic
    (93757, 'spell_ashbury_dark_archangel_form'),        -- SPELL_DARK_ARCHANGEL_FORM
    -- Baron Silverlaine
    (93857, 'spell_sfk_summon_worgen_spirit'),           -- SPELL_SUMMON_WORGEN_SPIRIT
    -- Commander Springvale
    (7054,  'spell_sfk_forsaken_ability'),               -- SPELL_FORSAKEN_ABILITY -- a STOCK 3.3.5 spell, not a Cata one
    (93686, 'spell_sfk_unholy_power'),                   -- SPELL_UNHOLY_POWER normal
    (93735, 'spell_sfk_unholy_power'),                   -- SPELL_UNHOLY_POWER_HC
    (93844, 'spell_sfk_unholy_empowerment'),             -- SPELL_UNHOLY_EMPOWERMENT (Wailing Guardsman)
    -- Lord Godfrey
    (93707, 'spell_godfrey_summon_bloodthirsty_ghouls'), -- SPELL_SUMMON_BLOODTHIRSTY_GHOULS
    (93520, 'spell_godfrey_pistol_barrage'),             -- SPELL_PISTOL_BARRAGE (93566 is the periodic it applies)
    (96344, 'spell_godfrey_pistol_barrage_aoe'),         -- SPELL_PISTOL_BARRAGE_AOE
    (93629, 'spell_godfrey_cursed_bullets'),             -- SPELL_CURSED_BULLETS normal
    (93761, 'spell_godfrey_cursed_bullets'),             -- SPELL_CURSED_BULLETS_HC
    -- Lord Walden
    (93572, 'spell_walden_toxic_coagulent'),             -- SPELL_TOXIC_COAGULENT
    (93697, 'spell_walden_conjure_poisonous_mixture'),   -- SPELL_CONJURE_POISONOUS_MIXTURE
    (93527, 'spell_walden_ice_shards'),                  -- SPELL_ICE_SHARDS
    (93695, 'spell_walden_conjure_mystery_toxin'),       -- SPELL_CONJURE_MYSTERY_TOXIN
    (93689, 'spell_walden_toxic_catalyst');              -- SPELL_TOXIC_CATALYST_AOE (the AOE filters targets, not 93573)

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'clone templates with a ScriptName' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 5000000 AND 5099999 AND `ScriptName` <> ''
UNION ALL SELECT 'spell_script_names rows (want 19)', CAST(COUNT(*) AS CHAR)
    FROM `spell_script_names` WHERE `ScriptName` LIKE 'spell_ashbury%'
       OR `ScriptName` LIKE 'spell_sfk_%' OR `ScriptName` LIKE 'spell_godfrey_%'
       OR `ScriptName` LIKE 'spell_walden_%'
-- `spell_dbc` is the DC OVERLAY table: it holds only the downported ids, while stock
-- 3.3.5 spells live in Spell.dbc and are absent from it. 7054 Forsaken Ability is stock,
-- so it is excluded here rather than being reported as a false positive.
UNION ALL SELECT 'bound Cata spells missing from spell_dbc (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spell_script_names` s
    WHERE (s.ScriptName LIKE 'spell_ashbury%' OR s.ScriptName LIKE 'spell_sfk_%'
        OR s.ScriptName LIKE 'spell_godfrey_%' OR s.ScriptName LIKE 'spell_walden_%')
      AND s.spell_id >= 90000
      AND s.spell_id NOT IN (SELECT ID FROM `spell_dbc`)
UNION ALL SELECT 'rows still both SmartAI and C++ (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5000000 AND 5099999
      AND `ScriptName` <> '' AND `AIName` <> ''
-- The two that matter: stock 3887 / 4278 must be untouched.
--
-- These report 1/0 rather than the text itself on purpose. creature_template.ScriptName
-- and AIName are utf8mb4_unicode_ci while a string literal takes the connection
-- collation, and mixing the two in one UNION fails outright with SQL error 1271
-- "Illegal mix of collations" -- which takes the whole report block down with it.
UNION ALL SELECT 'STOCK 3887 ScriptName still empty (want 1)',
    CAST((SELECT `ScriptName` = '' FROM `creature_template` WHERE `entry` = 3887) AS CHAR)
UNION ALL SELECT 'STOCK 3887 AIName still SmartAI (want 1)',
    CAST((SELECT `AIName` = 'SmartAI' FROM `creature_template` WHERE `entry` = 3887) AS CHAR)
UNION ALL SELECT 'STOCK 4278 ScriptName still empty (want 1)',
    CAST((SELECT `ScriptName` = '' FROM `creature_template` WHERE `entry` = 4278) AS CHAR)
UNION ALL SELECT 'STOCK 4278 AIName still SmartAI (want 1)',
    CAST((SELECT `AIName` = 'SmartAI' FROM `creature_template` WHERE `entry` = 4278) AS CHAR);
