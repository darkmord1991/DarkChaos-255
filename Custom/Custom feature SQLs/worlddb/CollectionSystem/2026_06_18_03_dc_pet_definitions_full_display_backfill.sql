-- ============================================================================
-- DC-Collection: pet preview full display-id + summon-spell backfill (160)
-- ============================================================================
-- Belt-and-suspenders companion to the IsCompanionSpell MINIPET-gate fix in
-- src/server/scripts/DC/AddonExtension/dc_addon_collection.cpp. The runtime
-- startup backfill (DCCollection.Pets.BackfillDisplayIdsOnStartup) now resolves
-- these automatically, but persisting the deterministically-resolved
-- CreatureDisplayInfo display id AND companion summon spell keeps the not-owned
-- pet 3D preview working even if the SummonProperties/Spell DBCs are rebuilt.
-- (Original defect: on the level-255 DBC build LookupEntry on the summon effect
-- MiscValueB returned NULL, so the strict "SummonProperties Type == MINIPET"
-- gate rejected every companion -> 0/185 resolved.)
--
-- Resolution chain (deterministic, replayed offline against Custom/CSV DBC/
-- Spell.csv + live creature_template_model): teaching item -> companion summon
-- spell (SPELL_EFFECT_SUMMON / SUMMON_PET) -> creature -> first valid model
-- display id. All display ids are STOCK except the two custom Devilsaurs
-- (500230 / 500231) -- no new DBC required.
--
-- The 33 genuinely-unresolvable definitions (dummy "NPC Equip" items with no
-- spell, Pet Fish / Pet Stone, script-only pet leashes / Goblin Weather /
-- Silver Shafted Arrow) are intentionally NOT listed here. The visible
-- turtle-egg colour variants and the Coralshell / Jubling fallbacks are in
-- 2026_06_18_00_dc_pet_definitions_preview_display_fix.sql.
--
-- UPDATEs only (idempotent); no INSERT, so no DELETE pre-step required.
-- ============================================================================

UPDATE `dc_pet_definitions` SET `display_id` = 7937, `pet_spell_id` = 4055
    WHERE `pet_entry` = 4401;
UPDATE `dc_pet_definitions` SET `display_id` = 5556, `pet_spell_id` = 10673
    WHERE `pet_entry` = 8485;
UPDATE `dc_pet_definitions` SET `display_id` = 5586, `pet_spell_id` = 10674
    WHERE `pet_entry` = 8486;
UPDATE `dc_pet_definitions` SET `display_id` = 5554, `pet_spell_id` = 10676
    WHERE `pet_entry` = 8487;
UPDATE `dc_pet_definitions` SET `display_id` = 5555, `pet_spell_id` = 10678
    WHERE `pet_entry` = 8488;
UPDATE `dc_pet_definitions` SET `display_id` = 9989, `pet_spell_id` = 10679
    WHERE `pet_entry` = 8489;
UPDATE `dc_pet_definitions` SET `display_id` = 5585, `pet_spell_id` = 10677
    WHERE `pet_entry` = 8490;
UPDATE `dc_pet_definitions` SET `display_id` = 5448, `pet_spell_id` = 10675
    WHERE `pet_entry` = 8491;
UPDATE `dc_pet_definitions` SET `display_id` = 5207, `pet_spell_id` = 10683
    WHERE `pet_entry` = 8492;
UPDATE `dc_pet_definitions` SET `display_id` = 6192, `pet_spell_id` = 10682
    WHERE `pet_entry` = 8494;
UPDATE `dc_pet_definitions` SET `display_id` = 6190, `pet_spell_id` = 10684
    WHERE `pet_entry` = 8495;
UPDATE `dc_pet_definitions` SET `display_id` = 6191, `pet_spell_id` = 10680
    WHERE `pet_entry` = 8496;
UPDATE `dc_pet_definitions` SET `display_id` = 328, `pet_spell_id` = 10711
    WHERE `pet_entry` = 8497;
UPDATE `dc_pet_definitions` SET `display_id` = 6291, `pet_spell_id` = 10698
    WHERE `pet_entry` = 8498;
UPDATE `dc_pet_definitions` SET `display_id` = 6290, `pet_spell_id` = 10697
    WHERE `pet_entry` = 8499;
UPDATE `dc_pet_definitions` SET `display_id` = 4615, `pet_spell_id` = 10707
    WHERE `pet_entry` = 8500;
