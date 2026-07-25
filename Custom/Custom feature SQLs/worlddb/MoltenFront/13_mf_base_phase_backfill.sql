-- =====================================================================
-- Molten Front -- 13  BASE-PHASE backfill (phaseMask=1) + uncompletable dailies
-- ---------------------------------------------------------------------
-- BUG FOUND FROM A FRESH BOOT LOG (2026-07-25). Errors.log reported seven
-- Molten Front dailies as flatly uncompletable:
--     Quest 29128 The Protectors of Hyjal    RequiredNpcOrGo1 52300
--     Quest 29137 Breach in the Defenses     RequiredNpcOrGo1 52633
--     Quest 29139 Aggressive Growth          RequiredNpcOrGo1 53107
--     Quest 29142 Traitors Return            RequiredNpcOrGo1 54343
--     Quest 29179 Hostile Elements           RequiredNpcOrGo1 52504
--     Quest 29192 The Wardens are Watching   RequiredNpcOrGo1 52815
--     Quest 29263 A Bitter Pill              RequiredNpcOrGo1 53112
--   ("...but creature with entry N does not exist, quest can't be done.")
--
-- ROOT CAUSE -- a curation hole in 01_/02_. Both files are self-deriving off
-- `phaseMask IN (2047,8,16,128)`. That set deliberately picks the fully-unlocked
-- campaign phases, but it OMITS **phaseMask = 1**, which in retail is the
-- always-visible BASE phase -- not a campaign stage at all. So the Molten Front's
-- permanent population was never ported:
--     source map-861 spawns at phaseMask=1 : 185 across 17 entries
--     of those already present here        :  50 across  7 entries (via other passes)
--     MISSING                             : 135 across 10 entries
-- Two of the ten are the kill targets of quests 29137 and 29179, which is why
-- those dailies could never tick. Overall 1,188 of the source's 1,760 map-861
-- spawns had been ported; this file adds the base-phase 135.
--
-- The ten un-cloned base-phase entries (raw id -> +3,600,000):
--     52504 Charred Soldier            43 spawns   <- quest 29179 target
--     52500 Hyjal Defender             27
--     52834 Wounded Hyjal Defender     23
--     75180 Wondi's Bunny (Smoothvine) 14
--     52633 Lava Burster               13          <- quest 29137 target
--     52503 Charred Vanquisher          9
--     53327 Druid of the Talon          3
--     52822 Zen'Vorka                   1
--     52135 Malfurion Stormrage         1
--     53080 Captain Irontree            1
--
-- Four more quest objectives are SUMMON/CREDIT-only NPCs (zero spawns in the
-- source too), so they need their template cloned but have nothing to place:
--     52300 Seething Pyrelord (source spawns are on map 1, not 861)
--     52815 Captured Druid of the Flame Kill Credit (credit proxy, no model use)
--     53107 Smothervine        (summoned)
--     53112 Subterranean Magma Worm (summoned)
-- 54343 Druid of the Flame (quest 29142) is ALREADY cloned as 3654343, so it only
-- needs the quest pointer moved.
--
-- Conventions copied verbatim from 01_/02_ so this stays consistent:
--   * column map = HyjalCata/29 (faction_A->faction, dmg_multiplier->DamageModifier,
--     Health_mod/Mana_mod/Armor_mod->*Modifier, speed_fly->speed_flight, LEAST(exp,2))
--   * `lootid` is copied UNOFFSET and the loot table is keyed by the RAW id -- that
--     is the dominant live convention for map 861 (16 of the 17 looted clones), not
--     an oversight.
--   * spawns land on map 861 / zone+area 4925 with phaseMask forced to 1.
--   * guid block 15,340,000+ (verified empty; 02_ uses 15,300,000+, 07_ 15,310,000+,
--     HyjalCata/102_ 15,320,000+, 08_ GOs 15,330,000+).
--
-- Idempotent (INSERT IGNORE on templates, delete-then-insert on the guid block,
-- value-guarded UPDATEs on the quests). Needs a worldserver restart.
-- =====================================================================
SET @OFF := 3600000;

-- Entry set used by every template-side INSERT below: the base-phase spawns plus
-- the four summon/credit-only quest objectives.
--   (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1)
--   UNION the literals 52300,52815,53107,53112

-- =========================== CREATURE TEMPLATES ======================
INSERT IGNORE INTO acore_world.creature_template
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1)
   OR entry IN (52300,52815,53107,53112);

-- ---- display models ----
INSERT IGNORE INTO acore_world.creature_template_model (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT entry+@OFF, idx, mid, scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND modelid4>0
) m;

