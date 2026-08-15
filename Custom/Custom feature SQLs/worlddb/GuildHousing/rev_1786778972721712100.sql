--
-- Legion Dalaran (map 1413): port the missing creature_addon pose layer.
--
-- The 2026-06-27 import wrote only 56 creature_addon rows for 1,206 spawns, so most
-- NPCs that should sit, sleep, kneel or lie wounded stand bolt upright instead --
-- visibly, on top of chairs, benches and beds.
--
-- Sitting is NOT an emote. It is creature_addon.bytes1, whose low byte is the
-- UnitStandStateType (1=SIT, 3=SLEEP, 5=SIT_MEDIUM_CHAIR, 7=DEAD, 8=KNEEL).
-- creature_addon.emote is a separate, looping EMOTE_* state.
--
-- Values come from the retail dumps, not from guesswork. Each of our spawns was
-- matched to its source spawn by pushing the source position through the documented
-- map 1220 -> 1413 transform; every row below matched within 1.5 yd and all but
-- three within 0.1 yd. Sources: BFA-HavenCore bfa_world.sql (per-guid
-- creature_addon) and LegionCore_world_2020_04_25.sql (per-entry
-- creature_template_addon).
--
-- Safety checks performed:
--   * All 46 target spawns are MovementType 0, wander_distance 0, path_id 0, so no
--     waypoint or random movement will fight the pose.
--   * Every emote id in the source set (10/38/378/426/428/432/461/469) was checked to
--     resolve to the SAME EMOTE_* constant in the BfA core as in ours, and to exist in
--     our live Emotes.dbc (175 records). Ids above ~470 exist only in the modern cores
--     and were skipped. Only 38/378/428/432/461 survive the filters below and are
--     actually written here.
--   * 11 source rows were dropped: 4 where the source NPC name disagreed with ours,
--     5 with no spawn of ours within 4 yd, 2 whose nearest match was beyond 1.5 yd.
--   * auras and mount were deliberately NOT ported -- importing auras blind can
--     apply invisibility or phase auras and hide the NPC outright.
--   * No cache_id bump: bytes1 and emote reach the client through the unit update
--     block, not through a cached *_QUERY_RESPONSE.
--

-- ---------------------------------------------------------------------------
-- Existing rows -- update the two pose columns only, so path_id/auras survive.
-- Salome and Punchy Lou carried the import's blanket bytes1=5 guess; the source
-- says SLEEP and SIT respectively.
-- ---------------------------------------------------------------------------
-- guid 9500776  Lyndras (entry 3500086): STAND -> KNEEL
-- guid 9500616  Salome (entry 3500375): SIT_MEDIUM_CHAIR -> SLEEP
-- guid 9500283  Punchy Lou (entry 3500504): SIT_MEDIUM_CHAIR -> SIT
UPDATE `creature_addon` SET `bytes1`=8, `emote`=0 WHERE `guid`=9500776;
UPDATE `creature_addon` SET `bytes1`=3, `emote`=0 WHERE `guid`=9500616;
UPDATE `creature_addon` SET `bytes1`=1, `emote`=0 WHERE `guid`=9500283;

