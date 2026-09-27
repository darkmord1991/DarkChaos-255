-- Falcosaur companion showcase creatures: size now comes from the DBCs.
-- CreatureModelData 500206 (falcosaurospet.m2) now carries retail ModelScale 0.1 and
-- CreatureDisplayInfo 500212-500215 the retail CreatureModelScale 1.25, so the hand-set
-- DisplayScale 0.75 from 2026_05_01_00_dc_falcosaur_variants.sql is no longer needed.
-- Final size = 0.1 * 1.25 * 1.0 = 0.125, as in retail. Requires the matching DBC deploy.

UPDATE `creature_template_model`
SET `DisplayScale` = 1
WHERE `CreatureID` IN (3461209,3461210,3461211,3461212)
  AND `Idx` = 0;
