#!/usr/bin/env python3
"""
Second half of the border-zone clone: the quests.

166_ cloned the NPCs and objects (creature +3,700,000 / gameobject +3,900,000)
but deliberately left quests alone, so the cloned NPCs currently offer nothing.
This finishes it.

    quest id   raw + 100,000

  194 quests, raw ids 28..13,075 -> 100,028..113,075.  The whole window
  100,000-199,999 was verified EMPTY (175 quests exist above 100,000 but every
  one of them is beyond 199,999, up to 920,101).

THE PART THAT NEEDS CARE -- CHAIN REMAPPING
  quest_template_addon carries PrevQuestID, NextQuestID, ExclusiveGroup and
  BreadcrumbForQuestId.  Each is a quest id, and each must be rewritten ONLY
  when it points at a quest that is also in the cloned set:

    * inside the set  -> +100,000, so the chain stays intact within map 750
    * outside the set -> left raw, because it points at a real prerequisite the
      player earns elsewhere in the world.  Blanking those would silently
      orphan chains; offsetting them would point at quests that do not exist.

  ExclusiveGroup is the subtle one.  It is not a quest id in the normal sense --
  it is a GROUP identifier that by convention equals one member's quest id, and
  its SIGN carries meaning (negative = "only one of the group may be taken",
  positive = "all of them"). So it is remapped by magnitude with the sign
  preserved, and only when the magnitude is a quest we cloned; getting the sign
  wrong inverts the rule for the whole group.

SOURCE SET
  Derived from the CLONED creature/gameobject templates (entry - offset), not
  from the spawn rows.  166_ already repointed the spawns, so the raw ids are no
  longer present there -- reading spawns would return nothing and this file
  would silently clone zero quests.

QUEST POI is rewritten to MapID 750 / WorldMapAreaId 1216 for the clones, so the
map markers land on the DC map instead of the real Kalimdor zones.  The raw
quests keep their own POI untouched.

    python gen_border_zone_quests.py [outdir]

Writes 167_border_zone_quests.sql.  Idempotent.
"""
import sys, os

OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r35/"
Q_OFF = 100000
C_OFF = 3700000
G_OFF = 3900000

# raw ids recovered from the clones that 166_ made
RAWC = ("SELECT `entry` - %d FROM `creature_template` WHERE `entry` BETWEEN %d AND %d"
        % (C_OFF, C_OFF, C_OFF + 99999))
RAWG = ("SELECT `entry` - %d FROM `gameobject_template` WHERE `entry` >= %d"
        % (G_OFF, G_OFF))

# the quest set: anything started or ended by a cloned NPC or object
QSET = ("SELECT DISTINCT `quest` FROM `creature_queststarter` WHERE `id` IN (%s)\n"
        "  UNION SELECT DISTINCT `quest` FROM `creature_questender`   WHERE `id` IN (%s)\n"
        "  UNION SELECT DISTINCT `quest` FROM `gameobject_queststarter` WHERE `id` IN (%s)\n"
        "  UNION SELECT DISTINCT `quest` FROM `gameobject_questender`   WHERE `id` IN (%s)"
        % (RAWC, RAWC, RAWG, RAWG))

COLS = {
 "quest_template_addon":
  "ID,MaxLevel,AllowableClasses,SourceSpellID,PrevQuestID,NextQuestID,ExclusiveGroup,"
  "BreadcrumbForQuestId,RewardMailTemplateID,RewardMailDelay,RequiredSkillID,RequiredSkillPoints,"
  "RequiredMinRepFaction,RequiredMaxRepFaction,RequiredMinRepValue,RequiredMaxRepValue,"
  "ProvidedItemCount,SpecialFlags",
 "quest_details": "ID,Emote1,Emote2,Emote3,Emote4,EmoteDelay1,EmoteDelay2,EmoteDelay3,EmoteDelay4,VerifiedBuild",
 "quest_offer_reward":
  "ID,Emote1,Emote2,Emote3,Emote4,EmoteDelay1,EmoteDelay2,EmoteDelay3,EmoteDelay4,RewardText,VerifiedBuild",
 "quest_request_items": "ID,EmoteOnComplete,EmoteOnIncomplete,CompletionText,VerifiedBuild",
 "quest_greeting": "ID,type,GreetEmoteType,GreetEmoteDelay,Greeting,VerifiedBuild",
}

