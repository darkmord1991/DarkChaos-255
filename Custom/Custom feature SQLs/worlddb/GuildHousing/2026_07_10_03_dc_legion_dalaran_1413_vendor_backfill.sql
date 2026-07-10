-- ---------------------------------------------------------------------------
-- npc_vendor backfill  (Legion Dalaran, map 1413)  --  CORRECTED
-- ---------------------------------------------------------------------------
-- Supersedes an earlier version of this file that substituted stock-WotLK
-- vendor lists (Innkeeper Jovia / Skeletal Petkeeper / Kirembri Silvermane)
-- for 21 of these 30 NPCs, on the assumption their real Legion item lists
-- were unrecoverable (the LegionCore world-DB source dump appeared to be
-- gone from disk). That assumption was WRONG -- the raw dump is present at
-- K:/Dark-Chaos/legion stuff/LegionCore-7.3.5-master/sql/base/
-- LegionCore_world_2020_04_25.sql (243 MB, just nested one level deeper
-- than the top-level search that missed it). Pulling the REAL npc_vendor
-- rows for these 30 raw LegionCore entries (subtract 3,500,000 from the
-- local entry) shows only **2 of the 30 ever had any vendor items at all**:
--   * Nomi (295 -> 3500295): 12 items
--   * Mel Lynchen "Barista" (483 -> 3500483): 13 items
-- The other 28 (Innkeeper/Barmaid/Brewmaiden/Bartender/Exotic Pets/Battle
-- Pet Master/Jewelcrafting/etc, "O'Shea Repairs", + the unclear-role ones)
-- genuinely have ZERO npc_vendor rows in the real Legion source, verified by
-- grepping the full raw dump (not just the offset-filtered extract) --
-- e.g. many Legion "Innkeeper"/"Barmaid" NPCs never sold food via
-- npc_vendor in retail at all (a separate baker/cook NPC usually did). The
-- earlier fabricated substitution has been removed entirely rather than
-- shipping data known to be inconsistent with the real source (it was never
-- applied to the live DB, so no cleanup was needed there).
--
-- Item ids sourced straight from the recovered dump (all low classic-era
-- food ids); 3 (58259, 81921, 81922 -- all cheeses) were missing from
-- item_template and got downported the same way as the other 19 in
-- worlddb/dc_vendor_item_downport_2026_07_10.sql -- see the follow-up
-- worlddb/dc_vendor_item_downport_2026_07_10_legion_cheese.sql.
--
-- 800031 "Dalaran Innkeeper" is NOT part of this LegionCore extraction (no
-- 3,500,000-offset counterpart) -- a DC-native "Guild House" utility NPC,
-- npcflag GOSSIP+VENDOR only (no INNKEEPER bit). Left alone; no source data
-- to recover for it either way.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` IN (3500295,3500483);

INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`) VALUES
(3500295,0,159,0,0,0),
(3500295,0,414,0,0,0),
(3500295,0,422,0,0,0),
(3500295,0,1179,0,0,0),
(3500295,0,1205,0,0,0),
(3500295,0,1645,0,0,0),
(3500295,0,1707,0,0,0),
(3500295,0,1708,0,0,0),
(3500295,0,2070,0,0,0),
(3500295,0,3927,0,0,0),
(3500295,0,8766,0,0,0),
(3500295,0,8932,0,0,0),
(3500483,0,414,0,0,0),
(3500483,0,422,0,0,0),
(3500483,0,1707,0,0,0),
(3500483,0,2070,0,0,0),
(3500483,0,3927,0,0,0),
(3500483,0,8932,0,0,0),
(3500483,0,27857,0,0,0),
(3500483,0,33443,0,0,0),
(3500483,0,35952,0,0,0),
(3500483,0,58258,0,0,0),
(3500483,0,58259,0,0,0),
(3500483,0,81921,0,0,0),
(3500483,0,81922,0,0,0);
