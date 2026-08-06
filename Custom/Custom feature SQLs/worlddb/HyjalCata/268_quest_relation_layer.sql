-- ---------------------------------------------------------------------------
-- 268  Restore the questgiver relation layer for the orphaned Cata quests
-- ---------------------------------------------------------------------------
-- 267_ made 62 unreachable quests structurally complete and said the real fix
-- was this: 1,801 quest_template rows have NO questgiver of any kind, because
-- the Cata quest layer was imported as templates without its relation layer.
-- This restores the part of it that can be restored SAFELY and provably.
--
-- What the 1,801 actually decompose into:
--
--   1,801  orphaned quests (no creature, gameobject or item starter)
--     327  have a creature starter in cata_world           <- the workable set
--      68  of those name a giver that exists on neither side at any id
--     117  name a giver that exists BOTH at the raw id AND as a +3,600,000
--          clone -- genuinely ambiguous, see below
--     142  name a giver that exists at exactly ONE of the two  <- imported here
--  ~1,400  have no starter in cata_world OR nelt_world either
--
-- That last number is the honest headline: **most orphans are not a lost
-- import.** They are quests the source DBs have no giver for either -- follow-up
-- steps in chains, script-started quests, class/profession content. No amount of
-- relation porting fixes them.
--
-- ============================ THE THREE GATES ==============================
--
-- 🔴 GATE 1 -- IDENTITY. The source names a RAW creature id; on our side that id
-- may hold a completely different creature. Comparing names caught 11 such
-- pairs. Ten were harmless expansion renames of the same NPC (Cata retitled
-- "Commander Eligor Dawnbringer" to "Crusade Commander..." and renamed the
-- Barrens/Stranglethorn flame keepers with their zones), but one was a real id
-- collision: cata 36795 is "Ruckus", ours is **Scourgelord Tyrannus**. Wiring
-- quest 24437 onto Tyrannus would have been a live bug, not a gap. Every pair
-- here is name-validated; 25920 and 25943 are the two allow-listed renames.
--
-- 🔴 GATE 2 -- AMBIGUITY. 117 pairs have the giver at BOTH the raw id and the
-- +3,600,000 clone, and the two are different NPCs in different places: the raw
-- is the stock WotLK one on map 0/1, the clone is the Cata one on map 750/751.
-- Picking wrong puts a Cata quest on a stock NPC in the wrong version of the
-- zone. It cannot be resolved from data -- I tried both obvious signals:
--   * per-zone majority fails, because both versions legitimately coexist
--     (Felwood 69% clone, Ashenvale 52%, Eastern Plaguelands 47%);
--   * quest_poi resolves 1 of the 117 -- the rest have no POI rows.
-- So all 117 are LEFT OUT. They need a per-quest content decision about which
-- version of the zone each belongs to, and a guess would be worse than the gap.
--
-- 🔴 GATE 3 -- COMPLETABILITY, and this one changed the shape of the file. Of
-- the 140 quests that would gain a starter, **29 have no questender, gain none
-- here, and are not auto-complete**. Enabling those would let a player accept a
-- quest that can NEVER be turned in and sits in their log forever -- strictly
-- worse than leaving it unofferable. Starters are therefore gated on the quest
-- having a turn-in path, which is why the enders are inserted FIRST: 75 quests
-- already have an ender, 23 gain one below, 13 are auto-complete (Flags & 128),
-- and the remaining 29 are skipped.
--
-- NET EFFECT: ~111 quests become genuinely playable, on 106 already-spawned
-- NPCs. That is real content, not log cleanup -- unlike 267_, which was
-- explicitly cosmetic.
--
-- Every statement re-derives its own set at apply time from the same guards, so
-- the file is idempotent and cannot act on anything that has since changed.

-- ---- 1. questENDERS first -- gate 3 depends on these existing ---------------
DELETE FROM acore_world.`creature_questender` WHERE (`id`,`quest`) IN (
  SELECT * FROM (
    SELECT IF(o.entry IS NOT NULL, e.id, e.id + 3600000) AS gid, e.quest
    FROM cata_world.creature_questender e
    JOIN cata_world.creature_template ct ON ct.entry = e.id
    JOIN acore_world.quest_template q ON q.ID = e.quest
    LEFT JOIN acore_world.creature_template o ON o.entry = e.id
    LEFT JOIN acore_world.creature_template o36 ON o36.entry = e.id + 3600000
    WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
      AND (COALESCE(o.name, o36.name) = ct.name OR e.id IN (25920,25943))
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
  ) t
);

