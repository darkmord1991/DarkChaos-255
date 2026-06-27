-- =====================================================================
-- Deepholm Downport  --  18  Quest credit-granting logic  (map 646)
-- ---------------------------------------------------------------------
-- Target: acore_world.  Run AFTER 01 + 11 + 17.
--
-- AUDIT RESULT (step 1): cata_world and the TrinityCore source contain NO
-- SmartAI (action 33) and NO spell-effect (KILL_CREDIT) logic for the 28
-- quest-objective "credit proxy" NPCs -- TDB ships these Deepholm quests
-- data-incomplete. So nothing could be *ported*; the credit had to be
-- *authored* from the quest structure. Of the 28:
--   * 2 already work natively via creature_template.KillCredit (44135 <- Zoltrik
--     Drakebane; 44228 <- Twilight Dragonspawn/Scalesister/Scalesworn Cultist).
--   * 1 is out of scope (42188 Ozruk, Stonecore dungeon).
--   * 25 need authored logic; only the ones below have an unambiguous trigger
--     in the data. The rest are flagged at the bottom (need retail design data).
--
-- Pattern used: talk-credit = SmartAI GOSSIP_HELLO (event 64) -> KILLEDMONSTER
-- (action 33) on the invoker (target 7); kill-credit = creature_template.KillCredit1.
-- KILLEDMONSTER only counts if the player is on the matching quest objective,
-- so firing on every gossip/kill is safe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- HIGH-CONFIDENCE: kill credits (native KillCredit)
-- ---------------------------------------------------------------------
-- Quest 26849/27932 "The Axe of Earthly Sundering" -- kill 5 Emerald Colossus
-- (44218, spawned x14) -> "Sundered Emerald Colossus" credit (44229).
UPDATE `creature_template` SET `KillCredit1` = 44229 WHERE `entry` = 44218 AND `KillCredit1` = 0;

-- ---------------------------------------------------------------------
-- HIGH-CONFIDENCE: talk credits (SmartAI gossip -> credit)
-- ---------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` IN (42466, 43805);

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (42466, 43805);

INSERT INTO `smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
 `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
 `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
 `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
-- Quest 26656 "Don't. Stop. Moving." -- Speak to Terrath the Steady (42466) -> credit 46139
(42466,0,0,0, 64,0,100,0, 0,0,0,0,0,0, 33,46139,0,0,0,0,0, 7,0,0,0,0, 0,0,0,0, 'Terrath the Steady - On Gossip Hello - quest credit Speak to Terrath (46139)'),
-- Quest 26426 "Violent Gale" -- Speak to Felsen the Enduring (43805) -> credit 44281
(43805,0,0,0, 64,0,100,0, 0,0,0,0,0,0, 33,44281,0,0,0,0,0, 7,0,0,0,0, 0,0,0,0, 'Felsen the Enduring - On Gossip Hello - quest credit Speak to Felsen (44281)');

-- ---------------------------------------------------------------------
-- MEDIUM-CONFIDENCE (best-guess trigger -- enable after verifying in-game)
-- ---------------------------------------------------------------------
-- Quest 27050 "Fungal Fury" -- stomp 10 mushrooms (44900). Doomshroom (43388,
-- spawned x76) is the most likely target, but several fungal mobs exist; verify
-- it's the right one before enabling.
-- UPDATE `creature_template` SET `KillCredit1` = 44900 WHERE `entry` = 43388 AND `KillCredit1` = 0;

-- ---------------------------------------------------------------------
-- FLAGGED -- need retail design data (trigger not determinable from our sources)
-- ---------------------------------------------------------------------
-- These have no gossip menu, ambiguous targets, or non-trivial mechanics
-- (escort / areatrigger / GO-interaction / scripted event). Each needs the
-- specific NPC/mob/GO + mechanic confirmed from retail (wowhead/sniffs):
--   45083  On Even Ground            -> interact 3x Servant of Therazane (no gossip; duel or talk?)
--   44772  Question the Slaves        -> talk 6x Enslaved Miner (44768) (no gossip menu)
--   44133  Rallying the Earthen Ring  -> rally 5x Earthen Ring Shaman (no gossip menu)
--   44938  Quicksilver Submersion     -> "Eavesdropping" (areatrigger / reach, not talk)
--   44051  Audience with the Stonemother -> talk Therazane (3 entries: 42465/44025/...) scripted audience
--   43164/43165/43166/43167  Sealing the Way -> 4 distinct seal objectives (GO/kill?)
--   43649  Close Escort              -> escort completion credit (needs escort waypoints + end)
--   43978  Keep Them off the Front    -> kill 30 front-line attackers (mob unidentified)
--   44290  One With the Ground        -> kill 1 (target unidentified)
--   43597  Don't. Stop. Moving. (Rockcandy)  -> item/interaction credit
--   43027/43028/43029  (Clues)        -> GO-click credits (GOs unidentified)
--   43038  Agitated Tunneler Transform / 43640 Resonating Blow / 45091 Depleted Totem -> item/transform
--   53744  Elemental Bonds Event Controller  -> scripted C++ set-piece
--   42188  Ozruk                      -> Stonecore dungeon (out of scope)
-- =====================================================================