-- ---- movement (flight/swim capability from InhabitType) ----
INSERT IGNORE INTO acore_world.creature_template_movement (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`)
SELECT entry+@OFF, 1, (InhabitType&2)>0, IF((InhabitType&4)>0,1,0), 0, 0, 0, 0
FROM nelt_world.creature_template
WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112))
  AND (InhabitType&4)>0;

-- ---- template spells ----
INSERT IGNORE INTO acore_world.creature_template_spell (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`)
SELECT entry+@OFF, idx, sp, 0 FROM (
  SELECT entry, 0 idx, spell1 sp FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell1>0
  UNION ALL SELECT entry, 1, spell2 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell2>0
  UNION ALL SELECT entry, 2, spell3 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell3>0
  UNION ALL SELECT entry, 3, spell4 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell4>0
  UNION ALL SELECT entry, 4, spell5 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell5>0
  UNION ALL SELECT entry, 5, spell6 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell6>0
  UNION ALL SELECT entry, 6, spell7 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell7>0
  UNION ALL SELECT entry, 7, spell8 FROM nelt_world.creature_template WHERE (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1) OR entry IN (52300,52815,53107,53112)) AND spell8>0
) s;

-- ---- loot (keyed by the RAW lootid, matching the live map-861 convention) ----
-- Only items that actually exist here are carried over, and reference rows
-- (mincountOrRef<0) always pass, exactly as 01_ does.
INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry IN (
        SELECT lootid FROM nelt_world.creature_template
        WHERE lootid>0
          AND (entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1)
               OR entry IN (52300,52815,53107,53112)))
  AND (lt.mincountOrRef<0 OR lt.item IN (SELECT entry FROM acore_world.item_template));

-- ---- creature_text ----
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text
WHERE entry IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1)
   OR entry IN (52300,52815,53107,53112);

-- ---- SmartAI ----
-- NOTE: cloned verbatim like 01_ does. Some Cata SmartAI rows carry RAW creature/
-- waypoint/spell ids in their event or action params, which this offset scheme does
-- not rewrite; those surface as "non-existent Text/WaypointPath/Spell" boot warnings
-- and are cleaned up per-case (see 09_ and the notes at the bottom of this file).
INSERT IGNORE INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT entryorguid+@OFF, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_x, target_y, target_z, target_o, comment
FROM nelt_world.smart_scripts
WHERE source_type=0 AND entryorguid>0
  AND (entryorguid IN (SELECT DISTINCT id FROM nelt_world.creature WHERE map=861 AND phaseMask=1)
       OR entryorguid IN (52300,52815,53107,53112));

-- =========================== BASE-PHASE SPAWNS ========================
-- 135 spawns: every source map-861 phaseMask=1 spawn whose clone is not already
-- placed. The NOT EXISTS guard keeps the 50 already-ported ones from doubling up.
DELETE FROM acore_world.creature WHERE guid BETWEEN 15340000 AND 15349999;

INSERT INTO acore_world.creature
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15340000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 861, 4925, 4925, 1, 1, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, GREATEST(c.spawntimesecs,120), c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'MoltenFront-BasePhase'
FROM nelt_world.creature c
JOIN nelt_world.creature_template ct ON ct.entry = c.id
WHERE c.map=861 AND c.phaseMask=1
  AND NOT EXISTS (SELECT 1 FROM acore_world.creature a
                  WHERE a.id = c.id + @OFF AND a.map = 861);

-- =========================== QUEST OBJECTIVE OFFSETS ==================
-- Same defect class (and same fix) as HyjalCata/116_: the quest import copied
-- objectives across un-offset, so they name raw Cata ids while every live
-- credit-giver is the +3,600,000 clone. Guarded on the exact current value AND on
-- the clone existing, so it cannot point a quest at a missing entry and is safe to
-- re-run.
UPDATE `quest_template` q SET q.`RequiredNpcOrGo1` = q.`RequiredNpcOrGo1` + 3600000
WHERE q.`ID` IN (29128,29137,29139,29142,29179,29192,29263)
  AND q.`RequiredNpcOrGo1` IN (52300,52633,53107,54343,52504,52815,53112)
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = q.`RequiredNpcOrGo1` + 3600000);

-- ---------------------------------------------------------------------
-- AFTER-APPLY EXPECTATIONS / REMAINING CAVEATS
--
-- * 29137 (Lava Burster) and 29179 (Charred Soldier) become fully completable:
--   their targets are now cloned AND spawned on map 861.
-- * 29139 / 29142 / 29263 target SUMMONED creatures (Smothervine, Druid of the
--   Flame, Subterranean Magma Worm). The objective now resolves to a real entry,
--   but completability still depends on whatever summons them -- verify in-world
--   and, if a summoner passes a raw id, fix that summoner the same way.
-- * 29192 targets a pure kill-CREDIT proxy (52815). It ticks only when something
--   calls KilledMonsterCredit on 3652815; confirm the Shadow Warden capture
--   script/SmartAI does so.
-- * 29128 (Seething Pyrelord) is a Hyjal-proper mob: its source spawns are on
--   map 1, so nothing is placed here. The objective is now valid; if the daily
--   should be doable, the Pyrelord needs spawning in the map-750 Hyjal content.
-- * Alternate campaign phases are still intentionally NOT ported (phaseMask 2:
--   148 spawns, 4: 148, 16384: 50, 96: 34, 512: 17, 13: 15, plus ~40 stragglers
--   = ~437). Those are progression variants of the same camps and would
--   double-spawn against the fully-unlocked set this zone ships. Left out on
--   purpose, recorded here so the count is never mistaken for an omission.
-- ---------------------------------------------------------------------
