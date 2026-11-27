-- =====================================================================
-- Mount Hyjal (acore map 750) : nelt_world richer-source gap
-- DRAFT / NEEDS USER DECISION -- DO NOT APPLY BLINDLY
-- =====================================================================
-- Verified facts (2026-06-30):
--   nelt_world Hyjal (map 1, zone/area 616): 2945 spawns / 381 templates
--   acore_world map 750 (the cata-sourced port): 4928 spawns / 318 templates
--   Templates in nelt NOT in port (orig = nelt.id):           119
--   Of those 119: 116 are nelt-EXCLUSIVE (0 spawns in cata_world),
--                 3 exist in cata elsewhere (7446 Rabid Shardtooth @ zone 618 = classic Hyjal,
--                 53697 Cinderling @ Firelands raid 861, 52526 Ruby's Dance Vehicle).
--   Missing spawns total: 628  (132 = "Wondi's Bunny" trigger junk / 37 tmpl,
--                                496 = real content / 82 tmpl)
--   dc-entry (orig+3,600,000) collisions in acore_world.creature_template: 0  (safe)
--   max acore_world.creature.guid = 9836243  (start new guids above a safe base)
--
-- The port is NOT broken: it already has 59 questgiver templates / 100 questgiver
-- spawns on map 750. The gap is the END-GAME LAYER that only nelt has:
--   * Molten Front daily hub + Firelands invasion (75xxx, 52xxx, 53xxx)
--   * Dragon-aspect finale event NPCs (Alexstrasza 54176, Nozdormu 54174, Ysera 54172,
--     Malfurion 54173, Thrall 54168, Jaina 54180, Tyrande 54179, Kalecgos 54175)
--   * The four Molten Lords: Andrazor 53267, Kelbnar 53265, Searris 53264, Fah Jarakk 53271,
--     plus Magria 54319 (rank 4)
--   * Hub questgivers/vendors/innkeeper: Hamuul Runetotem (52932/75166 dup), Choluna 50080,
--     Skylord Omnuron 50082, Captain Soren Moonfall 53073, Isara Riverstride (Innkeeper) 50068,
--     Jandunel Reedwind (General Goods vendor) 50070, Elder Windsong 55224, Elder Evershade 55227
--
-- RECOMMENDATION: import only the "real content" tier (exclude the 37 Wondi's Bunny
-- spawn-trigger templates -- those need the matching SmartAI/spell scripts to do
-- anything and will be inert clutter on 3.3.5). Even within the real tier, the
-- Molten Front / Firelands-invasion content is heavily scripted (daily-quest phasing,
-- vehicle events) and will spawn but NOT function without porting the scripts. The
-- safest high-value subset to add is: the standing questgivers / vendors / innkeeper
-- / flightpath NPCs + named elites, which give visible, mostly-functional content.
--
-- All statements below are TEMPLATES. The schemas differ (acore single `faction`
-- vs nelt `faction_A`/`faction_H`; acore has modelid1-4 + *Modifier cols nelt lacks),
-- so a cross-DB INSERT..SELECT must map columns explicitly and supply defaults.
-- Cross-database INSERT requires both schemas on one server (they are here).
-- =====================================================================

-- ---------- 0. Reusable selector: the "real" missing nelt Hyjal entries ----------
-- (excludes Wondi's Bunny trigger junk). Inspect before committing.
-- SELECT DISTINCT n.id
--   FROM nelt_world.creature n
--   JOIN nelt_world.creature_template ct ON ct.entry = n.id
--  WHERE n.map = 1 AND (n.zone = 616 OR n.area = 616)
--    AND n.id NOT IN (SELECT id - 3600000 FROM acore_world.creature WHERE map = 750)
--    AND ct.name NOT LIKE '%Bunny%' AND ct.name NOT LIKE 'Wondi%';

-- ---------- 1. CLONE TEMPLATES (entry = orig + 3,600,000) ----------
-- Map nelt -> acore columns. Defaults supplied for acore-only cols.
-- NOTE: modelid1 taken from the nelt SPAWN's modelid (template-level model may be 0
-- in nelt); pick the most common per entry. Adjust faction if 616 is Horde-side.
INSERT INTO acore_world.creature_template
      (entry, name, subname, minlevel, maxlevel, faction, npcflag, `rank`,
       unit_flags, ScriptName,
       modelid1, modelid2, modelid3, modelid4,
       DamageModifier, HealthModifier, ManaModifier, ArmorModifier, ExperienceModifier)
SELECT ct.entry + 3600000, ct.name, COALESCE(ct.subname,''),
       ct.minlevel, ct.maxlevel, ct.faction_A, ct.npcflag, ct.`rank`,
       ct.unit_flags, '',                       -- ScriptName: clear (3.3.5 scripts differ)
       (SELECT c.modelid FROM nelt_world.creature c
         WHERE c.id = ct.entry AND c.map = 1 AND (c.zone=616 OR c.area=616)
         ORDER BY c.guid LIMIT 1),              -- modelid1 from a spawn
       0, 0, 0,
       1, 1, 1, 1, 1
  FROM nelt_world.creature_template ct
 WHERE ct.entry IN (
       SELECT DISTINCT n.id FROM nelt_world.creature n
        WHERE n.map = 1 AND (n.zone = 616 OR n.area = 616)
          AND n.id NOT IN (SELECT id - 3600000 FROM acore_world.creature WHERE map = 750)
          AND ct.entry = n.id
 )
   AND ct.name NOT LIKE '%Bunny%' AND ct.name NOT LIKE 'Wondi%'   -- drop trigger junk
   AND (3600000 + ct.entry) NOT IN (SELECT entry FROM acore_world.creature_template);
-- !! VERIFY every cloned template's faction (4.x faction IDs may be absent in WotLK
--    Faction.dbc -- the same parent-faction problem noted for Twilight's Hammer etc.),
--    model (4.x displayId must exist client-side), and that *Modifier=1 is acceptable.

-- ---------- 2. CLONE SPAWNS into map 750 (id = orig + 3,600,000) ----------
-- nelt.creature -> acore.creature column map.
--   nelt.spawndist -> acore.wander_distance ; nelt has no zoneId/areaId split -> use 750 / 4923.
-- Let acore.guid AUTO_INCREMENT assign (do NOT carry nelt guids -- they collide).
INSERT INTO acore_world.creature
      (id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id,
       position_x, position_y, position_z, orientation,
       spawntimesecs, wander_distance, currentwaypoint,
       curhealth, curmana, MovementType, npcflag, unit_flags, ScriptName)
SELECT n.id + 3600000, 750, 4923, 4923,
       COALESCE(n.spawnMask,1), COALESCE(n.phaseMask,1), COALESCE(n.equipment_id,0),
       n.position_x, n.position_y, n.position_z, n.orientation,
       COALESCE(n.spawntimesecs,120), COALESCE(n.spawndist,0), COALESCE(n.currentwaypoint,0),
       0, 0, n.MovementType, COALESCE(n.npcflag,0), COALESCE(n.unit_flags,0), ''
  FROM nelt_world.creature n
  JOIN nelt_world.creature_template ct ON ct.entry = n.id
 WHERE n.map = 1 AND (n.zone = 616 OR n.area = 616)
   AND n.id NOT IN (SELECT id - 3600000 FROM acore_world.creature WHERE map = 750)
   AND ct.name NOT LIKE '%Bunny%' AND ct.name NOT LIKE 'Wondi%'      -- drop trigger junk
   AND (n.id + 3600000) IN (SELECT entry FROM acore_world.creature_template); -- only spawned if template exists

-- ---------- 3. FOLLOW-UPS (must do, else half-broken) ----------
-- a) MovementType=2 (waypoint) spawns need creature_addon.path_id + waypoint_data.
--    nelt stores waypoints elsewhere; any waypoint NPC imported here will stand still
--    until paths are ported. Count them first:
--    SELECT COUNT(*) FROM nelt_world.creature n JOIN nelt_world.creature_template ct ON ct.entry=n.id
--      WHERE n.map=1 AND (n.zone=616 OR n.area=616) AND n.MovementType=2
--        AND n.id NOT IN (SELECT id-3600000 FROM acore_world.creature WHERE map=750)
--        AND ct.name NOT LIKE '%Bunny%' AND ct.name NOT LIKE 'Wondi%';
-- b) Faction.dbc / FactionTemplate parent rows for any 4.x faction not in WotLK
--    (mirror the Twilight's Hammer/Earthen Ring/Therazane fixes already done).
-- c) Vendor NPCs (Jandunel Reedwind 50070, Isara 50068) need npc_vendor rows ported.
-- d) Quest links (creature_questender/queststarter, quest_template) are OUT OF SCOPE
--    here -- adding the NPC does not add its quests.
-- =====================================================================
-- TIER OPTIONS FOR THE USER (pick one before applying):
--   A) NOTHING -- the cata port is already playable; nelt content needs scripts.
--   B) Standing NPCs only (questgivers + vendors + innkeeper + named elites,
--      EXCLUDE 75xxx Molten Front + Firelands-invasion mobs) -- visible & mostly works.
--   C) All "real content" (496 spawns / 82 tmpl) -- but Molten Front/Firelands
--      events stay inert without script ports.
--   D) Everything incl. Wondi's Bunny triggers -- NOT recommended (inert clutter).
-- =====================================================================
