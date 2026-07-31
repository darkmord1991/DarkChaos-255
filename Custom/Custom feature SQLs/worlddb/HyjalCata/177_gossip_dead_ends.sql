-- ---------------------------------------------------------------------------
-- 177  Map 750 gossip dead-ends -- "click an option, nothing happens"
-- ---------------------------------------------------------------------------
-- Reported 2026-07-20: on Hyjal, clicking most gossip options leads nowhere.
--
-- CAUSE: `gossip_menu_option.ActionMenuID` points at a `gossip_menu.MenuID`
-- that has no row. AzerothCore still SHOWS the option (options live in
-- gossip_menu_option, which WAS imported) but when you click it the server has
-- no TextID to send, so the window closes / goes blank. The dialogue itself was
-- never the problem -- every single `npc_text` row these menus need is ALREADY
-- in this DB (verified: 27 of 27 present). Only the one-line menu -> text LINK
-- rows were left behind by the downport.
--
-- SCOPE: 39 broken options on NPCs spawned on map 750, resolving to 32 distinct
-- missing menus. This file fixes 36 of the 39 -- 15 via part A, 21 via part B
-- (17 immediately + 4 that part A first has to make exist) -- and leaves 3 that
-- have no source anywhere (part C).
--
-- (For reference, DB-wide the same query finds 113 broken options -- but most
-- of the rest are upstream AzerothCore gaps, not ours: AC's own
-- `data/sql/base/db_world/gossip_menu.sql` ships 5,165 menus and contains none
-- of those targets either. Out of scope here, which is map 750 only.)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The real Hyjal lore chains -- 27 menus + 21 options, from cata_world
-- ---------------------------------------------------------------------------
-- These are raw Cata menu ids used as-is by the +3,600,000 creature clones,
-- so no id remapping applies -- they are copied across unchanged.
--
-- What this restores, player-visible:
--   * Ysera (3640289)        -- all four "Tell me about the Shrine of ..."
--                               branches (Goldrinn / Grove of Aessina / Shrine
--                               of Aviana / Sanctuary of Malorne), which
--                               cross-link to each other (11493-11496).
--   * Matoclaw (3639928)     -- "Who is Tyrus Blackhorn?" (11320-11321) and
--                               "Tell me about the spirit of Aessina" (11550).
--   * Matoclaw (3652669)     -- "Tell me about the ancient, Malorne."
--                               (12972-12973-12984).
--   * Tyrus Blackhorn (3639933) -- the whole redemption dialogue
--                               (11322/11324/11325/11326).
--   * Hamuul Runetotem (3639858) -- "Tell me about Tortolla" (11551-11552).
--   * Ian Duran (3639433)    -- "Tell me about Goldrinn" (11542-11543).
--   * Takrik Ragehowl (3639432) -- "Lo'Gosh" (11544-11545).
--   * Choluna (3641005)      -- "Tell me about Aviana" (11547-11549).
--   * Silva Fil'naveth / Bunthen Plainswind -- the Half Pendant of Aquatic
--     Agility/Endurance answers (4223-4226). NOTE these four are stock-id
--     menus, so importing them also repairs the non-750 originals (NPCs 11800
--     / 11798). That is deliberate: the map-750 clones at +3,700,000 reuse them
--     via part B, so they have to exist, and fixing the original at the same
--     time is strictly an improvement, not scope creep.
--
-- Verified before writing:
--   * all 27 menus absent here, all 27 present in cata_world;
--   * all 27 referenced npc_text ids ALREADY present here (nothing to import);
--   * the option set is a CLOSED graph -- followed ActionMenuID transitively
--     until it stopped producing new menus (3 rounds; 11549 and 12984 are the
--     terminal leaves), so no new dead-end is introduced one step deeper;
--   * zero `conditions` rows (SourceTypeOrReferenceId 15) reference any of
--     them, so nothing is silently gated;
--   * cata_world's gossip_menu_option is column-for-column identical to ours
--     (same 14 names, same order). Only two widths differ and neither can
--     truncate here: `OptionNpcflag` bigint->int (observed values 0/1) and
--     `OptionBroadcastTextID` unsigned->signed (positive ids).
-- ---------------------------------------------------------------------------

DELETE FROM `gossip_menu` WHERE `MenuID` IN
    (4223,4224,4225,4226,11320,11321,11322,11324,11325,11326,11493,11494,11495,
     11496,11542,11543,11544,11545,11547,11548,11549,11550,11551,11552,12972,
     12973,12984);

INSERT INTO `gossip_menu` (`MenuID`,`TextID`)
SELECT `MenuID`, `TextID` FROM `cata_world`.`gossip_menu`
WHERE `MenuID` IN
    (4223,4224,4225,4226,11320,11321,11322,11324,11325,11326,11493,11494,11495,
     11496,11542,11543,11544,11545,11547,11548,11549,11550,11551,11552,12972,
     12973,12984);

DELETE FROM `gossip_menu_option` WHERE `MenuID` IN
    (4223,4224,4225,4226,11320,11321,11322,11324,11325,11326,11493,11494,11495,
     11496,11542,11543,11544,11545,11547,11548,11549,11550,11551,11552,12972,
     12973,12984);

