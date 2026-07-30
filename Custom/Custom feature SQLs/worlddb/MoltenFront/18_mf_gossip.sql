-- =====================================================================
-- Molten Front (map 861) -- 18  Gossip greetings for five silent NPCs
-- ---------------------------------------------------------------------
-- SYMPTOM: five Molten Front NPCs carry a gossip_menu_id on their template and
-- open a gossip window, but the window is blank -- the menu has no npc_text
-- behind it. Verified: all five MenuIDs have ZERO rows in acore_world.gossip_menu
-- AND zero rows in gossip_menu_option, AND zero rows in BOTH source DBs
-- (nelt_world / cata_world). Nothing was lost in the downport: retail keeps these
-- greetings in the client-side DB2 / broadcast_text layer, so there is nothing to
-- port. They have to be AUTHORED.
--
--   MenuID  NPC (live entry)                       npcflag
--   12799   Malfurion Stormrage      3652135       3 (gossip + questgiver)
--   12833   Thisalee Crow            3652444       3
--   12895   Keeper Taldros           3653446       1 (gossip)
--   12899   Captain Irontree         3653080       3
--   12970   Theresa Barkskin         3652825       3
--
-- The templates are NOT modified -- the existing gossip_menu_id values are kept
-- exactly as they are; this file only fills in what they point at.
--
-- npc_text ID BAND: 3,861,001 - 3,861,005. Chosen and verified free --
-- acore_world.npc_text has ZERO rows anywhere in 3,600,000-3,999,999 (the only
-- two ids above 3,600,000 are the 16,777,215 sentinel pair), and the
-- 3,861,000-3,861,099 sub-band is empty. The 386xxxx shape deliberately echoes
-- the map's +3,600,000 clone offset so the band reads as Molten Front content.
--
-- BroadcastTextID = 0 on every slot. That is the convention for DC-AUTHORED
-- gossip in this tree (HyjalCata/09_ and /125_ only carry non-zero
-- BroadcastTextIDs because they COPY rows out of cata_world/nelt_world npc_text,
-- where the retail broadcast_text ids already exist). Authoring a fake
-- BroadcastTextID would point at a non-existent broadcast_text row; 0 makes the
-- server use the text0_x/text1_x strings directly, which is what we want.
--
-- Each NPC gets ONE npc_text row carrying TWO greeting variants (slot 0 and
-- slot 1, Probability 1 each) so repeat visits are not identical. text*_1 (the
-- alternate-gender string) is filled with the same line, per stock practice.
--
-- Idempotent (DELETE-before-INSERT on both tables). Needs a worldserver restart
-- (or `.reload gossip_menu` + `.reload npc_text`).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. The greeting texts
-- ---------------------------------------------------------------------
DELETE FROM acore_world.npc_text WHERE `ID` BETWEEN 3861001 AND 3861005;

INSERT INTO acore_world.npc_text
(`ID`,`text0_0`,`text0_1`,`BroadcastTextID0`,`lang0`,`Probability0`,`text1_0`,`text1_1`,`BroadcastTextID1`,`lang1`,`Probability1`,`VerifiedBuild`) VALUES

-- 12799 Malfurion Stormrage -- measured archdruid directing the Firelands assault
(3861001,
 'Steady, $N. Every step we take beyond this portal is a step into Ragnaros'' own domain, and he feels each one.$B$BWe hold this ground because the Guardians of Hyjal bled for it. See that their sacrifice buys us the Firelands, and not merely a foothold upon it.',
 'Steady, $N. Every step we take beyond this portal is a step into Ragnaros'' own domain, and he feels each one.$B$BWe hold this ground because the Guardians of Hyjal bled for it. See that their sacrifice buys us the Firelands, and not merely a foothold upon it.',
 0, 0, 1,
 'Fandral was my friend once. I have not forgotten it, and I will not let it stay my hand.$B$BSpeak with the commanders here, champion. Each of them holds a thread of this war -- pull them all, and the Firelands unravels.',
 'Fandral was my friend once. I have not forgotten it, and I will not let it stay my hand.$B$BSpeak with the commanders here, champion. Each of them holds a thread of this war -- pull them all, and the Firelands unravels.',
 0, 0, 1, 0),

-- 12833 Thisalee Crow -- cocky night-elf druid scout
(3861002,
 'You made it! Ha! I had a wager riding on that, so thanks for the gold.$B$BI have been over every ridge on this rock while the rest of them were still arguing about maps. Ask me anything -- I have probably set fire to it already.',
 'You made it! Ha! I had a wager riding on that, so thanks for the gold.$B$BI have been over every ridge on this rock while the rest of them were still arguing about maps. Ask me anything -- I have probably set fire to it already.',
 0, 0, 1,
 'Scouting is simple, $N. You fly in, you count the enemy, you fly out. The trick is the last part.$B$BStick close and try to keep up. If you cannot, I promise to tell everyone you fought bravely.',
 'Scouting is simple, $N. You fly in, you count the enemy, you fly out. The trick is the last part.$B$BStick close and try to keep up. If you cannot, I promise to tell everyone you fought bravely.',
 0, 0, 1, 0),