HEADER = """-- ---------------------------------------------------------------------------
-- 167  Hyjal round-35 -- clone the border-zone quests
-- ---------------------------------------------------------------------------
-- Finishes what 166_ started.  166_ gave map 750 private copies of the stock
-- NPCs and objects (creature +3,700,000 / gameobject +3,900,000) but left the
-- quests shared, so the cloned NPCs offered nothing.  This clones the quests
-- too, at raw + 100,000.
--
--     194 quests, raw ids 28..13,075  ->  100,028..113,075
--
-- The window 100,000-199,999 was verified completely empty first: 175 quests
-- exist above 100,000, but every one is beyond 199,999 (up to 920,101).
--
-- CHAIN REMAPPING is the part that needs care.  PrevQuestID, NextQuestID,
-- ExclusiveGroup and BreadcrumbForQuestId each hold a quest id, and each is
-- rewritten ONLY when it points at a quest that is also in the cloned set:
--   * inside the set  -> +100,000, so the chain stays intact inside map 750
--   * outside the set -> LEFT RAW, because it points at a real prerequisite the
--     player earns elsewhere.  Blanking those would orphan chains; offsetting
--     them blindly would point at quests that do not exist.
--
-- ExclusiveGroup is the subtle one: it is a GROUP id (conventionally equal to
-- one member's quest id) whose SIGN carries meaning -- negative means "only one
-- of this group may be taken", positive means "all of them".  It is therefore
-- remapped by MAGNITUDE with the sign preserved.  Getting the sign wrong
-- inverts the rule for every quest in the group.
--
-- SOURCE SET is derived from the CLONED templates (entry - offset), not from
-- the spawn rows: 166_ already repointed those, so the raw ids are gone from
-- `creature`/`gameobject` and reading them would clone zero quests while
-- appearing to succeed.
--
-- quest_poi is rewritten to MapID 750 / WorldMapAreaId 1216 so the markers land
-- on the DC map.  The raw quests keep their own POI untouched.
--
-- Generated by HyjalCata/tools/gen_border_zone_quests.py.  Idempotent.
-- ---------------------------------------------------------------------------

"""


def cl(t):
    return ["`%s`" % c for c in COLS[t].split(",")]


def clone(table, key, off, where, extra=None):
    cols = cl(table)
    sel = []
    for c in cols:
        n = c.strip("`")
        if n == key:
            sel.append("`%s` + %d" % (n, off))
        elif extra and n in extra:
            sel.append(extra[n])
        else:
            sel.append("`%s`" % n)
    return ("INSERT INTO `%s` (%s)\nSELECT %s\nFROM `%s` WHERE %s;"
            % (table, ", ".join(cols), ", ".join(sel), table, where))


def block(title, body):
    return "-- --- %s %s\n%s\n\n" % (title, "-" * max(0, 72 - len(title)), body.strip())


