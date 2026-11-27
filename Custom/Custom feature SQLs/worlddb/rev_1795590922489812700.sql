-- DarkChaos: texts for the Giant Isles world bosses Oondasta (400100) and Thok the Bloodthirsty (400101).
-- boss_oondasta.cpp and boss_thok.cpp Talk() groups 0-6 but creature_text had no rows for either, so every call
-- logged "Could not find Text for Creature" (Nalak 400102 had the same gap, fixed earlier). Both are beasts, so the
-- lines are emotes: 16 = monster emote for flavour, 41 = raid boss emote for the mechanics players must react to.
-- %s is the speaker's name (no target is passed to Talk, so no $n tokens). ASCII only.
DELETE FROM `creature_text` WHERE `CreatureID` IN (400100, 400101);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
    `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(400100, 0, 0, '%s lets out a thunderous roar!', 16, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Aggro'),
(400100, 0, 1, '%s stomps the ground, and the whole isle shakes!', 16, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Aggro'),
(400100, 1, 0, '%s lowers his head and charges!', 41, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Charge'),
(400100, 2, 0, '%s bellows, calling his young to his side!', 41, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Summon Young'),
(400100, 3, 0, '%s flares his frill!', 41, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Frill Blast'),
(400100, 4, 0, '%s flies into a blind rage!', 41, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Berserk'),
(400100, 5, 0, '%s lets out a last rattling roar and crashes to the ground.', 16, 0, 100, 0, 0, 0, 0, 0,
    'Oondasta - Death'),
(400100, 6, 0, '%s tramples his prey.', 16, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Kill'),
(400100, 6, 1, '%s roars over the fallen.', 16, 0, 100, 0, 0, 0, 0, 0, 'Oondasta - Kill'),
(400101, 0, 0, '%s catches the scent of blood!', 16, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Aggro'),
(400101, 0, 1, '%s shrieks and lunges at the intruders!', 16, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Aggro'),
(400101, 1, 0, '%s lets out a deafening screech!', 41, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Screech'),
(400101, 2, 0, '%s fixates on a new victim!', 41, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Fixate'),
(400101, 3, 0, '%s smells blood and calls his pack!', 41, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Frenzy'),
(400101, 3, 1, '%s goes into a blood frenzy!', 41, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Frenzy'),
(400101, 4, 0, 'The bloodlust consumes %s!', 41, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Berserk'),
(400101, 5, 0, '%s collapses, his hunger finally spent.', 16, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Death'),
(400101, 6, 0, '%s tears into his fallen prey.', 16, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Kill'),
(400101, 6, 1, '%s howls over the kill.', 16, 0, 100, 0, 0, 0, 0, 0, 'Thok the Bloodthirsty - Kill');