UPDATE `dc_pet_definitions` SET `display_id` = 6299, `pet_spell_id` = 10706
    WHERE `pet_entry` = 8501;
UPDATE `dc_pet_definitions` SET `display_id` = 1206, `pet_spell_id` = 10714
    WHERE `pet_entry` = 10360;
UPDATE `dc_pet_definitions` SET `display_id` = 2957, `pet_spell_id` = 10716
    WHERE `pet_entry` = 10361;
UPDATE `dc_pet_definitions` SET `display_id` = 6303, `pet_spell_id` = 10717
    WHERE `pet_entry` = 10392;
UPDATE `dc_pet_definitions` SET `display_id` = 2177, `pet_spell_id` = 10688
    WHERE `pet_entry` = 10393;
UPDATE `dc_pet_definitions` SET `display_id` = 1072, `pet_spell_id` = 10709
    WHERE `pet_entry` = 10394;
UPDATE `dc_pet_definitions` SET `display_id` = 7920, `pet_spell_id` = 12243
    WHERE `pet_entry` = 10398;
UPDATE `dc_pet_definitions` SET `display_id` = 6288, `pet_spell_id` = 10695
    WHERE `pet_entry` = 10822;
UPDATE `dc_pet_definitions` SET `display_id` = 5369, `pet_spell_id` = 10685
    WHERE `pet_entry` = 11023;
UPDATE `dc_pet_definitions` SET `display_id` = 6295, `pet_spell_id` = 10704
    WHERE `pet_entry` = 11026;
UPDATE `dc_pet_definitions` SET `display_id` = 901, `pet_spell_id` = 10703
    WHERE `pet_entry` = 11027;
UPDATE `dc_pet_definitions` SET `display_id` = 304, `pet_spell_id` = 13548
    WHERE `pet_entry` = 11110;
UPDATE `dc_pet_definitions` SET `display_id` = 6294, `pet_spell_id` = 15067
    WHERE `pet_entry` = 11474;
UPDATE `dc_pet_definitions` SET `display_id` = 8909, `pet_spell_id` = 15048
    WHERE `pet_entry` = 11825;
UPDATE `dc_pet_definitions` SET `display_id` = 8910, `pet_spell_id` = 15049
    WHERE `pet_entry` = 11826;
UPDATE `dc_pet_definitions` SET `display_id` = 9209, `pet_spell_id` = 15648
    WHERE `pet_entry` = 11903;
UPDATE `dc_pet_definitions` SET `display_id` = 10993, `pet_spell_id` = 17709
    WHERE `pet_entry` = 13582;
UPDATE `dc_pet_definitions` SET `display_id` = 10990, `pet_spell_id` = 17707
    WHERE `pet_entry` = 13583;
UPDATE `dc_pet_definitions` SET `display_id` = 10992, `pet_spell_id` = 17708
    WHERE `pet_entry` = 13584;
UPDATE `dc_pet_definitions` SET `display_id` = 901, `pet_spell_id` = 19772
    WHERE `pet_entry` = 15996;
UPDATE `dc_pet_definitions` SET `display_id` = 14657, `pet_spell_id` = 23429
    WHERE `pet_entry` = 18964;
UPDATE `dc_pet_definitions` SET `display_id` = 14779, `pet_spell_id` = 23530
    WHERE `pet_entry` = 19054;
UPDATE `dc_pet_definitions` SET `display_id` = 14778, `pet_spell_id` = 23531
    WHERE `pet_entry` = 19055;
UPDATE `dc_pet_definitions` SET `display_id` = 14938, `pet_spell_id` = 23811
    WHERE `pet_entry` = 19450;
UPDATE `dc_pet_definitions` SET `display_id` = 14938, `pet_spell_id` = 23851
    WHERE `pet_entry` = 19462;
UPDATE `dc_pet_definitions` SET `display_id` = 15369, `pet_spell_id` = 24696
    WHERE `pet_entry` = 20371;
UPDATE `dc_pet_definitions` SET `display_id` = 15395, `pet_spell_id` = 25018
    WHERE `pet_entry` = 20651;
UPDATE `dc_pet_definitions` SET `display_id` = 15436, `pet_spell_id` = 25162
    WHERE `pet_entry` = 20769;
UPDATE `dc_pet_definitions` SET `display_id` = 15595, `pet_spell_id` = 25849
    WHERE `pet_entry` = 21168;