INSERT INTO acore_world.`creature_questender` (`id`,`quest`)
SELECT IF(o.entry IS NOT NULL, e.id, e.id + 3600000), e.quest
FROM cata_world.creature_questender e
JOIN cata_world.creature_template ct ON ct.entry = e.id
JOIN acore_world.quest_template q ON q.ID = e.quest
LEFT JOIN acore_world.creature_template o ON o.entry = e.id
LEFT JOIN acore_world.creature_template o36 ON o36.entry = e.id + 3600000
WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
  AND (COALESCE(o.name, o36.name) = ct.name OR e.id IN (25920,25943))
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID);

DELETE FROM acore_world.`gameobject_questender` WHERE (`id`,`quest`) IN (
  SELECT * FROM (
    SELECT IF(o.entry IS NOT NULL, e.id, e.id + 3600000) AS gid, e.quest
    FROM cata_world.gameobject_questender e
    JOIN cata_world.gameobject_template gt ON gt.entry = e.id
    JOIN acore_world.quest_template q ON q.ID = e.quest
    LEFT JOIN acore_world.gameobject_template o ON o.entry = e.id
    LEFT JOIN acore_world.gameobject_template o36 ON o36.entry = e.id + 3600000
    WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
      AND COALESCE(o.name, o36.name) = gt.name
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
  ) t
);

INSERT INTO acore_world.`gameobject_questender` (`id`,`quest`)
SELECT IF(o.entry IS NOT NULL, e.id, e.id + 3600000), e.quest
FROM cata_world.gameobject_questender e
JOIN cata_world.gameobject_template gt ON gt.entry = e.id
JOIN acore_world.quest_template q ON q.ID = e.quest
LEFT JOIN acore_world.gameobject_template o ON o.entry = e.id
LEFT JOIN acore_world.gameobject_template o36 ON o36.entry = e.id + 3600000
WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
  AND COALESCE(o.name, o36.name) = gt.name
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID);

-- ---- 2. questSTARTERS, gated on a turn-in path existing --------------------
-- The `Flags & 128` term is QUEST_FLAGS_AUTOCOMPLETE: those turn themselves in
-- and legitimately need no ender.
DELETE FROM acore_world.`creature_queststarter` WHERE (`id`,`quest`) IN (
  SELECT * FROM (
    SELECT IF(o.entry IS NOT NULL, s.id, s.id + 3600000) AS gid, s.quest
    FROM cata_world.creature_queststarter s
    JOIN cata_world.creature_template ct ON ct.entry = s.id
    JOIN acore_world.quest_template q ON q.ID = s.quest
    LEFT JOIN acore_world.creature_template o ON o.entry = s.id
    LEFT JOIN acore_world.creature_template o36 ON o36.entry = s.id + 3600000
    WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
      AND (COALESCE(o.name, o36.name) = ct.name OR s.id IN (25920,25943))
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_queststarter` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_queststarter` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.startquest = q.ID)
      AND (EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
           OR EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
           OR (q.Flags & 128) > 0)
  ) t
);

INSERT INTO acore_world.`creature_queststarter` (`id`,`quest`)
SELECT IF(o.entry IS NOT NULL, s.id, s.id + 3600000), s.quest
FROM cata_world.creature_queststarter s
JOIN cata_world.creature_template ct ON ct.entry = s.id
JOIN acore_world.quest_template q ON q.ID = s.quest
LEFT JOIN acore_world.creature_template o ON o.entry = s.id
LEFT JOIN acore_world.creature_template o36 ON o36.entry = s.id + 3600000
WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
  AND (COALESCE(o.name, o36.name) = ct.name OR s.id IN (25920,25943))
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_queststarter` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_queststarter` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.startquest = q.ID)
  AND (EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
       OR EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
       OR (q.Flags & 128) > 0);

