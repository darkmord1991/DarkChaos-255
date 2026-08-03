-- ---------------------------------------------------------------------------
-- 44  Azshara Crater -> map 750 portals (level 78+)
-- ---------------------------------------------------------------------------
-- The hand-off from the 1-80 area to the 80-130 continent: two portals placed
-- in Azshara Crater (map 37), usable from level 78, one per faction start.
--
--   3809082  Portal to Lor'danel           -> Darkshore  (Alliance start)
--   3809083  Portal to Bilgewater Harbor   -> Azshara    (Horde start)
--
-- Mechanism (same as the working Nordrassil portals): GO type 22 SPELL_CASTER
-- casts Data0 on the user; the spell is a TELEPORT_UNITS clone of 300600 and
-- its destination lives in spell_target_position.
--
-- LEVEL GATE -- verified against this fork's source, not assumed:
--   * GameObject.cpp:1471 `Unit* spellCaster = user;` and :1473
--     `triggeredFlags = TRIGGERED_NONE`, so the PLAYER is the caster and
--     Spell::CheckCast really runs (Spell.cpp:3538);
--   * CheckCast evaluates CONDITION_SOURCE_TYPE_SPELL (17) with the caster as
--     ConditionTarget 0 (Spell.cpp:5865-5870);
--   * CONDITION_LEVEL = 27, compared as
--     CompareValues(ConditionValue2, unit->GetLevel(), ConditionValue1)
--     (ConditionMgr.cpp:275), and COMP_TYPE_HIGH_EQ = 3 (Util.h:579-584)
--     => "player level >= 78".
--   * ErrorType 46 = SPELL_FAILED_LEVEL_REQUIREMENT (SharedDefines.h:986), so
--     an under-level player gets a proper "you are not high enough level"
--     message instead of a silent no-op.
--
-- PLACEMENT (the portals are NOT spawned here -- place them in-game so the
-- ground height is exact):
--     .go xyz -54.99 50.32 297.86 37      <- Archmage Thadeus, the AC hand-off
--     .gobject add 3809082                 <- Alliance portal, at your feet
--     .gobject add 3809083                 <- Horde portal
-- Put them side by side near Thadeus (he ends AC's level-80 quest 300803 and
-- gives the two breadcrumbs 81300/81301 from 43_). `.gobject add` writes the
-- spawn permanently; note the guids it prints.
--
-- Faction gating is deliberately NOT applied -- either portal is usable by
-- anyone (arriving in the other faction's town is the player's risk). To lock
-- them per team, add the commented CONDITION_TEAM rows at the bottom.
--
-- IDs (verified free): spells 300602-300603, GO templates 3809082-3809083.
-- Client: Spell.csv carries the two names (tooltip only -- the teleport works
-- without a client row). Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. teleport spells (server-side clones of the proven 300600 shape)
-- ---------------------------------------------------------------------------
DELETE FROM `spell_dbc` WHERE `ID` IN (300602, 300603);

DROP TEMPORARY TABLE IF EXISTS `tmp_dc750_portal_spell`;
CREATE TEMPORARY TABLE `tmp_dc750_portal_spell` AS
SELECT * FROM `spell_dbc` WHERE `ID` = 300600;
UPDATE `tmp_dc750_portal_spell` SET `ID` = 300602,
    `Name_Lang_enUS` = 'Portal to Lor''danel', `Name_Lang_enGB` = 'Portal to Lor''danel';
INSERT INTO `spell_dbc` SELECT * FROM `tmp_dc750_portal_spell`;
UPDATE `tmp_dc750_portal_spell` SET `ID` = 300603,
    `Name_Lang_enUS` = 'Portal to Bilgewater Harbor', `Name_Lang_enGB` = 'Portal to Bilgewater Harbor';
INSERT INTO `spell_dbc` SELECT * FROM `tmp_dc750_portal_spell`;
DROP TEMPORARY TABLE `tmp_dc750_portal_spell`;

