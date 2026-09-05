-- Hinterland BG: rescale the battleground NPCs to level-80 norms.
--
-- WHY
-- The guards were far outside any stock reference. Health is
-- creature_classlevelstats.basehp<exp> * HealthModifier, so:
--
--   Revantusk Watcher   exp=1 -> basehp1  9,215 x 60 =   552,900
--   Hinterland A. guard exp=2 -> basehp2 12,600 x 50 =   630,000
--
-- Stock level-80 rank-0 guards for comparison: Frostbrood Sentry 25,200,
-- Argent Champion 50,000, Dalaran Sunreaver Guardian 126,000 (the toughest
-- stock city guard in the game).
--
-- Armor made it far worse. Unit::CalcArmorReducedDamage at level 80 divides by
-- 8.5*174.5+40 = 1523.25 and caps reduction at 75%:
--   ArmorModifier 5 -> armor 48,645 -> 75% (at the cap)
--   ArmorModifier 1 -> armor  9,729 -> 39%
-- so the guards were proportionally tankier than the two raid bosses. Effective
-- physical HP for a basic guard was 630,000 / 0.25 = 2,520,000 - roughly ten
-- minutes of solo damage for the 5 resources that a normal NPC kill drains.
-- NPC attrition was not a viable route to the 450-resource win condition.
--
-- WHAT THIS DOES
--   * exp = 2 everywhere. Only 810001 and the two bosses used the WotLK table;
--     everything else drew from the TBC one, so identical HealthModifier values
--     produced a 37% spread between same-tier units on a level-80 map.
--   * ArmorModifier = 2 everywhere -> ~56% reduction. Off the 75% cap, so armor
--     tuning does something again, and bosses are no longer squishier than the
--     guards they command.
--   * Health and damage by role, identical for both factions. The Alliance line
--     guard sat at DamageModifier 1 while its Horde counterpart sat at 5 - a 4x
--     difference between the two most numerous spawns on the map. Both now use
--     the role value, which is set to preserve the (already play-tested) Horde
--     damage level rather than the weaker Alliance one.
--
-- Resulting health, all from basehp2 = 12,600:
--   boss     x335 = 4,221,000   (~4 min for 10 players at ~4k dps each)
--   elite    x10  =   126,000   (~70s solo)
--   standard x5   =    63,000   (~35s solo)
--   support  x3   =    37,800   (~21s solo)
--
-- Spawn counts are NOT touched here: the Alliance fields 35 guards to the
-- Horde's 19. That is addressed by the Kor'kron additions in the companion
-- file, since it is spawn work rather than a stat change.

-- Shared: expansion table and armor, every battleground NPC.
UPDATE `creature_template` SET `exp` = 2, `ArmorModifier` = 2
WHERE `entry` IN (810000, 810001, 810002, 810003, 810006, 810007, 810008,
                  810009, 810010, 810011, 810012, 810013, 810014, 810015,
                  810016, 810017, 810018, 810019, 810020, 810021, 810022, 810023);

-- Faction bosses.
UPDATE `creature_template` SET `HealthModifier` = 335, `DamageModifier` = 35
WHERE `entry` IN (810002, 810003);

-- Elites / captains.
UPDATE `creature_template` SET `HealthModifier` = 10, `DamageModifier` = 5
WHERE `entry` IN (810006, 810007, 810009, 810017);

-- Standard line guards and ranged.
UPDATE `creature_template` SET `HealthModifier` = 5, `DamageModifier` = 4
WHERE `entry` IN (810000, 810001, 810010, 810011, 810021, 810022);

-- Support, casters and camp attendants.
UPDATE `creature_template` SET `HealthModifier` = 3, `DamageModifier` = 3
WHERE `entry` IN (810008, 810012, 810013, 810014, 810015, 810016, 810018,
                  810019, 810020, 810023);

-- 810001 carried npcflag 1 (gossip) left over from the Stormwind city guard it
-- was cloned from - see its smart_scripts, which are still the city "on emote
-- wave/salute/bow" ambience rows. No other battleground guard offers gossip.
--
-- 810002 (Thrall) is here too: an earlier pending file cleared Varian's stale
-- AIName and added NO_XP to Thrall, and both of those landed, but the npcflag
-- statement in it did not - Thrall still shows a gossip icon on a raid boss.
UPDATE `creature_template` SET `npcflag` = 0 WHERE `entry` IN (810001, 810002);
