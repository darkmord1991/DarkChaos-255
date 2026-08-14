-- =====================================================================================
-- Dungeon instance portal look per difficulty  (supersedes mythic_portal_model_azjolnerub.sql)
--
-- FINAL SCHEME on this realm:
--     Normal (data1 = 0)  -> 8196  modern purple portal
--     Heroic (data1 = 1)  -> 9040  green portal
--     Mythic (data1 = 2)  -> 8197  purple portal WITH SKULL   <- rarest look for the top tier
--
-- This deliberately departs from Blizzard, who used the skull as the heroic marker and
-- green only for raid tiers. Mythic is our own tier, so the most distinctive asset goes
-- to it.
--
-- HOW IT WORKS (entirely client side, no core change):
--   `gameobject_template`.`type` = 31 (GAMEOBJECT_TYPE_DUNGEON_DIFFICULTY)
--       data0 = map id,  data1 = difficulty
--   One object per difficulty at the same spot; the client renders only the one matching
--   the player's selected difficulty for that map. Verified in the client binary: the
--   check at Wow.exe 0x00710B8A compares with a plain `cmp` and NO clamping, so
--   difficulty 2 matches fine on a 5-player map.
--
-- MODEL NOTE: displayId 8197 resolves to `Spells\instancenewportal_purple_skull.m2`. The
-- DC upgraded-model bake in patch-6.MPQ had replaced that with a modern portal that lost
-- the skull (SKULLPORTAL2.BLP was dropped), which is why Heroic and Mythic looked
-- identical for months. That override has been REMOVED from patch-6, so 8197 now falls
-- back to the stock model in patch.MPQ which still has the skull emitter. Do not re-add
-- a flattened override for that path or the skull disappears again.
--
-- SCOPE: the Mythic update is restricted to `entry` >= 800000 (DC's own cloned templates)
-- so Blizzard's raid portals -- which legitimately use data1 = 2 for 10-man heroic on maps
-- 631, 649, 669, 720, 724 -- keep their green look and are never touched.
--
-- APPLY: worldserver restart (gameobject_template is cached at load). Re-runnable: after
-- the first apply neither WHERE matches anything, so it is a no-op.
-- =====================================================================================

-- ---- Heroic 5-player portals -> green ------------------------------------------------
UPDATE `gameobject_template`
    SET `displayId` = 9040
    WHERE `type` = 31 AND `data1` = 1 AND `displayId` = 8197;

-- ---- Mythic portals -> skull ---------------------------------------------------------
UPDATE `gameobject_template`
    SET `displayId` = 8197
    WHERE `type` = 31 AND `data1` = 2 AND `entry` >= 800000 AND `displayId` = 9040;

-- ---- let clients see it --------------------------------------------------------------
-- SMSG_GAMEOBJECT_QUERY_RESPONSE carries `displayId` and the client caches it in
-- Cache\WDB\<locale>\gameobjectcache.wdb, never re-querying a known entry. Bumping
-- `version`.`cache_id` makes every client drop its cache at next login. Required after
-- ANY template change, not just this one.
UPDATE `version` SET `cache_id` = `cache_id` + 1;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'Heroic portals green 9040' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `gameobject_template` WHERE `type` = 31 AND `data1` = 1 AND `displayId` = 9040
UNION ALL SELECT 'Mythic portals skull 8197', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `type` = 31 AND `data1` = 2 AND `entry` >= 800000
      AND `displayId` = 8197
UNION ALL SELECT 'Normal portals unchanged 8196', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `type` = 31 AND `data1` = 0 AND `displayId` = 8196
UNION ALL SELECT 'Blizzard raid portals untouched (want 0 changed)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `type` = 31 AND `entry` < 800000 AND `data1` = 2
      AND `displayId` <> 9040;

-- =====================================================================================
-- OPTIONAL -- the TBC dungeons (maps 269, 540, 542-560, 585, 595) use their own portal
-- pair 7148 normal / 7149 heroic and are untouched above, so their heroic stays the TBC
-- icon portal rather than green. Uncomment to bring them in line:
--
--   UPDATE `gameobject_template` SET `displayId` = 9040
--       WHERE `type` = 31 AND `data1` = 1 AND `displayId` = 7149;
--
-- REVERT to the Blizzard-style arrangement:
--   UPDATE `gameobject_template` SET `displayId` = 8197
--       WHERE `type` = 31 AND `data1` = 1 AND `displayId` = 9040;
--   UPDATE `gameobject_template` SET `displayId` = 9040
--       WHERE `type` = 31 AND `data1` = 2 AND `entry` >= 800000 AND `displayId` = 8197;
-- =====================================================================================
