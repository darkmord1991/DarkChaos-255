-- ---------------------------------------------------------------------------
-- 125  Hyjal round-15 -- the 20 missing Molten Front gossip menus
-- ---------------------------------------------------------------------------
-- 21 creature_template rows in the clone block carry a gossip_menu_id that has
-- no `gossip_menu` row, so the NPC opens an EMPTY window -- no greeting text,
-- and any non-quest gossip option is gone.  These are the Molten Front hub
-- characters, i.e. most of the people a player talks to on map 861:
--   Commander Jarod Shadowsong, Anren Shadowseeker (x2 entries), General
--   Taldris Moonfall, Deldren Ravenelm, Arthorn Windsong, Keeper Taldros,
--   Keeper Krothis, Tholo Whitehoof, Rayne Feathersong, Marin Bladewing,
--   Captain Saynna Stormrunner, Choluna, Avrilla, Damek Bloombeard, Ricket,
--   Shadow Warden, Aggra, Hyjal Flame Guardian, Elder Evershade.
--
-- 20 of the 21 menus exist in nelt_world and are cloned verbatim -- menu ids
-- are NOT offset (creature_template already points at the raw id, and the
-- 12xxx/22xxx range holds no acore rows, verified).  `gossip_menu_option` is
-- brought across for the 12 rows that have one.
--
-- NOT fixed: menu 56049 on 3656049 "Tony Bachk" -- that id exists in neither
-- nelt_world nor cata_world.  56049 == the creature's own raw entry, so it
-- looks like a placeholder someone typed rather than real data; left alone
-- rather than invented.
--
-- gossip_menu.entry -> acore `MenuID`; gossip_menu.text_id -> `TextID`.
-- Idempotent (INSERT IGNORE).
-- ---------------------------------------------------------------------------
SET @MENUS := '12709,12974,12791,12900,12966,12968,12822,12896,12901,12798,12790,12795,12823,12825,12897,12840,12895,12893,12985,22015';

INSERT IGNORE INTO acore_world.gossip_menu (`MenuID`,`TextID`)
SELECT g.entry, g.text_id FROM nelt_world.gossip_menu g WHERE FIND_IN_SET(g.entry, @MENUS);

-- npc_text rows the menus point at (the greeting itself)
-- npc_text rows the menus point at (the greeting itself). nelt spells the
-- probability column `prob0` where acore uses `Probability0`; everything else
-- in the leading block matches positionally.
INSERT IGNORE INTO acore_world.npc_text
(`ID`,`text0_0`,`text0_1`,`BroadcastTextID0`,`lang0`,`Probability0`,`em0_0`,`em0_1`,`em0_2`,`em0_3`,`em0_4`,`em0_5`)
SELECT n.ID, n.text0_0, n.text0_1, n.BroadcastTextID0, n.lang0, n.prob0, n.em0_0, n.em0_1, n.em0_2, n.em0_3, n.em0_4, n.em0_5
FROM nelt_world.npc_text n
WHERE n.ID IN (SELECT g.text_id FROM nelt_world.gossip_menu g WHERE FIND_IN_SET(g.entry, @MENUS) AND g.text_id > 0);

INSERT IGNORE INTO acore_world.gossip_menu_option
(`MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,`OptionType`,`OptionNpcFlag`,`ActionMenuID`,`ActionPoiID`,`BoxCoded`,`BoxMoney`,`BoxText`,`BoxBroadcastTextID`,`VerifiedBuild`)
SELECT o.menu_id, o.id, o.option_icon, o.option_text, o.OptionBroadcastTextID, o.option_id, o.npc_option_npcflag, o.action_menu_id, o.action_poi_id, o.box_coded, o.box_money, o.box_text, o.BoxBroadcastTextID, 0
FROM nelt_world.gossip_menu_option o
WHERE FIND_IN_SET(o.menu_id, @MENUS);
