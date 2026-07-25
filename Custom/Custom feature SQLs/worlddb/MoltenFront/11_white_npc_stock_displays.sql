-- =====================================================================
-- Molten Front -- 11  White NPC fix: swap character-model displays to stock
-- ---------------------------------------------------------------------
-- WHY: 16 Cata displays cloned for map 861 use CHARACTER\*.M2 models whose
-- textures come from a CreatureDisplayInfoExtra bake. The 3.3.5 client's
-- CDIExtra bake path hard-crashed on these rows (disassembly-confirmed, see
-- 10_ header), so ExtendedDisplayInfoID was zeroed client-side to stop the
-- crash -- which leaves those NPCs rendering as untextured WHITE character
-- models. Rebuilding the bake data (CharSections etc.) is a separate project;
-- the pragmatic fix is to repoint the affected creatures at look-alike STOCK
-- WotLK NPC displays, which need no client patch at all.
--
-- Affected creatures (all DC +3,600,000 clones, verified via
-- creature_template_model against the zeroed display list):
--   3652703 Hyjal Enforcer        (NE m/f guards)     33364/33365
--   3652502 Hyjal Marksman        (NE m/f archers)    37936/37937/38544/38545
--   3652823+3652825 Theresa Barkskin (worgen f druid) 38052
--   3652824 General Taldris Moonfall (NE f officer)   38053
--   3653214 Damek Bloombeard      (dwarf m vendor)    38226
--   3652871+3654343 Druid of the Flame (NE fire druids) 38436/38540/38541/38542
--   3653881 Ayla Shadowstorm      (NE f vendor)       38536
--   3653882 Varlan Highbough      (NE m vendor)       38537
--   3654282 Brighthoof            (tauren m brave)    38725
-- (Displays 36445/36446 from the same batch are referenced by no
--  creature_template_model row -- nothing to swap.)
--
-- Replacements are all pre-WotLK-max stock displays (verified present in this
-- world DB + stock client):
--   Moonglade Warden 11774-11776 (NE m guards), Silverwing Sentinel 4841-4843,
--   Sentinel Stillbough 14613, Sentinel Brightgrass 4845 -> not used, see map,
--   Innkeeper Faralia 10582 (NE f civilian), Mathrengyl Bearwalker 2261
--   (NE m druid), Druid of the Talon 17343 (feathered NE druid, fits the
--   Druid-of-the-Flame silhouette), Bloodmoon Worgen 26787 (Northrend worgen),
--   Emissary Whitebeard 16793 (dwarf m), Bluffwatcher 2141 (tauren m brave).
--
-- Scoped to CreatureID >= 3600000 so no upstream creature is ever touched.
-- Idempotent (UPDATEs converge). Requires worldserver restart to reload
-- creature_template_model.
-- =====================================================================

UPDATE `creature_template_model` SET `CreatureDisplayID` = 11774 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 33364;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 4841  WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 33365;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 11775 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 37936;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 4842  WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 37937;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 11776 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38544;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 4843  WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38545;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 26787 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38052;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 14613 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38053;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 16793 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38226;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 17343 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` IN (38436, 38540, 38541, 38542);
UPDATE `creature_template_model` SET `CreatureDisplayID` = 10582 WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38536;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 2261  WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38537;
UPDATE `creature_template_model` SET `CreatureDisplayID` = 2141  WHERE `CreatureID` >= 3600000 AND `CreatureDisplayID` = 38725;

-- Druid of the Flame ended up with 4 identical display rows after the swap;
-- collapse the duplicates so the picker does not roll the same model 4x.
DELETE t1 FROM `creature_template_model` t1
JOIN `creature_template_model` t2
  ON t1.CreatureID = t2.CreatureID AND t1.CreatureDisplayID = t2.CreatureDisplayID
 AND t1.Idx > t2.Idx
WHERE t1.CreatureID >= 3600000 AND t1.CreatureDisplayID = 17343;