DELETE FROM acore_world.`gameobject_queststarter` WHERE (`id`,`quest`) IN (
  SELECT * FROM (
    SELECT IF(o.entry IS NOT NULL, s.id, s.id + 3600000) AS gid, s.quest
    FROM cata_world.gameobject_queststarter s
    JOIN cata_world.gameobject_template gt ON gt.entry = s.id
    JOIN acore_world.quest_template q ON q.ID = s.quest
    LEFT JOIN acore_world.gameobject_template o ON o.entry = s.id
    LEFT JOIN acore_world.gameobject_template o36 ON o36.entry = s.id + 3600000
    WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
      AND COALESCE(o.name, o36.name) = gt.name
      AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_queststarter` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_queststarter` x WHERE x.quest = q.ID)
      AND NOT EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.startquest = q.ID)
      AND (EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
           OR EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
           OR (q.Flags & 128) > 0)
  ) t
);

INSERT INTO acore_world.`gameobject_queststarter` (`id`,`quest`)
SELECT IF(o.entry IS NOT NULL, s.id, s.id + 3600000), s.quest
FROM cata_world.gameobject_queststarter s
JOIN cata_world.gameobject_template gt ON gt.entry = s.id
JOIN acore_world.quest_template q ON q.ID = s.quest
LEFT JOIN acore_world.gameobject_template o ON o.entry = s.id
LEFT JOIN acore_world.gameobject_template o36 ON o36.entry = s.id + 3600000
WHERE ((o.entry IS NULL) <> (o36.entry IS NULL))
  AND COALESCE(o.name, o36.name) = gt.name
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_queststarter` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_queststarter` x WHERE x.quest = q.ID)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.startquest = q.ID)
  AND (EXISTS (SELECT 1 FROM acore_world.`creature_questender` x WHERE x.quest = q.ID)
       OR EXISTS (SELECT 1 FROM acore_world.`gameobject_questender` x WHERE x.quest = q.ID)
       OR (q.Flags & 128) > 0);

-- ---- 3. UNIT_NPC_FLAG_QUESTGIVER on the resolved givers --------------------
-- A relation row on a creature without npcflag 2 logs "has creature entry (N)
-- for quest M, but npcflag does not include UNIT_NPC_FLAG_QUESTGIVER" and the
-- NPC shows no quest marker -- the same defect 261_ fixed for six Winterspring
-- rares. Only 4 of the 117 resolved givers need it, but it is derived rather
-- than hardcoded so it stays correct if the sets above change. OR'd, never
-- assigned, so nothing already on the template is lost.
UPDATE acore_world.`creature_template` ct
SET ct.`npcflag` = ct.`npcflag` | 2
WHERE (ct.`npcflag` & 2) = 0
  AND (EXISTS (SELECT 1 FROM acore_world.`creature_queststarter` r WHERE r.id = ct.`entry`)
       OR EXISTS (SELECT 1 FROM acore_world.`creature_questender` r WHERE r.id = ct.`entry`));

-- Verify after apply:
--   * relations added:  creature_queststarter +~111, creature_questender +31,
--     gameobject_queststarter/_questender a handful each.
--   * NO quest may be acceptable without a turn-in path -- this must be 0:
--       SELECT q.ID FROM quest_template q
--        WHERE EXISTS (SELECT 1 FROM creature_queststarter r WHERE r.quest=q.ID)
--          AND NOT EXISTS (SELECT 1 FROM creature_questender r WHERE r.quest=q.ID)
--          AND NOT EXISTS (SELECT 1 FROM gameobject_questender r WHERE r.quest=q.ID)
--          AND (q.Flags & 128) = 0
--          AND q.ID IN (<the ids this file touched>);
--   * no new "npcflag does not include UNIT_NPC_FLAG_QUESTGIVER" lines.
--   * the orphan count drops from 1,801 by ~111.
--
-- STILL OPEN, deliberately:
--   * the 117 ambiguous pairs -- need a per-quest call on which version of the
--     zone (stock map 0/1 vs DC map 750/751) each quest belongs to.
--   * the 29 starter-without-ender quests -- need their ender found or authored.
--   * the 68 whose giver exists nowhere, and the ~1,400 with no source relation
--     at all. The latter are not a porting gap and will not be fixed by one.
