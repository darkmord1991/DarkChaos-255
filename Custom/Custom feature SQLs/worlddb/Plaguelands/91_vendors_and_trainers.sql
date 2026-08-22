-- 91_vendors_and_trainers.sql -- map 751 Lordaeron extension, DB step 30.
--
-- `npc_vendor` and the trainer tables were never imported either. That makes FIVE
-- side tables missed by the same spawn-driven import:
--     npc_spellclick_spells (80_)  creature_text (82_)  waypoints (86_)
--     creature_equip_template (87_)  and now npc_vendor + trainer* (this file)
--
-- Visible effect: **167 band NPCs carry the VENDOR flag and 0 of them had a single
-- npc_vendor row** -- every one opened an empty shop window. 85 carry the TRAINER
-- flag with nothing to teach.
--
-- ===========================================================================
-- 1. npc_vendor -- 1,969 rows across 142 vendors
--
--    Schema: Cata has 9 columns to our 7, adding `type` and `PlayerConditionID`.
--    `type` is 1 (item) on every one of the 2,036 source rows, so dropping it loses
--    nothing; PlayerConditionID has no 3.3.5 equivalent.
--
--    TWO FILTERS, both dropping rows rather than fabricating data:
--      * 67 rows name an item that does not exist in our item_template. Those are
--        Cata items; shipping the row would give "Table `npc_vendor` has non
--        existent item" at boot and a broken entry in the shop.
--      * 31 rows use ExtendedCost 3023/3024/3322/3323, which are absent from our
--        ItemExtendedCost.dbc (the other 35 costs the band uses all exist). The 31
--        turn out to be a SUBSET of the 67, so the two filters together drop
--        exactly 67 rows and 2036 - 67 = 1969 survive.
--        **Dropping is deliberate: zeroing ExtendedCost instead would turn a
--        token-priced item into a plain-gold purchase.**
--
--    Verified: no vendor is emptied by the filters -- every one of the 142 that has
--    source rows keeps at least one. The other 25 flagged vendors (Innkeeper
--    Hershberg, Provisioner Elda, Sarah Goode...) have NO rows in the source at all;
--    that is a TDB 434 gap, not something this import lost, so their flag is left
--    alone rather than stripped -- Blizzard does sell from them, and an innkeeper
--    still works as an innkeeper.
-- ===========================================================================
DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 4100000 AND 4199999;

INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT cv.`entry` + 4100000, cv.`slot`, cv.`item`, cv.`maxcount`, cv.`incrtime`,
       cv.`ExtendedCost`, cv.`VerifiedBuild`
FROM `cata_world`.`npc_vendor` cv
WHERE EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = cv.`entry` + 4100000)
  AND (cv.`item` = 0 OR EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = cv.`item`))
  AND cv.`ExtendedCost` NOT IN (3023, 3024, 3322, 3323);

-- ===========================================================================
-- 2. trainer -- 43 rows, REMAPPED to +410,000, Type/Requirement REWRITTEN
--
--    THE TRAINER ID SPACES ARE COMPLETELY UNRELATED BETWEEN THE TWO DATABASES.
--    29 of the 44 ids the band references already exist here and mean something
--    else entirely:
--        id  3 : ours = Paladin trainer   cata = Priest trainer
--        id 10 : ours = Rogue trainer     cata = FISHING trainer
--        id 15 : ours = Shaman            cata = Hunter
--        id 16 : ours = Mage              cata = Warrior
--        id 33 : ours = Druid             cata = Rogue
--    Importing at Cata's ids would silently overwrite 29 stock class trainers and
--    break class training server-wide. Same class of trap as the stock `waypoints`
--    collision in 86_, but with far worse blast radius -- and it is invisible,
--    because nothing errors.
--
--    So every trainer id is shifted by +410,000. The band 410000-410999 was verified
--    empty in both `trainer` and `trainer_spell` (our own max Id is 401120).
--
--    Trainer 373 is EXCLUDED: it is the Archaeology trainer, and Archaeology is a
--    Cataclysm profession that does not exist in 3.3.5 -- every one of its spells is
--    >= 70000, so the list would be empty. Section 5 clears the flag on its NPC.
-- ===========================================================================
DELETE FROM `trainer` WHERE `Id` BETWEEN 410000 AND 410999;

