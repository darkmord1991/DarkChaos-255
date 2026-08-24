-- ---------------------------------------------------------------------------
-- 295  Map 750 -- the gameobject_template_addon layer, audited and backfilled
-- ---------------------------------------------------------------------------
-- Direct answer to "were all gameobject_template_addon entries also ported for
-- map 750?": **no.** Of the 1,048 GO templates spawned on 750, 706 resolve to a
-- cata_world source by name, **every one of those 706 has an addon row in the
-- source, and we hold 532** -- so 174 rows were dropped on import. This is the
-- same class the project has hit before: offset-band imports carry
-- gameobject_template and silently skip its addon.
--
-- WHAT A MISSING ROW ACTUALLY COSTS -- read from the core, not assumed.
-- GameObject.cpp:324-328:
--     if (GameObjectTemplateAddon const* templateAddon = GetTemplateAddon())
--     {
--         SetUInt32Value(GAMEOBJECT_FACTION, templateAddon->faction);
--         ReplaceAllGameObjectFlags((GameObjectFlags)templateAddon->flags);
--     }
-- No row means the block is skipped entirely, so faction stays 0 and flags stay
-- 0. That is *exactly* the default, which is why **112 of the 174 are provably
-- harmless**: their source rows are all-default across all nine columns
-- (faction, flags, mingold, maxgold, artkit0-3 -- measured: 0 carry gold and
-- 0 carry an artkit). Importing those 112 would insert rows that set 0/0 over a
-- value that is already 0/0. They are deliberately NOT imported; a table full of
-- no-op rows makes the next audit harder, not easier.
--
-- So the real gap is **62 templates / 732 spawns**, every spawn on map 750
-- (0 elsewhere, so nothing off-map can be affected by this file).
--
-- What those 62 are losing:
--   * 32 lose a FACTION. The Land Mine in 287_ showed what that means -- a GO
--     whose faction never resolves fails its hostility checks. Here it is
--     mailboxes (1735 / 1732 -- the Alliance/Horde split), fire and rubble
--     props (114), ore veins (94: Copper x109, Tin x34, Truesilver, Small and
--     Rich Thorium), and 15 Darkshore/Ashenvale area markers (84).
--   * 37 lose FLAGS, all three of which are load-bearing per SharedDefines.h:
--       0x02 GO_FLAG_LOCKED         "require key, spell, event to be opened"
--       0x04 GO_FLAG_INTERACT_COND  "cannot interact (condition to interact)"
--       0x20 GO_FLAG_NODESPAWN      "never despawn"
--     The 0x04 set is the substantial one -- around 40 quest objects (Encrusted
--     Clam x139, Smoked Meat x37, Ancient Statuette x52, Bear's Paw x27,
--     Bathran's Hair x24, Jadefire Brazier x24, Highborne Relic x46, Twilight
--     Plans x18, Troll Chest x13, Ancient Urn x14 ...) that are currently
--     interactable with no condition gate at all.
--
-- 🔴 NO CATACLYSM-ONLY FACTIONS IN THIS SET -- CHECKED, BECAUSE 287_ WAS BITTEN
-- BY EXACTLY THAT. GO 3795360's Land Mine carried Cata faction template 2206,
-- which does not exist in 3.3.5, so the trap went inert. Every non-zero faction
-- among these 62 (1735, 1732, 114, 94, 84, 35) IS present in
-- `factiontemplate_dbc`, so all 62 import verbatim with no remapping. The
-- INSERT re-asserts that anyway rather than trusting this comment.
--
-- 🔴 ALSO NOT AFFECTED: the "fall through elevators" failure mode. That is
-- GO_FLAG_TRANSPORT 0x08, and **0 of the 174 carry it** -- that defect belongs
-- to map 751 and Blackwing Descent, not here.
--
-- The +3.6M / +3.7M split: GO entries on this map use BOTH offsets (the 3.9M
-- band de-offsets by 3,700,000, the rest by 3,600,000), so the source is
-- resolved per template by trying both and requiring the NAME to match. Without
-- the name check a wrong band silently pairs two different objects.
--
-- Apply against acore_world, then restart worldserver. Idempotent: the INSERT
-- skips any entry that already has a row.

