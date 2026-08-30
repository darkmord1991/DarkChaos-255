-- ---------------------------------------------------------------------------
-- 308  Round 47 -- "Twilight Fanatic yells: Masters, I pledge this $r to you!"
-- ---------------------------------------------------------------------------
-- Reported in game: the `$r` token prints raw instead of the player's race.
--
-- WHY THE TOKEN IS RAW. `$r`/`$n`/`$c` are substituted by the CLIENT, not the
-- server, and only from the TARGET carried in the chat packet.
-- `CreatureTextMgr::SendChat` passes its `target` straight into
-- `ChatHandler::BuildChatPacket` (CreatureTextMgr.cpp:40), so no target means
-- no substitution. For SMART_ACTION_TALK that target comes from
-- SmartScript.cpp: with `target_type` 0 or 1 (NONE/SELF) `talkTarget` stays
-- null and falls back to `GetLastInvoker()`.
--
-- 🔴 Twilight Fanatic's whole script never sets an invoker. Its four rows are
-- UPDATE_IC (0), HEALTH_PCT (2), UPDATE_IC (0) and this LINK (61) -- not one of
-- them is an event AC calls `ProcessEvent` with a unit for, so `mLastInvoker`
-- is never assigned and `GetLastInvoker()` returns nothing. The yell is fired
-- by row 2's `link = 3` off the Prismatic Gaze cast, so it always speaks into
-- an empty target.
--
-- MEASURED DB-WIDE, not just on map 750: of 32 SMART_ACTION_TALK rows that
-- combine an invoker-less event (UPDATE_IC/OOC, HEALTH_PCT, WAYPOINT_REACHED,
-- TEXT_OVER, LINK) with target_type 0/1 and a $-token text, exactly **two**
-- belong to a script that can never have an invoker:
--   3732888 Twilight Fanatic  (map 750, 23 spawns)  <- fixed here
--   25144   Shattered Sun Bombardier (map 530, 4 spawns) -- STOCK AzerothCore
--           content, and its line ("Shoot that $c down!") is an out-of-combat
--           ambient call about a dragonhawk, not about a player. Left alone:
--           it is upstream's data and upstream's behaviour.
-- The other 30 are escort/waypoint lines on scripts that DO set an invoker
-- earlier (quest accept, gossip, aggro), so their token resolves. Checked, not
-- guessed -- do not re-audit them.
--
-- THE FIX follows stock AC's own precedent for this exact yell family: stock
-- `smart_scripts` for Twilight Disciple (2338) and Twilight Thug (2339) fire
-- the same broadcast text with **target_type 2 (VICTIM)**. cata_world's row for
-- 32888 uses target_type 1, and that is the outlier we inherited.
--
-- `useTalkTarget` (action_param3) is set to 1 at the same time, and that part
-- is NOT cosmetic: with target_type 2 and useTalkTarget 0, SmartScript's loop
-- takes the `IsCreature(target)` branch and makes THE VICTIM say the line
-- (SmartScript.cpp, SMART_ACTION_TALK) -- so a Fanatic fighting a Sentinel
-- would have the Sentinel pledge herself to the Twilight Hammer. With
-- useTalkTarget 1 the Fanatic always speaks and the victim is only the packet's
-- target, which is exactly what the substitution needs.
--
-- Apply against acore_world, then restart worldserver. SQL only, no rebuild.
-- ---------------------------------------------------------------------------

UPDATE `smart_scripts`
SET `target_type` = 2,
    `action_param3` = 1,
    `comment` = 'Twilight Fanatic - In Combat - Say Line 1 (victim as talk target so $r resolves)'
WHERE `entryorguid` = 3732888
  AND `source_type` = 0
  AND `id` = 3
  AND `action_type` = 1;

-- ---------------------------------------------------------------------------
-- The second half: our stored text says "Pin", not "$r"
-- ---------------------------------------------------------------------------
-- `creature_text` 3732888 group 1 id 1 reads "Masters, I pledge this Pin to
-- you!" -- a corrupt row inherited verbatim from **cata_world** (nelt_world,
-- stock AzerothCore and `broadcast_text` 835 all say `$r`). It is inert today
-- because `CreatureTextMgr::GetLocalizedChatString` (CreatureTextMgr.cpp:498)
-- prefers the BroadcastText whenever the row has one, which is why the player
-- saw "$r" and not "Pin" -- but the moment anyone clears BroadcastTextId, the
-- corruption becomes what the world hears. Corrected to match every other
-- source.
-- ---------------------------------------------------------------------------
UPDATE `creature_text`
SET `Text` = 'Masters, I pledge this $r to you!'
WHERE `CreatureID` = 3732888 AND `GroupID` = 1 AND `ID` = 1
  AND `Text` = 'Masters, I pledge this Pin to you!';

-- ---------------------------------------------------------------------------
-- Verify (expected: target_type 2 / action_param3 1, and no "Pin" left)
-- ---------------------------------------------------------------------------
--   SELECT id, event_type, target_type, action_param1, action_param3, comment
--     FROM smart_scripts WHERE entryorguid = 3732888 AND source_type = 0;
--   SELECT CreatureID, GroupID, ID, Text FROM creature_text WHERE CreatureID = 3732888;
--   -- in game: pull a Twilight Fanatic in Darkshore, wait for Prismatic Gaze
--   --   -> "Masters, I pledge this <your race> to you!"
-- ---------------------------------------------------------------------------
