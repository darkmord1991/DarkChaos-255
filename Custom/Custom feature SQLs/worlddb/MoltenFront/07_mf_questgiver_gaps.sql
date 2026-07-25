-- =====================================================================
-- Molten Front -- 07  Post-apply gap fixes (questgivers in excluded phases + loot)
-- ---------------------------------------------------------------------
-- Found by a live DB audit after 01-04 were applied.
--
-- GAP 1 -- two quest ENDERS live in phases the curated snapshot excludes.
-- 02's curation keeps phaseMask IN (2047,8,16,128); these two are in phase 12
-- and phase 1, so 01 never cloned their templates and 03 could not wire their
-- questender rows (its guard requires the +3,600,000 clone to exist). Result:
--   29206 "Into the Fire"      -- startable, NOT turn-in-able
--   29210 "Enduring the Heat"  -- startable, NOT turn-in-able
-- Both DO have enders in cata_world (Thisalee Crow 52444 / Theresa Barkskin
-- 52823+52825), so this is a curation side-effect, not missing source data.
-- Fixed by explicitly cloning + spawning those 3 entries regardless of phase.
--
-- GAP 2 -- two creatures on 861 have a lootid whose loot table came out EMPTY,
-- because 01's loot clone drops rows whose item does not exist in item_template
-- and every row for these two was dropped:
--   3652981 Cinderweb Spinner (lootid 52981), 3652680 Cinderling (lootid 52680)
-- Re-cloned from cata_world (richer: 323 / 4 source rows) with the same
-- item-exists guard; if a table still ends up empty its lootid is zeroed so the
-- core stops logging "creature has lootid X but no loot".
--
-- Guid block 15,310,000+ -- deliberately OUTSIDE 02's delete range
-- (15,300,000-15,309,999) so re-running 02 cannot wipe these rows.
-- Idempotent. Run AFTER 01-04.
-- =====================================================================
SET @OFF := 3600000;
SET @IDS := '52444,52823,52825';

-- ---------------- templates (same nelt -> acore column map as 01) ----------------
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template WHERE FIND_IN_SET(entry, @IDS);

INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT entry+@OFF, idx, mid, scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@IDS) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@IDS) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@IDS) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE FIND_IN_SET(entry,@IDS) AND modelid4>0
) m;

INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text WHERE FIND_IN_SET(entry,@IDS);

-- ---------------- spawns (map 861, phaseMask forced to 1) ----------------
DELETE FROM acore_world.creature WHERE guid BETWEEN 15310000 AND 15310099;
INSERT INTO acore_world.creature
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15310000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 861, 4925, 4925, 1, 1, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, GREATEST(c.spawntimesecs,120), c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'MoltenFront-QuestgiverGap'
FROM nelt_world.creature c
JOIN nelt_world.creature_template ct ON ct.entry=c.id
WHERE c.map=861 AND FIND_IN_SET(c.id,@IDS)
  AND (c.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);

-- ---------------- questender links (guarded by clone existence) ----------------
INSERT IGNORE INTO acore_world.creature_questender (`id`,`quest`)
SELECT e.id+@OFF, e.quest FROM cata_world.creature_questender e
WHERE e.quest IN (29206,29210) AND (e.id+@OFF) IN (SELECT entry FROM acore_world.creature_template);

-- ---------------- GAP 2: loot backfill from cata_world ----------------
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.Entry, lt.Item, lt.Reference, lt.Chance, lt.QuestRequired, lt.LootMode, lt.GroupId, lt.MinCount, lt.MaxCount
FROM cata_world.creature_loot_template lt
WHERE lt.Entry IN (52981,52680)
  AND (lt.Reference>0 OR lt.Item IN (SELECT entry FROM acore_world.item_template));

-- if a table is still empty, clear the lootid so the core stops erroring
UPDATE acore_world.creature_template ct SET ct.lootid=0
WHERE ct.entry IN (3652981,3652680)
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature_loot_template lt WHERE lt.Entry=ct.lootid);