UPDATE `dc_pet_definitions` SET `display_id` = 10269, `pet_spell_id` = 26010
    WHERE `pet_entry` = 21277;
UPDATE `dc_pet_definitions` SET `display_id` = 15984, `pet_spell_id` = 27241
    WHERE `pet_entry` = 22114;
UPDATE `dc_pet_definitions` SET `display_id` = 15992, `pet_spell_id` = 27570
    WHERE `pet_entry` = 22235;
UPDATE `dc_pet_definitions` SET `display_id` = 15398, `pet_spell_id` = 28487
    WHERE `pet_entry` = 22780;
UPDATE `dc_pet_definitions` SET `display_id` = 16189, `pet_spell_id` = 28505
    WHERE `pet_entry` = 22781;
UPDATE `dc_pet_definitions` SET `display_id` = 16259, `pet_spell_id` = 28738
    WHERE `pet_entry` = 23002;
UPDATE `dc_pet_definitions` SET `display_id` = 16257, `pet_spell_id` = 28739
    WHERE `pet_entry` = 23007;
UPDATE `dc_pet_definitions` SET `display_id` = 2176, `pet_spell_id` = 28740
    WHERE `pet_entry` = 23015;
UPDATE `dc_pet_definitions` SET `display_id` = 16587, `pet_spell_id` = 28871
    WHERE `pet_entry` = 23083;
UPDATE `dc_pet_definitions` SET `display_id` = 16942, `pet_spell_id` = 30152
    WHERE `pet_entry` = 23712;
UPDATE `dc_pet_definitions` SET `display_id` = 16943, `pet_spell_id` = 30156
    WHERE `pet_entry` = 23713;
UPDATE `dc_pet_definitions` SET `display_id` = 17723, `pet_spell_id` = 32298
    WHERE `pet_entry` = 25535;
UPDATE `dc_pet_definitions` SET `display_id` = 18269, `pet_spell_id` = 33050
    WHERE `pet_entry` = 27445;
UPDATE `dc_pet_definitions` SET `display_id` = 19600, `pet_spell_id` = 35156
    WHERE `pet_entry` = 29363;
UPDATE `dc_pet_definitions` SET `display_id` = 4626, `pet_spell_id` = 35239
    WHERE `pet_entry` = 29364;
UPDATE `dc_pet_definitions` SET `display_id` = 19987, `pet_spell_id` = 35907
    WHERE `pet_entry` = 29901;
UPDATE `dc_pet_definitions` SET `display_id` = 19986, `pet_spell_id` = 35909
    WHERE `pet_entry` = 29902;
UPDATE `dc_pet_definitions` SET `display_id` = 19985, `pet_spell_id` = 35910
    WHERE `pet_entry` = 29903;
UPDATE `dc_pet_definitions` SET `display_id` = 19999, `pet_spell_id` = 35911
    WHERE `pet_entry` = 29904;
UPDATE `dc_pet_definitions` SET `display_id` = 20026, `pet_spell_id` = 36027
    WHERE `pet_entry` = 29953;
UPDATE `dc_pet_definitions` SET `display_id` = 20027, `pet_spell_id` = 36028
    WHERE `pet_entry` = 29956;
UPDATE `dc_pet_definitions` SET `display_id` = 20037, `pet_spell_id` = 36029
    WHERE `pet_entry` = 29957;
UPDATE `dc_pet_definitions` SET `display_id` = 20029, `pet_spell_id` = 36031
    WHERE `pet_entry` = 29958;
UPDATE `dc_pet_definitions` SET `display_id` = 20042, `pet_spell_id` = 36034
    WHERE `pet_entry` = 29960;
UPDATE `dc_pet_definitions` SET `display_id` = 22349, `pet_spell_id` = 39709
    WHERE `pet_entry` = 32233;
UPDATE `dc_pet_definitions` SET `display_id` = 21304, `pet_spell_id` = 40319
    WHERE `pet_entry` = 32465;
UPDATE `dc_pet_definitions` SET `display_id` = 21328, `pet_spell_id` = 40405
    WHERE `pet_entry` = 32498;
UPDATE `dc_pet_definitions` SET `display_id` = 21362, `pet_spell_id` = 40549
    WHERE `pet_entry` = 32588;
