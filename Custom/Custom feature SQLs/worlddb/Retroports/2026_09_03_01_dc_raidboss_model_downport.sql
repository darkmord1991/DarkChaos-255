-- Raid-boss model downport: Cataclysm -> Dragonflight, baked with wxl-baker.
--
-- Companion to Custom/CSV DBC/CreatureModelData.csv + CreatureDisplayInfo.csv rows
-- 505000..505034 (models) / 505100..505134 (displays). The DBCs must be compiled and deployed to BOTH
-- the client patch and the worldserver data/dbc before these rows will load - a display
-- needs all three layers (DBC + creature_template_model + creature_model_info).
--
-- GeoBox, collision, ModelScale and every TextureVariation came from the retail DB2s,
-- not by hand: a wrong TextureVariation renders the model solid green and a wrong
-- ModelScale renders it microscopic.

-- Server-side bounds for each new display.
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 505100 AND 505134;
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES
(505100, 0.61111, 2.03128, 2, 0),
(505101, 0.61111, 2.03128, 2, 0),
(505102, 0.61111, 2.03128, 2, 0),
(505103, 0.61111, 2.03128, 2, 0),
(505104, 0.61111, 2.03128, 2, 0),
(505105, 0.61111, 2.03128, 2, 0),
(505106, 0.61111, 2.03128, 2, 0),
(505107, 0.61111, 2.03128, 2, 0),
(505108, 0.61111, 2.03128, 2, 0),
(505109, 0.61111, 2.03128, 2, 0),
(505110, 0.61111, 2.03128, 2, 0),
(505111, 0.61111, 2.03128, 2, 0),
(505112, 0.61111, 2.03128, 2, 0),
(505113, 0.61111, 2.03128, 2, 0),
(505114, 0.61111, 2.03128, 2, 0),
(505115, 0.61111, 2.03128, 2, 0),
(505116, 0.61111, 2.03128, 2, 0),
(505117, 0.61111, 2.03128, 2, 0),
(505118, 0.61111, 2.03128, 2, 0),
(505119, 0.61111, 2.03128, 2, 0),
(505120, 0.61111, 2.03128, 2, 0),
(505121, 0.61111, 2.03128, 2, 0),
(505122, 0.61111, 2.03128, 2, 0),
(505123, 0.61111, 2.03128, 2, 0),
(505124, 0.61111, 2.03128, 2, 0),
(505125, 0.61111, 2.03128, 2, 0),
(505126, 0.61111, 2.03128, 2, 0),
(505127, 0.61111, 2.03128, 2, 0),
(505128, 0.61111, 2.03128, 2, 0),
(505129, 0.61111, 2.03128, 2, 0),
(505130, 0.61111, 2.03128, 2, 0),
(505131, 0.61111, 2.03128, 2, 0),
(505132, 0.61111, 2.03128, 2, 0),
(505133, 0.61111, 2.03128, 2, 0),
(505134, 0.6111, 2.0313, 2, 0);

