/*
 * Mythic+ Keystone NPC & GameObject Templates
 * Database entries for M+2 through M+10 keystones
 * 
 * Installation:
 * 1. Create the creature entries (100200-101000)
 * 2. Create the gameobject entries for placeable keystones
 * 3. Place keystones in dungeons/instance portals
 */

-- ============================================================
-- CREATURE TEMPLATES: Keystone NPCs (M+2 through M+10)
-- ============================================================

-- M+2 Keystone NPC
DELETE FROM creature_template WHERE entry = 100200;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100200, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +2', 'M+2 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+3 Keystone NPC
DELETE FROM creature_template WHERE entry = 100300;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100300, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +3', 'M+3 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+4 Keystone NPC
DELETE FROM creature_template WHERE entry = 100400;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100400, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +4', 'M+4 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+5 Keystone NPC (Rare tier)
DELETE FROM creature_template WHERE entry = 100500;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100500, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +5', 'M+5 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+6 Keystone NPC (Rare tier)
DELETE FROM creature_template WHERE entry = 100600;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100600, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +6', 'M+6 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+7 Keystone NPC (Rare tier)
DELETE FROM creature_template WHERE entry = 100700;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100700, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +7', 'M+7 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+8 Keystone NPC (Epic tier)
DELETE FROM creature_template WHERE entry = 100800;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100800, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +8', 'M+8 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+9 Keystone NPC (Epic tier)
DELETE FROM creature_template WHERE entry = 100900;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (100900, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +9', 'M+9 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- M+10 Keystone NPC (Epic tier)
DELETE FROM creature_template WHERE entry = 101000;
INSERT INTO creature_template (entry, difficulty_entry_1, difficulty_entry_2, difficulty_entry_3, 
    KillCredit1, KillCredit2, modelid1, modelid2, modelid3, modelid4, name, subname, 
    IconName, gossip_menu_id, minlevel, maxlevel, exp, exp_unk, exp_unk_rank, minhealth, 
    maxhealth, minmana, maxmana, armour, faction, npcflag, speed_walk, speed_run, speed_swim, 
    speed_flight, detection_range, scale, rank, dmgschool, DamageModifier, BaseAttackTime, 
    RangeAttackTime, BaseVariance, RangeVariance, UnitClass, UnitFlags, UnitFlags2, dynamicflags, 
    family, trainer_type, trainer_spell, trainer_class, trainer_race, type, type_flags, 
    lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold, AIName, 
    MovementType, InhabitType, unk16, unk17, HealthModifier, ManaModifier, ArmorModifier, 
    DamageModifier, ExperienceModifier, RacialLeader, movementId, RegenHealth, mechanic_immune_mask, 
    flags_extra, ScriptName, VerifiedBuild) 
VALUES (101000, 0, 0, 0, 0, 0, 26095, 0, 0, 0, 'Keystone - Mythic +10', 'M+10 Difficulty', 
    '', 0, 70, 70, 0, 0, 0, 59000, 59000, 0, 0, 0, 2226, 4096, 1, 1.14286, 1, 1, 0, 1, 
    0, 0, 1, 2000, 2000, 1, 1, 8, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 0, 0, 1, 
    1, 1, 1, 1, 0, 0, 1, 0, 0, 'npc_keystone', 0);

-- ============================================================
-- GAMEOBJECT TEMPLATES: Placeable Keystones
-- ============================================================

-- Generic keystone placement GO (M+2-M+10, type = spell_focus/placeholder)
DELETE FROM gameobject_template WHERE entry = 300200;
INSERT INTO gameobject_template (entry, type, displayId, name, IconName, castBarCaption, unk1, 
    data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, 
    data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, data24, 
    data25, data26, data27, data28, data29, data30, data31, data32, data33, data34, AIName, 
    ScriptName, VerifiedBuild)
VALUES (300200, 24, 9367, 'Mythic+ Keystone Pedestal', '', '', '', 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 
    'go_keystone_pedestal', 0);

-- ============================================================
-- PLACEMENT NOTES
-- ============================================================

/*
 * To place keystones in the world:
 * 1. Place keystone NPCs (100200-101000) at dungeon entrances or hubs
 * 2. Use admin command: .gobject add 300200 <x> <y> <z> [map]
 * 3. Example: .gobject add 300200 1234.5 5678.9 12.3 1481  (Siege of Boralus)
 * 
 * Suggested Locations:
 * - Dungeon hubs in capitals
 * - Near dungeon entrances
 * - Quest hub areas
 * 
 * Admin Command Examples:
 * .npc add 100200  (Places M+2 keystone at location)
 * .npc add 100300  (Places M+3 keystone at location)
 * ... etc for all keystones up to M+10 (101000)
 */