UPDATE `dc_pet_definitions` SET `display_id` = 21900, `pet_spell_id` = 42609
    WHERE `pet_entry` = 33154;
UPDATE `dc_pet_definitions` SET `display_id` = 22388, `pet_spell_id` = 43697
    WHERE `pet_entry` = 33816;
UPDATE `dc_pet_definitions` SET `display_id` = 22389, `pet_spell_id` = 43698
    WHERE `pet_entry` = 33818;
UPDATE `dc_pet_definitions` SET `display_id` = 22459, `pet_spell_id` = 43918
    WHERE `pet_entry` = 33993;
UPDATE `dc_pet_definitions` SET `display_id` = 22776, `pet_spell_id` = 54187
    WHERE `pet_entry` = 34425;
UPDATE `dc_pet_definitions` SET `display_id` = 22855, `pet_spell_id` = 45082
    WHERE `pet_entry` = 34478;
UPDATE `dc_pet_definitions` SET `display_id` = 22903, `pet_spell_id` = 45125
    WHERE `pet_entry` = 34492;
UPDATE `dc_pet_definitions` SET `display_id` = 22966, `pet_spell_id` = 45127
    WHERE `pet_entry` = 34493;
UPDATE `dc_pet_definitions` SET `display_id` = 21304, `pet_spell_id` = 45174
    WHERE `pet_entry` = 34518;
UPDATE `dc_pet_definitions` SET `display_id` = 22938, `pet_spell_id` = 45175
    WHERE `pet_entry` = 34519;
UPDATE `dc_pet_definitions` SET `display_id` = 6293, `pet_spell_id` = 10696
    WHERE `pet_entry` = 34535;
UPDATE `dc_pet_definitions` SET `display_id` = 23507, `pet_spell_id` = 46425
    WHERE `pet_entry` = 35349;
UPDATE `dc_pet_definitions` SET `display_id` = 23506, `pet_spell_id` = 46426
    WHERE `pet_entry` = 35350;
UPDATE `dc_pet_definitions` SET `display_id` = 23574, `pet_spell_id` = 46599
    WHERE `pet_entry` = 35504;
UPDATE `dc_pet_definitions` SET `display_id` = 24393, `pet_spell_id` = 48406
    WHERE `pet_entry` = 37297;
UPDATE `dc_pet_definitions` SET `display_id` = 24620, `pet_spell_id` = 48408
    WHERE `pet_entry` = 37298;
UPDATE `dc_pet_definitions` SET `display_id` = 25002, `pet_spell_id` = 49964
    WHERE `pet_entry` = 38050;
UPDATE `dc_pet_definitions` SET `display_id` = 25457, `pet_spell_id` = 51716
    WHERE `pet_entry` = 38628;
UPDATE `dc_pet_definitions` SET `display_id` = 4185, `pet_spell_id` = 51851
    WHERE `pet_entry` = 38658;
UPDATE `dc_pet_definitions` SET `display_id` = 28456, `pet_spell_id` = 52615
    WHERE `pet_entry` = 39286;
UPDATE `dc_pet_definitions` SET `display_id` = 25900, `pet_spell_id` = 53082
    WHERE `pet_entry` = 39656;
UPDATE `dc_pet_definitions` SET `display_id` = 28214, `pet_spell_id` = 61348
    WHERE `pet_entry` = 39896;
UPDATE `dc_pet_definitions` SET `display_id` = 28084, `pet_spell_id` = 61351
    WHERE `pet_entry` = 39898;
UPDATE `dc_pet_definitions` SET `display_id` = 28215, `pet_spell_id` = 61349
    WHERE `pet_entry` = 39899;
UPDATE `dc_pet_definitions` SET `display_id` = 28089, `pet_spell_id` = 53316
    WHERE `pet_entry` = 39973;
UPDATE `dc_pet_definitions` SET `display_id` = 16633, `pet_spell_id` = 40990
    WHERE `pet_entry` = 40653;
UPDATE `dc_pet_definitions` SET `display_id` = 26452, `pet_spell_id` = 55068
    WHERE `pet_entry` = 41133;
UPDATE `dc_pet_definitions` SET `display_id` = 28216, `pet_spell_id` = 61357
    WHERE `pet_entry` = 43517;
UPDATE `dc_pet_definitions` SET `display_id` = 27627, `pet_spell_id` = 59250
    WHERE `pet_entry` = 43698;
