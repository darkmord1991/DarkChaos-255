-- ---------------------------------------------------------------------------
-- 156  Hyjal round-25 -- stop questgivers and vendors brawling
-- ---------------------------------------------------------------------------
-- Reported in-game: quest NPCs and vendors are in combat constantly, which
-- makes them hard or impossible to interact with.
--
-- NOT A FACTION BUG.  Comparing every questgiver/vendor on maps 750/861 against
-- `nelt_world`, only TWO templates differ from the source (Alysra 35 -> 2233,
-- Matoclaw 2233 -> 2252).  The factions were ported faithfully; 2252/2233 are
-- the Guardians of Hyjal, who are legitimately at war with the Firelands and
-- Twilight factions.
--
-- CAUSE: the same unported phase set behind rounds 21 and 25.  In Cata the
-- invasion mobs and the peaceful camp occupy DIFFERENT PHASES at different
-- points in the chain.  DC flattened everything into phaseMask 1, so the
-- invaders now stand permanently inside the camps.  Measured distance from a
-- questgiver/vendor to the nearest hostile on map 750:
--
--     Captain Saynna Stormrunner    3 yards from a Raging Invader
--     Mylune                        4
--     Elderlimb                    10   (Brimstone Destroyer)
--     Nenduil Meadowshade          11
--     Inoho Stronghide             12
--     Matoclaw                     18
--     Malfurion / Hamuul           21   (Charred Invader)
--
-- FIX: give the service NPCs UNIT_FLAG_IMMUNE_TO_NPC (0x200,
-- UnitDefines.h:266 -- "disables combat/assistance with NonPlayerCharacters").
-- This is the standard treatment for town NPCs and is the minimal change that
-- works here:
--   * the invaders stay exactly where they are and remain killable by players,
--     so the quests that need them are untouched;
--   * players can still attack the NPC if it is ever flagged for that, because
--     IMMUNE_TO_PC (0x100) is deliberately NOT set;
--   * no phase surgery, which would be a zone-wide redesign.
--
-- The pattern already exists in this data -- 28 of the 127 questgiver/vendor
-- templates on these maps carry the flag already.  This brings the other 99
-- into line rather than inventing a new convention.
--
-- Scope is limited to templates that actually have the questgiver (2) or vendor
-- (128) npcflag AND are spawned on map 750/861, so guards, invasion defenders
-- and other combat NPCs keep fighting as intended.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` ct
SET ct.`unit_flags` = ct.`unit_flags` | 512
WHERE (ct.`npcflag` & 130) <> 0
  AND (ct.`unit_flags` & 512) = 0
  AND EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = ct.`entry` AND c.`map` IN (750, 861));
