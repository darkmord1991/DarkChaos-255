-- Hyjal Frontier - faction base service NPCs (stubs)
--
-- Reserved scriptnames implemented in src/server/scripts/DC/HyjalFrontier/:
--   npc_hyjal_flightmaster      (hyjal_frontier_flightmaster.cpp)
--   npc_hyjal_guard_alliance    (hyjal_frontier_guards.cpp)
--   npc_hyjal_guard_horde       (hyjal_frontier_guards.cpp)
--   npc_hyjal_innkeeper         (hyjal_frontier_innkeeper.cpp)
--   npc_hyjal_emberwood_vendor  (hyjal_frontier_currency.cpp)
--
-- Entries are reserved in the 830020-830099 block (830000-830017 already
-- used by the legacy Hyjal Summit reskin set). Actual models/equip/loot to
-- be filled in once the Noggit pass is complete and tier placements are
-- decided.

DELETE FROM `creature_template` WHERE `entry` BETWEEN 830020 AND 830029;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`,
     `unit_flags`, `dynamicflags`, `family`, `type`, `type_flags`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
(830020, 'Hyjal Flight Master',        'Jaina''s Encampment', 130, 130, 1,
    35,  8193, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_flightmaster', 0),
(830021, 'Encampment Guard',           'Jaina''s Vanguard',   130, 130, 1,
    35,  0, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 8,
    20, 1, 2, 1, 1, 2, 'npc_hyjal_guard_alliance', 0),
(830022, 'Vanguard Grunt',             'Thrall''s Vanguard',  130, 130, 1,
    36,  0, 1, 1.14286, 1, 1, 1400, 2000, 1, 8256,  0, 0, 7, 8,
    20, 1, 2, 1, 1, 2, 'npc_hyjal_guard_horde', 0),
(830023, 'Innkeeper Cerelina',         NULL,                  130, 130, 1,
    35, 65537, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_innkeeper', 0),
(830024, 'Emberwood Sap Quartermaster', 'Defender of Nordrassil', 130, 130, 1,
    35,  129, 1, 1.14286, 1, 1, 1400, 2000, 1, 32832, 0, 0, 7, 2,
    15, 1, 1, 1, 1, 2, 'npc_hyjal_emberwood_vendor', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830020 AND 830024;
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(830020, 0, 17322, 1, 1, 0),
(830021, 0, 17322, 1, 1, 0),
(830022, 0, 17331, 1, 1, 0),
(830023, 0, 17330, 1, 1, 0),
(830024, 0, 17325, 1, 1, 0);
