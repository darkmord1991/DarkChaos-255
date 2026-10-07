-- Hunter pets: wire up the skill lines of the post-WotLK pet families.
--
-- A hunter pet learns its spells from the two skill lines on its CreatureFamily row: its family line
-- (basic attack, family special, the +5% "Tamed Pet Passive (DND)") and 270 "Pet - Generic Hunter"
-- (Growl, Cower, Hunter Pet Scaling 01-04, Tamed Pet Passive 00-11). SpellMgr::LoadPetLevelupSpellMap
-- and the sPetFamilySpellsStore loop in DBCStores.cpp collect them from SkillLineAbility.
--   * Fox 50, Dog 52 and Shale Spider 55 point at the Cata lines 808/811/817, which had no
--     SkillLineAbility rows: those pets knew no basic attack and no family ability.
--   * Direhorn 56, Feathermane 57, Mechanical 58, Quilen 59 and Blood Beast 60 had both lines at 0,
--     so they did not even get line 270 (no Growl, no stat scaling from the hunter).
--
-- The real family specials (Tailspin, Lock Jaw, Web Wrap, Gore, Feather Flurry, Defense Matrix,
-- Stone Armor, Blood Bolt) are not in the 3.3.5 Spell.dbc, so each line copies the closest stock pet
-- ability, all ranks, from that ability's own family line:
--   808   Fox           Bite  + Dust Cloud    (Cata Tailspin: "kicking up an obscuring cloud of dust")
--   811   Dog           Bite  + Pin           (Cata Lock Jaw: holds the target in place)
--   817   Shale Spider  Bite  + Web           (Cata Web Wrap: "encases the target in sticky webs")
--   30056 Direhorn      Smack + Gore          (retail Gore)
--   30057 Feathermane   Claw  + Snatch
--   30058 Mechanical    Smack + Shell Shield  (retail Defense Matrix: -50% damage taken)
--   30059 Quilen        Bite  + Shell Shield  (retail Stone Armor: -40% damage taken)
--   30060 Blood Beast   Bite  + Tendon Rip    (retail Blood Bolt: 50% snare)
-- 30056-30060 are a custom block (30000 + family id), clear of every Cata skill line id (max 824).
-- Basic attacks follow Cata for 808/811/817; Dash/Charge/Dive/Swoop rows are AcquireMethod 0
-- (talents), copied for parity with the stock lines.
--
-- The server never looks these lines up in SkillLine.dbc, so no SkillLine rows are needed; the client
-- gets the pet's spells from SMSG_PET_SPELLS. CategoryEnumID is client-only (the server's
-- CreatureFamily format skips it): Talent.dbc's CategoryMask decides which per-family movement
-- talents (Dash/Dive, Charge/Swoop, Mobility) a family sees, and no mask has the Cata ids 27/29/57
-- or the placeholder 0 of 56-60 in the right tree. Each family now borrows the id of a stock family
-- of the same tree and kind (land/flying). If a PetTalentType changes, re-pick from that tree.
-- The same CreatureFamily values are in Custom/CSV DBC/CreatureFamily.csv for the client DBC.

