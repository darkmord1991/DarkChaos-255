-- ---------------------------------------------------------------------------
-- 287  Boot log round 31 -- ten classes, all of them behaviour, not just noise
-- ---------------------------------------------------------------------------
-- Source: the LIVE Errors.log (286 lines / 31,266 bytes) read through ACMCP at
-- /home/wowcore/azeroth-server/logs.
--
-- 🔴 READ THIS BEFORE TRUSTING A LOCAL LOG AGAIN. `K:/Dark-Chaos/Server/logs/
-- Errors.log` is 2.4 MB / 17,191 lines and looks far more alarming (13,454
-- "wrong spawn mask" lines on classic dungeon maps, 2,909 on gameobjects, 600
-- pool_gameobject lines). It is a STALE local Windows test build --
-- `AzerothCore rev. 3afec5d1f60b+ 2026-02-17 (map_bots branch) (Win64)` per its
-- own Server.log banner -- roughly six months old and on a different branch.
-- None of those classes exist on the live server. Always read the log through
-- ACMCP (`view_logs`), never the local copy.
--
-- Sections, each independently revertible:
--   1  quest 700709 RequiredNpcOrGo1 sign  -- the quest is undoable today
--   2  gameobject_template_addon 3795360 faction 2206 -> 14
--   3  20 single-member ore pools with a leftover explicit chance -- 20 nodes
--      have not been spawning at all
--   4  creature_equip_template: 4 missing rows imported, 22 spawns zeroed
--   5  4 quest items: SoundOverrideSubclass -1 -> 0 (match the appended Item.dbc)
--   6  2 Firelands necks: Cata Mastery stat 49 -> 32 (crit)
--   7  7 dangling quest-chain references nulled
--   8  spell_target_position 74948 effIndex 0 -> 2 -- a dead teleport
--   9  npc_spellclick flag on a Castle Nathria prop
--  10  quest 13250 restored -- the ONLY stock quest missing from this DB
--  11  quest 26385 AllowableRaces: retail worgen (22) -> DC worgen (12)
--
-- Apply against acore_world, then restart worldserver. Idempotent: every
-- statement is guarded on the exact value it is replacing, so re-running is a
-- no-op.

-- ---------------------------------------------------------------------------
-- 1) Quest 700709 "Blackwing Descent: A Favor for Finkle"
-- ---------------------------------------------------------------------------
--     Quest 700709 has `RequiredNpcOrGo1` = -44202 but gameobject 44202 does
--     not exist, quest can't be done.
--
-- A negative RequiredNpcOrGo means GameObject (ObjectMgr::LoadQuests checks
-- `id < 0 && !GetGameObjectTemplate(-id)`). 44202 is a CREATURE -- "Finkle
-- Einhorn", faction 35, npcflag 1, ScriptName npc_chimaeron_finkle_einhorn,
-- spawned on map 669 -- so this is a sign slip in the original authoring, not
-- missing content. Verified DB-wide: 700709 is the ONLY quest with a negative
-- RequiredNpcOrGo whose absolute value resolves to a creature.
--
-- 🔴 WHY THIS IS THE THIRD TIME. The fix was already written twice and never
-- reached the database:
--   * `BlackwingDescent/32_finkle_quest_sign_fix.sql` has the correct UPDATE
--     and IS wired into that folder's apply_all.sql -- but BWD/apply_all.sql
--     has not been run since 32_ was added, and it SOURCEs 12_quests.sql
--     (which still carries the -44202 literal) BEFORE 32_.
--   * `HyjalCata/84_molten_front_quest_objectives.sql` describes the fix as
--     item 3 of its header and then never writes the statement -- the body
--     jumps from the creature imports straight to the 29xxx remaps.
-- So the source file is fixed too (12_quests.sql now carries +44202), and this
-- UPDATE lands it in the folder that actually gets applied.
UPDATE acore_world.`quest_template` SET `RequiredNpcOrGo1` = 44202
 WHERE `ID` = 700709 AND `RequiredNpcOrGo1` = -44202;

