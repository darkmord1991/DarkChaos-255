-- =====================================================================
-- Plaguelands Downport  --  49  Gameobject rotation quaternion fix
-- ---------------------------------------------------------------------
-- Gameobject guid 13621868 (entry 3808156, "Plague-Nel", map 751) has
-- rotation0..3 all 0 -- a zero quaternion, which can't be normalized --
-- logged at boot:
--   Table `gameobject` has gameobject (GUID: 13621868 Entry: 3808156)
--   with invalid rotation quaternion (non-unit), defaulting to
--   orientation on Z axis only
-- The engine already silently substitutes Quat(orientation, Z-only) when
-- this happens, so this is cosmetic (removes 1 boot-log line); this just
-- pre-computes the same Z-axis rotation with full float precision so the
-- stored data is self-consistent instead of relying on the runtime
-- fallback. orientation = 1.616 -> rotation2=sin(0.808), rotation3=cos(0.808).
-- =====================================================================

UPDATE `gameobject`
    SET `rotation2` = 0.722907, `rotation3` = 0.690946
    WHERE `guid` = 13621868 AND `map` = 751 AND `orientation` = 1.616
    AND `rotation0` = 0 AND `rotation1` = 0 AND `rotation2` = 0 AND `rotation3` = 0;
