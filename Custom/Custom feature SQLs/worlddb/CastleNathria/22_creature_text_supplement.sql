-- Castle Nathria (map 2296) -- creature_text supplement (22): the 37 helper/add lines missed by 09.
--
-- The 2026-07-21 all-source text sweep (shadowcore base + updates, world09, official TC 9.2.7 TDB)
-- found the original 09_creature_text.sql extract took only the 65 lines belonging to the 13
-- boss/co-boss entries -- the same shadowcore update file (2021_03_18_01_world_creature_text.sql)
-- holds 102 Nathria rows; these are the remaining 37, across 15 helper/add/controller entries
-- (Sun King's encounter dialogue, Xy'mox relic announces, Danse Macabre caller, Stone Legion
-- helpers, Prince Renathal's trash-gauntlet RP). The sweep also CONFIRMED no source anywhere has
-- creature_text for Hungering Destroyer (164261), Lady Inerva (165521), Huntsman Altimor (165066)
-- or Sire Denathrius (167406) -- the DC-authored lines in 09/17 stay.
--
-- Transcode conventions (same as 09): modern Type 14 -> 12 (Say/Yell), 41 -> 16 (Emote announce),
-- 42 -> 15 (Whisper); SL SoundKit ids + BroadcastTextIds zeroed (no 3.3.5 Sound.dbc backport --
-- same class as the r10 boss-VO silencing); Emote ids kept only when valid on 3.3.5 (961 zeroed).
-- GroupID/ID sequencing copied verbatim from source so any AI Talk() wiring binds 1:1.
--
-- Apply against acore_world.

DELETE FROM `creature_text` WHERE `CreatureID` IN (165805, 165760, 165788, 168973, 168317, 168512, 169062, 169267, 168870, 169835, 170404, 173119, 173120, 173298, 172652);
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (165805, 0, 0, 'My rage burns like a thousand suns!', 12, 0, 100, 15, 0, 0, 0, 0, 'Shade of Kael''thas - emerge'),
    (165805, 1, 0, 'The Shade of Kael''thas has emerged!', 16, 0, 100, 15, 0, 0, 0, 0, 'Shade of Kael''thas - emerge announce'),
    (165805, 2, 0, 'Fire consume you!', 12, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - Ember Blast'),
    (165805, 3, 0, '|TInterface\\ICONS\\SPELL_FIRE_SELFDESTRUCT.BLP:20|t %s is targeting |cFFFF0000$n|r for |cFFFF0000|Hspell:325873|h[Ember Blast]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - Ember Blast announce'),
    (165805, 4, 0, 'You shall all be engulfed in flame!', 12, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - Cloak of Flames'),
    (165805, 5, 0, 'Felomin ashal!', 12, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - cast'),
    (165805, 6, 0, 'I am not finished! Let me be free!', 12, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - 45pct'),
    (165805, 7, 0, 'No! I will not be confined again!', 12, 0, 100, 0, 0, 0, 0, 0, 'Shade of Kael''thas - 90pct'),
    (165760, 0, 0, 'More of those fools seek to hinder us. Do not allow them to interfere.', 12, 0, 100, 0, 0, 0, 0, 0, 'The Accuser (Sun King) - wave #1'),
    (165760, 1, 0, 'Additional guards are en route. Ensure that their deaths are swift.', 12, 0, 100, 0, 0, 0, 0, 0, 'The Accuser (Sun King) - wave #2'),
    (165760, 2, 0, 'Another interruption from the castle guard. Dispose of them.', 12, 0, 100, 0, 0, 0, 0, 0, 'The Accuser (Sun King) - wave #3'),
    (165788, 0, 0, '|TInterface\\ICONS\\Spell_AnimaRevendreth_Nova.BLP:20|tInterrupt Vile Occultist''s |cFFFF0000|Hspell:333002|h[Vulgar Brand]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - Vulgar Brand warn'),
    (165788, 1, 0, 'A Rockbound Vanquisher is flying in from above!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - Vanquisher wave'),
    (165788, 2, 0, 'Enemy reinforcements are on their way!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - reinforcements'),
    (165788, 3, 0, 'Vile Occultist reinforcements are on their way!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - Occultist wave'),
    (165788, 4, 0, 'Soul Infusers are on their way to attack Kael''thas!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - Infuser wave'),
    (165788, 5, 0, '|TInterface\\ICONS\\Spell_AnimaRevendreth_Buff.BLP:20|tPick up Infuser Orbs to gain |cFFFF0000|Hspell:326078|h[Infuser''s Boon]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Fight Controller - Infuser orb hint'),
    (168973, 0, 0, 'Renathal''s traitors?! Guards, stop them!', 12, 0, 100, 0, 0, 0, 0, 0, 'High Torturer Darithos - aggro'),
    (168973, 1, 0, '|TInterface\\ICONS\\Spell_AnimaRevendreth_Wave.BLP:20|tYou are targeted for |cFFFF0000|Hspell:328885|h[Greater Castigation]|h|r!', 15, 0, 100, 0, 0, 0, 0, 0, 'High Torturer Darithos - Castigation whisper'),
    (168317, 0, 0, '|TInterface\\ICONS\\Ability_Fixated_State_Green.blp:20|t A Fleeting Spirit fixates on you!', 15, 0, 100, 0, 0, 0, 0, 0, 'Fleeting Spirit - fixate whisper'),
    (168512, 0, 0, '|TInterface\\ICONS\\INV_Cape_Special_Maldraxxus_D_03.blp:20|t The Crystal of Phantasms conjures|cFFFF0000|Hspell:327887|h [Fleeting Spirits]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Crystal of Phantasms - announce'),
    (169062, 0, 0, '|TInterface\\ICONS\\INV_Archaeology_80_Witch_GuillotineAxe.BLP:20|t The Edge of Annihilation begins casting|cFFFF0000|Hspell:328789|h [Annihilate]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Edge of Annihilation - announce'),
    (169267, 0, 0, '|TInterface\\ICONS\\Ability_Ardenweald_Mage.BLP:20|t The Root of Extinction creates|cFFFF0000|Hspell:329834|h [Seeds of Extinction]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Root of Extinction - announce'),
    (168870, 0, 0, 'Take your places for the Danse Macabre!', 16, 0, 100, 0, 0, 0, 0, 0, 'Dance Controller - announce'),
    (169835, 0, 0, 'Bring me their anima, heroes!', 12, 0, 100, 0, 0, 0, 0, 0, 'Prince Renathal (SLG) - anima plea'),
    (169835, 1, 0, '|TInterface\\Icons\\INV_Misc_VoljinsShatteredTusk.BLP:20|t%s begins casting |cFFFF0000|Hspell:332683|h[Shattering Blast]|h|r!', 16, 0, 100, 0, 0, 0, 0, 0, 'Prince Renathal (SLG) - Shattering Blast'),
    (169835, 2, 0, 'I need more anima!', 12, 0, 100, 0, 0, 0, 0, 0, 'Prince Renathal (SLG) - more anima'),
    (170404, 0, 0, 'Champions, I will clear the skies!', 12, 0, 100, 53, 0, 0, 0, 0, 'General Draven (SLG) - clear skies'),
    (173119, 0, 0, 'Taking... all my strength... to hold back... their onslaught!', 12, 0, 100, 0, 0, 0, 0, 0, 'Prince Renathal (Denathrius) - holding'),
    (173120, 0, 0, 'Incoming! Take cover!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Draven (Denathrius) - incoming'),
    (173298, 0, 0, 'Stoneborn! Strike down these usurpers!', 12, 0, 100, 0, 0, 0, 0, 0, 'General Kaal (gauntlet) - aggro'),
    (172652, 0, 0, 'These brokers are a greedy lot. Do not let such potent weapons fall into their hands!', 12, 0, 100, 1, 0, 0, 0, 0, 'Prince Renathal - brokers'),
    (172652, 1, 0, 'Greed. Truly one of the most malignant of all sins.', 12, 0, 100, 1, 0, 0, 0, 0, 'Prince Renathal - greed'),
    (172652, 2, 0, 'Come, mortals. It is time to rid Revendreth of a haughty band of nobles that stand between us and Denathrius.', 12, 0, 100, 1, 0, 0, 0, 0, 'Prince Renathal - nobles'),
    (172652, 3, 0, 'Another passage back to the antechamber lies this way.', 12, 0, 100, 1, 0, 0, 0, 0, 'Prince Renathal - passage'),
    (172652, 4, 0, 'You have done well so far, mortals, striking a blow to the efforts of Denathrius. But do not underestimate his power. His might is... considerable.', 12, 0, 100, 1, 0, 0, 0, 0, 'Prince Renathal - progress'),
    (172652, 5, 0, 'Watch them scatter! It sickens me how far some of my people have fallen.', 12, 0, 100, 0, 0, 0, 0, 0, 'Prince Renathal - scatter');