-- Type and Requirement are REWRITTEN, not copied. Cata leaves `Requirement` at 0 on
-- every class trainer, which this core rejects (see the note above). The class for
-- each of the 17 was read off the SUBNAME of the creatures that use the trainer --
-- "Priest Trainer", "Warrior Trainer" and so on, hundreds of NPCs each, unanimous --
-- and cross-checked against the trainer's own greeting ("Hello, priest!  Ready for
-- some training?"). The two whose greeting is generic are the interesting ones:
--     46  greeting "Hello!  Can I teach you something?"  -> every creature is a
--         **Riding Trainer**, so it is not a class trainer at all: Type 1 (Mount).
--     149 greeting "Welcome!"                            -> every creature is a
--         **Portal Trainer**, i.e. mage portals: class 8.
-- Class ids are 3.3.5's: 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest,
-- 7 Shaman, 8 Mage, 9 Warlock, 11 Druid.
INSERT INTO `trainer` (`Id`, `Type`, `Requirement`, `Greeting`, `VerifiedBuild`)
SELECT ct.`Id` + 410000,
       CASE WHEN ct.`Id` = 46 THEN 1 ELSE ct.`Type` END,
       CASE ct.`Id`
            WHEN   3 THEN  5   -- Priest
            WHEN  15 THEN  3   -- Hunter
            WHEN  16 THEN  1   -- Warrior
            WHEN  17 THEN  4   -- Rogue
            WHEN  32 THEN  9   -- Warlock
            WHEN  33 THEN  4   -- Rogue
            WHEN  39 THEN 11   -- Druid
            WHEN  40 THEN  3   -- Hunter
            WHEN  44 THEN  8   -- Mage
            WHEN  46 THEN  0   -- Riding Trainer, retyped to Mount above
            WHEN 124 THEN  7   -- Shaman
            WHEN 127 THEN  5   -- Priest
            WHEN 135 THEN  8   -- Mage
            WHEN 145 THEN  1   -- Warrior
            WHEN 149 THEN  8   -- Mage (Portal Trainer)
            WHEN 154 THEN  9   -- Warlock
            WHEN 164 THEN  2   -- Paladin
            ELSE ct.`Requirement`  -- the 26 Tradeskill trainers; Type 2 ignores it
       END,
       ct.`Greeting`, ct.`VerifiedBuild`
FROM `cata_world`.`trainer` ct
WHERE ct.`Id` IN (3,10,15,16,17,29,32,33,39,40,44,46,48,49,51,56,58,62,63,75,80,83,
                  101,102,103,107,117,122,124,127,133,135,136,145,149,154,155,163,164,
                  388,389,390,407);

