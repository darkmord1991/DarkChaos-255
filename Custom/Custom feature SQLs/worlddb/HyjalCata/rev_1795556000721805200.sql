-- DarkChaos: Hyjal Frontier (map 750, zone 4923) - put the Sanctuary invasion back into quest phases.
-- The Cata import flattened every Mount Hyjal phase into phase 1, so 171 hostile level-128 elementals stood in and
-- around the zone's north town (graveyard, flight master, bank, Malfurion) of a 113-130 zone: level-114 players and
-- bots crossing to it were pulled and killed. In Cata (nelt_world phase_definitions + conditions, zone 616) the
-- Raging Invaders were phase 256 (only during The Sanctuary Must Not Fall) and the Charred Flamewakers / Brimstone
-- Destroyers phase 32 (the level-85 Regrowth hub). Here they become what DC's own quests for them need:
--   bit 64  Charred Flamewaker 3652791 (64) and Brimstone Destroyer 3652794 (62)
--           while 751274 Charred and Broken, 751275 Brimstone Tide or 751278 Hold the Regrowth is in the log
--   bit 128 Raging Invader 3652557 (45) while 751277 Rage Unchecked or 751278 Hold the Regrowth is in the log
-- Everyone else stops seeing (and being attacked by) them. Bits 64/128 were unused on map 750 (2-32 are taken).
-- dc_quest_phase is read at startup, so apply this, then restart the worldserver (the exe already has the layer).
-- Status mask 10 = complete or incomplete, i.e. in the quest log.
DELETE FROM `dc_quest_phase` WHERE `map` = 750 AND `phase_mask` IN (64, 128);
INSERT INTO `dc_quest_phase`
    (`map`, `phase_mask`, `quest`, `quest_status_mask`, `quest2`, `quest2_status_mask`, `comment`) VALUES
(750, 64, 751274, 10, 0, 0, 'Hyjal Frontier: Charred Flamewakers and Brimstone Destroyers during Charred and Broken'),
(750, 64, 751275, 10, 0, 0, 'Hyjal Frontier: Charred Flamewakers and Brimstone Destroyers during Brimstone Tide'),
(750, 64, 751278, 10, 0, 0, 'Hyjal Frontier: Charred Flamewakers and Brimstone Destroyers during Hold the Regrowth'),
(750, 128, 751277, 10, 0, 0, 'Hyjal Frontier: Raging Invaders at the Sanctuary during Rage Unchecked'),
(750, 128, 751278, 10, 0, 0, 'Hyjal Frontier: Raging Invaders at the Sanctuary during Hold the Regrowth');

UPDATE `creature` SET `phaseMask` = 64
    WHERE `map` = 750 AND `id` IN (3652791, 3652794) AND `phaseMask` = 1 AND `guid` IN (
    9843663, 9843667, 9843670, 9843680, 9843689, 9843691, 9843692, 9843693, 9843694, 9843695, 9843696, 9843697,
    9843698, 9843699, 9843700, 9843701, 9843702, 9843704, 9843705, 9843706, 9843708, 9843709, 9843711, 9843712,
    9843713, 9843714, 9843715, 9843716, 9843717, 9843719, 9843720, 9843721, 9843722, 9843723, 9843839, 9843841,
    9843843, 9843844, 9843846, 9843847, 9843848, 9843849, 9843850, 9843851, 9843852, 9843853, 9843854, 9843856,
    9843858, 9843859, 9843860, 9843862, 9843865, 9843866, 9843867, 9843868, 9843869, 9843871, 9843872, 9843873,
    9843874, 9843875, 9843878, 9843880, 9843882, 9843883, 9843884, 9843886, 9843887, 9843888, 9843889, 9843890,
    9843891, 9843892, 9843893, 9843894, 9843895, 9843896, 9843897, 9843900, 9843901, 9843903, 9843904, 9843905,
    9843906, 9843908, 9843909, 9843910, 9843914, 9843915, 9843916, 9843917, 9843919, 9843921, 9843924, 9843925,
    9843927, 9843930, 9843932, 9843933, 9843934, 9843937, 9843938, 9843939, 9843940, 9843941, 9843944, 9843945,
    9843946, 9843948, 9843949, 9843950, 9843953, 9843954, 9843955, 9843956, 9843959, 9843960, 9843962, 9843964,
    9843969, 9843973, 9843974, 9843978, 9843983, 9844163);

UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 750 AND `id` IN (3652557) AND `phaseMask` = 1 AND `guid` IN (
    9843724, 9843725, 9843733, 9843734, 9843735, 9843736, 9843737, 9843738, 9843739, 9843740, 9843742, 9843744,
    9843745, 9843746, 9843747, 9843748, 9843749, 9843750, 9843751, 9843769, 9843770, 9843772, 9843780, 9843781,
    9843782, 9843783, 9843784, 9843785, 9843786, 9843787, 9843788, 9843789, 9843790, 9843791, 9843792, 9843793,
    9843794, 9843795, 9843796, 9843797, 9843798, 9843799, 9843800, 9843801, 9843802);
