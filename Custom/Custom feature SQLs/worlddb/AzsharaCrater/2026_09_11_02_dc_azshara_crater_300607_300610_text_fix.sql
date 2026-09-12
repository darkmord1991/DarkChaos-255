-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- quest text for 300607 / 300610 matches the targets
-- ---------------------------------------------------------------------------
-- Both quests became obtainable with 2026_09_11_00_dc_azshara_crater_quest_relation_restore.sql,
-- and both describe creatures they do not ask for:
--
--   300607 "Killers in the Dark"
--     text:    8 Jadefire Betrayers + 6 Jadefire Shadowstalkers
--     targets: 8 Jadefire Felsworn (7109, 3 spawns) + 6 Jadefire Rogue (7106, 6 spawns)
--   300610 "Bounty: Obsidion"
--     text:    Obsidion
--     target:  The Ravenian (10507, 1 spawn, elite undead)
--
-- Text is changed, not targets:
--   * Obsidion (8400) and Jadefire Betrayer (7108) have no spawn on any map, so
--     pointing the objectives at them would make both quests uncompletable again.
--   * Jadefire Shadowstalker (7110) IS on the crater (5 spawns), but swapping it in
--     would leave the objective-2 map area of 300607 drawn around the Rogue camp
--     (2026_07_14_01_dc_azshara_crater_quest_pois_areas.sql builds it from 7106).
--
-- The rewrite keeps the 2026_07_14_00 lore voice and structure. The Jadefire are
-- satyrs (Highborne twisted by the Legion); The Ravenian is a Scholomance elite
-- (wight model), so it is described as undead rather than a shadowguard.
-- Each UPDATE is guarded on the current objective ids, so it does nothing if the
-- targets have been changed since.
--
-- No quest_offer_reward / quest_request_items rows exist for either quest; none
-- are added.
--
-- Apply, then `.reload quest_template` (or restart). Clients that cached the
-- old text see the new text after their WDB cache is cleared.
-- ---------------------------------------------------------------------------

UPDATE `quest_template`
SET `LogDescription` = 'Kill 8 Jadefire Felsworn and 6 Jadefire Rogues.',
    `QuestDescription` = 'Not all the Jadefire meet you face to face, $N. The worst of them wait in the dark.$B$BThe Felsworn were Highborne once, night elves who knelt to the Legion and let it twist them into satyrs. They share my title and nothing else: I swore myself to hunt the fel, and they swore themselves to serve it. Their rogues slip between the trees and open throats before a blade is even drawn.$B$BGo into the shadow and find them first. Eight Felsworn, six rogues. Let them learn what it is to be hunted.',
    `QuestCompletionLog` = 'The shadow-killers are hunted down.'
WHERE `ID` = 300607
  AND `RequiredNpcOrGo1` = 7109
  AND `RequiredNpcOrGo2` = 7106;

UPDATE `quest_template`
SET `LogTitle` = 'Bounty: The Ravenian',
    `LogDescription` = 'Slay The Ravenian.',
    `QuestDescription` = 'At the heart of it all stands the Ravenian, $N. A hulking, grave-cold horror dragged up from the crypts of Scholomance and set to watch over the ground where the deepest corruption festers.$B$BNothing passes it. I have tried, and I bear the marks of it. Whatever the satyrs and their demon masters are hiding beyond its post, they guard it with everything they have.$B$BBreak through and destroy it. Put the Ravenian down, and open the way to whatever waits within.',
    `QuestCompletionLog` = 'The Ravenian has been destroyed.'
WHERE `ID` = 300610
  AND `RequiredNpcOrGo1` = 10507;