INSERT INTO acore_world.`gameobject_template_addon`
  (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT t.`entry`, s.`faction`, s.`flags`, 0, 0, 0, 0, 0, 0
FROM acore_world.`gameobject_template` t
JOIN `cata_world`.`gameobject_template` cs
  ON cs.`entry` = COALESCE(
       (SELECT s2.`entry` FROM `cata_world`.`gameobject_template` s2
         WHERE s2.`entry` = CAST(t.`entry` AS SIGNED) - 3600000 AND s2.`name` = t.`name`),
       (SELECT s2.`entry` FROM `cata_world`.`gameobject_template` s2
         WHERE s2.`entry` = CAST(t.`entry` AS SIGNED) - 3700000 AND s2.`name` = t.`name`))
JOIN `cata_world`.`gameobject_template_addon` s ON s.`entry` = cs.`entry`
WHERE t.`entry` IN (SELECT DISTINCT `id` FROM acore_world.`gameobject` WHERE `map` = 750)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_template_addon` a WHERE a.`entry` = t.`entry`)
  -- only rows that actually carry something; the 112 all-default ones are no-ops
  AND (s.`faction` <> 0 OR s.`flags` <> 0)
  -- never import a faction this build cannot resolve (the 287_ Land Mine trap)
  AND (s.`faction` = 0
       OR EXISTS (SELECT 1 FROM acore_world.`factiontemplate_dbc` f WHERE f.`ID` = s.`faction`));

-- mingold/maxgold/artkits are written as literal 0 rather than copied from the
-- source: they are zero across this entire set (measured), and cata_world has an
-- artkit4 column this fork does not, so a SELECT * style copy would not line up.

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--   -- 62 new rows:
--   SELECT COUNT(*) FROM gameobject_template_addon
--    WHERE entry IN (SELECT DISTINCT id FROM gameobject WHERE map=750);
--       -> 934   (was 872)
--   NOTE the 872/934 figures are for ALL 1,048 map-750 templates. The 532 quoted
--   in the header is a different, narrower number -- it counts only the 706 that
--   resolve to a cata_world source. The other 342 are DC-authored/Legion and 340
--   of those already had addon rows, which is what makes the total 872.
--
--   -- the material gap is closed, and the 112 no-ops are still absent on
--   -- purpose, so this must report 112 and NOT 0:
--   SELECT COUNT(*) FROM gameobject_template t
--    WHERE t.entry IN (SELECT DISTINCT id FROM gameobject WHERE map=750)
--      AND NOT EXISTS(SELECT 1 FROM gameobject_template_addon a WHERE a.entry=t.entry)
--      AND COALESCE(
--          (SELECT s.entry FROM cata_world.gameobject_template s
--            WHERE s.entry=CAST(t.entry AS SIGNED)-3600000 AND s.name=t.name),
--          (SELECT s.entry FROM cata_world.gameobject_template s
--            WHERE s.entry=CAST(t.entry AS SIGNED)-3700000 AND s.name=t.name)) IS NOT NULL;
--       -> 112
--
--   -- spot checks:
--   SELECT entry, faction, flags FROM gameobject_template_addon
--    WHERE entry IN (3701731, 3894620, 3894107, 3908192);
--       -> 3701731 Copper Vein            faction 94,   flags 0
--          3894620 Mailbox                faction 1735, flags 0
--          3894107 Encrusted Clam         faction 0,    flags 4  (INTERACT_COND)
--          3908192 Snow-Covered Burrow    faction 114,  flags 32 (NODESPAWN)
--
--   -- and no invalid faction may have slipped in anywhere:
--   SELECT COUNT(*) FROM gameobject_template_addon a
--    WHERE a.faction > 0
--      AND NOT EXISTS (SELECT 1 FROM factiontemplate_dbc f WHERE f.ID = a.faction);
--       -> 0
--
--   -- boot log must stay clean: no new "has invalid faction ... defined in
--   -- `gameobject_template_addon`" lines (that class was closed in 287_).
--
-- IN-GAME CHECK THAT MATTERS: the ~40 quest objects gaining GO_FLAG_INTERACT_COND
-- (0x04) should stop being clickable by players who do not hold the quest.
-- Encrusted Clam (139 spawns in Darkshore) is the easiest one to test.
--
-- REVERT
--   Re-run the audit query in this header and delete exactly the entries it
--   returns; or, if nothing else has touched the table since:
--   DELETE FROM gameobject_template_addon
--    WHERE entry IN (SELECT DISTINCT id FROM gameobject WHERE map=750)
--      AND (mingold, maxgold, artkit0, artkit1, artkit2, artkit3) = (0,0,0,0,0,0)
--      AND entry NOT IN ( ... the 532 that already existed ... );
--   -- safest is the audit-query form; the 532 pre-existing rows are not listed
--   -- here and must not be caught by a broad delete.
--
-- ---------------------------------------------------------------------------
-- Scope note -- this file covers map 750 ONLY
-- ---------------------------------------------------------------------------
-- The question asked was about 750. The same gap very likely exists on the other
-- imported maps (751 Plaguelands, 861 Molten Front, 820 BFD, and the Kalimdor
-- clone bands spawned elsewhere). Memory already records 751 and Blackwing
-- Descent losing GO_FLAG_TRANSPORT 0x08 this way, which is the more dangerous
-- variant because it makes elevators drop players through the floor. Auditing
-- those is a follow-up rather than something to widen this file into: each band
-- needs its own source DB and its own name-match check, and 751's known 0x08
-- cases deserve an in-game test rather than a bulk import.
