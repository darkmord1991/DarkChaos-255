-- ---------------------------------------------------------------------------
-- 186  Felwood (map 750) -- wire up the Cata C++ layer + kill two dead cursors
-- ---------------------------------------------------------------------------
-- Follows the C++ survey of K:\Dark-Chaos\cata stuff (CataTC, M3ScriptDev3,
-- mangos-cata, Project-Neltharion) against everything actually spawned on map
-- 750. Result of that survey, recorded here because it is the reason this file
-- is short rather than long:
--
--   26 cata zone scripts reference ~220 distinct creature/spell ids.
--   Only NINE of those ids are creatures that actually spawn on map 750, and
--   seven of the nine are ALREADY ported and wired:
--     40409 Gromm'ko / 40412 Butcher ....... DC zone_mount_hyjal.cpp (grudge match)
--     40460 Activated Flameward ............ npc_activated_flameward
--     40573 (credit) / 40780 Emerald Drake . npc_emerald_drake_slash_burn
--     40185 Twilight Initiate .............. npc_graduation_speech_controller
--     75029 Flameward bunny ................ DC flameward system
--   Everything else in those files is unreachable, not missing: it drives the
--   Cata quest layer (quests, spellclick spells, vehicles, phasing) that was
--   never downported, so porting the C++ would produce dead code. The two
--   genuinely reachable gaps are both below.
--
-- BUG THIS FIXES -- two dead interact cursors. 181_/183_ imported the Cata
-- Felwood creatures faithfully, including npcflag 16777216 (SPELLCLICK). But
-- npc_spellclick_spells was never imported, so 42 spawns advertise a clickable
-- cursor that does absolutely nothing when clicked:
--     3747747 Whisperwind Lasher .... 20 spawns
--     3748457 Tainted Squirrel ...... 22 spawns
-- They are handled differently because only one of them can be made to work.
--
-- Apply against acore_world, then REBUILD worldserver (new C++ file). Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Corrupted Lasher (3748387) -- the SetEntry target the script morphs into
-- ---------------------------------------------------------------------------
-- npc_whisperwind_lasher turns ~30% of clicked lashers hostile via SetEntry.
-- The target template did not exist on our side (48387 has no spawns of its
-- own in cata_world, so the 181_/183_ spawn-driven import never picked it up),
-- which would have left SetEntry pointing at nothing.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 3748387;

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
WHERE s.`entry` = 48387;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3748387;

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, s.`modelid1`, 1, 1, s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` = 48387 AND s.`modelid1` > 0;

-- ---------------------------------------------------------------------------
-- B) The spellclick row that makes the lasher clickable for real
-- ---------------------------------------------------------------------------
-- Cata uses spell 89960 here. That id does NOT exist in 3.3.5 -- it is absent
-- from both the stock Spell.dbc and Custom/CSV DBC/Spell.csv -- and no Cata
-- spell source is available in the repo to downport it faithfully, so it is NOT
-- invented here. Spell 37752 "Stand" is used instead: it already exists both
-- server- and client-side, it is instant, self-range, a single
-- SPELL_EFFECT_SCRIPT_EFFECT with no aura and no base points, and it is
-- semantically exactly the interaction ("the lasher stands up"). No DBC change
-- and no client redistribution is needed.
--
-- cast_flags = 0 so the CREATURE is both caster and target (bit 0x01 would make
-- the clicking player the caster, 0x02 the target). user_type = 0
-- (SPELL_CLICK_USER_ANY) rather than cata's 1 (FRIEND): the lasher is faction
-- 35, friendly to everyone, so ANY is both correct and simpler.
--
-- This matters mechanically, not just cosmetically: Unit::HandleSpellClick only
-- reaches `creature->AI()->OnSpellClick(clicker, result)` with result = true
-- after a row actually casts, and the script returns early when result is
-- false. No row means the AI hook can never fire.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 3747747;

INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`) VALUES
(3747747, 37752, 0, 0);

-- ---------------------------------------------------------------------------
-- C) Wire the script
-- ---------------------------------------------------------------------------
-- AIName is cleared at the same time. 181_ carried cata's AIName='SmartAI'
-- across, but the matching smart_scripts rows were never imported (verified: 0
-- rows for entryorguid 3747747, source_type 0), so it was a dangling shell.
-- ScriptName wins over AIName in FactorySelector::SelectAI either way, but
-- leaving a SmartAI with no script rows is just noise.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `ScriptName` = 'npc_whisperwind_lasher', `AIName` = ''
 WHERE `entry` = 3747747;

-- ---------------------------------------------------------------------------
-- D) Tainted Squirrel (3748457) -- remove the cursor instead
-- ---------------------------------------------------------------------------
-- The opposite verdict, for the opposite reason. Cata's spellclick spell here
-- is 90102, which likewise does not exist in 3.3.5 -- but unlike the lasher
-- there is NO script for 48457 in any of the four cata sources, because in
-- Cata the spell itself does all the work (quest credit). With neither the
-- spell nor the quest downported there is nothing for a click to do, so the
-- honest fix is to stop advertising one: 22 squirrels currently show an
-- interact cursor that is guaranteed to do nothing.
--
-- 16777216 = UNIT_NPC_FLAG_SPELLCLICK. Only that bit is cleared; any other
-- npcflag bits on the template survive.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `npcflag` = `npcflag` & ~16777216
 WHERE `entry` = 3748457;

-- ---------------------------------------------------------------------------
-- Verification after applying + worldserver rebuild:
--   -- both templates present, lasher scripted, squirrel no longer clickable:
--   SELECT entry, name, npcflag, AIName, ScriptName FROM creature_template
--    WHERE entry IN (3747747,3748387,3748457);
--     -- 3747747 npcflag 16777216, AIName '', ScriptName npc_whisperwind_lasher
--     -- 3748387 Corrupted Lasher, faction 14
--     -- 3748457 npcflag 0
--
--   -- no map-750 creature advertises a spellclick it cannot serve (expect 0):
--   SELECT COUNT(DISTINCT t.entry) FROM creature_template t
--     JOIN creature c ON c.id = t.entry AND c.map = 750
--    WHERE (t.npcflag & 16777216) <> 0
--      AND NOT EXISTS (SELECT 1 FROM npc_spellclick_spells s WHERE s.npc_entry = t.entry);
--
-- In game: click a Whisperwind Lasher (~6080/-845, Whisperwind Grove). It
-- should stand up and wander; roughly one in three turns into a hostile
-- Corrupted Lasher and attacks. Either way it despawns 20s after leaving
-- combat.
-- ---------------------------------------------------------------------------