-- ===========================================================================
-- 3. trainer_spell -- 1,997 of 2,420 rows
--
--    Schemas are IDENTICAL (10 columns, same order), so only the TrainerId shifts.
--
--    Rows are filtered to SpellId < 70000. The 416 dropped rows are Cata-only ranks
--    (max id in the source is 104698) which this core cannot resolve; keeping them
--    would just reproduce the "non-existing spell" boot spam 88_ was written to end.
--
--    THE < 70000 CUTOFF IS NOT SUFFICIENT ON ITS OWN -- the first version of this
--    file justified it with a 1-in-10 sample that came back 200/200 present, and the
--    server then rejected seven rows it had missed. Sampling cannot prove a negative.
--    The seven are excluded explicitly, and each was re-confirmed against the DBCs
--    read out of the client with EXPLICIT archive priority (patch-enGB-3 wins, 53,799
--    records -- an alphabetical scan reads patch-enGB's stale 46,583 instead):
--      * 5570, 16864, 19503, 19028, 51886 are TALENT ranks, present in Talent.dbc.
--        ObjectMgr rejects any trainer spell with a talent cost, whatever its id --
--        so a range filter can never catch these.
--      * 69820, 69826 are simply absent from Spell.dbc despite being under 70000.
--    The verification block below re-derives the reject count from the live table so
--    a future source refresh cannot reintroduce the class silently.
--
--    ReqAbility1/2/3 are copied verbatim; they reference the same pre-Cata spells.
-- ===========================================================================
DELETE FROM `trainer_spell` WHERE `TrainerId` BETWEEN 410000 AND 410999;

INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`,
                             `ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT ts.`TrainerId` + 410000, ts.`SpellId`, ts.`MoneyCost`, ts.`ReqSkillLine`, ts.`ReqSkillRank`,
       ts.`ReqAbility1`, ts.`ReqAbility2`, ts.`ReqAbility3`, ts.`ReqLevel`, ts.`VerifiedBuild`
FROM `cata_world`.`trainer_spell` ts
WHERE ts.`SpellId` < 70000
  AND ts.`SpellId` NOT IN (5570, 16864, 19503, 19028, 51886,   -- talents; the core refuses these
                           69820, 69826)                        -- absent from Spell.dbc
  AND ts.`TrainerId` IN (3,10,15,16,17,29,32,33,39,40,44,46,48,49,51,56,58,62,63,75,80,83,
                         101,102,103,107,117,122,124,127,133,135,136,145,149,154,155,163,164,
                         388,389,390,407);

-- ===========================================================================
-- 4. creature_default_trainer -- 82 creatures
--
--    Cata's table is `creature_trainer` (CreatureID, TrainerID, MenuID, OptionID);
--    ours is `creature_default_trainer` (CreatureId, TrainerId) and **its primary key
--    is CreatureId alone, so a creature can have exactly ONE trainer.**
--
--    That matters for two NPCs. 47400 Nedric Sallow and 48619 Therisa Sallow are
--    Cata's all-in-one "Profession Trainer" NPCs, each offering ELEVEN professions
--    through separate gossip menus (trainers 48/51/63/80/102/103/117/122/388/389/390).
--    3.3.5 cannot represent that, so each is bound to the trainer with the most
--    teachable spells -- 63, with 226 -- chosen by an explicit ORDER BY so the result
--    is deterministic rather than whichever row the optimiser returns first.
--    **Their other ten professions are unavailable FROM THESE TWO NPCS**; the normal
--    single-profession trainers elsewhere in the band are unaffected.
--
--    The same ORDER BY also skips any trainer whose spell list is empty after the
--    SpellId < 70000 filter, which is what excludes Adam Hossack (see section 5).
-- ===========================================================================
DELETE FROM `creature_default_trainer` WHERE `CreatureId` BETWEEN 4100000 AND 4199999;

INSERT INTO `creature_default_trainer` (`CreatureId`, `TrainerId`)
SELECT DISTINCT ct.`CreatureID` + 4100000,
       (SELECT ts.`TrainerId` + 410000
          FROM `cata_world`.`trainer_spell` ts
         WHERE ts.`SpellId` < 70000
           AND ts.`TrainerId` IN (SELECT ct2.`TrainerID` FROM `cata_world`.`creature_trainer` ct2
                                  WHERE ct2.`CreatureID` = ct.`CreatureID`)
         GROUP BY ts.`TrainerId`
         ORDER BY COUNT(*) DESC, ts.`TrainerId`
         LIMIT 1)
FROM `cata_world`.`creature_trainer` ct
WHERE EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = ct.`CreatureID` + 4100000)
  AND EXISTS (SELECT 1 FROM `cata_world`.`creature_trainer` ct3
              JOIN `cata_world`.`trainer_spell` ts3 ON ts3.`TrainerId` = ct3.`TrainerID`
              WHERE ct3.`CreatureID` = ct.`CreatureID` AND ts3.`SpellId` < 70000);

