-- ---------------------------------------------------------------------------
-- 214  Map 750 -- the creature_model_info rows the new displays need
-- ---------------------------------------------------------------------------
-- THE ERROR MESSAGE IS MISLEADING, which is why this took an extra round.
--
--     "Creature (Entry: 3748768) has no model 36276 defined in table
--      `creature_template_model`, can't load."
--
-- It names `creature_template_model`, but that is not what it checked. From
-- Creature.cpp:517-530, the row and the DBC entry are both fine by then:
--
--     CreatureModel model = *ObjectMgr::ChooseDisplayId(cinfo, data);
--     CreatureModelInfo const* mInfo = sObjectMgr->GetCreatureModelRandomGender(&model, cinfo);
--     if (!mInfo)   // <-- THIS is what fails
--         LOG_ERROR(... "has no model {} defined in table `creature_template_model`" ...)
--
-- GetCreatureModelRandomGender resolves against `_creatureModelStore`, which is
-- loaded from the **`creature_model_info`** table -- server-side bounding
-- radius, combat reach and gender. Nothing to do with creature_template_model
-- and nothing to do with the DBC.
--
-- So there are THREE separate things a display id needs, and 211_/212_ only
-- supplied the first two:
--     1. a row in CreatureDisplayInfo.dbc      -- so the client can draw it
--     2. a row in creature_template_model      -- so the creature has a model
--     3. a row in creature_model_info          -- so the SERVER can size it
-- Miss (3) and the spawn is refused even though (1) and (2) are perfect. This
-- is the same distinction 195_ ran into.
--
-- SCOPE: 102 display ids across 72 creature entries, blocking 909 spawns on map
-- 750. All 102 exist in cata_world -- verified, none had to be invented. The
-- query is written over every map-750 spawn rather than just 212_'s imports, so
-- it also sweeps up any display from the earlier 188_/201_ passes that was
-- missing the same row.
--
-- SCHEMA -- checked before writing, unlike last time. cata_world's table is
-- (DisplayID, BoundingRadius, CombatReach, Gender, DisplayID_Other_Gender);
-- ours adds VerifiedBuild. Hence the explicit column list and the literal 0.
--
-- Apply against acore_world, then restart worldserver. Idempotent. No client
-- deploy needed -- this table is server-side only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Import the missing rows
-- ---------------------------------------------------------------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (
  SELECT * FROM (
    SELECT DISTINCT m.`CreatureDisplayID`
    FROM `creature` c
    JOIN `creature_template_model` m ON m.`CreatureID` = c.`id`
    WHERE c.`map` = 750 AND m.`CreatureDisplayID` > 0
      AND NOT EXISTS (SELECT 1 FROM `creature_model_info` i
                      WHERE i.`DisplayID` = m.`CreatureDisplayID`)
  ) x);

INSERT IGNORE INTO `creature_model_info`
    (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
SELECT i.`DisplayID`, i.`BoundingRadius`, i.`CombatReach`, i.`Gender`, i.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` i
WHERE i.`DisplayID` IN (
  SELECT * FROM (
    SELECT DISTINCT m.`CreatureDisplayID`
    FROM `creature` c
    JOIN `creature_template_model` m ON m.`CreatureID` = c.`id`
    WHERE c.`map` = 750 AND m.`CreatureDisplayID` > 0
      AND NOT EXISTS (SELECT 1 FROM `creature_model_info` i2
                      WHERE i2.`DisplayID` = m.`CreatureDisplayID`)
  ) y);

-- ---------------------------------------------------------------------------
-- B) Gender partners -- checked, and deliberately NOT touched
-- ---------------------------------------------------------------------------
-- DisplayID_Other_Gender points at the opposite-sex display, and if that id has
-- no creature_model_info row of its own GetCreatureModelRandomGender fails the
-- same way -- we would be back here with a different id in the message. So this
-- file originally carried an UPDATE to zero unresolvable partners.
--
-- It was measured instead of assumed, and all three counts came back zero:
--     dangling partners database-wide ................ 0
--     of the 102 imported rows, how many set a partner  0
--     of those, unresolvable after import ............ 0
-- None of these 102 displays uses the field at all. The UPDATE was a no-op, and
-- a database-wide UPDATE that does nothing is still something that can go wrong
-- later, so it is gone. The verification block below still checks the invariant.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   -- nothing on map 750 is missing its model_info any more (expect 0):
--   SELECT COUNT(DISTINCT m.CreatureDisplayID)
--     FROM creature c JOIN creature_template_model m ON m.CreatureID = c.id
--    WHERE c.map = 750 AND m.CreatureDisplayID > 0
--      AND NOT EXISTS (SELECT 1 FROM creature_model_info i
--                      WHERE i.DisplayID = m.CreatureDisplayID);
--
--   -- and no dangling gender partners anywhere (expect 0):
--   SELECT COUNT(*) FROM creature_model_info a
--    WHERE a.DisplayID_Other_Gender > 0
--      AND NOT EXISTS (SELECT 1 FROM creature_model_info b
--                      WHERE b.DisplayID = a.DisplayID_Other_Gender);
--
--   -- spot-check the one in the report:
--   SELECT * FROM creature_model_info WHERE DisplayID = 36276;
--
-- Errors.log should lose the "has no model <id> defined" block entirely. That
-- was the last of the three layers; with 211_ (DBC), 212_/213_
-- (creature_template_model) and this one, all 909 spawns should load.
-- ---------------------------------------------------------------------------