def main():
    p = [HEADER]
    QR = "`ID` BETWEEN %d AND %d" % (Q_OFF, Q_OFF + 99999)
    inset = "`ID` IN (%s)" % QSET

    # quest_template: copy every column, offsetting ID; RequiredNpcOrGo repointed after.
    p.append(block("quest_template", """
DELETE FROM `quest_template` WHERE {QR};

-- SELECT * is safe here and preferable: quest_template has ~90 columns that
-- differ between forks, and only `ID` needs changing.  Every other clone block
-- in 166_/167_ uses an explicit list because it rewrites interior columns.
CREATE TEMPORARY TABLE `_qt_clone` AS SELECT * FROM `quest_template` WHERE {inset};
UPDATE `_qt_clone` SET `ID` = `ID` + {O};
INSERT INTO `quest_template` SELECT * FROM `_qt_clone`;
DROP TEMPORARY TABLE `_qt_clone`;

-- Mail templates are ONE quest per template, first registration wins -- a clone
-- keeping the id either loses its own mail (cosmetic) or, when it registers
-- first, strips the mail reward from the STOCK quest (quest 5128 lost its
-- Everlook letter this way).  Clones reward without the follow-up mail.  The
-- mail fields live in quest_template_addon on this fork, and the column is
-- `RewardMailTemplateID` -- capital ID, unlike the worldserver's log message.
UPDATE `quest_template_addon` SET `RewardMailTemplateID` = 0, `RewardMailDelay` = 0
WHERE `ID` BETWEEN {A} AND {B} AND `RewardMailTemplateID` <> 0;

-- objectives that name a creature or object we cloned should point at the clone
UPDATE `quest_template` SET `RequiredNpcOrGo1` = `RequiredNpcOrGo1` + {C}
WHERE {QR} AND `RequiredNpcOrGo1` > 0 AND `RequiredNpcOrGo1` IN ({RAWC});
UPDATE `quest_template` SET `RequiredNpcOrGo2` = `RequiredNpcOrGo2` + {C}
WHERE {QR} AND `RequiredNpcOrGo2` > 0 AND `RequiredNpcOrGo2` IN ({RAWC});
UPDATE `quest_template` SET `RequiredNpcOrGo3` = `RequiredNpcOrGo3` + {C}
WHERE {QR} AND `RequiredNpcOrGo3` > 0 AND `RequiredNpcOrGo3` IN ({RAWC});
UPDATE `quest_template` SET `RequiredNpcOrGo4` = `RequiredNpcOrGo4` + {C}
WHERE {QR} AND `RequiredNpcOrGo4` > 0 AND `RequiredNpcOrGo4` IN ({RAWC});
-- a NEGATIVE RequiredNpcOrGo is a gameobject id, stored negated
UPDATE `quest_template` SET `RequiredNpcOrGo1` = `RequiredNpcOrGo1` - {G}
WHERE {QR} AND `RequiredNpcOrGo1` < 0 AND -`RequiredNpcOrGo1` IN ({RAWG});
UPDATE `quest_template` SET `RequiredNpcOrGo2` = `RequiredNpcOrGo2` - {G}
WHERE {QR} AND `RequiredNpcOrGo2` < 0 AND -`RequiredNpcOrGo2` IN ({RAWG});
UPDATE `quest_template` SET `RequiredNpcOrGo3` = `RequiredNpcOrGo3` - {G}
WHERE {QR} AND `RequiredNpcOrGo3` < 0 AND -`RequiredNpcOrGo3` IN ({RAWG});
UPDATE `quest_template` SET `RequiredNpcOrGo4` = `RequiredNpcOrGo4` - {G}
WHERE {QR} AND `RequiredNpcOrGo4` < 0 AND -`RequiredNpcOrGo4` IN ({RAWG});
""".format(QR=QR, inset=inset, O=Q_OFF, A=Q_OFF, B=Q_OFF + 99999,
           C=C_OFF, G=G_OFF, RAWC=RAWC, RAWG=RAWG)))

    # addon + the chain remap
    p.append(block("quest_template_addon + chain remap", """
DELETE FROM `quest_template_addon` WHERE {QR};
{ins}

-- Only rewrite a link when its target is also cloned; otherwise it names a real
-- prerequisite from elsewhere in the world and must stay raw.
UPDATE `quest_template_addon` SET `PrevQuestID` = `PrevQuestID` + {O}
WHERE {QR} AND `PrevQuestID` > 0 AND `PrevQuestID` IN ({QSET});
UPDATE `quest_template_addon` SET `PrevQuestID` = `PrevQuestID` - {O}
WHERE {QR} AND `PrevQuestID` < 0 AND -`PrevQuestID` IN ({QSET});
UPDATE `quest_template_addon` SET `NextQuestID` = `NextQuestID` + {O}
WHERE {QR} AND `NextQuestID` > 0 AND `NextQuestID` IN ({QSET});
UPDATE `quest_template_addon` SET `BreadcrumbForQuestId` = `BreadcrumbForQuestId` + {O}
WHERE {QR} AND `BreadcrumbForQuestId` > 0 AND `BreadcrumbForQuestId` IN ({QSET});

-- ExclusiveGroup: remap by MAGNITUDE, keep the SIGN.  Negative = "only one of
-- the group", positive = "all of them" -- flipping it would invert the rule.
UPDATE `quest_template_addon` SET `ExclusiveGroup` = `ExclusiveGroup` + {O}
WHERE {QR} AND `ExclusiveGroup` > 0 AND `ExclusiveGroup` IN ({QSET});
UPDATE `quest_template_addon` SET `ExclusiveGroup` = `ExclusiveGroup` - {O}
WHERE {QR} AND `ExclusiveGroup` < 0 AND -`ExclusiveGroup` IN ({QSET});
""".format(QR=QR, O=Q_OFF, QSET=QSET,
           ins=clone("quest_template_addon", "ID", Q_OFF, inset))))

    # the text/emote side tables
    side = []
    for t in ("quest_details", "quest_offer_reward", "quest_request_items"):
        side.append("DELETE FROM `%s` WHERE %s;\n%s" % (t, QR, clone(t, "ID", Q_OFF, inset)))
    # quest_greeting is NOT one of these, despite the name.  Its `ID` is the
    # CREATURE entry (when type = 0), not the quest id, so keying it off the
    # quest set matched creature entries against quest ids by coincidence and
    # wrote them at the quest offset -- five rows pointing at creatures that do
    # not exist.  It is cloned correctly on the creature side in 166_, at the
    # creature offset; 169_ deletes the bad rows this block produced.
    p.append(block("quest text / emote tables", "\n\n".join(side)))

    # questgiver links -- both the quest id AND the npc/go id move
    p.append(block("questgiver links -- both sides remapped", """
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN {A} AND {B};
INSERT INTO `creature_queststarter` (`id`,`quest`)
SELECT `id` + {C}, `quest` + {O} FROM `creature_queststarter`
WHERE `id` IN ({RAWC}) AND `quest` IN ({QSET});

DELETE FROM `creature_questender` WHERE `quest` BETWEEN {A} AND {B};
INSERT INTO `creature_questender` (`id`,`quest`)
SELECT `id` + {C}, `quest` + {O} FROM `creature_questender`
WHERE `id` IN ({RAWC}) AND `quest` IN ({QSET});

DELETE FROM `gameobject_queststarter` WHERE `quest` BETWEEN {A} AND {B};
INSERT INTO `gameobject_queststarter` (`id`,`quest`)
SELECT `id` + {G}, `quest` + {O} FROM `gameobject_queststarter`
WHERE `id` IN ({RAWG}) AND `quest` IN ({QSET});

DELETE FROM `gameobject_questender` WHERE `quest` BETWEEN {A} AND {B};
INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT `id` + {G}, `quest` + {O} FROM `gameobject_questender`
WHERE `id` IN ({RAWG}) AND `quest` IN ({QSET});
""".format(A=Q_OFF, B=Q_OFF + 99999, O=Q_OFF, C=C_OFF, G=G_OFF,
           RAWC=RAWC, RAWG=RAWG, QSET=QSET)))

    # POI, retargeted at the DC map
    p.append(block("quest POI -- retargeted at map 750 / WorldMapArea 1216", """
DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN {A} AND {B};
DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN {A} AND {B};

INSERT INTO `quest_poi`
  (`QuestID`,`id`,`ObjectiveIndex`,`MapID`,`WorldMapAreaId`,`Floor`,`Priority`,`Flags`,`VerifiedBuild`)
SELECT `QuestID` + {O}, `id`, `ObjectiveIndex`, 750, 1216, `Floor`, `Priority`, `Flags`, 0
FROM `quest_poi` WHERE `QuestID` IN ({QSET});

INSERT INTO `quest_poi_points` (`QuestID`,`Idx1`,`Idx2`,`X`,`Y`,`VerifiedBuild`)
SELECT `QuestID` + {O}, `Idx1`, `Idx2`, `X`, `Y`, 0
FROM `quest_poi_points` WHERE `QuestID` IN ({QSET});
""".format(A=Q_OFF, B=Q_OFF + 99999, O=Q_OFF, QSET=QSET)))

    p.append(block("verification -- all of these should return zero rows", """
-- 1. a cloned quest whose Prev/Next points at a quest that does not exist
--    SELECT a.ID, a.PrevQuestID, a.NextQuestID FROM quest_template_addon a
--    WHERE a.ID BETWEEN {A} AND {B}
--      AND ((a.PrevQuestID > 0 AND NOT EXISTS (SELECT 1 FROM quest_template q WHERE q.ID = a.PrevQuestID))
--        OR (a.NextQuestID > 0 AND NOT EXISTS (SELECT 1 FROM quest_template q WHERE q.ID = a.NextQuestID)));
--
-- 2. a cloned quest with no giver and no ender
--    SELECT q.ID FROM quest_template q WHERE q.ID BETWEEN {A} AND {B}
--      AND NOT EXISTS (SELECT 1 FROM creature_queststarter s WHERE s.quest = q.ID)
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = q.ID)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_queststarter s WHERE s.quest = q.ID)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender e WHERE e.quest = q.ID);
--
-- 3. an ExclusiveGroup whose sign flipped (magnitude moved but sign did not)
--    SELECT ID, ExclusiveGroup FROM quest_template_addon
--    WHERE ID BETWEEN {A} AND {B} AND ExclusiveGroup <> 0
--      AND SIGN(ExclusiveGroup) <> (SELECT SIGN(o.ExclusiveGroup) FROM quest_template_addon o
--                                   WHERE o.ID = quest_template_addon.ID - {O});
""".format(A=Q_OFF, B=Q_OFF + 99999, O=Q_OFF)))

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "167_border_zone_quests.sql")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(p))
    print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


if __name__ == "__main__":
    main()
