-- ---------------------------------------------------------------------------
-- 153  Hyjal round-24 -- resolve the AIName / ScriptName double-ownership
-- ---------------------------------------------------------------------------
-- 19 templates carry BOTH `AIName` = 'SmartAI' and a DC `ScriptName`.
-- `FactorySelector::SelectAI` resolves ScriptName FIRST, so on every one of them
-- the SmartAI never runs: 112 `smart_scripts` rows plus the 110 rows in the 24
-- timed action lists they call = **222 dead rows**.
--
-- This is not leftover source noise.  Checked against `nelt_world`: all 19 have
-- `AIName` = 'SmartAI' and an EMPTY ScriptName there, with identical row counts.
-- They ran as SmartAI upstream; DC's C++ are re-implementations layered on top.
--
-- Each of the 19 was diffed against its C++ before this file was written.  The
-- verdict was the same every time: **the C++ is the fuller implementation**, so
-- it keeps ownership and the misleading `AIName` is cleared.  Examples of the
-- C++ doing strictly more than the data it replaced:
--
--   npc_the_forlorn_spire_controller  SmartAI summoned Taldros+Sira unconditionally;
--                                     the C++ quest-gates, randomises one of three
--                                     druids, sets the phase and can be reset.
--   npc_the_forlorn_spire_anydruid    236 lines of escort: Igniter/Sentinel/Pyrelord
--                                     waves, kill counting, talk lines, camera
--                                     handoff, far-abandon cleanup.  The SmartAI
--                                     was 8 rows + 37 action-list rows of walking.
--   npc_into_the_fire_controller      adds quest gating + a second windcaller the
--                                     SmartAI never summoned.
--
-- Clearing `AIName` changes NOTHING at runtime -- ScriptName already won -- and
-- it adds no boot noise: `SmartAIMgr::CheckIfSmartAIInDatabaseExists`
-- (SmartScriptMgr.cpp:326) only warns in the other direction, for AIName =
-- 'SmartAI' with no rows.  What it buys is an honest DB: nobody later "fixes"
-- rows that cannot execute, and the owner of each NPC's behaviour is unambiguous.
--
-- The rows themselves are deliberately KEPT, not deleted -- they are the only
-- surviving record of the upstream behaviour and are what any future port back
-- to SmartAI would start from.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` SET `AIName` = ''
WHERE `AIName` = 'SmartAI'
  AND `ScriptName` IN (
    'npc_trained_fire_hawk_vehicle',           -- 3653300
    'npc_into_the_fire_windcaller_nordrala',   -- 3653355
    'npc_turtle_punter',                       -- 3652988
    'npc_hyjal_wisp_away',                     -- 3653083
    'npc_spirit_of_logosh_goldrinn_vehicle',   -- 3639622, 3639627
    'npc_blazing_trainer_agility_training',    -- 3640434
    'npc_the_forlorn_spire_anydruid',          -- 3652965
    'npc_the_forlorn_spire_warden',            -- 3652955
    'npc_the_forlorn_spire_camera',            -- 3653017
    'npc_the_forlorn_spire_controller',        -- 3675186
    'npc_twilight_proveditor',                 -- 3639436
    'npc_twilight_slave',                      -- 3639431
    'npc_emerald_flameweaver_infiltrators',    -- 3640856
    'npc_molten_front_behemoth',               -- 3652552
    'npc_spawn_of_smolderos_grudge_match',     -- 3640427
    'npc_punt_child_of_tortolla',              -- 3652177
    'npc_into_the_fire_controller',            -- 3675181
    'npc_into_the_fire_end_controller'         -- 3675182
  );

-- ---------------------------------------------------------------------------
-- What the C++ genuinely did NOT carry over
-- ---------------------------------------------------------------------------
-- Four of the suppressed branches cast spells that **do not exist in 3.3.5 at
-- all** -- checked against the built Custom/DBCs/Spell.dbc, not `spell_dbc`:
--
--     87853   Trained Fire Hawk, cast after waypoint 7
--     93488   Spirit of Lo'Gosh / Goldrinn, SELF_CAST
--    151268   Forlorn Spire Camera, CROSS_CAST
--    151278   Blazing Trainer, the SPELLHIT that triggered its FAIL_QUEST
--
-- Those branches were inert even under SmartAI, so nothing was lost with them.
-- The Blazing Trainer's quest failure is reached another way in C++ anyway
-- (`player->FailQuest(QUEST_AGILITY_TRAINING)`, zone_mount_hyjal.cpp:1677/1690).
--
-- Everything else audited as covered:
--   * Turtle Punter's kill credit (SmartAI CALL_KILLEDMONSTER 52177) is granted
--     by `npc_punt_child_of_tortolla` instead -- KilledMonsterCredit(
--     NPC_PUTING_SEASON_CREDIT = 3652177), zone_mount_hyjal.cpp:3309.  Its
--     PASSENGER_REMOVED aura strip is likewise covered
--     (SPELL_VISUAL_HOLD_CHILD = 96303).  An earlier note in this README called
--     the Punter a confirmed hole; that was wrong and is corrected here.
--   * Hyjal Wisp's CALL_KILLEDMONSTER 3652531 -> KilledMonsterCredit(
--     NPC_FIRE_ATTACKER_PORTAL), zone_molten_front.cpp:235.
--   * every plain combat cast (74143, 97247, 97243, 80182, 73918, 96427) is
--     genuinely cast by its script, not merely declared as an enum constant --
--     which is the trap that made the Punter look broken.
--
-- TWO real gaps remained; one is now fixed:
--
--   FIXED (needs a worldserver rebuild): Hyjal Wisp's DEATH -> FAIL_QUEST 29143.
--     The wisp IS the escort objective, so losing it left "Wisp Away" stuck
--     in-progress forever.  Added to `npc_hyjal_wisp_awayAI::JustDied` in
--     zone_molten_front.cpp.
--
--   OPEN (cosmetic, not scheduled): Windcaller Nordrala no longer casts Faerie
--     Fire (6950) in combat.  The spell exists; it is a minor debuff on an
--     escort mob and is left as a C++ TODO rather than reinstated blindly.
-- ---------------------------------------------------------------------------
