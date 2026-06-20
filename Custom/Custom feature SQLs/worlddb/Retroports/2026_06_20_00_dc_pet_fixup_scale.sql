-- Dark Chaos - pet batch fixup: reset DisplayScale to 1.0 for the 48 companions.
-- Size is now governed by retail ModelScale (CreatureModelData) x CreatureModelScale
-- (CreatureDisplayInfo), imported into the CSV DBCs by retroport_tools/dc_pet_fixup.py.
-- The old per-row DisplayScale (0.15-0.25) double-shrunk models that already carry a
-- small retail CreatureModelScale, making most companions microscopic.

UPDATE `creature_template_model` SET `DisplayScale`=1
WHERE `CreatureID` BETWEEN 3461230 AND 3461277 AND `Idx`=0;

-- effect-inflated geobox -> DisplayScale clamped so they don't render giant.
-- TODO: refine from the real M2 vertex AABB once the WowExport pass lands.
UPDATE `creature_template_model` SET `DisplayScale`=0.088 WHERE `CreatureID`=3461231 AND `Idx`=0;
UPDATE `creature_template_model` SET `DisplayScale`=0.442 WHERE `CreatureID`=3461253 AND `Idx`=0;
UPDATE `creature_template_model` SET `DisplayScale`=0.553 WHERE `CreatureID`=3461265 AND `Idx`=0;
UPDATE `creature_template_model` SET `DisplayScale`=0.099 WHERE `CreatureID`=3461266 AND `Idx`=0;
UPDATE `creature_template_model` SET `DisplayScale`=0.099 WHERE `CreatureID`=3461267 AND `Idx`=0;
