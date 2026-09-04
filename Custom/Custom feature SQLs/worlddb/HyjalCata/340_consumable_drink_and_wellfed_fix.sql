-- ---------------------------------------------------------------------------
-- 340  Make the Frontier drinks restore mana, and the feasts actually buff
-- ---------------------------------------------------------------------------
-- Two separate defects found auditing the 400800-400823 consumable line.
--
-- ---------------------------------------------------------------------------
-- DEFECT 1 -- all four drinks restored ZERO mana
-- ---------------------------------------------------------------------------
-- 300551 / 300556 / 300561 / 300566 are built EXACTLY like Blizzard's own drinks
-- (verified field-by-field against stock spell 43183 in the LIVE server's
-- Spell.dbc):
--
--     effect 0 : APPLY_AURA, aura  85 MOD_POWER_REGEN,  BasePoints -1
--     effect 1 : APPLY_AURA, aura 226 PERIODIC_DUMMY,   BasePoints = the real
--                value (5000 / 10000 / 22000 / 45000), period 2200 ms
--
-- The data is correct. What was missing is that the dummy's value only reaches
-- MOD_POWER_REGEN through a HARDCODED SPELL-ID WHITELIST in
-- `AuraEffect::HandlePeriodicDummyAuraTick` -- 430, 431, 432, 1133, 1135, 1137,
-- 10250, 22734, 27089, 34291, 43182, 43183, 46755, 49472, 57073, 61830.
--
-- 🔴 The DC ids are not in it, so the tick did nothing and effect 0 stayed at
-- (-1 + 1) = 0. The drinks played the animation and restored nothing.
--
-- Fixed in C++ by `spell_dc_frontier_drink`
-- (src/server/scripts/DC/HyjalFrontier/hyjal_frontier_consumables.cpp), which
-- hooks the dummy tick and performs the same ChangeAmount the core does for the
-- stock ids -- arena 6-second ramp included. Section 1 binds it.
-- **Requires a worldserver REBUILD.**
--
-- ---------------------------------------------------------------------------
-- DEFECT 2 -- the "feast" tier was an expensive placebo
-- ---------------------------------------------------------------------------
-- The four stews/feasts (300584-300587) carry
-- `Effect_2 = 64 SPELL_EFFECT_TRIGGER_SPELL` with **EffectTriggerSpell_2 = 0** --
-- they trigger nothing. Their aura-84 amount also equals the plain ration of the
-- same tier (300584 = 6000 = 300550), so Emberwood Hearty Stew at 16000 copper
-- was functionally identical to the Trail Ration at 9000. Their own tooltip says
-- "triggers a Well Fed buff", which never existed.
--
-- ---------------------------------------------------------------------------
-- 🔴 WHY THE BUFF IS A PERCENTAGE AND NOT FLAT STATS
-- ---------------------------------------------------------------------------
-- Blizzard's Well Fed uses aura 29 SPELL_AURA_MOD_STAT -- a flat number. On an
-- 80-255 fork that decays to nothing: `Unit::GetTotalStatValue` is
-- `((BASE_VALUE + CreateStat) * BASE_PCT + TOTAL_VALUE) * TOTAL_PCT`; gear lands
-- in BASE_VALUE and aura 29 in TOTAL_VALUE, so a flat +20 is noise beside
-- level-130 gear. Same reason the DC buff pass already moved 31 spells off flat
-- auras.
--
-- These use **aura 137 SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE**, misc value -1
-- (all stats) -- what Blessing of Kings (20217) uses.
--
-- 🔴 NOT aura 80 SPELL_AURA_MOD_PERCENT_STAT. Its handler early-returns on
-- non-players (`if (!target->IsPlayer()) return;`), so pets, ghouls and
-- felguards would silently get nothing. 137 has no such guard.
--
-- 🔴 `EffectBasePoints` is stored as VALUE - 1 (CalcValue adds 1 back when
-- EffectDieSides = 1), so a 3% buff is written as basePoints 2. Blessing of
-- Kings is basePoints 9 for its 10%.
--
--     Emberwood +2%   Skyfire +3%   Summit +4%   Nordrassil +5%
--
-- Modest against Kings' 10%, and it never stops scaling.
--
-- 🔴 Multiple aura-137 effects with the same misc value MULTIPLY
-- (`GetTotalAuraMultiplier`), so without section 4 a player could stack all four
-- tiers into 1.02 x 1.03 x 1.04 x 1.05. Section 4 makes them mutually exclusive,
-- highest wins. They deliberately do NOT conflict with Blessing of Kings -- food
-- and class buffs are meant to stack.
--
-- ---------------------------------------------------------------------------
-- HOW THE BUFF IS TRIGGERED
-- ---------------------------------------------------------------------------
-- Section 3 replaces the dead `Effect_2 = 64` with Blizzard's actual Well Fed
-- construction, copied from stock food spells 5004/5005/5006/5007:
--
--     Effect_2 = 6 APPLY_AURA, aura 23 PERIODIC_TRIGGER_SPELL,
--     period 10000 ms, EffectTriggerSpell_2 = the Well Fed spell
--
-- i.e. you must eat for 10 seconds to earn it, exactly like retail. Checked, not
-- assumed: the food is DurationIndex 8 = **15,000 ms** (read from the live
-- server's SpellDuration.dbc), so the 10s trigger fires once inside the eating
-- window. Well Fed itself is DurationIndex 347 = **900,000 ms** = 15 minutes,
-- the stock Well Fed duration.
--
-- ---------------------------------------------------------------------------
-- 🔴 SERVER BEHAVIOUR IS PURE SQL; THE CLIENT NEEDS THE TOOLTIP
-- ---------------------------------------------------------------------------
-- `DBCStores.cpp:355` loads Spell.dbc and then overlays `world.spell_dbc` BY ID
-- (DBCDatabaseLoader::Load -- "If exist in DBC file override from DB"), so these
-- rows fully define the spells server-side. No server-side DBC deploy is needed
-- for them to WORK.
--
-- But 300588-300591 are ids the CLIENT has never seen, so without a client-side
-- Spell.dbc row the buff shows with no icon and no tooltip. The four rows are
-- appended to `Custom/CSV DBC/Spell.csv` and Spell.dbc redeployed alongside this
-- file.
--
-- 🔴 No `USE` statement -- select acore_world in your client.
--
-- Apply against acore_world. Idempotent (DELETE before every INSERT).
-- Needs a worldserver REBUILD (defect 1 is C++) and a restart.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Bind the drink script
-- ---------------------------------------------------------------------------
DELETE FROM `spell_script_names`
WHERE `spell_id` IN (300551, 300556, 300561, 300566)
  AND `ScriptName` = 'spell_dc_frontier_drink';

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(300551, 'spell_dc_frontier_drink'),
(300556, 'spell_dc_frontier_drink'),
(300561, 'spell_dc_frontier_drink'),
(300566, 'spell_dc_frontier_drink');

-- ---------------------------------------------------------------------------
-- 2. Build the four Well Fed buffs (300588-300591)
-- ---------------------------------------------------------------------------
-- 🔴 CLONED from the existing food row 300584, not hand-authored. `spell_dbc`
-- mirrors a 234-field DBC; typing that out invites a wrong value in a column
-- nobody thinks to check. Cloning inherits a row already known to load and only
-- the fields that must differ are overridden.
--
-- 🔴 The clone goes through a staging table because
-- `INSERT INTO spell_dbc SELECT * FROM spell_dbc WHERE ID = 300584` cannot work
-- -- it would collide on the primary key with the row it is copying. Staging
-- lets the id be rewritten between the copy and the insert. It is a REAL table,
-- not TEMPORARY, so re-reading it in a later statement cannot raise MySQL 1137
-- "Can't reopen table".
DROP TABLE IF EXISTS `dc_wellfed_stage`;
CREATE TABLE `dc_wellfed_stage` LIKE `spell_dbc`;

-- One clone per tier. Each UPDATE frees id 300584 in the staging table again,
-- so the next INSERT has somewhere to land.
INSERT INTO `dc_wellfed_stage` SELECT * FROM `spell_dbc` WHERE `ID` = 300584;
UPDATE `dc_wellfed_stage` SET `ID` = 300588 WHERE `ID` = 300584;
INSERT INTO `dc_wellfed_stage` SELECT * FROM `spell_dbc` WHERE `ID` = 300584;
UPDATE `dc_wellfed_stage` SET `ID` = 300589 WHERE `ID` = 300584;
INSERT INTO `dc_wellfed_stage` SELECT * FROM `spell_dbc` WHERE `ID` = 300584;
UPDATE `dc_wellfed_stage` SET `ID` = 300590 WHERE `ID` = 300584;
INSERT INTO `dc_wellfed_stage` SELECT * FROM `spell_dbc` WHERE `ID` = 300584;
UPDATE `dc_wellfed_stage` SET `ID` = 300591 WHERE `ID` = 300584;

-- The shared Well Fed shape.
-- 🔴 AuraInterruptFlags MUST be cleared. The donor is a FOOD row carrying 262272
-- (cancel on standing / moving); inheriting that would make the buff vanish the
-- moment the player stood up, which is the opposite of a 15-minute food buff.
-- InterruptFlags and the food's Attributes are reset for the same reason --
-- 134217728 is the value stock Well Fed (24799) carries.
UPDATE `dc_wellfed_stage`
SET `Name_Lang_enUS`         = 'Well Fed',
    `Description_Lang_enUS`  = 'Increases all stats by $s1%.',
    `AuraInterruptFlags`     = 0,
    `InterruptFlags`         = 0,
    `Attributes`             = 134217728,
    `SpellIconID`            = 59,
    `DurationIndex`          = 347,
    `Effect_1`               = 6,
    `EffectAura_1`           = 137,
    `EffectDieSides_1`       = 1,
    `EffectMiscValue_1`      = -1,
    `EffectAuraPeriod_1`     = 0,
    `ImplicitTargetA_1`      = 1,
    `Effect_2`               = 0,
    `EffectAura_2`           = 0,
    `EffectBasePoints_2`     = 0,
    `EffectDieSides_2`       = 0,
    `EffectAuraPeriod_2`     = 0,
    `EffectTriggerSpell_2`   = 0,
    `EffectMiscValue_2`      = 0,
    `ImplicitTargetA_2`      = 0
WHERE `ID` BETWEEN 300588 AND 300591;

-- Per-tier percentage. basePoints = percent - 1 (CalcValue adds the 1 back).
UPDATE `dc_wellfed_stage` SET `EffectBasePoints_1` = 1, `SpellLevel` = 80,  `BaseLevel` = 80  WHERE `ID` = 300588;
UPDATE `dc_wellfed_stage` SET `EffectBasePoints_1` = 2, `SpellLevel` = 95,  `BaseLevel` = 95  WHERE `ID` = 300589;
UPDATE `dc_wellfed_stage` SET `EffectBasePoints_1` = 3, `SpellLevel` = 110, `BaseLevel` = 110 WHERE `ID` = 300590;
UPDATE `dc_wellfed_stage` SET `EffectBasePoints_1` = 4, `SpellLevel` = 125, `BaseLevel` = 125 WHERE `ID` = 300591;

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 300588 AND 300591;
INSERT INTO `spell_dbc` SELECT * FROM `dc_wellfed_stage`;
DROP TABLE `dc_wellfed_stage`;

-- ---------------------------------------------------------------------------
-- 3. Point the four feasts at their Well Fed buff
-- ---------------------------------------------------------------------------
-- `ID + 4` maps 300584->300588, 300585->300589, 300586->300590, 300587->300591.
UPDATE `spell_dbc`
SET `Effect_2`             = 6,
    `EffectAura_2`         = 23,      -- PERIODIC_TRIGGER_SPELL
    `EffectAuraPeriod_2`   = 10000,   -- eat 10s to earn it, as retail does
    `EffectDieSides_2`     = 1,
    `EffectBasePoints_2`   = 0,
    `EffectMiscValue_2`    = 0,
    `ImplicitTargetA_2`    = 1,
    `EffectTriggerSpell_2` = `ID` + 4
WHERE `ID` BETWEEN 300584 AND 300587;

-- ---------------------------------------------------------------------------
-- 4. Make the four tiers mutually exclusive
-- ---------------------------------------------------------------------------
-- stack_rule 4 = SPELL_GROUP_STACK_RULE_EXCLUSIVE_HIGHEST (SpellMgr.h) -- only
-- the strongest applies. Group 3000 is free (highest existing is 1126).
DELETE FROM `spell_group_stack_rules` WHERE `group_id` = 3000;
DELETE FROM `spell_group` WHERE `id` = 3000;

INSERT INTO `spell_group` (`id`, `spell_id`) VALUES
(3000, 300588),
(3000, 300589),
(3000, 300590),
(3000, 300591);

INSERT INTO `spell_group_stack_rules` (`group_id`, `stack_rule`, `description`) VALUES
(3000, 4, 'DC Frontier Well Fed - only the highest tier applies');

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- The four Well Fed spells exist and are percentage-based (expect 4 rows, aura
-- 137, misc -1, basePoints 1/2/3/4, duration 347, AuraInterruptFlags 0):
-- SELECT ID, Name_Lang_enUS, EffectAura_1, EffectBasePoints_1, EffectMiscValue_1,
--        DurationIndex, AuraInterruptFlags, Attributes
-- FROM spell_dbc WHERE ID BETWEEN 300588 AND 300591 ORDER BY ID;
--
-- 🔴 The feasts must now trigger them (expect trigger = ID + 4 on all four, and
-- aura 23 with period 10000 -- a row still showing Effect_2 = 64 means section 3
-- did not run):
-- SELECT ID, Effect_2, EffectAura_2, EffectAuraPeriod_2, EffectTriggerSpell_2
-- FROM spell_dbc WHERE ID BETWEEN 300584 AND 300587 ORDER BY ID;
--
-- Drink script bound (expect 4):
-- SELECT COUNT(*) FROM spell_script_names WHERE ScriptName = 'spell_dc_frontier_drink';
--
-- Exclusivity in place (expect 4 group rows + 1 rule row with stack_rule 4):
-- SELECT * FROM spell_group WHERE id = 3000;
-- SELECT * FROM spell_group_stack_rules WHERE group_id = 3000;
--
-- 🔴 The staging table must be gone (expect 0 -- if it survived, the run stopped
-- part-way and spell_dbc may hold an incomplete set):
-- SELECT COUNT(*) FROM information_schema.TABLES
-- WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_wellfed_stage';
--
-- IN GAME, after the rebuild + restart:
--   * drink any Frontier drink -> mana must actually tick up. Before this it
--     played the animation and restored nothing, so "the bar moves" is the test.
--   * eat a stew/feast for 10+ seconds -> "Well Fed" appears, 15 min, +2..5% all
--     stats, and it must SURVIVE STANDING UP (that is the AuraInterruptFlags
--     check).
--   * eat a lower-tier feast while a higher Well Fed is up -> the higher one
--     must stay; they must never both show.
--
-- 🔴 On the client the buff needs its Spell.dbc row or it appears with no icon
-- and no tooltip. Rows for 300588-300591 go into `Custom/CSV DBC/Spell.csv` and
-- Spell.dbc is redeployed with this change.
-- ---------------------------------------------------------------------------
