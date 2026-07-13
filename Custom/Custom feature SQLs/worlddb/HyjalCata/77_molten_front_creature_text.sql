-- =====================================================================
-- Molten Front -- 77  Missing creature_text rows
-- ---------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): "SmartAIMgr: Entry N ... using
-- non-existent Text id M, skipped" boot-log errors for 2 creatures whose
-- smart_scripts SAY actions reference creature_text GroupIDs that were
-- never downported.
--   3608297 "Magronos the Unyielding" (offset of 8297) -- combat enrage
--     yell, GroupID 0. Source: cata_world.creature_text.
--   3654168 "Thrall" (offset of 54168) -- the Thrall/Aggra betrothal scene
--     (4 lines, GroupID 0-3). cata_world had zero rows for this entry;
--     found in nelt_world instead (same content, different source DB).
-- BroadcastTextId values (10677, 52802/52804/52805/52806) all already
-- exist in this DB's broadcast_text -- verified before writing.
-- =====================================================================
DELETE FROM `creature_text` WHERE `CreatureID` IN (3608297,3654168);

INSERT INTO `creature_text` (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`) VALUES
(3608297,0,0,'%s becomes enraged!',16,0,100,0,0,0,10677,0,'combat Enrage'),
(3654168,0,0,'In the face of this cataclysm, I''ve seen how truly fleeting our lives can be. And I, for one, will not waste another second of mine.',12,0,100,1,0,24760,52802,0,'Thrall'),
(3654168,1,0,'Aggra... though I was not born on Draenor, I have always tried to honor the traditions of our ancestors...',12,0,100,1,0,24761,52804,0,'Thrall'),
(3654168,2,0,'I stand before you - Go''el, Son of Durotan, Son of Garad... and if you would have me, I would be your life-mate.',12,0,100,1,0,24762,52805,0,'Thrall'),
(3654168,3,0,'For so long as I live, I will stand at your side... as you have stood at mine.',12,0,100,1,0,24763,52806,0,'Thrall');