INSERT INTO `gossip_menu_option`
    (`MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,`OptionType`,`OptionNpcFlag`,
     `ActionMenuID`,`ActionPoiID`,`BoxCoded`,`BoxMoney`,`BoxText`,`BoxBroadcastTextID`,`VerifiedBuild`)
SELECT `MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,`OptionType`,`OptionNpcflag`,
       `ActionMenuID`,`ActionPoiID`,`BoxCoded`,`BoxMoney`,`BoxText`,`BoxBroadcastTextID`,`VerifiedBuild`
FROM `cata_world`.`gossip_menu_option`
WHERE `MenuID` IN
    (4223,4224,4225,4226,11320,11321,11322,11324,11325,11326,11493,11494,11495,
     11496,11542,11543,11544,11545,11547,11548,11549,11550,11551,11552,12972,
     12973,12984);

-- ---------------------------------------------------------------------------
-- B) The +3,700,000 clone band -- redirect to the identical raw menus
-- ---------------------------------------------------------------------------
-- A second, separate group of map-750 NPCs are Felwood/Moonglade/Winterspring
-- NPCs cloned into the Hyjal Frontier with a +3,700,000 offset on BOTH the
-- creature entry and the gossip MenuID (Golhine the Hooded 3709465, Loganaar
-- 3712042, Kaerbrus 3705501, Nalesette Wildbringer 3700543, Rabine Saturna
-- 3711801, Grazle 3711554, Azzleby 3711119, Witch Doctor Mau'ari 3710307,
-- Malyfous Darkhammer 3710637, Niby the Almighty 3714469, Zap Farflinger
-- 3714742, Ulathek 3714523, Arathandris Silversky 3709528, Maybess Riverbreeze
-- 3709529, Silva Fil'naveth 3711800, Bunthen Plainswind 3711798).
--
-- That importer offset the MENUS it cloned but not the menus those menus POINT
-- AT, so every "next step" in the band dead-ends -- e.g. Golhine's "I wish to
-- unlearn my talents" -> 3704461, which does not exist, though plain 4461 does.
--
-- Fixed by pointing the band's broken options back at the RAW menu id rather
-- than cloning 17 more menus into the band. `gossip_menu` is a GLOBAL table
-- keyed by MenuID -- it is not per-creature -- and the band's clones are
-- verbatim copies that share their originals' TextID (spot-checked: menus 2208
-- and 3702208 both map to texts 2844/2845/2848), so the raw menu renders
-- exactly the same dialogue. Redirecting is therefore behaviour-identical to
-- cloning, adds no rows, and -- unlike cloning -- does not cascade: each cloned
-- menu's own sub-options point one level deeper again (2992, 5765, 5843, 10373,
-- 2704, 56002 ...), so a faithful in-band clone would have to recurse.
--
-- Only rewrites options whose raw counterpart actually exists, so it is safe to
-- re-run and cannot create a NEW dangling id. Part A must run first -- it is
-- what makes raw 4223-4226 exist for the Silva/Bunthen pendant options.
--
-- NOTE the WHERE clause is scoped to the +3,700,000 BAND, not to map 750, so it
-- also repairs ~4 options on band NPCs that are not currently spawned on 750
-- (Elder Nightwind/Stonespire/Brightspear/Riversong directions, the
-- Competitor's Tabard pair). That is deliberate: the band is a single import
-- artefact with a single systematic defect, and a map-scoped fix would leave
-- identical breakage behind to resurface the moment one of those NPCs is
-- placed. 24 rows update in total.
-- ---------------------------------------------------------------------------

UPDATE `gossip_menu_option` o
SET o.`ActionMenuID` = o.`ActionMenuID` - 3700000
WHERE o.`MenuID` >= 3700000
  AND o.`ActionMenuID` >= 3700000
  AND NOT EXISTS (SELECT 1 FROM (SELECT `MenuID` FROM `gossip_menu`) g WHERE g.`MenuID` = o.`ActionMenuID`)
  AND EXISTS (SELECT 1 FROM (SELECT `MenuID` FROM `gossip_menu`) g2 WHERE g2.`MenuID` = o.`ActionMenuID` - 3700000);

-- ---------------------------------------------------------------------------
-- C) Not fixable -- 3 options with no source anywhere
-- ---------------------------------------------------------------------------
-- Left alone deliberately, NOT silently blanked:
--   3702209 (raw 2209) -- Arathandris Silversky, "What plants are in Felwood
--                         that might be corrupted?"
--   3702705 (raw 2705) -- Witch Doctor Mau'ari, "I'd like you to make me a new
--                         Cache of Mau'ari please"
--   3721401 (raw 21401) -- Maybess Riverbreeze, same Felwood plants question
-- None of these menus exist in this DB, in cata_world, or in AzerothCore's own
-- base gossip_menu.sql -- they are upstream gaps that the raw NPCs share (the
-- identical option is broken on stock Arathandris 9528 / Mau'ari 10307 /
-- Maybess 9529 too, so this is not a downport artefact). Fixing them means
-- authoring Blizzard dialogue we do not have; flagged here rather than
-- pretending. Removing the options instead would be a defensible alternative
-- if the dead click is worse than a missing line -- that is a content call.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification -- should drop from 36 to 3:
--   SELECT COUNT(*) FROM gossip_menu_option gmo
--   JOIN creature_template ct ON ct.gossip_menu_id = gmo.MenuID
--   JOIN creature c ON c.id = ct.entry AND c.map = 750
--   WHERE gmo.ActionMenuID <> 0
--     AND NOT EXISTS (SELECT 1 FROM gossip_menu gm WHERE gm.MenuID = gmo.ActionMenuID);
-- ---------------------------------------------------------------------------
