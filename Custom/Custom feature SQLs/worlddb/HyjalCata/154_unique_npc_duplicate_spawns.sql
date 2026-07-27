-- ---------------------------------------------------------------------------
-- 154  Hyjal round-25 -- stacked duplicates of unique quest NPCs
-- ---------------------------------------------------------------------------
-- Visible at Nordrassil and the Sanctuary of Malorne: three Arch Druid Hamuul
-- Runetotems on top of each other, two Malfurions, two Mataclaws, and so on.
--
-- CAUSE
--   In Cata these NPCs follow the Hyjal chain from camp to camp, and each
--   occurrence lives in its own PHASE.  The downport flattened every occurrence
--   into phaseMask 1 (the same root cause as round 21's base-phase finding), so
--   all of them exist simultaneously and pile up.  Nothing logs this -- it is
--   only visible in-game, and it only became visible at all once 150_ handed
--   players the quest-invisibility detection that had been hiding most of them.
--
-- METHOD
--   Single-linkage clustering per NPC NAME at a 40-yard radius, per map,
--   keeping the lowest guid in each cluster.  40 yards is safe here because the
--   camps are far apart -- the Sanctuary group sits at x 4620-4655 and the
--   Nordrassil group at x 4394-4482, a 138-yard gap -- so clustering merges
--   stacks without ever merging two genuine camps.  The result is exactly one
--   of each NPC per camp, which is what the zone should look like.
--
-- SAFETY
--   * Clustering is by NAME, not entry, because the pile-ups are mostly
--     CROSS-entry (e.g. Hamuul 3639858 and 3652838 standing 2.8 yards apart).
--     A same-entry sweep alone finds only 8 of these.
--   * Every entry that starts or ends a quest keeps at least one spawn --
--     verified per entry before writing this file.  Hamuul 3652838 goes 6 -> 2
--     spawns, Malfurion 3652845 5 -> 3, Saynna 3652844 5 -> 4, and so on; both
--     Hamuul entries survive, so both his quest sets stay reachable.
--   * The one entry left with no spawn is 3654393 "Ranela Featherglen", and
--     that is correct: 3654392 and 3654393 are BYTE-IDENTICAL flight masters
--     (npcflag 8193, same subname, same taxi position) standing 0.2 yards
--     apart.  Neither starts nor ends a quest and 3654392 remains, so the flight
--     point is untouched.
--   * Checked before deleting: these 19 guids have ZERO rows in
--     `creature_addon`, `pool_creature`, `game_event_creature`,
--     `creature_formations` (leader or member) and guid-keyed `smart_scripts`.
--     Nothing dangles.
--
-- Deleting the spawn row is the right fix rather than re-phasing, because DC
-- deliberately built this zone unphased; re-introducing Cata's phase set would
-- be a zone-wide redesign, not a duplicate cleanup.
--
-- Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `creature` WHERE `guid` IN (
    9843536,   -- Hamuul 3652838, 0.1y from Hamuul 3639858 guid 9843535
    9843636,   -- Hamuul 3652838, Sanctuary stack
    9843669,   -- Hamuul 3652838, Sanctuary stack
    9843766,   -- Hamuul 3652838, 2.8y from Hamuul 3639858 guid 9842752 (Nordrassil)
    9843809,   -- Hamuul 3652838, 5.2y from the same
    9843640,   -- Malfurion 3652845, Sanctuary stack
    9843665,   -- Malfurion 3652845, Sanctuary stack
    9843816,   -- Malfurion 3652845, 6.3y from guid 9843764 (Nordrassil)
    9843638,   -- Saynna 3652844, Sanctuary stack
    9843664,   -- Saynna 3652844, Sanctuary stack
    9843683,   -- Avrilla 3652898, 3.2y from guid 9843569
    9843819,   -- Avrilla 3652898, 3.8y from guid 9843569
    9843684,   -- Keeper Taldros 3652900, 15.6y from guid 9843562
    9843821,   -- Keeper Taldros 3652900, 4.8y from guid 9843562
    9843677,   -- Mylune 3652671, 0.4y from guid 9843567
    9843768,   -- Matoclaw 3652669, 14.5y from guid 9843566
    9843817,   -- Elderlimb 3652906, 8.0y from guid 9843776
    9843568,   -- Ranela Featherglen 3654393, 0.2y from identical 3654392 guid 9842750
    9844990    -- Jarod Shadowsong 3640772, 20.1y from guid 9844834
);

-- Defensive: drop any addon rows that might be attached to those spawns by a
-- later import (there are none today, but a re-run after new content should not
-- leave orphans behind).
DELETE FROM `creature_addon` WHERE `guid` IN (
    9843536,9843636,9843669,9843766,9843809,9843640,9843665,9843816,9843638,9843664,
    9843683,9843819,9843684,9843821,9843677,9843768,9843817,9843568,9844990
);

-- ---------------------------------------------------------------------------
-- NOT touched, and why
-- ---------------------------------------------------------------------------
--   Lost Warden (3641499, 29 spawns), Twilight Servitor (3639644, 24),
--   Twilight Overseer (3640123, 5), Fire Attacker Portal (3652531, 10) -- these
--   are generic ambient/objective mobs.  Multiple spawns are correct.
--
--   Anren Shadowseeker and Tholo Whitehoof each keep two spawns on map 861 --
--   they are ~215 yards apart (the Forlorn Spire camp and the Shrine), so they
--   are two different camps, not a stack.
--
--   Kalecgos 3652995 (starts a quest) and 3653009 (ends one) stand 3.8 yards
--   apart.  They are NOT merged: they are different entries carrying different
--   halves of the same hand-in, and deleting either breaks that quest.  Fixing
--   the visual would mean merging the quest links onto one entry, which is a
--   content edit rather than a duplicate cleanup.
-- ---------------------------------------------------------------------------