-- destinations = the two faction start points (40_faction_starts.sql)
DELETE FROM `spell_target_position` WHERE `ID` IN (300602, 300603);
INSERT INTO `spell_target_position` (`ID`, `EffectIndex`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`) VALUES
(300602, 0, 750, 7462.24,  -326.55,   8.21, 3.194),
(300603, 0, 750, 3527.24, -6518.98,  43.59, 0.122);

-- ---------------------------------------------------------------------------
-- 2. portal gameobjects (clones of the working Nordrassil pair)
-- ---------------------------------------------------------------------------
-- 3809080 carries the blue/Alliance portal art (display 4396), 3809081 the
-- red/Horde one (4395) -- kept faction-appropriate. Data1 (charges) = 0 =
-- unlimited uses, inherited from the source rows.
DELETE FROM `gameobject_template` WHERE `entry` IN (3809082, 3809083);

DROP TEMPORARY TABLE IF EXISTS `tmp_dc750_portal_go`;
CREATE TEMPORARY TABLE `tmp_dc750_portal_go` AS
SELECT * FROM `gameobject_template` WHERE `entry` = 3809080;
UPDATE `tmp_dc750_portal_go` SET `entry` = 3809082, `name` = 'Portal to Lor''danel', `Data0` = 300602;
INSERT INTO `gameobject_template` SELECT * FROM `tmp_dc750_portal_go`;
DROP TEMPORARY TABLE `tmp_dc750_portal_go`;

CREATE TEMPORARY TABLE `tmp_dc750_portal_go` AS
SELECT * FROM `gameobject_template` WHERE `entry` = 3809081;
UPDATE `tmp_dc750_portal_go` SET `entry` = 3809083, `name` = 'Portal to Bilgewater Harbor', `Data0` = 300603;
INSERT INTO `gameobject_template` SELECT * FROM `tmp_dc750_portal_go`;
DROP TEMPORARY TABLE `tmp_dc750_portal_go`;

DELETE FROM `gameobject_template_addon` WHERE `entry` IN (3809082, 3809083);
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT 3809082, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`
FROM `gameobject_template_addon` WHERE `entry` = 3809080;
INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT 3809083, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`
FROM `gameobject_template_addon` WHERE `entry` = 3809081;

-- ---------------------------------------------------------------------------
-- 3. the level-78 gate
-- ---------------------------------------------------------------------------
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 17 AND `SourceEntry` IN (300602, 300603);
INSERT INTO `conditions`
  (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
   `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
   `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(17, 0, 300602, 0, 0, 27, 0, 78, 3, 0, 0, 46, 0, '', 'DC750 Lor''danel portal - requires level 78'),
(17, 0, 300603, 0, 0, 27, 0, 78, 3, 0, 0, 46, 0, '', 'DC750 Bilgewater portal - requires level 78');

-- OPTIONAL faction lock -- uncomment to make each portal team-only.
-- CONDITION_TEAM = 6, ConditionValue1: 469 = Alliance, 67 = Horde. Same
-- ElseGroup as the level row => both must pass (AND).
-- INSERT INTO `conditions`
--   (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
--    `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
--    `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
-- (17, 0, 300602, 0, 0, 6, 0, 469, 0, 0, 0, 0, 0, '', 'DC750 Lor''danel portal - Alliance only'),
-- (17, 0, 300603, 0, 0, 6, 0,  67, 0, 0, 0, 0, 0, '', 'DC750 Bilgewater portal - Horde only');

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- SELECT ID FROM spell_dbc WHERE ID IN (300602, 300603);                -- 2
-- SELECT entry, name, type, displayId, Data0 FROM gameobject_template
--   WHERE entry IN (3809082, 3809083);                                  -- 2, type 22
-- SELECT SourceEntry, ConditionValue1, ConditionValue2, ErrorType FROM conditions
--   WHERE SourceTypeOrReferenceId = 17 AND SourceEntry IN (300602, 300603);
-- After placing: SELECT guid, id, map, position_x, position_y FROM gameobject
--   WHERE id IN (3809082, 3809083);
-- In-game: at level 77 the portal must refuse with a level message; at 78 it
-- must land you at the start hub. `.gobject add` requires a server restart or
-- `.reload gameobject_template` for the template rows to be visible first.
