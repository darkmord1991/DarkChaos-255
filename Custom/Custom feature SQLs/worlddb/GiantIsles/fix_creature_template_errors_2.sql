-- =============================================================================
-- Giant Isles & Hinterland BG — Creature Template Error Fixes (Batch 2)
-- Addresses startup warnings from the second error batch:
--   1. Entry 400321: deprecated IMMUNITY_KNOCKBACK (0x40000000) in flags_extra
--      + speed_walk / speed_run both zero (clamped to minimum by server)
--   2. Entries 400100–400102 (world bosses): CREATURE_FLAG_EXTRA_INSTANCE_BIND
--      (0x80) set on open-world map 1405 — not an instance, flag is wrong
--   3. Missing creature_template for orphaned model/equip/addon rows:
--      400201 (Witch Doctor Tala'jin), 400211 (Armsmaster Jin'kala),
--      400221 (Zandalari Beast Handler), 400301 (Corrupted Direhorn Spirit)
--   4. Missing creature_template_model for kill-credit entries that are never
--      visually spawned: 400339, 920102, 920103
--   5. pickpocketloot references with no matching pickpocketing_loot_template
--      rows: 400500–400505, 400510–400513, 400520–400521
--   6. skinloot reference with no matching skinning_loot_template: 400523
-- =============================================================================

-- 1. Entry 400321 (Coastal Cannon): remove deprecated IMMUNITY_KNOCKBACK flag
--    (0x40000000).  Remaining flags_extra=2 keeps the civilian-passable bit.
--    Also fix speed_walk=0 / speed_run=0 — the server clamps both to 1 / 1.14286
--    on load; setting the correct values removes the silent clamp.
UPDATE `creature_template`
SET `speed_walk` = 1, `speed_run` = 1.14286, `flags_extra` = 2
WHERE `entry` = 400321;

-- 2. World bosses 400100–400102: remove CREATURE_FLAG_EXTRA_INSTANCE_BIND (0x80)
--    and CREATURE_FLAG_EXTRA_CIVILIAN (0x01).  Both flags are wrong for
--    open-world outdoor bosses on map 1405 (Giant Isles).
UPDATE `creature_template`
SET `flags_extra` = 0
WHERE `entry` IN (400100, 400101, 400102);

-- 3. Add missing creature_template rows for entries that already have model,
--    equip and (in the case of 400301) addon rows in giant_isles_creatures.sql
--    but were never given a matching template row.

DELETE FROM `creature_template` WHERE `entry` IN (400201, 400211, 400221, 400301);
INSERT INTO `creature_template`
(`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,
 `KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,
 `minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
 `speed_walk`,`speed_run`,`rank`,`dmgschool`,
 `BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,
 `unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,
 `lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
 `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
 `HealthModifier`,`ManaModifier`,`ArmorModifier`,`DamageModifier`,`ExperienceModifier`,
 `RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
-- 400201: female caster companion NPC (carries tribal wand, defined in equip_template)
(400201,0,0,0,0,0,'Witch Doctor Tala\'jin','Zandalari Witch Doctor','Speak',400001,
 80,80,2,35,3,
 1,1.14286,0,0,
 2000,2000,1,1,
 2,768,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',0,1,
 10,5,1,1,1,
 0,0,1,2,'',12340),
-- 400211: male warrior trainer NPC (dual axes, defined in equip_template)
(400211,0,0,0,0,0,'Armsmaster Jin\'kala','Zandalari Armsmaster','Speak',400011,
 80,80,2,35,3,
 1,1.14286,0,0,
 2000,2000,1,1,
 1,768,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',0,1,
 8,1,1,1,1,
 0,0,1,2,'',12340),
-- 400221: beast-handler companion guard (axe + crossbow, defined in equip_template)
(400221,0,0,0,0,0,'Zandalari Beast Handler',NULL,NULL,0,
 81,81,2,35,3,
 1.2,1.28571,1,0,
 2000,2000,1,1,
 1,32832,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',1,1,
 15,1,1.5,7,1,
 0,0,1,0,'',12340),
-- 400301: corrupted primal direhorn spirit — hostile shadow-damaged elite beast
(400301,0,0,0,0,0,'Corrupted Direhorn Spirit',NULL,NULL,0,
 81,81,2,14,0,
 1.2,1.14286,1,4,
 2000,2000,1,1,
 1,32832,2048,0,0,1,0,
 0,0,0,0,0,
 1500,2500,'',1,1,
 100,1,2,12,1,
 0,0,1,128,'',12340);

-- 4. Add creature_template_model rows for kill-credit creatures.
--    These are never physically spawned; display 11686 (Invisible Stalker)
--    satisfies the FK without making the NPC visible.

DELETE FROM `creature_template_model` WHERE `CreatureID` = 400339;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
    (400339, 0, 11686, 1, 1, 12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (920102, 920103);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
    (920102, 0, 11686, 1, 1, 12340),
    (920103, 0, 11686, 1, 1, 12340);

-- 5. Null out pickpocketloot for temple creatures that reference loot IDs with
--    no matching rows in pickpocketing_loot_template.
UPDATE `creature_template`
SET `pickpocketloot` = 0
WHERE `entry` IN (400500, 400501, 400502, 400504, 400505,
                  400510, 400511, 400512, 400513,
                  400520, 400521);

-- 6. Null out skinloot for the Eranikus dragon boss whose skinning loot table
--    was never populated.
UPDATE `creature_template`
SET `skinloot` = 0
WHERE `entry` = 400523;
