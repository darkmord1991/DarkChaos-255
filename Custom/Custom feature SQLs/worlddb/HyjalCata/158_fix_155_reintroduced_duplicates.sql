-- ---------------------------------------------------------------------------
-- 158  CORRECTIVE -- 155_ undid 154_'s duplicate cleanup
-- ---------------------------------------------------------------------------
-- Self-inflicted, and worth writing down so the shape is not repeated.
--
-- 154_ removed stacked unique NPCs using single-linkage clustering by NAME at a
-- 40-yard radius.  155_ then topped the zone up from cata_world using a
-- proximity guard of only 10 yards, keyed on ENTRY.  Those two do not compose:
--
--   * 10 < 40, so any Cata spawn sitting 10-40 yards from a survivor looked
--     "absent" to 155_ and was re-imported -- re-creating the very stacks 154_
--     had just cleared.
--   * worse, 154_ DELETED rows first, so at the positions it cleaned there was
--     no longer any DC spawn within 10 yards at all, and 155_ put them
--     straight back.  Five Hamuuls, two Malfurions and two Saynnas returned,
--     several at literally 0 yards from a kept spawn.
--
-- 34 of the 1,257 rows 155_ imported are questgiver/vendor templates; those are
-- the ones visible as duplicates.  The other 1,223 are ambient and hostile
-- population and are exactly what was wanted -- they stay.
--
-- FIX, TWO PARTS
--   1. this file deletes the 34 offending rows;
--   2. 155_ has been amended so a re-run cannot reintroduce them: it now skips
--      any template carrying the questgiver (2) or vendor (128) npcflag
--      outright.  That is a flat rule rather than a wider radius, because
--      radius-matching between two files is precisely what failed here.
--      Placement of unique service NPCs belongs to the original port plus
--      154_; 155_'s job is population density, and the two should not both
--      own the same rows.
--
-- Safe to run before or after re-applying 155_ (155_ no longer creates these).
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE c FROM `creature` c
JOIN `creature_template` ct ON ct.`entry` = c.`id`
WHERE c.`guid` BETWEEN 15500000 AND 15599999
  AND (ct.`npcflag` & 130) <> 0;

-- ---------------------------------------------------------------------------
-- Sanity: after this, no unique NPC should have two spawns within 40 yards.
-- The query below should return zero rows -- keep it as the check for any
-- future top-up pass.
--
--   SELECT t1.name, a.guid, b.guid,
--          ROUND(SQRT(POW(a.position_x-b.position_x,2)+POW(a.position_y-b.position_y,2))) d
--   FROM creature a
--   JOIN creature b ON b.map=a.map AND b.guid>a.guid
--   JOIN creature_template t1 ON t1.entry=a.id
--   JOIN creature_template t2 ON t2.entry=b.id
--   WHERE a.map IN (750,861) AND t1.name=t2.name AND (t1.npcflag & 130)<>0
--     AND SQRT(POW(a.position_x-b.position_x,2)+POW(a.position_y-b.position_y,2)) < 40;
-- ---------------------------------------------------------------------------
