-- ---------------------------------------------------------------------------
-- 128  Hyjal round-15 -- creature_model_info for the Molten Front displays
-- ---------------------------------------------------------------------------
-- CRITICAL: these creatures do not spawn AT ALL.  Seen live on map 861:
--     Creature (Entry: 3652981) has no model 38463 defined in table
--     `creature_template_model`, can't load.
-- ...repeated for ~30 Molten Front entries (Fire Hawk, Cinderweb Spinner /
-- Creeper / Clutchkeeper / Cocoon, Druid of the Flame, Injured Druid of the
-- Talon, Flamewaker Sentinel, Emberspit Scorpion, Ancient Charhound, Hyjal
-- Marksman, Commander Jarod Shadowsong, General Taldris Moonfall, ...).
--
-- The message is MISLEADING.  Creature.cpp:529 emits it when
-- `ObjectMgr::GetCreatureModelRandomGender` returns null, and that happens when
-- the display id has no **`creature_model_info`** row -- not when
-- creature_template_model is missing.  All the creature_template_model rows are
-- present and correct; what MoltenFront/01_mf_templates.sql never brought
-- across is the per-display model_info (bounding radius / combat reach /
-- gender), which the core treats as mandatory.  `Creature::Create` returns
-- false, so the spawn is silently dropped.
--
-- 50 display ids are affected (58 creature_template_model rows across the whole
-- 3,600,000-3,699,999 block).  All 50 exist in nelt_world.creature_model_info
-- and are cloned verbatim -- display ids are never offset.
--
-- Note this also covers 37989 / 37990 / 37992, the three Wings of Aviana
-- displays round 14 added to Custom/CSV DBC/CreatureDisplayInfo.csv: they need
-- a server-side model_info row too, which round 14 did not add.
--
-- nelt column names differ (modelid / bounding_radius / combat_reach /
-- modelid_other_gender); acore adds VerifiedBuild.  Idempotent.
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO acore_world.creature_model_info
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
SELECT n.modelid, n.bounding_radius, n.combat_reach, n.gender, n.modelid_other_gender, 0
FROM nelt_world.creature_model_info n
WHERE n.modelid IN (
  SELECT DISTINCT m.CreatureDisplayID
  FROM acore_world.creature_template_model m
  WHERE m.CreatureID BETWEEN 3600000 AND 3699999 AND m.CreatureDisplayID > 0
);

-- Same gap, GameObject side is not applicable, but the transform/summon targets
-- 126_ imports bring their own displays in with them -- re-run of the same
-- self-deriving select covers them because it reads creature_template_model
-- rather than a hardcoded id list.

-- --- sanity: a model_info row whose other-gender partner is itself missing ---
-- GetCreatureModelRandomGender logs "has modelid_other_gender N not found in
-- table `creature_model_info`" and falls back, which is noisy but harmless.
-- Pull those partners across too rather than leave a second round of warnings.
INSERT IGNORE INTO acore_world.creature_model_info
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
SELECT n.modelid, n.bounding_radius, n.combat_reach, n.gender, n.modelid_other_gender, 0
FROM nelt_world.creature_model_info n
WHERE n.modelid IN (
  SELECT DISTINCT i.DisplayID_Other_Gender
  FROM acore_world.creature_model_info i
  WHERE i.DisplayID_Other_Gender > 0
    AND i.DisplayID IN (
      SELECT DISTINCT m.CreatureDisplayID
      FROM acore_world.creature_template_model m
      WHERE m.CreatureID BETWEEN 3600000 AND 3699999 AND m.CreatureDisplayID > 0)
);

-- ---------------------------------------------------------------------------
-- CLIENT-SIDE COUNTERPART -- one display is missing from the DBC as well:
--   3652825 "Theresa Barkskin" reports the *other* variant of this error,
--   "has no model defined in table `creature_template_model`" (no display id in
--   the text).  That fires from Creature.cpp:520 when GetFirstValidModel()
--   is empty -- ObjectMgr::LoadCreatureTemplateModels DROPS any row whose
--   CreatureDisplayID is absent from CreatureDisplayInfo.dbc, and 38052 is the
--   only Molten Front display not in the built DBC (38053, its neighbour, is
--   there).  A model_info row alone will NOT fix her; she needs a
--   CreatureDisplayInfo row, i.e. the client display-downport path.
--   Tracked in 00_README round-15 "deferred".
-- ---------------------------------------------------------------------------