-- ---------------------------------------------------------------------------
-- 2) GameObject 3795360 "Land Mine" -- Cataclysm faction template
-- ---------------------------------------------------------------------------
--     GameObject (Entry: 3795360) has invalid faction (2206) defined in
--     `gameobject_template_addon`.
--
-- 3795360 is cata_world GO 195360 "Land Mine" (type 6, trap) cloned at
-- +3,600,000, with 175 spawns in zone 4930 on map 750. Its addon row copied
-- faction 2206 verbatim; 2206 is the Cataclysm "Azshara Land Mine" template
-- (its only other users in cata_world are creatures 35134 / 51189 "Azshara Land
-- Mine Bunny", neither of which was imported) and it does not exist in the
-- 3.3.5 FactionTemplate.dbc -- 897 rows, max id 2379, 2206 is a gap.
--
-- NOT just a log line: ObjectMgr keeps the bad value rather than clearing it,
-- so at runtime GetFactionTemplateEntry() returns nullptr and the trap's
-- hostility check never resolves -- all 175 mines are inert.
--
-- 14 is the value the STOCK 3.3.5 Land Mine (gameobject 191502) uses in this
-- same table, so this is matching a peer rather than inventing a mapping.
-- Checked first: creature_template has zero rows with a faction missing from
-- factiontemplate_dbc, and this is the only bad gameobject_template_addon row,
-- so nothing else in the DB needs the same treatment.
UPDATE acore_world.`gameobject_template_addon` SET `faction` = 14
 WHERE `entry` = 3795360 AND `faction` = 2206;

-- ---------------------------------------------------------------------------
-- 3) 20 ore pools that never spawn
-- ---------------------------------------------------------------------------
--     Pool Id 130007833 has no equal chance pooled entites defined and explicit
--     chance sum is not 100. The pool will not be spawned.
--
-- 20 lines, 20 pools, every one of them a SINGLE member carrying an explicit
-- chance of 10 or 80. PoolMgr requires that a pool either use equal chance
-- (every member at 0) or have its explicit chances sum to exactly 100; neither
-- holds, so the pool is dropped and the node never appears.
--
-- 🔴 THIS IS COLLATERAL FROM 284_. The pool_template descriptions still record
-- the original size -- "Hyjal-Nel pool 7833 (4 members)", "(3 members)" -- and
-- 284_ section 1 deleted the members whose gameobject rows did not exist. That
-- left one survivor per pool still holding its old relative weight. 284_ was
-- right to remove them (they pointed at nothing) but it did not renormalise
-- what remained.
--
-- All 20 are mining nodes in zone 4923 on map 750: 10 x Iron Deposit
-- (3601735), 5 x Small Thorium Vein (3600324), 5 x Rich Thorium Vein
-- (3775404). Every pool has max_limit = 1 and exactly one candidate, so
-- equal-chance means "spawn it", which is the only sensible reading. Verified:
-- none of the 20 is a child in `pool_pool`, so no mother pool re-rolls them.
--
-- Written as an explicit pool_entry list rather than derived from the table:
-- the "chance sum <> 100" predicate has to read `pool_gameobject` itself, and
-- MySQL rejects a subquery on the table being updated (error 1093) -- the same
-- trap 284_ hit.
UPDATE acore_world.`pool_gameobject` SET `chance` = 0
 WHERE `chance` <> 0 AND `pool_entry` IN (
  130007833,130007838,130007931,130008030,130008066,
  130008118,130008137,130008218,130008237,130008241,
  130008460,130008513,130008545,130008637,130008667,
  130008678,130008691,130008719,130008731,130008811);

