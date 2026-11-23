-- Map 751: undo the entry-wide emote / pose copy from 107_addon_animation_layer_751.sql
--
-- Report: the Hammerfall guards all play the hammer / woodwork animation.
--
-- Cause: 107_ filled creature_addon for the +4,100,000 band with ONE value per entry, "the most
-- common NON-ZERO value across that entry's nelt spawns". When only one source spawn has a value,
-- every spawn gets it. In nelt_world only 1 of 20 Hammerfall Guardians (2621) has emote 173
-- EMOTE_STATE_WORK, the guard working at (-975.5, -3561.2), and stock WotLK agrees. 107_ gave the
-- emote to all 21 guards on 751. bytes1 got the same rule, so whole camps of crowd NPCs sit, sleep,
-- kneel or lie dead where their own source spawn stands.
--
-- Fix: each spawn gets the value of ITS OWN source spawn, matched by position within 1.5 yd:
--   1. nelt_world spawn (creature_addon, else creature_template_addon, else 0);
--   2. else cata_world spawn with a creature_addon row (bytes1 re-packed as
--      StandState | VisFlags << 16 | AnimTier << 24);
--   3. else the source entry's majority value COUNTING zero (what 107_ should have used).
-- Scope: only entries with 3 or more spawns on 751 (single named NPCs are left alone), and only
-- rows that still hold the value 107_ wrote. Each UPDATE checks the old value, so the file is
-- re-runnable and does not touch a row someone changed by hand since. path_id, auras, bytes2 and
-- mount are not touched (auras differ from nelt only where 107_ stripped hidden or missing spells).
--
-- Kept on purpose: guid 16714346, the one Hammerfall Guardian that works in the source; 57
-- Forsaken Vanguards that are corpses in the source; Stormpike Soldier 16717051, which chops wood
-- in the source.
--
-- Takes effect on respawn or worldserver restart (creature_addon is read at load).

-- ---------------------------------------------------------------------------
-- 1. emote
-- ---------------------------------------------------------------------------
-- Scarlet Warrior 4101535: 2 spawns, 69 STATE_USE_STANDING -> 0 none (own cata_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16718931,16718933);
-- Scarlet Warrior 4101535: 21 spawns, 69 STATE_USE_STANDING -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16718831,16718834,16718837,16718929,16718934,16718935,16718936,16718940,16718941,16718953,
  16718956,16718957,16718958,16718959,16718960,16718961,16718962,16719075,16719076,16719168,
  16719190);
-- Scarlet Warrior 4101535: 8 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16718836,16718930,16718932,16718937,16718938,16718939,16718948,16719077);
-- Syndicate Conjuror 4102590: 6 spawns, 69 STATE_USE_STANDING -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16713744,16713747,16713763,16713775,16713778,16713780);
-- Syndicate Conjuror 4102590: 3 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16713757,16713772,16713820);
-- Hammerfall Guardian 4102621: 4 spawns, 173 STATE_WORK -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 173 AND `guid` IN (
  16714323,16714335,16714336,16714345);
-- Hammerfall Guardian 4102621: 16 spawns, 173 STATE_WORK -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 173 AND `guid` IN (
  16714304,16714305,16714308,16714309,16714315,16714317,16714320,16714321,16714325,16714326,
  16714329,16714337,16714338,16714339,16714340,16714341);
-- Wildhammer Warrior 4142518: 1 spawns, 375 STATE_READY2H -> 0 none (own cata_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 375 AND `guid` IN (
  16712618);
-- Apothecary Initiate 4144786: 15 spawns, 69 STATE_USE_STANDING -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16720109,16720110,16720128,16720129,16720130,16720131,16720139,16720140,16720141,16720142,
  16720475,16720476,16720477,16720478,16720480);
-- Worgen Renegade 4144793: 28 spawns, 333 STATE_READY1H -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 333 AND `guid` IN (
  16715683,16715685,16715761,16715762,16715767,16715769,16715839,16715840,16715842,16715846,
  16715849,16715894,16715897,16715899,16715903,16715909,16715911,16715913,16715915,16715923,
  16715924,16715925,16715926,16715927,16715929,16715934,16715935,16715936);
-- Worgen Renegade 4144793: 2 spawns, 333 STATE_READY1H -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 333 AND `guid` IN (
  16715682,16715684);
-- Inconspicuous Bear 4145750: 28 spawns, 69 STATE_USE_STANDING -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16714539,16714540,16714541,16714542,16714544,16714546,16714548,16714549,16714633,16714635,
  16714637,16714638,16714639,16714640,16714641,16714643,16714644,16714645,16714646,16714649,
  16714650,16714652,16714653,16714654,16714672,16714674,16714677,16714716);
-- Inconspicuous Bear 4145750: 1 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16714651);
-- Forsaken Trooper 4146053: 8 spawns, 376 STATE_READY_BOW -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 376 AND `guid` IN (
  16714683,16714684,16714685,16714686,16714687,16714757,16714758,16714759);
-- Forsaken Apothecary 4146483: 8 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16715856,16715873,16715877,16715884,16715886,16716002,16716006,16716007);
-- Sludge Guard 4147786: 9 spawns, 385 STATE_HOLD_RIFLE -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 385 AND `guid` IN (
  16717889,16717914,16717916,16717921,16717925,16717935,16717936,16717937,16718065);
-- SI:7 Operative 4148741: 7 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16716817,16716818,16716819,16716822,16716823,16716905,16716918);
-- Stormpike Soldier 4148878: 3 spawns, 69 STATE_USE_STANDING -> 0 none (no own source spawn, entry majority)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16717045,16717049,16717088);
-- Stormpike Soldier 4148878: 16 spawns, 69 STATE_USE_STANDING -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 69 AND `guid` IN (
  16717047,16717048,16717050,16717052,16717053,16717054,16717058,16717059,16717060,16717062,
  16717066,16717245,16717246,16717247,16717248,16717249);
