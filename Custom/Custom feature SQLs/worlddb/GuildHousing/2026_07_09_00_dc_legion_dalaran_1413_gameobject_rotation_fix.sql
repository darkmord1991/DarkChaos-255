-- =====================================================================
-- Legion Dalaran (map 1413) -- gameobject rotation quaternion fix
-- ---------------------------------------------------------------------
-- The 9 Legion Dalaran portal gameobjects (guids 9602001-9602009) carry
-- rotation0/1 = 0 and rotation2/3 = (0.81342, 0.58175), whose sum of
-- squares is 1.000083 -- just outside ObjectMgr's 1e-5 unit-quaternion
-- tolerance (5-decimal rounding from the source data), so every one
-- logged at boot:
--   Table `gameobject` has gameobject (GUID: N Entry: M) with invalid
--   rotation quaternion (non-unit), defaulting to orientation on Z axis
--   only
-- The engine already silently substitutes Quat(orientation, Z-only) when
-- this happens, so this is cosmetic (removes 9 boot-log lines); this just
-- pre-computes the same Z-axis rotation with full float precision so the
-- stored data is self-consistent instead of relying on the runtime
-- fallback. orientation = 1.9 -> rotation2=sin(0.95), rotation3=cos(0.95).
-- =====================================================================

UPDATE `gameobject`
    SET `rotation0` = 0, `rotation1` = 0, `rotation2` = 0.813416, `rotation3` = 0.581683
    WHERE `guid` IN (9602001,9602002,9602003,9602004,9602005,9602006,9602007,9602008,9602009)
    AND `map` = 1413 AND `orientation` = 1.9;