UPDATE `dc_pet_definitions` SET `display_id` = 28217, `pet_spell_id` = 61350
    WHERE `pet_entry` = 44721;
UPDATE `dc_pet_definitions` SET `display_id` = 28216, `pet_spell_id` = 61357
    WHERE `pet_entry` = 44723;
UPDATE `dc_pet_definitions` SET `display_id` = 14273, `pet_spell_id` = 61472
    WHERE `pet_entry` = 44738;
UPDATE `dc_pet_definitions` SET `display_id` = 16189, `pet_spell_id` = 61855
    WHERE `pet_entry` = 44819;
UPDATE `dc_pet_definitions` SET `display_id` = 2955, `pet_spell_id` = 10713
    WHERE `pet_entry` = 44822;
UPDATE `dc_pet_definitions` SET `display_id` = 28397, `pet_spell_id` = 61991
    WHERE `pet_entry` = 44841;
UPDATE `dc_pet_definitions` SET `display_id` = 28482, `pet_spell_id` = 62491
    WHERE `pet_entry` = 44965;
UPDATE `dc_pet_definitions` SET `display_id` = 28489, `pet_spell_id` = 62508
    WHERE `pet_entry` = 44970;
UPDATE `dc_pet_definitions` SET `display_id` = 4732, `pet_spell_id` = 62510
    WHERE `pet_entry` = 44971;
UPDATE `dc_pet_definitions` SET `display_id` = 14473, `pet_spell_id` = 62514
    WHERE `pet_entry` = 44972;
UPDATE `dc_pet_definitions` SET `display_id` = 15470, `pet_spell_id` = 62513
    WHERE `pet_entry` = 44973;
UPDATE `dc_pet_definitions` SET `display_id` = 16205, `pet_spell_id` = 62516
    WHERE `pet_entry` = 44974;
UPDATE `dc_pet_definitions` SET `display_id` = 28502, `pet_spell_id` = 62542
    WHERE `pet_entry` = 44980;
UPDATE `dc_pet_definitions` SET `display_id` = 16910, `pet_spell_id` = 62564
    WHERE `pet_entry` = 44982;
UPDATE `dc_pet_definitions` SET `display_id` = 28507, `pet_spell_id` = 62561
    WHERE `pet_entry` = 44983;
UPDATE `dc_pet_definitions` SET `display_id` = 28493, `pet_spell_id` = 62562
    WHERE `pet_entry` = 44984;
UPDATE `dc_pet_definitions` SET `display_id` = 28946, `pet_spell_id` = 62609
    WHERE `pet_entry` = 44998;
UPDATE `dc_pet_definitions` SET `display_id` = 28539, `pet_spell_id` = 62674
    WHERE `pet_entry` = 45002;
UPDATE `dc_pet_definitions` SET `display_id` = 28948, `pet_spell_id` = 62746
    WHERE `pet_entry` = 45022;
UPDATE `dc_pet_definitions` SET `display_id` = 28734, `pet_spell_id` = 63318
    WHERE `pet_entry` = 45180;
UPDATE `dc_pet_definitions` SET `display_id` = 29189, `pet_spell_id` = 63712
    WHERE `pet_entry` = 45606;
UPDATE `dc_pet_definitions` SET `display_id` = 29060, `pet_spell_id` = 64351
    WHERE `pet_entry` = 45942;
UPDATE `dc_pet_definitions` SET `display_id` = 11709, `pet_spell_id` = 65358
    WHERE `pet_entry` = 46398;
UPDATE `dc_pet_definitions` SET `display_id` = 25384, `pet_spell_id` = 65382
    WHERE `pet_entry` = 46544;
UPDATE `dc_pet_definitions` SET `display_id` = 25173, `pet_spell_id` = 65381
    WHERE `pet_entry` = 46545;
UPDATE `dc_pet_definitions` SET `display_id` = 22629, `pet_spell_id` = 44369
    WHERE `pet_entry` = 46707;
UPDATE `dc_pet_definitions` SET `display_id` = 29279, `pet_spell_id` = 65682
    WHERE `pet_entry` = 46767;
UPDATE `dc_pet_definitions` SET `display_id` = 29348, `pet_spell_id` = 66030
    WHERE `pet_entry` = 46802;
UPDATE `dc_pet_definitions` SET `display_id` = 29372, `pet_spell_id` = 66096
    WHERE `pet_entry` = 46820;
