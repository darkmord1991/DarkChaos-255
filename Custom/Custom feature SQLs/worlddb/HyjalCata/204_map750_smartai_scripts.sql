-- ---------------------------------------------------------------------------
-- 204  Map 750 -- restore the SmartAI behaviour the creature imports dropped
-- ---------------------------------------------------------------------------
-- Live Errors.log:
--     "Creature entry (3733071) has SmartAI enabled but no SmartAI entries in
--      the database."  x102
--
-- 181_/183_/184_ copied `creature_template.AIName = 'SmartAI'` from cata_world
-- but never the `smart_scripts` rows, so 102 creatures declare an AI and then
-- have no behaviour at all. Every one of the 102 HAS a script in cata_world, so
-- these are restored rather than silenced by clearing the flag (which is what
-- 186_ had to do for the one entry whose source script genuinely did not exist).
--
-- APPLY 203_ FIRST. Those scripts contain 156 CAST actions over 117 spells, 45
-- of which did not exist here; importing the scripts without the spells just
-- trades one error for a stream of "unknown spell" ones.
--
-- ---------------------------------------------------------------------------
-- THREE ID CLASSES ARE REMAPPED -- a raw copy would be subtly wrong
-- ---------------------------------------------------------------------------
--  1. `entryorguid` (source_type 0)  +3,700,000   -- the creature itself.
--  2. action_type 33 KILL_CREDIT     +3,700,000   -- action_param1 is a
--     CREATURE entry. Copied raw it would credit the Kalimdor original, which
--     does not exist on map 750, and the quest objective would never tick.
--     Affects entries 47365 and 48227 in the creature scripts, and 47555
--     inside action list 4755600.
--  3. action_type 80 CALL_TIMED_ACTIONLIST  +370,000,000  -- action_param1 is
--     an action-list id, and this core numbers lists as entry x 100. Since the
--     creature moves by +3,700,000, its lists move by +370,000,000, which also
--     preserves the sub-index (3410300..3410304 -> 373410300..373410304 stay
--     distinct). Verified: the 10 resulting ids collide with NOTHING, and the
--     existing 370M-band lists already follow the same convention.
--
-- Checked and NOT present in this batch, so not remapped: action_type 12
-- (SUMMON_CREATURE), nested action lists inside the lists themselves, and any
-- quest or gameobject id. The only summon in the whole set is inside spell
-- 75097, handled in 203_.
--
-- NOTE the DELETEs below are scoped to exact entryorguid values. source_type 9
-- must NEVER be range-deleted -- action lists from unrelated creatures share
-- the same numeric space.
--
-- Apply against acore_world AFTER 203_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Tamed Crawler (3740271) -- the creature spell 75097 summons
-- ---------------------------------------------------------------------------
-- Referenced only through that spell, so it has no spawn of its own and no
-- earlier import saw it.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 3740271;

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,
     `unit_flags2`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,
     `DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, 0, 0, 0, 0,
       s.`name`, s.`subname`, s.`IconName`, s.`gossip_menu_id`, s.`minlevel`, s.`maxlevel`, s.`faction`,
       COALESCE(s.`npcflag`, 0), s.`speed_walk`, s.`speed_run`, s.`rank`, s.`dmgschool`,
       s.`BaseAttackTime`, s.`RangeAttackTime`, s.`BaseVariance`, s.`RangeVariance`, s.`unit_class`,
       COALESCE(s.`unit_flags`, 0), s.`unit_flags2`, s.`family`, s.`type`, s.`type_flags`,
       0, 0, 0, s.`PetSpellDataId`, s.`VehicleId`, s.`mingold`, s.`maxgold`, '', s.`MovementType`,
       s.`HoverHeight`, s.`HealthModifier`, s.`ManaModifier`, s.`ArmorModifier`, s.`DamageModifier`,
       s.`ExperienceModifier`, s.`RacialLeader`, s.`movementId`, s.`RegenHealth`, s.`flags_extra`, '', s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` = 40271;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3740271;

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, s.`modelid1`, 1, 1, s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` = 40271 AND s.`modelid1` > 0;

-- ---------------------------------------------------------------------------
-- B) smart_scripts source_type 0 -- the 102 creature scripts
-- ---------------------------------------------------------------------------
-- The 102 entry ids are PINNED as a literal. Computing them live with a
-- NOT EXISTS would have been a trap: the same predicate feeds the DELETE and
-- the INSERT, and dropping the guard widens the set to 260 entries / 591 rows,
-- silently REPLACING scripts that already work -- including any hand-authored
-- or previously repaired ones. Pinning also keeps the file re-runnable.
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (
  3703694, 3703812, 3703841, 3724042, 3732855, 3732858, 3732859, 3732860,
  3732861, 3732862, 3732863, 3732868, 3732869, 3732888, 3732890, 3732899,
  3732928, 3732935, 3732969, 3732970, 3732985, 3732988, 3732989, 3732990,
  3732996, 3732999, 3733009, 3733020, 3733021, 3733022, 3733041, 3733043,
  3733044, 3733057, 3733071, 3733079, 3733083, 3733084, 3733091, 3733107,
  3733115, 3733117, 3733127, 3733179, 3733180, 3733206, 3733207, 3733262,
  3733277, 3733311, 3733345, 3733359, 3733864, 3733905, 3733978, 3733981,
  3734033, 3734041, 3734046, 3734103, 3734248, 3734282, 3734302, 3734304,
  3734306, 3734309, 3734318, 3734326, 3734339, 3734385, 3734405, 3734413,
  3734414, 3734415, 3734417, 3734423, 3743073, 3747339, 3747341, 3747369,
  3747398, 3747439, 3747556, 3747601, 3747675, 3747679, 3747692, 3747696,
  3747842, 3748038, 3748154, 3748258, 3748259, 3748315, 3748331, 3748332,
  3748344, 3748453, 3748455, 3748456, 3748556, 3748574);

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT c.`entryorguid` + 3700000, c.`source_type`, c.`id`, c.`link`, c.`event_type`, c.`event_phase_mask`,
       c.`event_chance`, c.`event_flags`,
       c.`event_param1`, c.`event_param2`, c.`event_param3`, c.`event_param4`, c.`event_param5`,
       c.`action_type`,
       CASE c.`action_type`
         WHEN 33 THEN c.`action_param1` + 3700000      -- KILL_CREDIT: creature entry
         WHEN 80 THEN c.`action_param1` + 370000000    -- CALL_TIMED_ACTIONLIST: list id
         ELSE c.`action_param1`
       END,
       c.`action_param2`, c.`action_param3`, c.`action_param4`, c.`action_param5`, c.`action_param6`,
       c.`target_type`, c.`target_param1`, c.`target_param2`, c.`target_param3`,
       c.`target_x`, c.`target_y`, c.`target_z`, c.`target_o`, c.`comment`
FROM `cata_world`.`smart_scripts` c
WHERE c.`source_type` = 0
  AND c.`entryorguid` IN (
  3694, 3812, 3841, 24042, 32855, 32858, 32859, 32860,
  32861, 32862, 32863, 32868, 32869, 32888, 32890, 32899,
  32928, 32935, 32969, 32970, 32985, 32988, 32989, 32990,
  32996, 32999, 33009, 33020, 33021, 33022, 33041, 33043,
  33044, 33057, 33071, 33079, 33083, 33084, 33091, 33107,
  33115, 33117, 33127, 33179, 33180, 33206, 33207, 33262,
  33277, 33311, 33345, 33359, 33864, 33905, 33978, 33981,
  34033, 34041, 34046, 34103, 34248, 34282, 34302, 34304,
  34306, 34309, 34318, 34326, 34339, 34385, 34405, 34413,
  34414, 34415, 34417, 34423, 43073, 47339, 47341, 47369,
  47398, 47439, 47556, 47601, 47675, 47679, 47692, 47696,
  47842, 48038, 48154, 48258, 48259, 48315, 48331, 48332,
  48344, 48453, 48455, 48456, 48556, 48574);

-- ---------------------------------------------------------------------------
-- C) smart_scripts source_type 9 -- the 10 timed action lists (41 rows)
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (
  373403300, 373404100, 373410300, 373410301, 373410302, 373410303, 373410304,
  374755600, 374769200, 374825800);

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT l.`entryorguid` + 370000000, l.`source_type`, l.`id`, l.`link`, l.`event_type`, l.`event_phase_mask`,
       l.`event_chance`, l.`event_flags`,
       l.`event_param1`, l.`event_param2`, l.`event_param3`, l.`event_param4`, l.`event_param5`,
       l.`action_type`,
       CASE l.`action_type`
         WHEN 33 THEN l.`action_param1` + 3700000      -- KILL_CREDIT inside a list (47555)
         WHEN 80 THEN l.`action_param1` + 370000000    -- defensive: no nested lists in this batch
         ELSE l.`action_param1`
       END,
       l.`action_param2`, l.`action_param3`, l.`action_param4`, l.`action_param5`, l.`action_param6`,
       l.`target_type`, l.`target_param1`, l.`target_param2`, l.`target_param3`,
       l.`target_x`, l.`target_y`, l.`target_z`, l.`target_o`, l.`comment`
FROM `cata_world`.`smart_scripts` l
WHERE l.`source_type` = 9
  AND l.`entryorguid` IN (3403300, 3404100, 3410300, 3410301, 3410302, 3410303, 3410304,
                          4755600, 4769200, 4825800);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(DISTINCT entryorguid) FROM smart_scripts
--    WHERE source_type=0 AND entryorguid BETWEEN 3700000 AND 3799999;      -- >= 102
--   SELECT COUNT(*) FROM smart_scripts WHERE source_type=9 AND entryorguid IN
--     (373403300,373404100,373410300,373410301,373410302,373410303,373410304,
--      374755600,374769200,374825800);                                     -- 41
--
--   -- every CALL_TIMED_ACTIONLIST resolves to a list that exists (expect 0):
--   SELECT COUNT(*) FROM smart_scripts s
--    WHERE s.entryorguid BETWEEN 3700000 AND 3799999 AND s.source_type=0
--      AND s.action_type=80
--      AND NOT EXISTS (SELECT 1 FROM smart_scripts l
--                       WHERE l.source_type=9 AND l.entryorguid=s.action_param1);
--
--   -- every KILL_CREDIT points at a creature that exists here (expect 0):
--   SELECT COUNT(*) FROM smart_scripts s
--    WHERE s.action_type=33 AND s.entryorguid BETWEEN 3700000 AND 3799999
--      AND NOT EXISTS (SELECT 1 FROM creature_template t WHERE t.entry=s.action_param1);
--
--   -- no creature declares SmartAI without rows (expect 0):
--   SELECT COUNT(*) FROM creature_template t
--    WHERE t.entry BETWEEN 3600000 AND 3799999 AND t.AIName='SmartAI'
--      AND NOT EXISTS (SELECT 1 FROM smart_scripts s
--                       WHERE s.entryorguid=t.entry AND s.source_type=0);
--
-- Errors.log should gain no further "has SmartAI enabled but no SmartAI
-- entries" lines for the 3.7M range.
-- ---------------------------------------------------------------------------