-- ---------------------------------------------------------------------------
-- 4) creature_equip_template -- 26 spawns with no equipment layer
-- ---------------------------------------------------------------------------
--     Table `creature` have creature (Entry: 7310897) with equipment_id 1 not
--     found in table `creature_equip_template`, set to no equipment.
--
-- 26 lines, and the DB agrees exactly: 3 spawns with equipment_id > 0 and no
-- matching row, plus 23 spawns with equipment_id = -1 ("pick a random template")
-- for creatures that have no template at all. The other 4,986 rows at -1 are
-- fine and are not touched.
--
-- 4a. Four clones whose equipment layer simply was not carried across. These
--     are content, not noise -- the NPCs are standing there empty-handed.
DELETE FROM acore_world.`creature_equip_template` WHERE `CreatureID` IN (7310897,7312578,7312740,3653834);
INSERT INTO acore_world.`creature_equip_template` (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`) VALUES
(7310897,1,13721,0,5258,18019),   -- Sindrayl        <- acore 10897
(7312578,1, 2714,0,   0,18019),   -- Mishellena      <- acore 12578
(7312740,1, 5303,0,   0,18019),   -- Faustron        <- acore 12740
(3653834,1,70691,0,   0,18019);   -- Devout Harbinger <- cata_world 53834
-- Every referenced item exists here (13721, 5258, 2714, 5303 stock; 70691 is a
-- downported Firelands staff, displayid 99038), so none of these produces an
-- invisible weapon.

-- 4b. The remaining 11 entries (22 spawns) have no equipment anywhere -- not in
--     acore_world, not in cata_world -- so -1 can never resolve. Setting 0 is
--     exactly what the core already does at load; this only stops it saying so.
--     3675193 is an event-starter bunny and 7352289 / 73532xx are Firelands
--     elementals and bosses that genuinely wield nothing.
UPDATE acore_world.`creature` SET `equipment_id` = 0
 WHERE `equipment_id` = -1
   AND `id` IN (3653196,3653759,3653771,3653864,3654163,3675193,
                7352289,7353264,7353265,7353267,7353271);

-- ---------------------------------------------------------------------------
-- 5) 4 quest items -- SoundOverrideSubclass disagrees with Item.dbc
-- ---------------------------------------------------------------------------
--     Item (Entry: 44887) does not have a correct SoundOverrideSubclass (-1),
--     must be 0.
--
-- Checked against the three Item.dbc copies before touching item_template:
--   stock AC v19        46,096 records -- 44887/44888/46387/46388 ABSENT
--   Custom/DBCs (master) 153,478 records -- present at idx 153290-153326, value 0
--   live data/dbc        153,370 records -- same rows, same value 0
-- So Blizzard never shipped client rows for these four class-12 quest items;
-- the DC pipeline backfilled them and, reasonably, wrote 0. The DB still
-- carries AC's -1, and ObjectMgr compares the two. No duplicate ids in any
-- copy -- this is a value mismatch, not DBC corruption.
--
-- Aligning the DB to the DBC rather than the reverse: rebuilding Item.dbc to
-- put -1 back would be a client redeploy for a field that only selects weapon
-- swing sounds, which class 12 never plays.
UPDATE acore_world.`item_template` SET `SoundOverrideSubclass` = 0
 WHERE `entry` IN (44887,44888,46387,46388) AND `SoundOverrideSubclass` = -1;

-- ---------------------------------------------------------------------------
-- 6) 2 Firelands necklaces still carrying the Cataclysm Mastery stat
-- ---------------------------------------------------------------------------
--     Item (Entry: 70106) has wrong (non-existing?) stat_type4 (49)
--
-- MAX_ITEM_MOD is 49 in this core (ItemTemplate.h), so 0-48 are valid and 49 --
-- Cataclysm's ITEM_MOD_MASTERY_RATING -- is one past the end. The core drops
-- the stat, so both necks are handing out three stats instead of four.
-- Verified DB-wide: exactly these two rows use a stat type >= 49, in exactly
-- one slot each.
--
-- 32 = ITEM_MOD_CRIT_RATING is a judgment call, and it is the house convention
-- for this batch rather than a guess: their ilvl-365 peers in the same import
-- (70105, 70110, 70112) all use 32 in a throughput slot, and neither 70106 nor
-- 70107 already carries 32, so nothing ends up with a duplicated stat type.
-- The magnitudes (153 and 131) are left alone.
UPDATE acore_world.`item_template` SET `stat_type4` = 32 WHERE `entry` = 70106 AND `stat_type4` = 49;
UPDATE acore_world.`item_template` SET `stat_type4` = 32 WHERE `entry` = 70107 AND `stat_type4` = 49;

-- ---------------------------------------------------------------------------
-- 7) 7 dangling quest-chain references
-- ---------------------------------------------------------------------------
--     Quest 28847 has `RewardNextQuest` = 28837 but quest 28837 does not exist
--     Quest 28745 has PrevQuestId 28638, but no such quest
--
-- All 7 targets exist in cata_world and were never imported:
--     28837 Altered Beasts            28638 The Owls Have It
--     28637 A Taste for Bear          28471 The Final Piece
--     28519 Pain of the Blood Elves   28513 Pride of the Highborne
--     26473 Bathran's Hair
-- Importing them properly -- givers, objectives, POI, remapping every target
-- onto the +3,600,000 clones -- is a content job, not a log fix, and a
-- half-import is worse than the gap. Left for a future round; nulling the
-- references does not make the import any harder.
--
-- Zero behaviour change, verified in the core rather than assumed:
--   * RewardNextQuest -- ObjectMgr.cpp:5787 already assigns 0 on this path.
--   * PrevQuestId -- ObjectMgr.cpp:5794-5799 logs and then does NOT push onto
--     `prevQuests`, so SatisfyQuestPrevQuest has nothing to check and the quest
--     is already obtainable. Nulling the column matches the loaded state.
UPDATE acore_world.`quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 28847 AND `RewardNextQuest` = 28837;
UPDATE acore_world.`quest_template` SET `RewardNextQuest` = 0 WHERE `ID` = 28479 AND `RewardNextQuest` = 28513;
UPDATE acore_world.`quest_template_addon` SET `PrevQuestID` = 0 WHERE `ID` = 28745 AND `PrevQuestID` = 28638;
UPDATE acore_world.`quest_template_addon` SET `PrevQuestID` = 0 WHERE `ID` = 28719 AND `PrevQuestID` = 28637;
UPDATE acore_world.`quest_template_addon` SET `PrevQuestID` = 0 WHERE `ID` = 28472 AND `PrevQuestID` = 28471;
UPDATE acore_world.`quest_template_addon` SET `PrevQuestID` = 0 WHERE `ID` = 28536 AND `PrevQuestID` = 28519;
UPDATE acore_world.`quest_template_addon` SET `PrevQuestID` = 0 WHERE `ID` = 13623 AND `PrevQuestID` = 26473;

-- ---------------------------------------------------------------------------
-- 8) spell_target_position 74948 -- a teleport that goes nowhere
-- ---------------------------------------------------------------------------
--     Spell (Id: 74948, effIndex: 0) listed in `spell_target_position` does not
--     have target TARGET_DEST_DB (17).
--
-- Spell 74948 "Twilight Speech" (spell_dbc overlay row, used by
-- gameobject_template 3802996) has three effects:
--     E1 eff=6  targetA=25 targetB=0
--     E2 eff=6  targetA=25 targetB=0
--     E3 eff=5  targetA=25 targetB=17   <- SPELL_EFFECT_TELEPORT_UNITS
-- SpellMgr.cpp:1561 accepts the row when TargetA OR TargetB at that effIndex is
-- 17. The destination row was filed under effIndex 0, where neither target is
-- 17, so it is rejected and mSpellTargetPositions never learns the destination
-- -- the GO's teleport silently does nothing. The teleport lives at effect
-- index 2. Row content (map 750, 4742.48 / -4972.12 / 907.45) is correct and
-- untouched; only the index moves. The other 8 map-750 rows already validate.
-- The column is `EffectIndex` in this fork (the log message says "effIndex",
-- which is the C++ local, not the column name). PK is (ID, EffectIndex) and
-- 74948 has exactly one row, so there is nothing at index 2 to collide with.
UPDATE acore_world.`spell_target_position` SET `EffectIndex` = 2
 WHERE `ID` = 74948 AND `EffectIndex` = 0;

