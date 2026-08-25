-- ---------------------------------------------------------------------------
-- 301  Round 43 -- 11 trainer gossip menus that had no options
-- ---------------------------------------------------------------------------
--     Trainer creature template references GossipMenuId 12532 has no
--     `gossip_menu_option` entries. This will fallback to MenuID 0.
--
-- Same layer that was missing under the Shadowfang Keep teleporter in 300_, now
-- across 11 more menus: the NPCs, their greeting text and their trainer spell
-- lists all imported, but the `gossip_menu_option` rows never did.
--
-- 🔴 THE LOG LINE UNDERSTATES THIS. "Fallback to MenuID 0" sounds harmless, and
-- the ObjectMgr.cpp:10314 comment right above the warning spells out what it
-- really means: the menu "will display: I wish to unlearn my talents." Menu 0 is
-- the generic template, and its options are picked purely by npcflag -- so a
-- trainer falling back to it gets "Train me!" **plus** the talent-unlearn, pet-
-- unlearn and dual-spec entries (options 14/15/16, all gated only on npcflag 16)
-- and loses its authored greeting. The trainers work; they just present wrong.
--
-- ---------------------------------------------------------------------------
-- These 11 are outliers, not normal Blizzard data
-- ---------------------------------------------------------------------------
-- Worth checking before writing anything, because plenty of Blizzard menus
-- legitimately carry text and no options. Counted across the whole DB:
--     514 distinct gossip menus are referenced by trainer templates
--     503 of them HAVE options
--      11 do not  <- exactly the ones in the log
-- and every one of the 11 belongs to an imported or custom NPC (Legion Dalaran
-- 3.5M/4.1M, map 750 3.6M/3.7M, and one 400xxx DC custom). Every stock-range
-- trainer already has its options. So this is an import gap, not Blizzard's
-- data being sparse.
--
-- ---------------------------------------------------------------------------
-- Where the text comes from
-- ---------------------------------------------------------------------------
-- 🔴 NOT FROM THE SOURCE DBS -- THEY DO NOT HAVE IT EITHER. cata_world and
-- nelt_world were checked first and hold options for exactly ONE of the eleven
-- (11877). So ten menus are filled from **our own stock data**: for each class,
-- the MODAL OptionText among stock class-trainer menus of that class, with the
-- same OptionType/OptionIcon/OptionNpcFlag triple those rows use. That keeps the
-- new NPCs indistinguishable from the 503 that already work, rather than
-- inventing phrasing.
--     class  1 Warrior  "I require warrior training."                 (36 rows)
--     class  3 Hunter   "I seek training in the ways of the Hunter."   (20)
--     class  4 Rogue    "I would like to train."                        (6)
--     class  8 Mage     "I am interested in mage training."            (38)
--     class  9 Warlock  "I am interested in warlock training."         (19)
--     class 11 Druid    "I seek training as a druid."                  (16)
-- 11877 is the exception and uses its OWN authentic text from nelt_world, since
-- that menu really does have a source row -- the Tauren druid phrasing about the
-- Earth Mother, which would have been lost by falling back to the class modal.
--
-- Each NPC's class comes from `trainer`.`Requirement` (Type 0 = class trainer),
-- not from its name -- which matters for 12533 "Sentinel Moonwing", a night-elf
-- sentinel who is actually a WARRIOR trainer (TrainerId 1, Requirement 1).
-- Angler Tideborn is the one Type 2 (profession) trainer here and gets the
-- profession modal "Train me." (227 rows) with no talent options.
--
-- ---------------------------------------------------------------------------
-- Why there are no `conditions` rows for the class gating
-- ---------------------------------------------------------------------------
-- Checked rather than assumed, since a wrong-class player must not see a train
-- option. PlayerGossip.cpp gates all three types in core:
--     OptionType  5 GOSSIP_OPTION_TRAINER      -> trainer->IsTrainerValidForPlayer()
--     OptionType 16 GOSSIP_OPTION_UNLEARNTALENTS -> creature->CanResetTalents()
--     OptionType 20 GOSSIP_OPTION_DUALSPEC_INFO  -> CanResetTalents() + specs + level
-- so the options hide themselves for the wrong class, exactly as they do for the
-- 503 menus that already exist. Adding condition rows would be redundant.
--
-- The talent options are included because stock class-trainer menus carry them
-- almost universally (e.g. warrior: 36 train rows against 37 unlearn and 37
-- dual-spec). The profession trainer gets none, matching stock.
--
-- ---------------------------------------------------------------------------
-- gossip_menu_option -- 31 rows across 11 menus
-- ---------------------------------------------------------------------------
DELETE FROM acore_world.`gossip_menu_option`
 WHERE `MenuID` IN (4608,11877,12049,12053,12531,12532,12533,12535,12536,8006100,400130);
