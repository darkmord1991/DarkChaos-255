-- Races 28-31: grant the racials the stock way, through SkillLineAbility.
-- Same mechanism as ../CharacterCreation/03_custom_racials_skilllineability.sql: the rows ride the
-- faction language skill (Common 98, Orcish 109) with the race's own bit as RaceMask, and are taught
-- at every login. Harmless until the races exist: no character has these bits yet.
--
-- Ids 31720-31738: this table reached 31713 on 2026-11-01, the client DBC stops at 31448.
-- Not granted: the helper spells 256374, 256893, 256896, 273218 and 274739-274742.
-- Regeneration and Da Voodoo Shuffle are the stock troll spells, shared with Drakkari.
--
-- Needs 10_spell_dbc.sql first. A row whose spell the server does not know is skipped.

DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN 31720 AND 31738;
INSERT INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`, `ExcludeClass`, `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`, `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`) VALUES
-- Alliance, skill 98 (Language: Common)
-- Void Elf 29 = 1 << 28
(31720, 98, 255668, 268435456, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Chill of Night
(31721, 98, 255670, 268435456, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Preternatural Calm
(31722, 98, 255669, 268435456, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Entropic Embrace
(31723, 98, 256948, 268435456, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Spatial Rift
(31724, 98, 257040, 268435456, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Spatial Rift: Teleport
-- Lightforged Draenei 30 = 1 << 29
(31725, 98, 255651, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Holy Resistance
(31726, 98, 255650, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Forge of Light (Blacksmithing)
(31727, 98, 259930, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Forge of Light (summon)
(31728, 98, 255647, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Light's Judgment
(31729, 98, 255652, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Light's Reckoning
(31730, 98, 255653, 536870912, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Demonbane
-- Horde, skill 109 (Language: Orcish)
-- Drakkari Troll 28 = 1 << 27
(31731, 109, 910200, 134217728, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),  -- Blood of the Gods
(31732, 109, 20555, 134217728, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Regeneration
(31733, 109, 910201, 134217728, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),  -- Frozen Empire
(31734, 109, 58943, 134217728, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0),   -- Da Voodoo Shuffle
-- Mag'har Orc 31 = 1 << 30
(31735, 109, 274738, 1073741824, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Ancestral Call
(31736, 109, 273216, 1073741824, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Open Skies
(31737, 109, 273217, 1073741824, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Sympathetic Vigor
(31738, 109, 273220, 1073741824, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0); -- Savage Blood