-- Stormpike Soldier 4148878: 1 spawns, 69 STATE_USE_STANDING -> 234 STATE_WORK_CHOPWOOD (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 234 WHERE `emote` = 69 AND `guid` IN (
  16717051);
-- Stormpike Trainee 4148912: 24 spawns, 375 STATE_READY2H -> 0 none (own nelt_world spawn)
UPDATE `creature_addon` SET `emote` = 0 WHERE `emote` = 375 AND `guid` IN (
  16717284,16717285,16717289,16717290,16717291,16717293,16717294,16717295,16717296,16717297,
  16717298,16717299,16717301,16717302,16717303,16717305,16717538,16717542,16717543,16717544,
  16717545,16717546,16717547,16717548);

-- ---------------------------------------------------------------------------
-- 2. bytes1 (stand state)
-- ---------------------------------------------------------------------------
-- Scarlet Warrior 4101535: 2 spawns, 3 sleep -> 0 stand (own cata_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16718954,16718955);
-- Scarlet Warrior 4101535: 21 spawns, 3 sleep -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16718831,16718834,16718837,16718929,16718934,16718935,16718936,16718940,16718941,16718953,
  16718956,16718957,16718958,16718959,16718960,16718961,16718962,16719075,16719076,16719168,
  16719190);
-- Scarlet Warrior 4101535: 6 spawns, 3 sleep -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16718836,16718937,16718938,16718939,16718948,16719077);
-- Syndicate Conjuror 4102590: 6 spawns, 8 kneel -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 8 AND `guid` IN (
  16713744,16713747,16713763,16713775,16713778,16713780);
-- Syndicate Conjuror 4102590: 3 spawns, 8 kneel -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 8 AND `guid` IN (
  16713757,16713772,16713820);
-- Argent Defender 4111194: 1 spawns, 1 sit -> 0 stand (own cata_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16721211);
-- Syndicate Thief 4124477: 11 spawns, 3 sleep -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16713739,16713741,16713751,16713752,16713755,16713758,16713760,16713765,16713770,16713779,
  16713817);
-- Syndicate Thief 4124477: 11 spawns, 3 sleep -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16713750,16713754,16713756,16713762,16713764,16713767,16713769,16713777,16713784,16713816,
  16713819);
-- Forsaken Trooper 4144791: 21 spawns, 1 sit -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16715681,16715760,16715766,16715838,16715841,16715843,16715847,16715854,16715855,16715867,
  16715869,16715885,16715893,16715895,16715907,16715912,16715918,16715921,16715931,16715932,
  16716005);
-- Forsaken Trooper 4144791: 3 spawns, 1 sit -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16715887,16716004,16716009);
-- Worgen Renegade 4144793: 28 spawns, 1 sit -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16715683,16715685,16715761,16715762,16715767,16715769,16715839,16715840,16715842,16715846,
  16715849,16715894,16715897,16715899,16715903,16715909,16715911,16715913,16715915,16715923,
  16715924,16715925,16715926,16715927,16715929,16715934,16715935,16715936);
-- Orc Sea Dog 4144913: 2 spawns, 3 sleep -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16715613,16715654);
-- Orc Sea Dog 4144913: 11 spawns, 3 sleep -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16715605,16715609,16715617,16715655,16715657,16715658,16715660,16715663,16715664,16715672,
  16715673);
-- Orc Sea Dog 4144913: 1 spawns, 3 sleep -> 1 sit (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 1 WHERE `bytes1` = 3 AND `guid` IN (
  16715610);
-- Forsaken Vanguard 4145280: 7 spawns, 7 dead -> 0 stand (own cata_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 7 AND `guid` IN (
  16721452,16721454,16721458,16721462,16721470,16721607,16721625);
-- Forsaken Vanguard 4145280: 38 spawns, 7 dead -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 7 AND `guid` IN (
  16721351,16721357,16721359,16721362,16721364,16721371,16721374,16721381,16721383,16721384,
  16721385,16721389,16721391,16721392,16721393,16721400,16721401,16721403,16721406,16721415,
  16721425,16721430,16721433,16721435,16721441,16721443,16721449,16721453,16721459,16721463,
  16721508,16721509,16721510,16721511,16721530,16721578,16721581,16721644);
-- SI:7 Assassin 4148742: 5 spawns, 8 kneel -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 8 AND `guid` IN (
  16716919,16717069,16717071,16717084,16717254);
-- SI:7 Assassin 4148742: 1 spawns, 8 kneel -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 8 AND `guid` IN (
  16716820);
-- Stormpike Soldier 4148878: 3 spawns, 1 sit -> 0 stand (no own source spawn, entry majority)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16717045,16717049,16717088);
-- Stormpike Soldier 4148878: 16 spawns, 1 sit -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 1 AND `guid` IN (
  16717047,16717048,16717050,16717051,16717052,16717053,16717054,16717057,16717058,16717059,
  16717060,16717061,16717062,16717064,16717065,16717066);
-- Stormpike Trainee 4148912: 27 spawns, 3 sleep -> 0 stand (own nelt_world spawn)
UPDATE `creature_addon` SET `bytes1` = 0 WHERE `bytes1` = 3 AND `guid` IN (
  16717284,16717285,16717287,16717288,16717289,16717290,16717291,16717293,16717294,16717295,
  16717296,16717297,16717298,16717299,16717300,16717301,16717302,16717303,16717304,16717305,
  16717306,16717538,16717539,16717540,16717541,16717542,16717549);

-- Expected on first run: 211 emote rows, 224 bytes1 rows.
