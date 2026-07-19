-- Castle Nathria (map 2296) -- creature_text (boss yells), transcoded from shadowcore's
-- 2021_03_18_01_world_creature_text.sql (2176 lines total; 65 lines across 9 of our 13 boss/co-boss
-- entries reference this raid -- the file also holds a large amount of unrelated Legion-zone content,
-- some of it Spanish-localized, which is NOT part of this extract).
--
-- Column mapping: source has (CreatureID, GroupID, ID, Text, Type, Language, Probability, Emote,
-- Duration, Sound, BroadcastTextId, comment) -- no TextRange column, defaulted to 0 here. GroupID/ID
-- sequencing is copied as-is from source (already a clean 0..N-1 per-creature sequence, ID always 0 --
-- nothing to renumber). Emote/Duration/Sound/BroadcastTextId are zeroed per this pass's scope (retail
-- SoundKit ids and BroadcastText localization rows don't carry over to 3.3.5; not needed for basic
-- yell functionality).
--
-- Type: source uses two values for these entries -- 14 (plain spoken line) and 41 (a handful of
-- "boss begins casting/using <ability>" narrated lines wrapped in retail icon+spell-hyperlink markup,
-- which won't render on 3.3.5 but the underlying English text is kept verbatim). 14 is transcoded to
-- 12 (Yell); 41 is transcoded to 16 (Emote), since those lines read as narrated ability telegraphs
-- rather than first-person speech.
--
-- Coverage gap: 4 of the 13 boss/co-boss entries have ZERO creature_text rows in this source (or in
-- the 2 bulk world dumps / 3 boss-specific patch files, all checked and confirmed empty for these):
-- Hungering Destroyer (164261), Huntsman Altimor (165066), Lady Inerva Darkvein (165521), and Sire
-- Denathrius (167406) -- yes, including the raid's own final boss. This is a genuine source-data gap,
-- not an oversight; no rows are written for these 4 entries.
--
-- NOTE: the C++ boss AI for this raid has not been ported yet (deferred), so none of these rows are
-- actually triggered by anything right now -- this just gets the yell content into the DB, ready for
-- when the AI is ported and calls Talk(GROUP_ID).
--
-- Apply against acore_world.

-- ---------------------------------------------------------------------------
-- Shriekwing (164406) -- 2 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 164406;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (164406, 0, 0, '|TINTERFACE\\ICONS\\Spell_Shadow_Deathscream.blp:20|t Shriekwing begins to unleash an |cFFFF0404|Hspell:330711|h[Earsplitting Shriek]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Shriekwing - Earsplitting Shriek cast'),
    (164406, 1, 0, '|TINTERFACE\\ICONS\\ability_deathwing_bloodcorruption_earth.blp:20|t Shriekwing begins to fade under the effects of |cFFFF0404|Hspell:328921|h[Blood Shroud]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Shriekwing - Blood Shroud cast');

-- ---------------------------------------------------------------------------
-- Huntsman Altimor (165066) -- NO creature_text rows in any source checked.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Hungering Destroyer (164261) -- NO creature_text rows in any source checked.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Sun King's Salvation (165759) -- 2 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 165759;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (165759, 0, 0, 'I can... feel my strength... returning...', 12, 0, 100, 0, 0, 0, 0, 0, 'Sun King''s Salvation - Yell #1'),
    (165759, 1, 0, 'You must... be joking...', 12, 0, 100, 0, 0, 0, 0, 0, 'Sun King''s Salvation - Death');

-- ---------------------------------------------------------------------------
-- Artificer Xy'mox (166644) -- 11 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 166644;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (166644, 0, 0, 'Wonderful! I have been hoping to test these relics on live targets.', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #1'),
    (166644, 1, 0, 'Mind your step!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #2'),
    (166644, 2, 0, 'Let us see if the legends of this relic are true!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #3'),
    (166644, 3, 0, 'Destruction is guaranteed!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #4'),
    (166644, 4, 0, 'The warp beckons!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #5'),
    (166644, 5, 0, 'The anticipation to use this relic is killing me! Though, it will more likely kill you.', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #6'),
    (166644, 6, 0, 'To die is your only value!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #7'),
    (166644, 7, 0, 'You cannot bargain with death!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #8'),
    (166644, 8, 0, 'Die together!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #9'),
    (166644, 9, 0, 'I hope this wondrous item is as lethal as it looks!', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Yell #10'),
    (166644, 10, 0, 'This exchange has no further value. Consider our business concluded, for now.', 12, 0, 100, 0, 0, 0, 0, 0, 'Artificer Xy''mox - Death');

-- ---------------------------------------------------------------------------
-- Lady Inerva Darkvein (165521) -- NO creature_text rows in any source checked.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Council of Blood -- Baroness Frieda (166969) -- 7 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 166969;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (166969, 0, 0, 'Dear guests and vile intruders, take your places for the dance macabre!', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #1'),
    (166969, 1, 0, 'Shimmy right!', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #2'),
    (166969, 2, 0, 'Sashay left!', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #3'),
    (166969, 3, 0, 'Prance Forward!', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #4'),
    (166969, 4, 0, 'Boogie down!', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #5'),
    (166969, 5, 0, 'Enough! Your gyrations sicken me.', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Yell #6'),
    (166969, 6, 0, 'You will always... be beneath me...', 12, 0, 100, 0, 0, 0, 0, 0, 'Baroness Frieda - Death');

-- ---------------------------------------------------------------------------
-- Council of Blood -- Lord Stavros (166970) -- 10 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 166970;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (166970, 0, 0, 'How dare you invade my party in such dreadful attire!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #1'),
    (166970, 1, 0, 'Everyone, find your partners! Or die!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #2'),
    (166970, 2, 0, 'Come, friends! Dance until you bleed!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #3'),
    (166970, 3, 0, 'Everyone, take your positions! It is time for the dance macabre!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #4'),
    (166970, 4, 0, 'Boogie down!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #5'),
    (166970, 5, 0, 'Shimmy right!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #6'),
    (166970, 6, 0, 'Sashay left!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #7'),
    (166970, 7, 0, 'Prance Forward!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #8'),
    (166970, 8, 0, 'Your steps were simply delicious! Pity you have to die now.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Yell #9'),
    (166970, 9, 0, 'But I am... the life... of the party...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Stavros - Death');

-- ---------------------------------------------------------------------------
-- Council of Blood -- Castellan Niklaus (166971) -- 1 line
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 166971;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (166971, 0, 0, 'What kind... of strategy... was that...', 12, 0, 100, 0, 0, 0, 0, 0, 'Castellan Niklaus - Death');

-- ---------------------------------------------------------------------------
-- Sludgefist (164407) -- 14 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 164407;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (164407, 0, 0, 'Gonna flatten your bones!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #1'),
    (164407, 1, 0, 'You flat now!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #2'),
    (164407, 2, 0, '|TInterface\\Icons\\SPELL_NATURE_EARTHQUAKE:20|tSludgefist readies a |cFFFF0000|Hspell:332318|h[Destructive Stomp]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Destructive Stomp cast'),
    (164407, 3, 0, 'Stand still.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #4'),
    (164407, 4, 0, 'Master be so happy!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #5'),
    (164407, 5, 0, 'Squish you!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #6'),
    (164407, 6, 0, 'Skull stomping time!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #7'),
    (164407, 7, 0, 'Stone harder than head.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #8'),
    (164407, 8, 0, 'Ouchie!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #9'),
    (164407, 9, 0, 'Crush your face!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #10'),
    (164407, 10, 0, 'Sound so sweet to squish you with my feet.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #11'),
    (164407, 11, 0, 'Smash!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #12'),
    (164407, 12, 0, 'No fair.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Yell #13'),
    (164407, 13, 0, 'Master... gonna be mad... at you...', 12, 0, 100, 0, 0, 0, 0, 0, 'Sludgefist - Death');

-- ---------------------------------------------------------------------------
-- Stone Legion Generals -- General Kaal (168112) -- 10 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 168112;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (168112, 0, 0, 'Tear you asunder!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #1'),
    (168112, 1, 0, 'No escape!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #2'),
    (168112, 2, 0, 'Bleed!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #3'),
    (168112, 3, 0, 'Flesh to stone!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #4'),
    (168112, 4, 0, 'My blade will find you!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #5'),
    (168112, 5, 0, 'I will not be broken!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #6'),
    (168112, 6, 0, 'Tremble in my shadow!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #7'),
    (168112, 7, 0, 'Grashaal, shield yourself! It is time to rain terror from above!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #8'),
    (168112, 8, 0, 'I will end you myself!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Yell #9'),
    (168112, 9, 0, 'My blood... for... master...', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal - Death');

-- ---------------------------------------------------------------------------
-- Stone Legion Generals -- General Grashaal (168113) -- 8 lines
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 168113;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (168113, 0, 0, '|TInterface\\Icons\\INV_DataCrystal06.blp:20|t%s begins casting |cFFFF0000|Hspell:339690|h[Crystalize]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Crystalize cast'),
    (168113, 1, 0, 'General Kaal, Get cover! My soldiers will strike from the sky!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #2'),
    (168113, 2, 0, 'Die by my hand!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #3'),
    (168113, 3, 0, 'I will break you!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #4'),
    (168113, 4, 0, 'Your blades will break across my skin!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #5'),
    (168113, 5, 0, 'I will drive you into the ground!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #6'),
    (168113, 6, 0, 'I cannot be shattered!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Yell #7'),
    (168113, 7, 0, 'To serve... was my... greatest honor...', 12, 0, 100, 0, 0, 0, 0, 0, 'General Grashaal - Death');

-- ---------------------------------------------------------------------------
-- Sire Denathrius (167406) -- NO creature_text rows in any source checked (including the dedicated
-- creature_text patch file -- the final boss's dialogue is not present in any of the 4 sources).
-- ---------------------------------------------------------------------------
