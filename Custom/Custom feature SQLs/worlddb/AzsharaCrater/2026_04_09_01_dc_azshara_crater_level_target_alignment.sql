-- Align Azshara Crater quest levels with their required kill targets.
-- Scope: clear data mismatches and large level drifts.
--
-- Notes:
-- 1) This pass fixes obvious wrong target entries for objective text that already
--    names a specific creature type.
-- 2) This pass then retunes QuestLevel/MinLevel for high-delta outliers.
-- 3) Remaining extreme mismatches (300941, 300945, 300965) are intentionally
--    left for manual design review because the current objective names do not
--    have clean level-equivalent replacements in creature_template.

-- Ghostly Presence: replace credit marker with the actual Ethereal Scavenger.
UPDATE `quest_template`
SET `RequiredNpcOrGo2` = 18309
WHERE `ID` = 300700
  AND `QuestSortID` = 268;

-- Highborne Corruption: match objective text to correct creatures.
UPDATE `quest_template`
SET
    `RequiredNpcOrGo1` = 6117,
    `RequiredNpcOrGo2` = 11466
WHERE `ID` = 300944
  AND `QuestSortID` = 268;

-- Eldreth Incursion: match objective text to correct creatures.
UPDATE `quest_template`
SET
    `RequiredNpcOrGo1` = 11470,
    `RequiredNpcOrGo2` = 11469
WHERE `ID` = 300946
  AND `QuestSortID` = 268;

-- Level alignment pass for high-delta quests.
UPDATE `quest_template`
SET
    `QuestLevel` = CASE `ID`
        WHEN 300205 THEN 15
        WHEN 300400 THEN 39
        WHEN 300401 THEN 45
        WHEN 300402 THEN 51
        WHEN 300403 THEN 53
        WHEN 300511 THEN 61
        WHEN 300512 THEN 61
        WHEN 300514 THEN 61
        WHEN 300700 THEN 65
        WHEN 300702 THEN 62
        WHEN 300944 THEN 54
        WHEN 300946 THEN 60
        WHEN 300961 THEN 63
        ELSE `QuestLevel`
    END,
    `MinLevel` = CASE `ID`
        WHEN 300205 THEN 11
        WHEN 300400 THEN 35
        WHEN 300401 THEN 41
        WHEN 300402 THEN 47
        WHEN 300403 THEN 49
        WHEN 300511 THEN 57
        WHEN 300512 THEN 57
        WHEN 300514 THEN 57
        WHEN 300700 THEN 61
        WHEN 300702 THEN 58
        WHEN 300944 THEN 50
        WHEN 300946 THEN 56
        WHEN 300961 THEN 59
        ELSE `MinLevel`
    END
WHERE `ID` IN (
    300205,
    300400,
    300401,
    300402,
    300403,
    300511,
    300512,
    300514,
    300700,
    300702,
    300944,
    300946,
    300961
)
  AND `QuestSortID` = 268;
