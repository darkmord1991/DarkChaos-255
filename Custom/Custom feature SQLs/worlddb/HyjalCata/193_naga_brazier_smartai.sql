-- ---------------------------------------------------------------------------
-- 193  Hyjal round-45 -- wire the Naga Brazier (Muglash escort, Ashenvale)
-- ---------------------------------------------------------------------------
-- FULL C++ SCRIPT AUDIT OF MAP 750, and the result is that almost nothing is
-- missing.  Method: pull every script identifier out of the Cata-era zone
-- sources for our seven zones (Project-Neltharion + CataTC,
-- zone_{ashenvale,azshara,darkshore,felwood,moonglade,winterspring,mount_hyjal}
-- .cpp) -- 190 identifiers, of which 65 already exist in our tree.  Of the 125
-- "missing", 63 are `xAI` struct names rather than ScriptNames, leaving 62 real
-- candidates.
--
-- Then the test that actually matters -- REACHABILITY.  A script only does
-- anything if its creature is SPAWNED here.  Of those 62, exactly ONE creature
-- script and ONE gameobject script attach to something spawned on map 750:
--
--   npc_ruul_snowhoof  -> our 3712818 is ALREADY AIName='SmartAI' with 20
--                         smart_scripts rows.  The C++ version would be
--                         redundant; porting it would fight the SmartAI.
--   go_naga_brazier    -> our 3778247 has AIName='SmartGameObjectAI' and ZERO
--                         script rows.  This is the one genuine gap, and it is
--                         what this file fixes.
--
-- The other 60 attach to creatures with no spawn on this map (Bilgewater
-- goblin-questline vehicles, Azshara rocketway props, trial controllers).
-- Porting them would compile dead code.  This mirrors the earlier finding and
-- the 279-tile expansion did not change it.
--
-- WHY SMARTAI AND NOT THE C++ PORT: the Cata `go_naga_brazier` casts the nearby
-- creature's AI to `npc_muglash::npc_muglashAI` and pokes a member directly.
-- OUR npc_muglash is better factored -- it exposes
--     DoAction(ACTION_EXTINGUISH_BLAZIER)   // = 0
-- which does exactly what the Cata script did (Talk(SAY_MUG_BRAZIER_WAIT) and
-- set the brazier flag).  SmartAI can call that hook directly via
-- SMART_ACTION_DO_ACTION, so the behaviour is reachable with no C++ at all --
-- and CLAUDE.md says to prefer SmartAI unless its vocabulary falls short.  Here
-- it does not.
--
-- Constants verified against this core, not assumed:
--   SMART_EVENT_GOSSIP_HELLO      = 64   (valid for GAMEOBJECT scripts)
--   SMART_ACTION_DO_ACTION        = 223  (param1 = ActionId)
--   SMART_TARGET_CLOSEST_CREATURE = 19   (entry, maxDist, dead?)
--   ACTION_EXTINGUISH_BLAZIER     = 0    (zone_ashenvale.cpp)
--   Muglash on map 750            = 3712717, ScriptName npc_muglash, 1 spawn
-- Range 10 yards matches the Cata script's INTERACTION_DISTANCE * 2.
--
-- event_param1 = 1 restricts this to a real GossipHello (i.e. a player using
-- the brazier) so a reportUse does not fire it.
-- ---------------------------------------------------------------------------

DELETE FROM `smart_scripts` WHERE `entryorguid` = 3778247 AND `source_type` = 1;
INSERT INTO `smart_scripts`
  (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
   `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`,
   `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`,
   `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`,
   `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
  (3778247, 1, 0, 0, 64, 0, 100, 0, 1, 0, 0, 0,
   223, 0, 0, 0, 0, 0, 0, 19, 3712717, 10, 0, 0, 0, 0, 0,
   'Naga Brazier - On Gossip Hello - Tell Muglash the brazier is extinguished');

-- Verify -- the brazier should stop reporting a dead SmartGameObjectAI:
--   SELECT COUNT(*) FROM `gameobject` g JOIN `gameobject_template` t ON t.entry = g.id
--    WHERE g.map = 750 AND t.AIName = 'SmartGameObjectAI'
--      AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
--                      WHERE s.entryorguid = t.entry AND s.source_type = 1);