-- Spawnable boss templates, so each model can be verified in-game with .npc add.
DELETE FROM `creature_template` WHERE `entry` BETWEEN 3465000 AND 3465034;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`, `unit_flags`, `type`, `RegenHealth`, `MovementType`, `AIName`) VALUES
(3465000, 'Al''Akir', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465001, 'Anduin Wrynn', 'Shadowlands', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465002, 'Archimonde', 'Warlords of Draenor', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465003, 'Archimonde, Unbound', 'Warlords of Draenor', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465004, 'Zovaal, Unmade', 'Shadowlands', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465005, 'Blackhand', 'Warlords of Draenor', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465006, 'Cho''gall', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465007, 'Cho''gall, Twilight', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465008, 'Diurna', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465009, 'Sinestra', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465010, 'Eranog', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465011, 'Faceless General of N''Zoth', 'Battle for Azeroth', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465012, 'Kilrogg Deadeye', 'Warlords of Draenor', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465013, 'Beth''tilac, Unburnt', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465014, 'Fyrakk', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465015, 'Grand Magistrix Elisande', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465016, 'Elisande, Shadowed', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465017, 'Gul''dan', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465018, 'Gul''dan, Hulked', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465019, 'Gul''dan, Ascendant', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465020, 'Zovaal, the Jailer', 'Shadowlands', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465021, 'Kargath Bladefist', 'Warlords of Draenor', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465022, 'Kil''jaeden', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465023, 'Kurog Grimtotem', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465024, 'Larodar', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465025, 'Odyn', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465026, 'Ragnaros', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465027, 'Raszageth', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465028, 'Shannox', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465029, 'Scalecommander Sarkareth', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465030, 'Smolderon', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465031, 'Terros', 'Dragonflight', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465032, 'Ultraxion', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465033, 'Xavius', 'Legion', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, ''),
(3465034, 'Beth''tilac', 'Cataclysm', 255, 255, 2, 16, 0, 1, 1.14286, 3, 1, 0, 6, 1, 0, '');

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3465000 AND 3465034;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(3465000, 0, 505100, 1, 1),
(3465001, 0, 505101, 1, 1),
(3465002, 0, 505102, 1, 1),
(3465003, 0, 505103, 1, 1),
(3465004, 0, 505104, 1, 1),
(3465005, 0, 505105, 1, 1),
(3465006, 0, 505106, 1, 1),
(3465007, 0, 505107, 1, 1),
(3465008, 0, 505108, 1, 1),
(3465009, 0, 505109, 1, 1),
(3465010, 0, 505110, 1, 1),
(3465011, 0, 505111, 1, 1),
(3465012, 0, 505112, 1, 1),
(3465013, 0, 505113, 1, 1),
(3465014, 0, 505114, 1, 1),
(3465015, 0, 505115, 1, 1),
(3465016, 0, 505116, 1, 1),
(3465017, 0, 505117, 1, 1),
(3465018, 0, 505118, 1, 1),
(3465019, 0, 505119, 1, 1),
(3465020, 0, 505120, 1, 1),
(3465021, 0, 505121, 1, 1),
(3465022, 0, 505122, 1, 1),
(3465023, 0, 505123, 1, 1),
(3465024, 0, 505124, 1, 1),
(3465025, 0, 505125, 1, 1),
(3465026, 0, 505126, 1, 1),
(3465027, 0, 505127, 1, 1),
(3465028, 0, 505128, 1, 1),
(3465029, 0, 505129, 1, 1),
(3465030, 0, 505130, 1, 1),
(3465031, 0, 505131, 1, 1),
(3465032, 0, 505132, 1, 1),
(3465033, 0, 505133, 1, 1),
(3465034, 0, 505134, 1, 1);

-- Feed the new models to the Jade Forest training dummies.
-- pool 3 Cataclysm, 4 Pandaria/Draenor, 5 Legion/BfA/Shadowlands, 7 Dragonflight:
--   505100  Al'Akir                      Cataclysm
--   505101  Anduin Wrynn                 Shadowlands
--   505102  Archimonde                   Warlords of Draenor
--   505103  Archimonde, Unbound          Warlords of Draenor
--   505104  Zovaal, Unmade               Shadowlands
--   505105  Blackhand                    Warlords of Draenor
--   505106  Cho'gall                     Cataclysm
--   505107  Cho'gall, Twilight           Cataclysm
--   505108  Diurna                       Dragonflight
--   505109  Sinestra                     Cataclysm
--   505110  Eranog                       Dragonflight
--   505111  Faceless General of N'Zoth   Battle for Azeroth
--   505112  Kilrogg Deadeye              Warlords of Draenor
--   505113  Beth'tilac, Unburnt          Cataclysm
--   505114  Fyrakk                       Dragonflight
--   505115  Grand Magistrix Elisande     Legion
--   505116  Elisande, Shadowed           Legion
--   505117  Gul'dan                      Legion
--   505118  Gul'dan, Hulked              Legion
--   505119  Gul'dan, Ascendant           Legion
--   505120  Zovaal, the Jailer           Shadowlands
--   505121  Kargath Bladefist            Warlords of Draenor
--   505122  Kil'jaeden                   Legion
--   505123  Kurog Grimtotem              Dragonflight
--   505124  Larodar                      Dragonflight
--   505125  Odyn                         Legion
--   505126  Ragnaros                     Cataclysm
--   505127  Raszageth                    Dragonflight
--   505128  Shannox                      Cataclysm
--   505129  Scalecommander Sarkareth     Dragonflight
--   505130  Smolderon                    Dragonflight
--   505131  Terros                       Dragonflight
--   505132  Ultraxion                    Cataclysm
--   505133  Xavius                       Legion
--   505134  Beth'tilac                   Cataclysm
DELETE FROM `dc_training_boss_display_pool` WHERE `display_id` BETWEEN 505100 AND 505134;
INSERT INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`) VALUES
(3, 505100, 2),
(5, 505101, 2),
(4, 505102, 2),
(4, 505103, 2),
(5, 505104, 2),
(4, 505105, 2),
(3, 505106, 2),
(3, 505107, 2),
(7, 505108, 2),
(3, 505109, 2),
(7, 505110, 2),
(5, 505111, 2),
(4, 505112, 2),
(3, 505113, 2),
(7, 505114, 2),
(5, 505115, 2),
(5, 505116, 2),
(5, 505117, 2),
(5, 505118, 2),
(5, 505119, 2),
(5, 505120, 2),
(4, 505121, 2),
(5, 505122, 2),
(7, 505123, 2),
(7, 505124, 2),
(5, 505125, 2),
(3, 505126, 2),
(7, 505127, 2),
(3, 505128, 2),
(7, 505129, 2),
(7, 505130, 2),
(7, 505131, 2),
(3, 505132, 2),
(5, 505133, 2),
(3, 505134, 2);