-- 12895 Keeper Taldros -- flamewatch keeper, weary and watchful
(3861003,
 'Keep your voice low and your eyes on the ridgeline, $C. The flames watch us as surely as we watch them.$B$BI have kept this vigil since the Guardians first crossed over. Nothing moves out there that I have not counted twice.',
 'Keep your voice low and your eyes on the ridgeline, $C. The flames watch us as surely as we watch them.$B$BI have kept this vigil since the Guardians first crossed over. Nothing moves out there that I have not counted twice.',
 0, 0, 1,
 'The fire here does not merely burn -- it remembers. Turn your back on a smoldering field and you may find it standing behind you.$B$BWatch the ash, traveler. When it stirs without wind, run.',
 'The fire here does not merely burn -- it remembers. Turn your back on a smoldering field and you may find it standing behind you.$B$BWatch the ash, traveler. When it stirs without wind, run.',
 0, 0, 1, 0),

-- 12899 Captain Irontree -- gruff sentinel commander holding the line
(3861004,
 'You will forgive me if I do not salute. Both hands are busy holding this line together.$B$BMy sentinels have not slept since the portal opened, and they will not until the last Druid of the Flame is ash. Make yourself useful and they might get an hour.',
 'You will forgive me if I do not salute. Both hands are busy holding this line together.$B$BMy sentinels have not slept since the portal opened, and they will not until the last Druid of the Flame is ash. Make yourself useful and they might get an hour.',
 0, 0, 1,
 'Orders are simple here, $N: hold the camp, burn what comes at it, and do not chase them into the deep.$B$BThe ones who chase do not come back. I have written enough letters home for one war.',
 'Orders are simple here, $N: hold the camp, burn what comes at it, and do not chase them into the deep.$B$BThe ones who chase do not come back. I have written enough letters home for one war.',
 0, 0, 1, 0),

-- 12970 Theresa Barkskin -- worgen druid healer tending the wounded
(3861005,
 'Mind the cots, $N -- step lightly. Half of these defenders should not be breathing at all, and I intend to keep them ungrateful about it.$B$BIf you are hurt, say so now. I would rather mend you here than gather you in pieces later.',
 'Mind the cots, $N -- step lightly. Half of these defenders should not be breathing at all, and I intend to keep them ungrateful about it.$B$BIf you are hurt, say so now. I would rather mend you here than gather you in pieces later.',
 0, 0, 1,
 'The burns out here do not close the way honest wounds do. There is something in that fire that fights the healing.$B$BSo I fight back. Bring me the wounded, champion, and leave the rest to Theresa.',
 'The burns out here do not close the way honest wounds do. There is something in that fire that fights the healing.$B$BSo I fight back. Bring me the wounded, champion, and leave the rest to Theresa.',
 0, 0, 1, 0);

-- ---------------------------------------------------------------------
-- 2. Bind each menu to its text.
--    Guarded on the npc_text row AND on the owning creature_template still
--    carrying that gossip_menu_id, so a menu can never be bound to a template
--    that has moved on.
-- ---------------------------------------------------------------------
DELETE FROM acore_world.gossip_menu WHERE `MenuID` IN (12799,12833,12895,12899,12970) AND `TextID` BETWEEN 3861001 AND 3861005;

INSERT INTO acore_world.gossip_menu (`MenuID`,`TextID`)
SELECT v.menu, v.txt
FROM (
  SELECT 12799 AS menu, 3861001 AS txt, 3652135 AS npc UNION ALL  -- Malfurion Stormrage
  SELECT 12833, 3861002, 3652444 UNION ALL                        -- Thisalee Crow
  SELECT 12895, 3861003, 3653446 UNION ALL                        -- Keeper Taldros
  SELECT 12899, 3861004, 3653080 UNION ALL                        -- Captain Irontree
  SELECT 12970, 3861005, 3652825                                  -- Theresa Barkskin
) v
WHERE EXISTS (SELECT 1 FROM acore_world.npc_text n WHERE n.`ID` = v.txt)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template ct
              WHERE ct.`entry` = v.npc AND ct.`gossip_menu_id` = v.menu);

-- ---------------------------------------------------------------------
-- NOTES
--  * No gossip_menu_option rows are authored. Four of the five NPCs are
--    questgivers (npcflag 3) and Keeper Taldros is gossip-only (npcflag 1);
--    none of them has a vendor/trainer/flightmaster sub-menu here, so a plain
--    greeting is the correct and complete behaviour. Options can be layered on
--    later without touching these rows.
--  * $N / $C are the standard 3.3.5 gossip tokens (player name / class) and are
--    resolved server-side -- no client DBC prerequisite for anything in this file.
--  * Apostrophes inside the text are SQL-escaped as '' (Ragnaros'' own domain).
-- ---------------------------------------------------------------------
