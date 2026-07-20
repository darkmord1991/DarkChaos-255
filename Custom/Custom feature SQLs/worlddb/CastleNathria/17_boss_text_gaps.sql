-- Castle Nathria (map 2296) -- boss creature_text gap-fill (17).
--
-- Two boss entries have C++ AI Talk() calls but ZERO creature_text rows in any of the 4 source dumps
-- checked during the original transcode (see 09_creature_text.sql's coverage-gap note): Huntsman Altimor
-- (165066) and Sire Denathrius (167406, the raid's final boss). With the AI now ported and live, every
-- Talk() on a missing GroupID is a silent no-op AND logs a CreatureTextMgr error on each fire -- so the
-- bosses are mute and the worldserver log fills with "text group N not found" spam.
--
-- The lines below are DC-AUTHORED, thematically faithful to each encounter (they are NOT verbatim retail
-- sniff rips -- the source data genuinely had none). GroupIDs match the boss AI's SAY_* enum values
-- EXACTLY so each Talk(SAY_x) resolves:
--   Huntsman Altimor  (boss_huntsman_altimor.cpp):  SAY_AGGRO=0, SAY_VICIOUS_LUNGE=2, SAY_MARGORE_DEAD=3, SAY_RIP_SOUL=4
--   Sire Denathrius   (boss_sire_denathrius.cpp):   SAY_AGGRO=0..SAY_DEATH=7 (all 8 consecutive)
-- Replace with exact retail text later if a clean sniff becomes available; the GroupID layout is what
-- matters for the AI wiring and will not change.
--
-- Type 12 = Yell. Apply against acore_world (idempotent: scoped DELETE before INSERT).

-- ---------------------------------------------------------------------------
-- Huntsman Altimor (165066) -- 4 lines (groups 0,2,3,4 -- the AI never calls Talk(1))
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 165066;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (165066, 0, 0, 'You would make fine quarry. Bargast! Margore! Bakar! To the hunt!', 12, 0, 100, 0, 0, 0, 0, 0, 'Huntsman Altimor - Aggro'),
    (165066, 2, 0, 'Run them down!', 12, 0, 100, 0, 0, 0, 0, 0, 'Huntsman Altimor - Vicious Lunge'),
    (165066, 3, 0, 'You will answer for that, mongrels!', 12, 0, 100, 0, 0, 0, 0, 0, 'Huntsman Altimor - Hound slain'),
    (165066, 4, 0, 'Your soul is mine to claim!', 12, 0, 100, 0, 0, 0, 0, 0, 'Huntsman Altimor - Rip Soul');

-- ---------------------------------------------------------------------------
-- Sire Denathrius (167406) -- 8 lines (groups 0-7)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` = 167406;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
    (167406, 0, 0, 'Welcome, guests, to my humble abode. I have prepared a most fitting reception for your kind.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Aggro'),
    (167406, 1, 0, 'Remornia, awaken! Let us remind these vermin what true power looks like.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Intermission'),
    (167406, 2, 0, 'You will not leave this place. None of you.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Phase Two'),
    (167406, 3, 0, 'Enough of this farce. I shall end you myself.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Phase Three'),
    (167406, 4, 0, 'Bleed for me!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Ravage'),
    (167406, 5, 0, 'Drown in your own blood!', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Massacre'),
    (167406, 6, 0, 'A pity. I expected so much more.', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Slay'),
    (167406, 7, 0, 'The Master... will not... be denied...', 12, 0, 100, 0, 0, 0, 0, 0, 'Sire Denathrius - Death');
