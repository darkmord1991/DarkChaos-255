-- =====================================================================
-- Deepholm Downport  --  31  Credit SmartAI cleanup (load-warning fixes)
-- ---------------------------------------------------------------------
-- The Neltharion credit-script port (21) hit a TrinityCore<->AzerothCore SmartAI
-- divergence: higher action ids differ (action 85 = INVOKER_CAST in TC, but
-- SELF_CAST/unhandled in this AC fork), and 21 over-set AIName on credit proxies
-- Neltharion had no script for. Result = harmless load warnings:
--   * "SmartAI enabled but no entries"  (AIName set, no rows)
--   * "Not handled action_type(85)"      (TC INVOKER_CAST chains, skipped)
-- This file cleans them and keeps the credits that actually work on AC.
-- (The SPELLHIT->CALL_KILLEDMONSTER credits 44229/44768 use stable ids and are fine;
--  missing CAST spells 86808/80470 are added by 32; 84276 isn't in the Cata client
--  so its one row stays skipped; the 42465/44135 TALK lines need creature_text -
--  cosmetic, deferred.)
-- =====================================================================

-- A) Revert AIName on credit-proxy creatures with no working SmartAI rows
--    (they're invisible kill-credit targets / unscripted proxies -> default AI).
UPDATE `creature_template` SET `AIName`='' WHERE `entry` IN
 (43027,43028,43029,43038,43164,43165,43166,43167,43597,43640,43649,43978,44025,44051,
  44133,44228,44281,44290,44772,46139,53744,44900,44938,45083,45091);

-- B) Terrath (42466) / Felsen (43805): replace the un-portable TC chain with a simple
--    AC-native talk credit (gossip-hello -> CALL_KILLEDMONSTER on the player). Stable
--    action ids; this is the same pattern the original 18 used and it works on AC.
DELETE FROM `smart_scripts` WHERE `source_type`=0 AND `entryorguid` IN (42466,43805);
DELETE FROM `smart_scripts` WHERE `source_type`=9 AND `entryorguid` IN (4246600,4246601);
UPDATE `creature_template` SET `AIName`='SmartAI' WHERE `entry` IN (42466,43805);
INSERT INTO `smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
 `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
 `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
 `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(42466,0,0,0,64,0,100,0,0,0,0,0,0,0,33,46139,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Terrath the Steady - gossip hello -> Speak-to-Terrath credit 46139'),
(43805,0,0,0,64,0,100,0,0,0,0,0,0,0,33,44281,0,0,0,0,0,7,0,0,0,0,0,0,0,0,'Felsen the Enduring - gossip hello -> Speak-to-Felsen credit 44281');
