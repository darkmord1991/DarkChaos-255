-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone: the Lupine Spectre creature the summon
-- spell points at, and the entry remap that makes 94199 reach it.
--
-- Wolf Master Nandos casts SPELL_SUMMON_LUPINE_SPECTRE (94199) three times the moment
-- he arrives. The spell is a real SPELL_EFFECT_SUMMON and has been in `spell_dbc` since
-- 01_sfk_cata_spells.sql, but it summons nothing, for two reasons at once:
--
--   1. its EffectMiscValue_1 is 50923, the RAW RETAIL entry, and this clone lives in the
--      +5,000,000 band;
--   2. entry 50923 + 5,000,000 does not exist either -- the creature was never imported.
--
-- Fixing only (1) would just move the failure, which is why both are done here.
--
-- ---------------------------------------------------------------------------------
-- WHY IT WAS MISSED, AND THE ONE-LINE CHANGE THAT STOPS IT RECURRING
-- ---------------------------------------------------------------------------------
-- 03_templates.sql says it plainly: summoned adds "are NOT spawned -- the bosses create
-- them at runtime -- so they appear nowhere in `creature` and cannot be derived from
-- spawn data. The list therefore comes from the `SKCreatures` enum in sfk_cata.h and
-- must stay in step with it. Leaving them out is silent and total."
--
-- The Lupine Spectre was never in that enum, so it was never in the import set, so it
-- was never imported -- exactly the silent failure the comment warns about.
-- `NPC_LUPINE_SPECTRE` has been added to the enum alongside this file, so a re-run of
-- 03 picks the creature up on its own and this file becomes redundant rather than load-
-- bearing.
--
-- ---------------------------------------------------------------------------------
-- SOURCE AND SHAPE
-- ---------------------------------------------------------------------------------
-- Same cross-database INSERT ... SELECT as 03, same explicit column list, same forced
-- values (lootid / pickpocketloot / skinloot / movementId / ScriptName), for the same
-- reasons 03 gives: cata_world and acore_world disagree on both the column set and the
-- column order, so anything positional silently scrambles the row.
--
--   50923  Lupine Spectre       level 20, faction 16, beast, display 2446
--   50924  Lupine Spectre (1)   its heroic variant, linked via difficulty_entry_1
--
-- Both are pulled, because the core resolves the heroic creature through
-- difficulty_entry_1 at summon time -- importing only the base entry gives a normal-mode
-- spectre on heroic and mythic.
--
-- Display 2446 needs no work: it is already in this realm's `creature_model_info`, it is
-- already in the SERVER's CreatureDisplayInfo.dbc, and two other SFK templates already
-- use it. No new art, no DBC deploy.
--
-- REQUIRES 03_templates.sql (the band) and 22_sfk_summon_chain_spells.sql (the rest of
-- the chain). A worldserver restart is needed for the spell_dbc change: DBC stores are
-- loaded once at boot.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature_template
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (50923 + 5000000, 50924 + 5000000);

INSERT INTO `creature_template`
    (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
     `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`,
     `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`,
     `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`,
     `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
     `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`,
     `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
     t.entry + 5000000,
     IF(t.difficulty_entry_1 = 0, 0, t.difficulty_entry_1 + 5000000),
     IF(t.difficulty_entry_2 = 0, 0, t.difficulty_entry_2 + 5000000),
     IF(t.difficulty_entry_3 = 0, 0, t.difficulty_entry_3 + 5000000),
     t.KillCredit1, t.KillCredit2, t.name, t.subname, t.IconName, t.gossip_menu_id,
     t.minlevel, t.maxlevel, t.faction, t.npcflag, t.speed_walk, t.speed_run, t.rank,
     t.dmgschool, t.DamageModifier, t.BaseAttackTime, t.RangeAttackTime, t.BaseVariance,
     t.RangeVariance, t.unit_class, t.unit_flags, t.unit_flags2, t.family, t.type,
     t.type_flags, 0, 0, 0, t.PetSpellDataId, t.VehicleId,
     t.mingold, t.maxgold, t.AIName, t.MovementType, t.HoverHeight, t.HealthModifier,
     t.ManaModifier, t.ArmorModifier, t.ExperienceModifier, t.RacialLeader, 0,
     t.RegenHealth, t.flags_extra, '', t.VerifiedBuild
FROM `cata_world`.`creature_template` t
WHERE t.entry IN (50923, 50924);

-- -------------------------------------------------------------------------------------
-- 2. creature_template_model
--
-- Not optional. ObjectMgr refuses to load a creature that has no row here, and the error
-- it prints names only this table -- the same mistake that made the whole instance come
-- up empty the first time (see 11_creature_models.sql).
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (50923 + 5000000, 50924 + 5000000);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.CreatureID + 5000000, m.Idx, m.CreatureDisplayID, 1, m.Probability, m.VerifiedBuild
FROM `cata_world`.`creature_template_model` m
WHERE m.CreatureID IN (50923, 50924);

-- -------------------------------------------------------------------------------------
-- 3. Point the spell at the imported entry
--
-- Only now that the row exists. Scoped by id, so a re-run is a no-op.
-- -------------------------------------------------------------------------------------
UPDATE `spell_dbc` SET `EffectMiscValue_1` = 50923 + 5000000
WHERE `ID` = 94199 AND `Effect_1` = 28;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'Lupine Spectre templates imported (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (50923 + 5000000, 50924 + 5000000)
UNION ALL SELECT 'their creature_template_model rows (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (50923 + 5000000, 50924 + 5000000)
UNION ALL SELECT 'heroic variant linked from the base entry (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` = 50923 + 5000000 AND `difficulty_entry_1` = 50924 + 5000000
UNION ALL SELECT 'their display ids missing from creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` IN (50923 + 5000000, 50924 + 5000000) AND i.`DisplayID` IS NULL
UNION ALL SELECT 'spell 94199 now targets 5050923 (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `spell_dbc` WHERE `ID` = 94199 AND `EffectMiscValue_1` = 50923 + 5000000
UNION ALL SELECT 'SFK summon spells still pointing at a raw retail entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `spell_dbc` s LEFT JOIN `creature_template` c ON c.`entry` = s.`EffectMiscValue_1`
    WHERE s.`ID` IN (93858, 93860, 93895, 93897, 93922, 93923, 93926, 93929, 94199)
      AND s.`Effect_1` = 28 AND c.`entry` IS NULL
UNION ALL SELECT 'stock entries 50923/50924 touched (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (50923, 50924);