-- ===========================================================================
-- 5. Adam Hossack -- clear the TRAINER flag
--
--    4147382 "Adam Hossack, Archaeology Trainer" is the one band trainer left with
--    nothing to teach: Archaeology is a Cataclysm profession, so all of trainer 373's
--    spells are >= 70000 and none survive. With the flag set and no
--    creature_default_trainer row he would offer a training window that cannot open.
--    Same treatment section 3 of 87_ gave the two Rated-BG battlemasters.
--
--    UNIT_NPC_FLAG_TRAINER = 0x10 = 16.
-- ===========================================================================
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~16
WHERE `entry` = 4147382 AND (`npcflag` & 16);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'npc_vendor rows (want 1969)' AS what, COUNT(*) AS n
FROM `npc_vendor` WHERE `entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT '  ...distinct vendors served (want 142)', COUNT(DISTINCT `entry`)
FROM `npc_vendor` WHERE `entry` BETWEEN 4100000 AND 4199999
UNION ALL SELECT '  ...naming an item we do not have (want 0)', COUNT(*)
FROM `npc_vendor` v WHERE v.`entry` BETWEEN 4100000 AND 4199999 AND v.`item` > 0
  AND NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = v.`item`)
UNION ALL SELECT 'trainer rows (want 43)', COUNT(*) FROM `trainer` WHERE `Id` BETWEEN 410000 AND 410999
UNION ALL SELECT 'trainer_spell rows (want 1997)', COUNT(*) FROM `trainer_spell` WHERE `TrainerId` BETWEEN 410000 AND 410999
UNION ALL SELECT '  ...spell >= 70000 leaked through (want 0)', COUNT(*)
FROM `trainer_spell` WHERE `TrainerId` BETWEEN 410000 AND 410999 AND `SpellId` >= 70000
UNION ALL SELECT '  ...known-bad spells leaked through (want 0)', COUNT(*)
FROM `trainer_spell` WHERE `TrainerId` BETWEEN 410000 AND 410999
  AND `SpellId` IN (5570,16864,19503,19028,51886,69820,69826)
UNION ALL SELECT 'class trainers with a VALID class requirement (want 17)', COUNT(*)
FROM `trainer` WHERE `Id` BETWEEN 410000 AND 410999 AND `Type` = 0
  AND `Requirement` BETWEEN 1 AND 11
UNION ALL SELECT '  ...class trainers still on Requirement 0 (want 0)', COUNT(*)
FROM `trainer` WHERE `Id` BETWEEN 410000 AND 410999 AND `Type` = 0 AND `Requirement` = 0
UNION ALL SELECT 'the Riding Trainer retyped to Mount (want 1)', COUNT(*)
FROM `trainer` WHERE `Id` = 410046 AND `Type` = 1
UNION ALL SELECT 'creature_default_trainer rows (want 82)', COUNT(*)
FROM `creature_default_trainer` WHERE `CreatureId` BETWEEN 4100000 AND 4199999
UNION ALL SELECT 'Adam Hossack still flagged TRAINER (want 0)', COUNT(*)
FROM `creature_template` WHERE `entry` = 4147382 AND (`npcflag` & 16)
UNION ALL SELECT 'STOCK trainers still intact (want 29)', COUNT(*)
FROM `trainer` WHERE `Id` IN (3,10,15,16,17,29,32,33,39,40,44,46,48,49,51,56,58,62,63,75,80,83,101,102,103,107,117,122,124)
UNION ALL SELECT '  ...stock trainer 3 still Paladin, Requirement 2 (want 1)', COUNT(*)
FROM `trainer` WHERE `Id` = 3 AND `Requirement` = 2;

-- must be empty: a band creature pointed at a trainer that has no spells, which
-- opens an empty training window
SELECT 'PROBLEM: trainer bound with no spells' AS problem, d.`CreatureId`, d.`TrainerId`
FROM `creature_default_trainer` d
WHERE d.`CreatureId` BETWEEN 4100000 AND 4199999
  AND NOT EXISTS (SELECT 1 FROM `trainer_spell` s WHERE s.`TrainerId` = d.`TrainerId`);

-- must be empty: a creature_default_trainer row whose trainer row is missing
SELECT 'PROBLEM: dangling TrainerId' AS problem, d.`CreatureId`, d.`TrainerId`
FROM `creature_default_trainer` d
WHERE d.`CreatureId` BETWEEN 4100000 AND 4199999
  AND NOT EXISTS (SELECT 1 FROM `trainer` t WHERE t.`Id` = d.`TrainerId`);

-- must be empty: a band NPC still flagged TRAINER with no trainer bound. The 2 that
-- were never in the source at all are expected to appear here -- everything else is a
-- real problem
SELECT 'CHECK: trainer flag with no trainer' AS problem, t.`entry`, t.`name`
FROM `creature_template` t
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND (t.`npcflag` & 16)
  AND NOT EXISTS (SELECT 1 FROM `creature_default_trainer` d WHERE d.`CreatureId` = t.`entry`);
