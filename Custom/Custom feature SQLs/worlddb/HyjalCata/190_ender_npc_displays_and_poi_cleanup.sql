-- ---------------------------------------------------------------------------
-- 190  Hyjal round-45 -- displays for the ender NPCs 186_ added, + POI cleanup
-- ---------------------------------------------------------------------------
-- Post-apply verification of round 45 found three loose ends.  Two are fixed
-- here; the third is a source-side gap and is documented rather than papered
-- over.
--
-- 1. THREE DISPLAYS WITH NO model_info -- 36456, 36483, 36540.  These belong to
--    Jez Goodgrub, Francis Morcott and Jeb Guthrie, the Winterspring quest
--    enders 186_ created.  They post-date the 238-display sweep in 181_/187_,
--    which was computed before those NPCs existed, so they were never in that
--    set.  Left alone the three enders would be INVISIBLE -- and they are the
--    hand-in for five quests, so the quests would look broken again.
--
--    All three are character models we already ship (Goblin male, Worgen male,
--    Human male), so the same treatment applies as the earlier batch: shipped
--    in this round's client deploy are 3 CreatureDisplayInfo rows, 3
--    CreatureDisplayInfoExtra rows (Cata race 22 Worgen remapped to DC race 12,
--    3 dangling ItemDisplayInfo refs zeroed) and 3 baked NPC textures into
--    patch-9.  BOTH HALVES MUST GO LIVE TOGETHER.
--
-- 2. ONE ORPHAN POI BLOB -- quest 13892, blob 0, WorldMapArea 1259 (Darkshore).
--    It has no points here because it has NO POINTS IN CATA EITHER: 33 of
--    cata_world's quest_poi rows carry no matching quest_poi_points, and this is
--    one of them.  A blob with no points draws nothing, so the row is dead
--    weight that will show up in every future audit as a false positive.  It is
--    deleted rather than filled -- there is nothing to fill it with.
--
-- NOT FIXED, on purpose: 38 vendors on map 750 are still empty.  Re-checking
-- after the 83 quest items landed shows ZERO additional vendor rows become
-- available, so those vendors have no usable cata_world source at all -- their
-- stock is not something this round can recover.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (36456, 36483, 36540);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `gender`, `DisplayID_Other_Gender`) VALUES
  (36456, 0.306000, 1.500000, 0, 0),   -- Jez Goodgrub      (Goblin male)
  (36483, 0.306000, 1.500000, 0, 0),   -- Francis Morcott   (Worgen male)
  (36540, 0.306000, 1.500000, 0, 0);   -- Jeb Guthrie       (Human male)

-- orphan blob: no points exist for it in cata_world either
DELETE FROM `quest_poi_points` WHERE `QuestID` = 13892 AND `Idx1` = 0;
DELETE FROM `quest_poi` WHERE `QuestID` = 13892 AND `id` = 0 AND `MapID` = 750;

-- Verify -- both should read 0:
--   SELECT COUNT(DISTINCT m.CreatureDisplayID) FROM `creature` c
--     JOIN `creature_template_model` m ON m.CreatureID = c.id
--     LEFT JOIN `creature_model_info` i ON i.DisplayID = m.CreatureDisplayID
--    WHERE c.map = 750 AND i.DisplayID IS NULL;
--   SELECT COUNT(*) FROM `quest_poi` ap WHERE ap.MapID = 750
--     AND NOT EXISTS (SELECT 1 FROM `quest_poi_points` pt
--                     WHERE pt.QuestID = ap.QuestID AND pt.Idx1 = ap.id);
