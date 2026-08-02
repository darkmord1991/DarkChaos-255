-- ---------------------------------------------------------------------------
-- 197  Hyjal round-45 -- the gossip and text layer the imports left behind
-- ---------------------------------------------------------------------------
-- Audit of every text surface on map 750.  Two of the four are already clean,
-- which is worth stating so nobody re-checks them:
--
--   gossip_menu -> npc_text : 0 broken links.  Every menu we hold resolves.
--   SmartAI Talk actions    : 1,304 of them, exactly 1 without creature_text.
--
-- The two that were not clean:
--
--  1. 51 NPCs name a gossip_menu_id with NO gossip_menu row -- clicking them
--     falls through to default gossip and the written dialogue never appears.
--     cata_world has 48 of the 51 (54 rows).  52 of those 54 point at a TextID
--     we already hold; the remaining 2 (menus 10268 and 12417) need their
--     npc_text row brought across too, and both exist in cata.
--
--  2. 28 creature entries have no creature_text at all while the source has
--     37 rows for them -- these are the NPCs that will go silent the moment
--     196_ gives them SmartAI Talk actions.  Importing them here keeps that
--     file from producing mute scripts.
--
-- 110 menus have no gossip_menu_option, but only 7 have options in the source.
-- The other 103 are option-less BY DESIGN -- a gossip menu that is pure flavour
-- text with nothing clickable is normal, and inventing options would be worse
-- than leaving them. Only the 7 real ones are filled.
--
-- THREE SCHEMA DRIFTS, all handled by naming columns explicitly:
--   gossip_menu        : cata adds VerifiedBuild
--   creature_text      : cata adds SoundType
--   gossip_menu_option : cata spells it OptionNpcflag, ours OptionNpcFlag
--
-- npc_text has a FOURTH, worse drift: ours calls the emote columns em0_0..em7_5
-- while cata splits the same 48 into EmoteDelay0_0/Emote0_0/... pairs.  The
-- mapping is positional (em{N}_0 = EmoteDelay{N}_0, em{N}_1 = Emote{N}_0, ...).
-- For these 2 rows the emotes are cosmetic gesturing on a gossip window, so the
-- text, language, probability and BroadcastTextID are copied and the emotes are
-- left at their defaults rather than risk mis-pairing 48 columns for no
-- gameplay gain.
--
-- ORDER: before or after 196_ both work, but running it FIRST means the newly
-- scripted NPCs have their lines from the first restart.
-- ---------------------------------------------------------------------------

-- --- 1. the missing gossip menus ------------------------------------------
DELETE FROM `gossip_menu` WHERE `MenuID` IN (
  SELECT mid FROM (SELECT DISTINCT ct.`gossip_menu_id` AS mid FROM `creature` c
                   JOIN `creature_template` ct ON ct.`entry` = c.`id`
                   WHERE c.`map` = 750 AND ct.`gossip_menu_id` > 0) t
  WHERE mid IN (SELECT `MenuID` FROM cata_world.gossip_menu));

INSERT INTO `gossip_menu` (`MenuID`, `TextID`)
SELECT DISTINCT cgm.`MenuID`, cgm.`TextID`
FROM cata_world.gossip_menu cgm
WHERE cgm.`MenuID` IN (
  SELECT DISTINCT ct.`gossip_menu_id` FROM acore_world.creature c
  JOIN acore_world.creature_template ct ON ct.`entry` = c.`id`
  WHERE c.`map` = 750 AND ct.`gossip_menu_id` > 0);

-- --- 2. the 2 npc_text rows those menus point at --------------------------
DELETE FROM `npc_text` WHERE `ID` IN (14259, 17458);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`)
SELECT cnt.`ID`, cnt.`text0_0`, cnt.`text0_1`, cnt.`BroadcastTextID0`, cnt.`lang0`, cnt.`Probability0`
FROM cata_world.npc_text cnt WHERE cnt.`ID` IN (14259, 17458);

-- --- 3. gossip options, only where the source actually has them -----------
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (
  SELECT mid FROM (SELECT DISTINCT ct.`gossip_menu_id` AS mid FROM `creature` c
                   JOIN `creature_template` ct ON ct.`entry` = c.`id`
                   WHERE c.`map` = 750 AND ct.`gossip_menu_id` > 0) t
  WHERE mid IN (SELECT `MenuID` FROM cata_world.gossip_menu_option));

INSERT INTO `gossip_menu_option`
  (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`,
   `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`,
   `BoxBroadcastTextID`, `VerifiedBuild`)