INSERT INTO acore_world.`gossip_menu_option`
  (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`)
VALUES
-- 4608    Warlock      Maressa Milner 4148612 / Bee Bruxworthy 4149718
(4608, 0, 3, 'I am interested in warlock training.', 0, 5, 16),
(4608, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(4608, 2, 0, 'Learn about Dual Talent Specialization.', 0, 20, 1),
-- 11877   Druid        Mala Skywatcher 4152319
(11877, 0, 3, 'I seek further druidic training to have a closer understanding of the Earth Mother''s will.', 0, 5, 16),
(11877, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(11877, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 12049   Mage         Fizz Lighter 3649896
(12049, 0, 3, 'I am interested in mage training.', 0, 5, 16),
(12049, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12049, 2, 0, 'Learn about Dual Talent Specialization.', 0, 20, 1),
-- 12053   Warlock      Evol Fingers 3649895
(12053, 0, 3, 'I am interested in warlock training.', 0, 5, 16),
(12053, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12053, 2, 0, 'Learn about Dual Talent Specialization.', 0, 20, 1),
-- 12531   Rogue        Angela Hipple 4149870
(12531, 0, 3, 'I would like to train.', 0, 5, 16),
(12531, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12531, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 12532   Warrior      Warrior-Matic NX-01 3649902
(12532, 0, 3, 'I require warrior training.', 0, 5, 16),
(12532, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12532, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 12533   Warrior      Sentinel Moonwing 3749923
(12533, 0, 3, 'I require warrior training.', 0, 5, 16),
(12533, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12533, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 12535   Hunter       Lanla Bowleaf 3749927
(12535, 0, 3, 'I seek training in the ways of the Hunter.', 0, 5, 16),
(12535, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12535, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 12536   Rogue        Kenral Nightwind 3749939
(12536, 0, 3, 'I would like to train.', 0, 5, 16),
(12536, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(12536, 2, 0, 'I wish to know about Dual Talent Specialization.', 0, 20, 1),
-- 8006100 Mage         Archmage Celindra 3500127
(8006100, 0, 3, 'I am interested in mage training.', 0, 5, 16),
(8006100, 1, 0, 'I wish to unlearn my talents.', 0, 16, 16),
(8006100, 2, 0, 'Learn about Dual Talent Specialization.', 0, 20, 1),
-- 400130  profession   Angler Tideborn 401120 (Fishing, trainer Type 2)
(400130, 0, 3, 'Train me.', 0, 5, 16);

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(*) FROM gossip_menu_option WHERE MenuID IN
--       (4608,11877,12049,12053,12531,12532,12533,12535,12536,8006100,400130);
--                                                                          -> 31
--  2  The count of option-less trainer menus must go to zero:
--     SELECT COUNT(DISTINCT ct.gossip_menu_id) FROM creature_template ct
--      WHERE ct.gossip_menu_id > 0 AND (ct.npcflag & 16) = 16
--        AND NOT EXISTS (SELECT 1 FROM gossip_menu_option o
--                         WHERE o.MenuID = ct.gossip_menu_id);              -> 0
--  3  All 11 warnings go on the next restart -- SQL only, no rebuild needed.
--
--  In game: each of the 12 NPCs should greet with its own text and offer a
--  single class-appropriate train option (plus talent options for the class
--  trainers) instead of menu 0's generic list.
--
-- ---------------------------------------------------------------------------
-- One related gap left alone, deliberately
-- ---------------------------------------------------------------------------
-- Menu 400130 (Angler Tideborn) is the only one of the eleven that ALSO has no
-- `gossip_menu` row, so it has no greeting text either -- the other ten all had
-- theirs. That is a separate defect from the one logged: the core falls back to
-- the default gossip body, the option added here works regardless, and the
-- warning clears. Authoring a greeting means minting an npc_text id, which is
-- content work rather than a log fix, so it is flagged instead of guessed.
-- His flavour text is not lost meanwhile -- `trainer`.`Greeting` already carries
-- a full one, shown in the training window.