-- ---------------------------------------------------------------------------
-- New rows. Per-spawn notes are listed here rather than inline, because a
-- trailing -- comment on the last VALUES tuple swallows the statement
-- terminator (see sql-generator comment traps).
--
--   guid 9500254   entry 28705    Katherine Lee                emote ONESHOT_USE_STANDING
--   guid 9500023   entry 3500009  Fuzz                         SLEEP
--   guid 9500252   entry 3500081  Bradford Duncan              emote ONESHOT_USE_STANDING
--   guid 9500775   entry 3500086  Lyndras                      KNEEL
--   guid 16710108  entry 3500086  Lyndras                      KNEEL
--   guid 9500138   entry 3500136  Nargut                       SLEEP
--   guid 9500130   entry 3500137  Rhukah                       SLEEP
--   guid 9500524   entry 3500143  Mato                         KNEEL
--   guid 9500489   entry 3500155  Paymaster Alstein            KNEEL
--   guid 9500300   entry 3500159  Paymaster Chang              KNEEL
--   guid 9500985   entry 3500244  Marshmallow                  SLEEP
--   guid 9500782   entry 3500304  Vanessa VanCleef             KNEEL
--   guid 9500787   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500788   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500789   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500790   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500791   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500792   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500793   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500794   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500795   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500796   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500797   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500798   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500799   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500800   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500801   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500802   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500803   entry 3500307  Wounded Kirin Tor Guardian   emote STATE_LOOT
--   guid 9500805   entry 3500309  Smacky                       emote STATE_TALK
--   guid 9500806   entry 3500314  Valmir                       emote STATE_TALK
--   guid 9500807   entry 3500315  Phraid                       emote STATE_TALK
--   guid 9500644   entry 3500378  Dirk Thunderwood             KNEEL
--   guid 9500615   entry 3500386  Zelanis                      emote STATE_SIT_CHAIR_LOW
--   guid 9500585   entry 3500387  Gregory Charles              emote ONESHOT_ATTACK2H_LOOSE
--   guid 9500619   entry 3500397  Renzik "The Shiv"            SIT
--   guid 9500993   entry 3500429  Eldragosa                    SLEEP
--   guid 9500350   entry 3500510  Classic Larry                SIT
--   guid 9500998   entry 3500587  Raven Vasya                  SIT
--   guid 16710035  entry 3501019  Roaster Rat                  DEAD
--   guid 16710047  entry 3501019  Roaster Rat                  DEAD
--   guid 16710050  entry 3501019  Roaster Rat                  DEAD
--   guid 16710062  entry 3501023  Bastard                      DEAD
-- ---------------------------------------------------------------------------
DELETE FROM `creature_addon` WHERE `guid` IN (9500254,9500023,9500252,9500775,16710108,9500138,9500130,9500524,9500489,9500300,9500985,9500782,9500787,9500788,9500789,9500790,9500791,9500792,9500793,9500794,9500795,9500796,9500797,9500798,9500799,9500800,9500801,9500802,9500803,9500805,9500806,9500807,9500644,9500615,9500585,9500619,9500993,9500350,9500998,16710035,16710047,16710050,16710062);
INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(9500254, 0, 0, 0, 0, 432, 0, NULL),
(9500023, 0, 0, 3, 0, 0, 0, NULL),
(9500252, 0, 0, 0, 0, 432, 0, NULL),
(9500775, 0, 0, 8, 0, 0, 0, NULL),
(16710108, 0, 0, 8, 0, 0, 0, NULL),
(9500138, 0, 0, 3, 0, 0, 0, NULL),
(9500130, 0, 0, 3, 0, 0, 0, NULL),
(9500524, 0, 0, 8, 0, 0, 0, NULL),
(9500489, 0, 0, 8, 0, 0, 0, NULL),
(9500300, 0, 0, 8, 0, 0, 0, NULL),
(9500985, 0, 0, 3, 0, 0, 0, NULL),
(9500782, 0, 0, 8, 0, 0, 0, NULL),
(9500787, 0, 0, 0, 0, 428, 0, NULL),
(9500788, 0, 0, 0, 0, 428, 0, NULL),
(9500789, 0, 0, 0, 0, 428, 0, NULL),
(9500790, 0, 0, 0, 0, 428, 0, NULL),
(9500791, 0, 0, 0, 0, 428, 0, NULL),
(9500792, 0, 0, 0, 0, 428, 0, NULL),
(9500793, 0, 0, 0, 0, 428, 0, NULL),
(9500794, 0, 0, 0, 0, 428, 0, NULL),
(9500795, 0, 0, 0, 0, 428, 0, NULL),
(9500796, 0, 0, 0, 0, 428, 0, NULL),
(9500797, 0, 0, 0, 0, 428, 0, NULL),
(9500798, 0, 0, 0, 0, 428, 0, NULL),
(9500799, 0, 0, 0, 0, 428, 0, NULL),
(9500800, 0, 0, 0, 0, 428, 0, NULL),
(9500801, 0, 0, 0, 0, 428, 0, NULL),
(9500802, 0, 0, 0, 0, 428, 0, NULL),
(9500803, 0, 0, 0, 0, 428, 0, NULL),
(9500805, 0, 0, 0, 0, 378, 0, NULL),
(9500806, 0, 0, 0, 0, 378, 0, NULL),
(9500807, 0, 0, 0, 0, 378, 0, NULL),
(9500644, 0, 0, 8, 0, 0, 0, NULL),
(9500615, 0, 0, 0, 0, 461, 0, NULL),
(9500585, 0, 0, 0, 0, 38, 0, NULL),
(9500619, 0, 0, 1, 0, 0, 0, NULL),
(9500993, 0, 0, 3, 0, 0, 0, NULL),
(9500350, 0, 0, 1, 0, 0, 0, NULL),
(9500998, 0, 0, 1, 0, 0, 0, NULL),
(16710035, 0, 0, 7, 0, 0, 0, NULL),
(16710047, 0, 0, 7, 0, 0, 0, NULL),
(16710050, 0, 0, 7, 0, 0, 0, NULL),
(16710062, 0, 0, 7, 0, 0, 0, NULL);
