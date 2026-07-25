-- ---------------------------------------------------------------------------
-- 116  Hyjal round-14 -- quest objectives pointing at dead un-offset shells
-- ---------------------------------------------------------------------------
-- Nine objectives across eight map-750 quests require a RAW Cata creature id
-- while every credit-giver on the server (C++ script constant, SmartAI kill
-- credit, or the credit NPC itself) uses the +3,600,000 clone.  The quests are
-- therefore uncompletable -- the objective can never tick.
--
-- The raw ids do exist in creature_template, which is why nothing errors at
-- boot: an earlier pass (84_) copied quest data from cata_world and pulled the
-- objective templates across un-offset.  Those shells have VerifiedBuild=15595,
-- no AIName, no ScriptName and ZERO spawns; the live ones are the clones:
--
--   25233 End of the Supply Line   39436 -> 3639436  (npc_twilight_proveditor)
--   25294 Walking the Dog          39673 -> 3639673  (npc_spawn_of_smolderos_dog
--                                                     calls KilledMonsterCredit
--                                                     with 3639673)
--   25315 Graduation Speech        40618 -> 3640618  (C++ NPC_ constant)
--   25392 Oh, Deer!                40031 -> 3640031  (credit NPC itself)
--   25502 Prepping the Soil        40461 -> 3640461  (NPC_KILL_CREDIT_OBJ_1)
--   25502 Prepping the Soil        40462 -> 3640462  (NPC_KILL_CREDIT_OBJ_2)
--   25523 Flight in the Firelands  47459 -> 3647459  (Guardian Flag Tracker)
--   25574 Flames from Above        40856 -> 3640856  (npc_emerald_flameweaver_
--                                                     infiltrators)
--   29101 Punting Season           52177 -> 3652177  (npc_punt_child_of_tortolla
--                                                     credits NPC_PUTING_SEASON_
--                                                     CREDIT = 3652177)
--
-- 29101 deserves a note: the Turtle Punter's SmartAI *does* credit the raw
-- 52177 -- but that SmartAI never runs, because 3652988 also carries
-- ScriptName 'npc_turtle_punter' and FactorySelector::SelectAI checks the
-- ScriptName BEFORE AIName (CreatureAISelector.cpp).  The live path is the C++
-- one, which credits 3652177, so the quest is realigned onto the clone rather
-- than the other way round.
--
-- Each UPDATE is guarded on the exact current value and on the clone existing,
-- so it is idempotent and cannot point a quest at a missing entry.
-- ---------------------------------------------------------------------------

UPDATE `quest_template` q SET q.`RequiredNpcOrGo1` = q.`RequiredNpcOrGo1` + 3600000
WHERE q.`ID` IN (25233,25294,25315,25392,25502,25523,25574,29101)
  AND q.`RequiredNpcOrGo1` IN (39436,39673,40618,40031,40461,47459,40856,52177)
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = q.`RequiredNpcOrGo1` + 3600000);

UPDATE `quest_template` q SET q.`RequiredNpcOrGo2` = q.`RequiredNpcOrGo2` + 3600000
WHERE q.`ID` = 25502 AND q.`RequiredNpcOrGo2` = 40462
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = q.`RequiredNpcOrGo2` + 3600000);

-- The eight now-unreferenced un-offset shells are left in creature_template on
-- purpose: they are inert (no spawns, no AI) and deleting them would break the
-- ON DELETE-less quest_template_addon / creature_queststarter rows that other
-- passes may still reference.  They cost one row each.

-- ---------------------------------------------------------------------------
-- Not fixed here -- quest 29147 "Call the Flock" requires Alpine Songbird
-- (52595) and Forest Owl (52596), which have no +3,600,000 clone at all.
-- 118_ imports those templates; their 86 nelt spawns are a separate content
-- job (see 00_README round-14 section).
-- ---------------------------------------------------------------------------
