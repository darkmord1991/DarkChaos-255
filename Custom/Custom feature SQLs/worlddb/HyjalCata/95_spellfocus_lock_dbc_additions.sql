-- ---------------------------------------------------------------------------
-- spellfocusobject_dbc (6) + lock_dbc (1) -- Twilight Highlands GO gaps
-- ---------------------------------------------------------------------------
-- "GameObject (Entry: N GoType: 8) have data0=M but SpellFocus (Id: M) not
-- exist" for Lycanthoth's Altar/Twilight Anvil/Infiltrators' Camp Focus/Ogre
-- Outhouse/Aviana's Burial Circle/Blaithe's Roost (map 750/751, +3,600,000
-- offset GOs), and "have data1=1939 but lock (Id: 1939) not found" for
-- Jadefire Barrier. Extracted from the real Cata 4.3.4 client
-- (K:/UntouchedClients/Cata, relocated mid-session from K:/Cata --
-- locale-enUS.MPQ). SpellFocusObject.dbc dropped from 18 fields (WotLK,
-- multi-locale name array) to 2 (Cata, single Name+offset) -- same
-- simplification pattern as CreatureFamily.dbc earlier this round.
-- lock_dbc kept its 33-field WotLK-compatible layout (no drift).
-- ---------------------------------------------------------------------------
DELETE FROM `spellfocusobject_dbc` WHERE `ID` IN (1651,1656,1658,1659,1661,1662);

INSERT INTO `spellfocusobject_dbc` (`ID`,`Name_Lang_enUS`,`Name_Lang_Mask`) VALUES
(1651,'Lycanthoth''s Altar',0),
(1656,'Twilight Anvil',0),
(1658,'Infiltrators'' Encampment',0),
(1659,'Ogre Outhouse',0),
(1661,'Aviana''s Burial Circle',0),
(1662,'Blaithe''s Roost',0);

DELETE FROM `lock_dbc` WHERE `ID` = 1939;

INSERT INTO `lock_dbc`
    (`ID`,`Type_1`,`Type_2`,`Type_3`,`Type_4`,`Type_5`,`Type_6`,`Type_7`,`Type_8`,
     `Index_1`,`Index_2`,`Index_3`,`Index_4`,`Index_5`,`Index_6`,`Index_7`,`Index_8`,
     `Skill_1`,`Skill_2`,`Skill_3`,`Skill_4`,`Skill_5`,`Skill_6`,`Skill_7`,`Skill_8`,
     `Action_1`,`Action_2`,`Action_3`,`Action_4`,`Action_5`,`Action_6`,`Action_7`,`Action_8`)
VALUES
(1939,3,0,0,0,0,0,0,0,88697,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
