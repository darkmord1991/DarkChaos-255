-- =====================================================================
-- Legion Dalaran (map 1413) -- creature_template.type fixes
-- ---------------------------------------------------------------------
-- ObjectMgr::CheckCreatureTemplate rejects any `type` outside CreatureType
-- (1-13, SharedDefines.h) and force-corrects it to CREATURE_TYPE_HUMANOID(7)
-- at load, logging "has invalid creature type". Two distinct bugs here:
--
--  * type=14 on 3 companion-pet NPCs (npcflag 0x40000000 = COMPANION):
--    Splint Jr. / Stitches Jr. Jr. / Heliosus. 14 is retail's
--    CREATURE_TYPE_WILD_PET, added well after this fork's 13-value enum --
--    copied straight from a modern client source without remapping. Forcing
--    these to HUMANOID is visibly wrong for a mini-pet; the correct
--    equivalent in this fork's enum is CREATURE_TYPE_NON_COMBAT_PET (12).
--
--  * type=0 on 10 utility/decor NPCs (vendors, boss-display dummies, a
--    training totem, unnamed housing props "Table"/"Fault"/"Scout"/
--    "Creature 220011"/"230000"): 0 isn't a valid CreatureType at all (the
--    "no type" value is 10, CREATURE_TYPE_NOT_SPECIFIED) -- these were
--    simply never given an explicit type. Being forced to HUMANOID is
--    harmless for pure-utility NPCs but still incorrect data; setting the
--    real NOT_SPECIFIED value removes the log spam.
-- =====================================================================

UPDATE `creature_template` SET `type` = 12 WHERE `entry` IN (3500352,3500366,3500273);

UPDATE `creature_template` SET `type` = 10 WHERE `entry` IN (100100,100051,100050,800028,800033,800032,3500575,3500570,3500582,3500580,3500579);
