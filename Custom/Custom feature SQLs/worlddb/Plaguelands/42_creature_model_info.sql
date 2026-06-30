-- =====================================================================
-- creature_model_info for the dc clones (maps 750 + 751) -- fixes
--   "Creature (Entry: X) has no model Y defined ... can't load"
-- ---------------------------------------------------------------------
-- AC refuses to load any creature whose creature_template_model display id lacks a
-- creature_model_info row (BoundingRadius/CombatReach/Gender). The cata clone created
-- creature_template_model but NOT creature_model_info (the Deepholm 07 step). Import the
-- rows from cata_world for every display id any +3.6M clone uses, plus the gendered
-- DisplayID_Other_Gender partners. INSERT IGNORE so stock display ids are never clobbered.
-- Global (CreatureID>=3,600,000 covers both zones); idempotent. Apply after templates (01/29).
-- =====================================================================
INSERT IGNORE INTO acore_world.creature_model_info
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`
FROM cata_world.creature_model_info cmi
WHERE cmi.`DisplayID` IN (
        SELECT DISTINCT CreatureDisplayID FROM acore_world.creature_template_model WHERE CreatureID >= 3600000)
   OR cmi.`DisplayID` IN (
        SELECT DISTINCT g.`DisplayID_Other_Gender` FROM cata_world.creature_model_info g
        WHERE g.`DisplayID` IN (SELECT DISTINCT CreatureDisplayID FROM acore_world.creature_template_model WHERE CreatureID >= 3600000)
          AND g.`DisplayID_Other_Gender` > 0);