-- ---------------------------------------------------------------------------
-- 9) Soul Pedestal -- SPELLCLICK flag with nothing behind it
-- ---------------------------------------------------------------------------
--     npc_spellclick_spells: Creature template 173382 has UNIT_NPC_FLAG_SPELLCLICK
--     but no data in spellclick table! Removing flag
--
-- 173382 "Soul Pedestal" is a Castle Nathria prop (type 10, faction 14, 4
-- spawns on map 2296 in zone 13224) from the SL transcode. It has no
-- ScriptName, no AIName, no smart_scripts rows and no spellclick rows here or
-- in cata_world, so there is no intended click behaviour to preserve -- the
-- flag came across with the template. The core strips it at load anyway;
-- 16777216 is UNIT_NPC_FLAG_SPELLCLICK and it is the only bit set.
UPDATE acore_world.`creature_template` SET `npcflag` = 0
 WHERE `entry` = 173382 AND `npcflag` = 16777216;

-- ---------------------------------------------------------------------------
-- 10) Quest 13250 "Proof of Demise: Gal'darah" -- restored
-- ---------------------------------------------------------------------------
--     Quest condition specifies non-existing quest (13250), skipped
--
-- 13250 is STOCK AzerothCore content (data/sql/base/db_world/quest_template.sql
-- line 8728) and it is missing from acore_world. Sized before acting: the id
-- sets of the base file and the live table were diffed in 500-id buckets across
-- the whole 0-14,500 stock range, and **13250 is the only stock quest missing**
-- (the negative deltas in the 13500/14000 buckets are DC's own additions). Its
-- eleven "Proof of Demise" siblings 13245-13256 are all present.
--
-- The symptom is a loot gate: conditions row (SourceType 1, group 31368, entry
-- 43693) gates the Mojo Remnant of Akali on this quest, and with the quest gone
-- the condition is dropped and the item drops unconditionally from Gal'darah.
--
-- ⚠️ CONSEQUENCE, STATED PLAINLY: restoring the quest re-arms that gate, so
-- item 43693 stops dropping for players who do not have the quest -- and
-- nobody can take it, because DC removed Lan'dalock's daily `pool_quest`
-- entries (0 rows in the whole 13245-13256 range). That is exactly the state
-- all eleven siblings are already in, so this restores parity rather than
-- creating a new dead end. If you would rather keep the item dropping, skip
-- this section and delete the conditions row instead -- both are defensible;
-- stock parity is the one I picked.
--
-- Rows copied verbatim from the base files. Column counts were checked against
-- the live schema first (quest_template 105/105, quest_template_addon 18/18,
-- quest_offer_reward 11/11, quest_request_items 5/5), so the bare VALUES form
-- is safe here -- no fork drift in these four tables.
-- Reverting is `DELETE FROM quest_template WHERE ID = 13250;` plus the three
-- companions.
DELETE FROM acore_world.`quest_request_items` WHERE `ID` = 13250;
DELETE FROM acore_world.`quest_offer_reward` WHERE `ID` = 13250;
DELETE FROM acore_world.`quest_template_addon` WHERE `ID` = 13250;
DELETE FROM acore_world.`quest_template` WHERE `ID` = 13250;

INSERT INTO acore_world.`quest_template` VALUES
(13250,2,80,80,4416,85,0,0,0,0,0,0,8,222000,0,0,0,0,0,0,20616,0,47241,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1090,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'Proof of Demise: Gal\'darah','Archmage Lan\'dalock in Dalaran wants you to return with the Mojo Remnant of Akali.$B$BThis quest may only be completed on Heroic difficulty.','The Drakkari prophets of Zul\'Drak have done the unthinkable: they\'ve slain most of their gods to absorb their powers! The most dangerous of all is the High Prophet of Akali, Gal\'darah.$B$BSequestered within the bowels of Gundrak, Gal\'darah has absorbed almost all of the mojo from slain Akali and now stands poised to erupt with his followers from the city. If we do not kill him now, we will be awash in a sea of madness and unthinkable power!$B$BHurry, $N, bring me what\'s left of Akali\'s mojo.','','Return to Archmage Lan\'dalock at Forlorn Woods in Crystalsong Forest.',0,0,0,0,0,0,0,0,43693,0,0,0,0,0,1,0,0,0,0,0,0,'','','','',12340);

INSERT INTO acore_world.`quest_template_addon` VALUES
(13250,0,0,0,0,0,13245,0,0,0,0,0,0,0,0,0,0,1);

INSERT INTO acore_world.`quest_offer_reward` VALUES
(13250,0,0,0,0,0,0,0,0,'Thank you, $N. I will see to it that the very essence of the god is kept safe until it can be handed over to the Zandalar tribe.$b$bPerhaps they\'ll be able to find a way to reincorporate Akali from it?',12340);

INSERT INTO acore_world.`quest_request_items` VALUES
(13250,0,0,'Do you have the mojo?$b$bIt is sickening to witness the demise of yet another great troll nation.$b$bI can only think that if it weren\'t for the interference of the Lich King, the trolls wouldn\'t have felt pressured to turn on their own gods and steal their power as a defense against the Scourge.',12340);

-- ---------------------------------------------------------------------------
-- 11) Quest 26385 -- retail worgen race number in a DC-worgen database
-- ---------------------------------------------------------------------------
--     Quest 26385 does not contain any playable races in `AllowableRaces`
--     (2097152), value set to 0 (all races).
--
-- 2097152 is bit 21 = race 22, RETAIL Worgen. This build's worgen is **race
-- 12** (see Custom/Worgoblin -- worgen was deliberately mapped onto the FelOrc
-- slot to stay client-compatible with no DLL patch), so bit 21 names a race
-- that does not exist here and the core zeroes the whole mask. "Breaking Waves
-- of Change" is a Gilneas quest and silently became available to every race.
-- 2048 is bit 11 = race 12.
--
-- Confirmed both races really are playable server-side before assuming a
-- numbering issue rather than a missing race: ChrRaces.dbc row 9 has Flags 4
-- and row 12 has Flags 6 -- neither sets 0x01 CHRRACES_FLAGS_NOT_PLAYABLE --
-- so RaceMgr::LoadRaces puts both in the playable mask.
--
-- SCOPE, checked rather than guessed: 238 quests set bit 21, but 237 of them
-- carry broad Cata masks (8388607 = every bit 0-22, or 2098253) that already
-- include several playable bits, so the core accepts them and remapping would
-- be a 238-row rewrite with no error to justify it. 26385 is the only one whose
-- mask is bit 21 ALONE. 0 quests set bit 24 (retail goblin 25).
UPDATE acore_world.`quest_template` SET `AllowableRaces` = 2048
 WHERE `ID` = 26385 AND `AllowableRaces` = 2097152;

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT RequiredNpcOrGo1 FROM quest_template WHERE ID=700709;            -> 44202
--  2  SELECT faction FROM gameobject_template_addon WHERE entry=3795360;      -> 14
--  3  SELECT COUNT(*) FROM (SELECT pool_entry FROM pool_gameobject
--       GROUP BY pool_entry HAVING SUM(chance=0)=0 AND SUM(chance)<>100) z;   -> 0
--  4  SELECT COUNT(*) FROM creature_equip_template
--      WHERE CreatureID IN (7310897,7312578,7312740,3653834);                 -> 4
--     SELECT COUNT(*) FROM creature c WHERE (c.equipment_id>0 AND NOT EXISTS
--       (SELECT 1 FROM creature_equip_template e WHERE e.CreatureID=c.id
--         AND e.ID=c.equipment_id))
--       OR (c.equipment_id=-1 AND NOT EXISTS
--       (SELECT 1 FROM creature_equip_template e WHERE e.CreatureID=c.id));   -> 0
--  5  SELECT COUNT(*) FROM item_template
--      WHERE entry IN (44887,44888,46387,46388) AND SoundOverrideSubclass=0;  -> 4
--  6  SELECT COUNT(*) FROM item_template WHERE stat_type1>=49 OR stat_type2>=49
--       OR stat_type3>=49 OR stat_type4>=49 OR stat_type5>=49 OR stat_type6>=49
--       OR stat_type7>=49 OR stat_type8>=49 OR stat_type9>=49
--       OR stat_type10>=49;                                                   -> 0
--  7  SELECT COUNT(*) FROM quest_template_addon a WHERE a.PrevQuestID<>0
--       AND NOT EXISTS (SELECT 1 FROM quest_template q
--         WHERE q.ID=ABS(a.PrevQuestID));                                     -> 0
--  8  SELECT EffectIndex FROM spell_target_position WHERE ID=74948;           -> 2
--  9  SELECT npcflag FROM creature_template WHERE entry=173382;               -> 0
-- 10  SELECT COUNT(*) FROM quest_template WHERE ID=13250;                     -> 1
-- 11  SELECT AllowableRaces FROM quest_template WHERE ID=26385;               -> 2048
--
-- Next boot, 65 of the 286 lines should be gone:
--   20  pool "will not be spawned"
--   26  equipment_id not found
--    7  quest-chain PrevQuestId / RewardNextQuest
--    4  SoundOverrideSubclass
--    2  stat_type4
--    1  each: 3795360 faction, quest 700709, spell 74948, spellclick 173382,
--        quest 26385 race mask, quest 13250 condition
--
-- ---------------------------------------------------------------------------
-- NOT done here, and why
-- ---------------------------------------------------------------------------
-- * 20 creature_template_addon auras on +3.6M clones (82917, 81550, 64573,
--   91378, 65097, 65499, 82781, 68603, 68543, 67024, 68268, 68294, 78718,
--   69526, 69322, 79919, 80126, 90317, 75773, 96372). NOT a rebuild
--   regression -- checked all three Spell.dbc copies including stock AC v19
--   (49,839 records): none of the 20 exists in stock 3.3.5 either, so they are
--   Cata-era ids that happen to sit in the WotLK numeric range. Same class as
--   272_, needs a Spell.dbc downport round of its own.
--
-- * Area trigger 5876 "does not exist in AreaTrigger.dbc" -- it DOES exist in
--   the live server's AreaTrigger.dbc (1,380 records, id 5876 at index 1369,
--   map 750, valid coords). This line is from a boot that predates the deploy
--   and should be gone after the next restart. Nothing to do. Control that
--   proves the DBC read is current, not cached: SpellFocusObject 1884/1888/
--   1889/1896 really are still absent from the same directory.
--
-- * reference_loot_template 24161 at 110% and skinning 7448 / 10807 at 138% /
--   134% -- still pre-existing STOCK loot balance, unchanged position from
--   215_ and 219_.
--
-- * ~130 "isn't creature entry and not referenced from loot, and thus useless"
--   lines -- documented benign; 266_ proved blind deletion is dangerous.
--
-- * The 4100xxx GoType 22 / GoType 8 block (Legion Dalaran retail spells and
--   SpellFocus ids) -- no downport source, unchanged.
--
-- ---------------------------------------------------------------------------
-- Unrelated finding worth acting on separately
-- ---------------------------------------------------------------------------
-- Custom/DBCs/Item.dbc is 153,478 records; both K:/Dark-Chaos/Server/data/dbc
-- and the live /home/wowcore/azeroth-server/data/dbc are at 153,370. The 108
-- missing ids are a contiguous 410000+ block. An Item.dbc deploy is pending.