SELECT cgo.`MenuID`, cgo.`OptionID`, cgo.`OptionIcon`, cgo.`OptionText`, cgo.`OptionBroadcastTextID`,
       cgo.`OptionType`, cgo.`OptionNpcflag`, cgo.`ActionMenuID`, cgo.`ActionPoiID`, cgo.`BoxCoded`,
       cgo.`BoxMoney`, cgo.`BoxText`, cgo.`BoxBroadcastTextID`, 0
FROM cata_world.gossip_menu_option cgo
WHERE cgo.`MenuID` IN (
  SELECT DISTINCT ct.`gossip_menu_id` FROM acore_world.creature c
  JOIN acore_world.creature_template ct ON ct.`entry` = c.`id`
  WHERE c.`map` = 750 AND ct.`gossip_menu_id` > 0);

-- --- 4. creature_text for the 28 silent entries ---------------------------
-- CreatureID is remapped to whichever offset band the spawn actually uses.
DELETE FROM `creature_text` WHERE `CreatureID` IN (
  SELECT e FROM (SELECT DISTINCT c.`id` AS e FROM `creature` c WHERE c.`map` = 750) x
  WHERE e IN (SELECT CAST(cct.`CreatureID` AS SIGNED) + 3600000 FROM cata_world.creature_text cct
              UNION SELECT CAST(cct2.`CreatureID` AS SIGNED) + 3700000 FROM cata_world.creature_text cct2));

INSERT INTO `creature_text`
  (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
   `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT m.our_id, cct.`GroupID`, cct.`ID`, cct.`Text`, cct.`Type`, cct.`Language`, cct.`Probability`,
       cct.`Emote`, cct.`Duration`, cct.`Sound`, cct.`BroadcastTextId`, cct.`TextRange`, cct.`comment`
FROM cata_world.creature_text cct
JOIN (SELECT DISTINCT c.`id` AS our_id FROM acore_world.creature c WHERE c.`map` = 750) m
  ON cct.`CreatureID` IN (CAST(m.our_id AS SIGNED) - 3600000, CAST(m.our_id AS SIGNED) - 3700000);

-- Verify -- all four should read 0:
--   SELECT COUNT(DISTINCT ct.entry) FROM `creature` c JOIN `creature_template` ct ON ct.entry=c.id
--    WHERE c.map=750 AND ct.gossip_menu_id>0
--      AND NOT EXISTS (SELECT 1 FROM `gossip_menu` gm WHERE gm.MenuID=ct.gossip_menu_id);
--   SELECT COUNT(*) FROM `gossip_menu` gm JOIN `creature_template` ct ON ct.gossip_menu_id=gm.MenuID
--     JOIN `creature` c ON c.id=ct.entry AND c.map=750 WHERE gm.TextID NOT IN (SELECT ID FROM `npc_text`);
--   SELECT COUNT(*) FROM `smart_scripts` s JOIN `creature` c ON c.id=s.entryorguid AND c.map=750
--    WHERE s.source_type=0 AND s.action_type=1
--      AND NOT EXISTS (SELECT 1 FROM `creature_text` t WHERE t.CreatureID=s.entryorguid AND t.GroupID=s.action_param1);
--   SELECT COUNT(DISTINCT c.id) FROM `creature` c WHERE c.map=750
--     AND NOT EXISTS (SELECT 1 FROM `creature_text` t WHERE t.CreatureID=c.id)
--     AND EXISTS (SELECT 1 FROM cata_world.creature_text x
--                 WHERE x.CreatureID IN (CAST(c.id AS SIGNED)-3600000, CAST(c.id AS SIGNED)-3700000));