UPDATE `dc_pet_definitions` SET `display_id` = 29372, `pet_spell_id` = 66096
    WHERE `pet_entry` = 46821;
UPDATE `dc_pet_definitions` SET `display_id` = 29404, `pet_spell_id` = 66175
    WHERE `pet_entry` = 46831;
UPDATE `dc_pet_definitions` SET `display_id` = 28734, `pet_spell_id` = 63318
    WHERE `pet_entry` = 46892;
UPDATE `dc_pet_definitions` SET `display_id` = 29805, `pet_spell_id` = 67413
    WHERE `pet_entry` = 48112;
UPDATE `dc_pet_definitions` SET `display_id` = 29807, `pet_spell_id` = 67414
    WHERE `pet_entry` = 48114;
UPDATE `dc_pet_definitions` SET `display_id` = 29803, `pet_spell_id` = 67415
    WHERE `pet_entry` = 48116;
UPDATE `dc_pet_definitions` SET `display_id` = 29802, `pet_spell_id` = 67416
    WHERE `pet_entry` = 48118;
UPDATE `dc_pet_definitions` SET `display_id` = 29809, `pet_spell_id` = 67417
    WHERE `pet_entry` = 48120;
UPDATE `dc_pet_definitions` SET `display_id` = 29810, `pet_spell_id` = 67418
    WHERE `pet_entry` = 48122;
UPDATE `dc_pet_definitions` SET `display_id` = 29808, `pet_spell_id` = 67419
    WHERE `pet_entry` = 48124;
UPDATE `dc_pet_definitions` SET `display_id` = 29806, `pet_spell_id` = 67420
    WHERE `pet_entry` = 48126;
UPDATE `dc_pet_definitions` SET `display_id` = 29819, `pet_spell_id` = 67527
    WHERE `pet_entry` = 48527;
UPDATE `dc_pet_definitions` SET `display_id` = 30157, `pet_spell_id` = 68767
    WHERE `pet_entry` = 49287;
UPDATE `dc_pet_definitions` SET `display_id` = 30409, `pet_spell_id` = 68810
    WHERE `pet_entry` = 49343;
UPDATE `dc_pet_definitions` SET `display_id` = 30356, `pet_spell_id` = 69002
    WHERE `pet_entry` = 49362;
UPDATE `dc_pet_definitions` SET `display_id` = 30462, `pet_spell_id` = 69452
    WHERE `pet_entry` = 49646;
UPDATE `dc_pet_definitions` SET `display_id` = 30412, `pet_spell_id` = 69535
    WHERE `pet_entry` = 49662;
UPDATE `dc_pet_definitions` SET `display_id` = 30413, `pet_spell_id` = 69536
    WHERE `pet_entry` = 49663;
UPDATE `dc_pet_definitions` SET `display_id` = 30414, `pet_spell_id` = 69541
    WHERE `pet_entry` = 49665;
UPDATE `dc_pet_definitions` SET `display_id` = 30507, `pet_spell_id` = 69677
    WHERE `pet_entry` = 49693;
UPDATE `dc_pet_definitions` SET `display_id` = 31174, `pet_spell_id` = 70613
    WHERE `pet_entry` = 49912;
UPDATE `dc_pet_definitions` SET `display_id` = 31073, `pet_spell_id` = 71840
    WHERE `pet_entry` = 50446;
UPDATE `dc_pet_definitions` SET `display_id` = 22778, `pet_spell_id` = 75134
    WHERE `pet_entry` = 54436;
UPDATE `dc_pet_definitions` SET `display_id` = 31956, `pet_spell_id` = 75613
    WHERE `pet_entry` = 54810;
UPDATE `dc_pet_definitions` SET `display_id` = 32031, `pet_spell_id` = 75906
    WHERE `pet_entry` = 54847;
UPDATE `dc_pet_definitions` SET `display_id` = 28734, `pet_spell_id` = 75936
    WHERE `pet_entry` = 54857;
UPDATE `dc_pet_definitions` SET `display_id` = 32670, `pet_spell_id` = 78381
    WHERE `pet_entry` = 56806;
UPDATE `dc_pet_definitions` SET `display_id` = 500230, `pet_spell_id` = 300740
    WHERE `pet_entry` = 300410;
UPDATE `dc_pet_definitions` SET `display_id` = 500231, `pet_spell_id` = 300741
    WHERE `pet_entry` = 300411;