DELETE FROM `skilllineability_dbc` WHERE `ID` BETWEEN 31600 AND 31738;
INSERT INTO `skilllineability_dbc` (`ID`, `SkillLine`, `Spell`, `RaceMask`, `ClassMask`, `ExcludeRace`, `ExcludeClass`, `MinSkillLineRank`, `SupercededBySpell`, `AcquireMethod`, `TrivialSkillLineRankHigh`, `TrivialSkillLineRankLow`, `CharacterPoints_1`, `CharacterPoints_2`) VALUES
-- 808 Pet - Fox
(31600, 808, 17253, 0, 0, 0, 0, 1, 17255, 2, 0, 0, 0, 0), -- Bite Rank 1
(31601, 808, 17255, 0, 0, 0, 0, 1, 17256, 2, 0, 0, 0, 0), -- Bite Rank 2
(31602, 808, 17256, 0, 0, 0, 0, 1, 17257, 2, 0, 0, 0, 0), -- Bite Rank 3
(31603, 808, 17257, 0, 0, 0, 0, 1, 17258, 2, 0, 0, 0, 0), -- Bite Rank 4
(31604, 808, 17258, 0, 0, 0, 0, 1, 17259, 2, 0, 0, 0, 0), -- Bite Rank 5
(31605, 808, 17259, 0, 0, 0, 0, 1, 17260, 2, 0, 0, 0, 0), -- Bite Rank 6
(31606, 808, 17260, 0, 0, 0, 0, 1, 17261, 2, 0, 0, 0, 0), -- Bite Rank 7
(31607, 808, 17261, 0, 0, 0, 0, 1, 27050, 2, 0, 0, 0, 0), -- Bite Rank 8
(31608, 808, 27050, 0, 0, 0, 0, 1, 52473, 2, 0, 0, 0, 0), -- Bite Rank 9
(31609, 808, 52473, 0, 0, 0, 0, 1, 52474, 2, 0, 0, 0, 0), -- Bite Rank 10
(31610, 808, 52474, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Bite Rank 11
(31611, 808, 50285, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Dust Cloud
(31612, 808, 17220, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31613, 808, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31614, 808, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 811 Pet - Dog
(31615, 811, 17253, 0, 0, 0, 0, 1, 17255, 2, 0, 0, 0, 0), -- Bite Rank 1
(31616, 811, 17255, 0, 0, 0, 0, 1, 17256, 2, 0, 0, 0, 0), -- Bite Rank 2
(31617, 811, 17256, 0, 0, 0, 0, 1, 17257, 2, 0, 0, 0, 0), -- Bite Rank 3
(31618, 811, 17257, 0, 0, 0, 0, 1, 17258, 2, 0, 0, 0, 0), -- Bite Rank 4
(31619, 811, 17258, 0, 0, 0, 0, 1, 17259, 2, 0, 0, 0, 0), -- Bite Rank 5
(31620, 811, 17259, 0, 0, 0, 0, 1, 17260, 2, 0, 0, 0, 0), -- Bite Rank 6
(31621, 811, 17260, 0, 0, 0, 0, 1, 17261, 2, 0, 0, 0, 0), -- Bite Rank 7
(31622, 811, 17261, 0, 0, 0, 0, 1, 27050, 2, 0, 0, 0, 0), -- Bite Rank 8
(31623, 811, 27050, 0, 0, 0, 0, 1, 52473, 2, 0, 0, 0, 0), -- Bite Rank 9
(31624, 811, 52473, 0, 0, 0, 0, 1, 52474, 2, 0, 0, 0, 0), -- Bite Rank 10
(31625, 811, 52474, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Bite Rank 11
(31626, 811, 50245, 0, 0, 0, 0, 1, 53544, 2, 0, 0, 0, 0), -- Pin Rank 1
(31627, 811, 53544, 0, 0, 0, 0, 1, 53545, 2, 0, 0, 0, 0), -- Pin Rank 2
(31628, 811, 53545, 0, 0, 0, 0, 1, 53546, 2, 0, 0, 0, 0), -- Pin Rank 3
(31629, 811, 53546, 0, 0, 0, 0, 1, 53547, 2, 0, 0, 0, 0), -- Pin Rank 4
(31630, 811, 53547, 0, 0, 0, 0, 1, 53548, 2, 0, 0, 0, 0), -- Pin Rank 5
(31631, 811, 53548, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Pin Rank 6
(31632, 811, 17211, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31633, 811, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31634, 811, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 817 Pet - Exotic Shale Spider
(31635, 817, 17253, 0, 0, 0, 0, 1, 17255, 2, 0, 0, 0, 0), -- Bite Rank 1
(31636, 817, 17255, 0, 0, 0, 0, 1, 17256, 2, 0, 0, 0, 0), -- Bite Rank 2
(31637, 817, 17256, 0, 0, 0, 0, 1, 17257, 2, 0, 0, 0, 0), -- Bite Rank 3
(31638, 817, 17257, 0, 0, 0, 0, 1, 17258, 2, 0, 0, 0, 0), -- Bite Rank 4
(31639, 817, 17258, 0, 0, 0, 0, 1, 17259, 2, 0, 0, 0, 0), -- Bite Rank 5
(31640, 817, 17259, 0, 0, 0, 0, 1, 17260, 2, 0, 0, 0, 0), -- Bite Rank 6
(31641, 817, 17260, 0, 0, 0, 0, 1, 17261, 2, 0, 0, 0, 0), -- Bite Rank 7
(31642, 817, 17261, 0, 0, 0, 0, 1, 27050, 2, 0, 0, 0, 0), -- Bite Rank 8
(31643, 817, 27050, 0, 0, 0, 0, 1, 52473, 2, 0, 0, 0, 0), -- Bite Rank 9
(31644, 817, 52473, 0, 0, 0, 0, 1, 52474, 2, 0, 0, 0, 0), -- Bite Rank 10
(31645, 817, 52474, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Bite Rank 11
(31646, 817, 4167, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Web Rank 1
(31647, 817, 17219, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31648, 817, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 30056 Pet - Direhorn
(31649, 30056, 49966, 0, 0, 0, 0, 1, 49967, 2, 0, 0, 0, 0), -- Smack Rank 1
(31650, 30056, 49967, 0, 0, 0, 0, 1, 49968, 2, 0, 0, 0, 0), -- Smack Rank 2
(31651, 30056, 49968, 0, 0, 0, 0, 1, 49969, 2, 0, 0, 0, 0), -- Smack Rank 3
(31652, 30056, 49969, 0, 0, 0, 0, 1, 49970, 2, 0, 0, 0, 0), -- Smack Rank 4
(31653, 30056, 49970, 0, 0, 0, 0, 1, 49971, 2, 0, 0, 0, 0), -- Smack Rank 5
(31654, 30056, 49971, 0, 0, 0, 0, 1, 49972, 2, 0, 0, 0, 0), -- Smack Rank 6
(31655, 30056, 49972, 0, 0, 0, 0, 1, 49973, 2, 0, 0, 0, 0), -- Smack Rank 7
(31656, 30056, 49973, 0, 0, 0, 0, 1, 49974, 2, 0, 0, 0, 0), -- Smack Rank 8
(31657, 30056, 49974, 0, 0, 0, 0, 1, 52475, 2, 0, 0, 0, 0), -- Smack Rank 9
(31658, 30056, 52475, 0, 0, 0, 0, 1, 52476, 2, 0, 0, 0, 0), -- Smack Rank 10
(31659, 30056, 52476, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Smack Rank 11
(31660, 30056, 35290, 0, 0, 0, 0, 1, 35291, 2, 0, 0, 0, 0), -- Gore Rank 1
(31661, 30056, 35291, 0, 0, 0, 0, 1, 35292, 2, 0, 0, 0, 0), -- Gore Rank 2
(31662, 30056, 35292, 0, 0, 0, 0, 1, 35293, 2, 0, 0, 0, 0), -- Gore Rank 3
(31663, 30056, 35293, 0, 0, 0, 0, 1, 35294, 2, 0, 0, 0, 0), -- Gore Rank 4
(31664, 30056, 35294, 0, 0, 0, 0, 1, 35295, 2, 0, 0, 0, 0), -- Gore Rank 5
(31665, 30056, 35295, 0, 0, 0, 0, 1, 35296, 2, 0, 0, 0, 0), -- Gore Rank 6
(31666, 30056, 7000, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31667, 30056, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31668, 30056, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 30057 Pet - Feathermane
(31669, 30057, 16827, 0, 0, 0, 0, 1, 16828, 2, 0, 0, 0, 0), -- Claw Rank 1
(31670, 30057, 16828, 0, 0, 0, 0, 1, 16829, 2, 0, 0, 0, 0), -- Claw Rank 2
(31671, 30057, 16829, 0, 0, 0, 0, 1, 16830, 2, 0, 0, 0, 0), -- Claw Rank 3
(31672, 30057, 16830, 0, 0, 0, 0, 1, 16831, 2, 0, 0, 0, 0), -- Claw Rank 4
(31673, 30057, 16831, 0, 0, 0, 0, 1, 16832, 2, 0, 0, 0, 0), -- Claw Rank 5
(31674, 30057, 16832, 0, 0, 0, 0, 1, 3010, 2, 0, 0, 0, 0), -- Claw Rank 6
(31675, 30057, 3010, 0, 0, 0, 0, 1, 3009, 2, 0, 0, 0, 0), -- Claw Rank 7
(31676, 30057, 3009, 0, 0, 0, 0, 1, 27049, 2, 0, 0, 0, 0), -- Claw Rank 8
(31677, 30057, 27049, 0, 0, 0, 0, 1, 52471, 2, 0, 0, 0, 0), -- Claw Rank 9
(31678, 30057, 52471, 0, 0, 0, 0, 1, 52472, 2, 0, 0, 0, 0), -- Claw Rank 10
(31679, 30057, 52472, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Claw Rank 11
(31680, 30057, 50541, 0, 0, 0, 0, 1, 53537, 2, 0, 0, 0, 0), -- Snatch Rank 1
(31681, 30057, 53537, 0, 0, 0, 0, 1, 53538, 2, 0, 0, 0, 0), -- Snatch Rank 2
(31682, 30057, 53538, 0, 0, 0, 0, 1, 53540, 2, 0, 0, 0, 0), -- Snatch Rank 3
(31683, 30057, 53540, 0, 0, 0, 0, 1, 53542, 2, 0, 0, 0, 0), -- Snatch Rank 4
(31684, 30057, 53542, 0, 0, 0, 0, 1, 53543, 2, 0, 0, 0, 0), -- Snatch Rank 5
(31685, 30057, 53543, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Snatch Rank 6
(31686, 30057, 17216, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31687, 30057, 23145, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dive
(31688, 30057, 52825, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Swoop
-- 30058 Pet - Mechanical
(31689, 30058, 49966, 0, 0, 0, 0, 1, 49967, 2, 0, 0, 0, 0), -- Smack Rank 1
(31690, 30058, 49967, 0, 0, 0, 0, 1, 49968, 2, 0, 0, 0, 0), -- Smack Rank 2
(31691, 30058, 49968, 0, 0, 0, 0, 1, 49969, 2, 0, 0, 0, 0), -- Smack Rank 3
(31692, 30058, 49969, 0, 0, 0, 0, 1, 49970, 2, 0, 0, 0, 0), -- Smack Rank 4
(31693, 30058, 49970, 0, 0, 0, 0, 1, 49971, 2, 0, 0, 0, 0), -- Smack Rank 5
(31694, 30058, 49971, 0, 0, 0, 0, 1, 49972, 2, 0, 0, 0, 0), -- Smack Rank 6
(31695, 30058, 49972, 0, 0, 0, 0, 1, 49973, 2, 0, 0, 0, 0), -- Smack Rank 7
(31696, 30058, 49973, 0, 0, 0, 0, 1, 49974, 2, 0, 0, 0, 0), -- Smack Rank 8
(31697, 30058, 49974, 0, 0, 0, 0, 1, 52475, 2, 0, 0, 0, 0), -- Smack Rank 9
(31698, 30058, 52475, 0, 0, 0, 0, 1, 52476, 2, 0, 0, 0, 0), -- Smack Rank 10
(31699, 30058, 52476, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Smack Rank 11
(31700, 30058, 26064, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Shell Shield
(31701, 30058, 17221, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31702, 30058, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31703, 30058, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 30059 Pet - Quilen
(31704, 30059, 17253, 0, 0, 0, 0, 1, 17255, 2, 0, 0, 0, 0), -- Bite Rank 1
(31705, 30059, 17255, 0, 0, 0, 0, 1, 17256, 2, 0, 0, 0, 0), -- Bite Rank 2
(31706, 30059, 17256, 0, 0, 0, 0, 1, 17257, 2, 0, 0, 0, 0), -- Bite Rank 3
(31707, 30059, 17257, 0, 0, 0, 0, 1, 17258, 2, 0, 0, 0, 0), -- Bite Rank 4
(31708, 30059, 17258, 0, 0, 0, 0, 1, 17259, 2, 0, 0, 0, 0), -- Bite Rank 5
(31709, 30059, 17259, 0, 0, 0, 0, 1, 17260, 2, 0, 0, 0, 0), -- Bite Rank 6
(31710, 30059, 17260, 0, 0, 0, 0, 1, 17261, 2, 0, 0, 0, 0), -- Bite Rank 7
(31711, 30059, 17261, 0, 0, 0, 0, 1, 27050, 2, 0, 0, 0, 0), -- Bite Rank 8
(31712, 30059, 27050, 0, 0, 0, 0, 1, 52473, 2, 0, 0, 0, 0), -- Bite Rank 9
(31713, 30059, 52473, 0, 0, 0, 0, 1, 52474, 2, 0, 0, 0, 0), -- Bite Rank 10
(31714, 30059, 52474, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Bite Rank 11
(31715, 30059, 26064, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Shell Shield
(31716, 30059, 17221, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31717, 30059, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31718, 30059, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Charge
-- 30060 Pet - Blood Beast
(31719, 30060, 17253, 0, 0, 0, 0, 1, 17255, 2, 0, 0, 0, 0), -- Bite Rank 1
(31720, 30060, 17255, 0, 0, 0, 0, 1, 17256, 2, 0, 0, 0, 0), -- Bite Rank 2
(31721, 30060, 17256, 0, 0, 0, 0, 1, 17257, 2, 0, 0, 0, 0), -- Bite Rank 3
(31722, 30060, 17257, 0, 0, 0, 0, 1, 17258, 2, 0, 0, 0, 0), -- Bite Rank 4
(31723, 30060, 17258, 0, 0, 0, 0, 1, 17259, 2, 0, 0, 0, 0), -- Bite Rank 5
(31724, 30060, 17259, 0, 0, 0, 0, 1, 17260, 2, 0, 0, 0, 0), -- Bite Rank 6
(31725, 30060, 17260, 0, 0, 0, 0, 1, 17261, 2, 0, 0, 0, 0), -- Bite Rank 7
(31726, 30060, 17261, 0, 0, 0, 0, 1, 27050, 2, 0, 0, 0, 0), -- Bite Rank 8
(31727, 30060, 27050, 0, 0, 0, 0, 1, 52473, 2, 0, 0, 0, 0), -- Bite Rank 9
(31728, 30060, 52473, 0, 0, 0, 0, 1, 52474, 2, 0, 0, 0, 0), -- Bite Rank 10
(31729, 30060, 52474, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Bite Rank 11
(31730, 30060, 50271, 0, 0, 0, 0, 1, 53571, 2, 0, 0, 0, 0), -- Tendon Rip Rank 1
(31731, 30060, 53571, 0, 0, 0, 0, 1, 53572, 2, 0, 0, 0, 0), -- Tendon Rip Rank 2
(31732, 30060, 53572, 0, 0, 0, 0, 1, 53573, 2, 0, 0, 0, 0), -- Tendon Rip Rank 3
(31733, 30060, 53573, 0, 0, 0, 0, 1, 53574, 2, 0, 0, 0, 0), -- Tendon Rip Rank 4
(31734, 30060, 53574, 0, 0, 0, 0, 1, 53575, 2, 0, 0, 0, 0), -- Tendon Rip Rank 5
(31735, 30060, 53575, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tendon Rip Rank 6
(31736, 30060, 17215, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0), -- Tamed Pet Passive (DND)
(31737, 30060, 61684, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0), -- Dash
(31738, 30060, 61685, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0); -- Charge

-- Fox, Dog and Shale Spider already have overlay rows (Plaguelands creaturefamily backfill).
UPDATE `creaturefamily_dbc` SET `CategoryEnumID` = 10 WHERE `ID` = 50;
UPDATE `creaturefamily_dbc` SET `CategoryEnumID` = 23 WHERE `ID` = 52;
UPDATE `creaturefamily_dbc` SET `CategoryEnumID` = 15 WHERE `ID` = 55;

-- 56-60 had no overlay row, so the server used the DBC placeholder with both skill lines at 0.
DELETE FROM `creaturefamily_dbc` WHERE `ID` BETWEEN 56 AND 60;
INSERT INTO `creaturefamily_dbc` (`ID`, `MinScale`, `MinScaleLevel`, `MaxScale`, `MaxScaleLevel`, `SkillLine_1`, `SkillLine_2`, `PetFoodMask`, `PetTalentType`, `CategoryEnumID`, `Name_Lang_enUS`, `Name_Lang_Mask`, `IconFile`) VALUES
(56, 0.7, 1, 1.1, 60, 30056, 270, 1, 0, 25, 'Direhorn', 0, 'Interface\\Icons\\Ability_Hunter_Pet_Devilsaur'),
(57, 0.7, 1, 1.0, 60, 30057, 270, 1, 0, 4, 'Feathermane', 0, 'Interface\\Icons\\Ability_Hunter_Pet_Vulture'),
(58, 0.7, 1, 1.0, 60, 30058, 270, 1, 0, 19, 'Mechanical', 0, 'Interface\\Icons\\INV_Misc_EngGizmos_27'),
(59, 0.7, 1, 1.0, 60, 30059, 270, 1, 0, 5, 'Quilen', 0, 'Interface\\Icons\\Ability_Hunter_Pet_Dog'),
(60, 0.7, 1, 1.0, 60, 30060, 270, 1, 0, 10, 'Blood Beast', 0, 'Interface\\Icons\\Ability_Hunter_Pet_Ravager');
