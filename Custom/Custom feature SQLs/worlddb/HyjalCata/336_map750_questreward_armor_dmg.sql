-- ---------------------------------------------------------------------------
-- 336  Armour and weapon damage for the 145 map-750 quest rewards
-- ---------------------------------------------------------------------------
-- GENERATED, do not hand-edit. Produced by:
--
--   python Custom/Documentation/scripts/gen_zone_gear_armor_dmg.py --     --dbc-dir K:/tmp/cata-itemcurves --items-csv qr_items.csv --out <this>
--
-- Cata stores neither `armor` nor weapon `dmg_min/dmg_max` -- both are DERIVED
-- from ItemLevel + Quality + slot through curve DBCs:
--   armor  = ItemArmorTotal[ilvl][armorType] x ItemArmorQuality[ilvl][quality]
--            x ArmorLocation[slot][armorType];  shields = ItemArmorShield[ilvl][q]
--   weapon = ItemDamage<Type>[ilvl][quality] x delay/1000, split 0.85 .. 1.15
--
-- 🔴 MUST RUN AFTER 335_, which is what set the ItemLevel and the weapon `delay`
-- these values are computed from. Run it before 335_ and every number is wrong.
--
--   weapons 22   armour 119   skipped 4
--
-- The 4 skips are correct: one neck (62192) and three rings (62156, 62210,
-- 62214). Cata's armour tables have no value for those slots, so they get no
-- armour rather than a fabricated one. Cloaks ARE covered.
--
-- VERIFIED BEFORE SHIPPING -- armour is ordered by armour class at every slot
-- that carries more than one, which is the check that matters for a derived
-- table:
--   ilvl388 shoulder  cloth 1101  leather 1427             plate 2797
--   ilvl388 chest                 leather 1902  mail 2697  plate 3729
--   ilvl388 waist     cloth  825  leather 1070  mail 1517  plate 2098
--   ilvl388 wrist     cloth  642  leather  832  mail 1180  plate 1632
--   13 such slots, 0 out of order. Shields 8,395 / 11,361 -- inside the
--   7,259-12,490 band 310_ established for the clone set.
--
-- Caster weapons deliberately come out lower than melee at the same item level
-- (an ilvl-315 staff at 153 dps against an ilvl-285 dagger's 237). They use the
-- ItemDamage*Caster curves; that is correct Cata behaviour, not a bug.
--
-- 🔴 No `USE` statement -- select acore_world in your client. A `USE` line is
-- exactly what made 335_ report SQL error 1064: the client lost the terminating
-- semicolon and handed MySQL a bare `acore_world` token. (335_ still applied in
-- full -- the client continued past the error.)
--
-- Apply against acore_world AFTER 335_. Idempotent -- absolute assignments.
-- Needs a worldserver restart, and a client cache-id bump so players stop
-- seeing the old statless tooltip.
-- ---------------------------------------------------------------------------
UPDATE `item_template` SET `armor`=1124 WHERE `entry`=52583;
UPDATE `item_template` SET `armor`=1205 WHERE `entry`=52599;
UPDATE `item_template` SET `armor`=860 WHERE `entry`=52614;
UPDATE `item_template` SET `armor`=654 WHERE `entry`=52616;
UPDATE `item_template` SET `armor`=2907 WHERE `entry`=52619;
UPDATE `item_template` SET `dmg_min1`=469,`dmg_max1`=635,`dmg_type1`=0 WHERE `entry`=52631;
UPDATE `item_template` SET `dmg_min1`=363,`dmg_max1`=491,`dmg_type1`=0 WHERE `entry`=52641;
UPDATE `item_template` SET `dmg_min1`=363,`dmg_max1`=491,`dmg_type1`=0 WHERE `entry`=52645;
UPDATE `item_template` SET `armor`=8395 WHERE `entry`=52654;
UPDATE `item_template` SET `armor`=11361 WHERE `entry`=52655;
UPDATE `item_template` SET `armor`=654 WHERE `entry`=53399;
UPDATE `item_template` SET `armor`=1010 WHERE `entry`=53401;
UPDATE `item_template` SET `dmg_min1`=1099,`dmg_max1`=1486,`dmg_type1`=0 WHERE `entry`=53403;
UPDATE `item_template` SET `armor`=1285 WHERE `entry`=53414;
UPDATE `item_template` SET `armor`=632 WHERE `entry`=53420;
UPDATE `item_template` SET `armor`=492 WHERE `entry`=53426;
UPDATE `item_template` SET `armor`=779 WHERE `entry`=53428;
UPDATE `item_template` SET `armor`=1028 WHERE `entry`=55128;
UPDATE `item_template` SET `armor`=1689 WHERE `entry`=55129;
UPDATE `item_template` SET `dmg_min1`=771,`dmg_max1`=1043,`dmg_type1`=0 WHERE `entry`=55132;
UPDATE `item_template` SET `armor`=1222 WHERE `entry`=56624;
UPDATE `item_template` SET `armor`=1229 WHERE `entry`=56625;
UPDATE `item_template` SET `armor`=2116 WHERE `entry`=56626;
UPDATE `item_template` SET `armor`=1930 WHERE `entry`=57360;
UPDATE `item_template` SET `armor`=947 WHERE `entry`=57361;
UPDATE `item_template` SET `armor`=887 WHERE `entry`=57362;
UPDATE `item_template` SET `armor`=3030 WHERE `entry`=57363;
UPDATE `item_template` SET `armor`=688 WHERE `entry`=57415;
UPDATE `item_template` SET `armor`=922 WHERE `entry`=57416;
UPDATE `item_template` SET `armor`=2328 WHERE `entry`=57417;
UPDATE `item_template` SET `armor`=922 WHERE `entry`=57490;
UPDATE `item_template` SET `armor`=2963 WHERE `entry`=57491;
UPDATE `item_template` SET `armor`=642 WHERE `entry`=62140;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62141;
UPDATE `item_template` SET `armor`=1308 WHERE `entry`=62142;
UPDATE `item_template` SET `armor`=2331 WHERE `entry`=62143;
UPDATE `item_template` SET `armor`=642 WHERE `entry`=62144;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62145;
UPDATE `item_template` SET `armor`=1308 WHERE `entry`=62146;
UPDATE `item_template` SET `armor`=2331 WHERE `entry`=62147;
UPDATE `item_template` SET `armor`=917 WHERE `entry`=62148;
UPDATE `item_template` SET `armor`=1427 WHERE `entry`=62149;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=62150;
UPDATE `item_template` SET `armor`=2098 WHERE `entry`=62151;
UPDATE `item_template` SET `armor`=917 WHERE `entry`=62152;
UPDATE `item_template` SET `armor`=1427 WHERE `entry`=62153;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=62154;
UPDATE `item_template` SET `armor`=2098 WHERE `entry`=62155;
UPDATE `item_template` SET `armor`=1902 WHERE `entry`=62157;
UPDATE `item_template` SET `armor`=3030 WHERE `entry`=62158;
UPDATE `item_template` SET `dmg_min1`=2013,`dmg_max1`=2724,`dmg_type1`=0 WHERE `entry`=62159;
UPDATE `item_template` SET `armor`=734 WHERE `entry`=62172;
UPDATE `item_template` SET `armor`=1308 WHERE `entry`=62173;
UPDATE `item_template` SET `armor`=1632 WHERE `entry`=62174;
UPDATE `item_template` SET `dmg_min1`=1339,`dmg_max1`=1811,`dmg_type1`=0 WHERE `entry`=62175;
UPDATE `item_template` SET `armor`=2564 WHERE `entry`=62177;
UPDATE `item_template` SET `dmg_min1`=2013,`dmg_max1`=2724,`dmg_type1`=0 WHERE `entry`=62181;
UPDATE `item_template` SET `armor`=1284 WHERE `entry`=62182;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=62183;
UPDATE `item_template` SET `armor`=2797 WHERE `entry`=62184;
UPDATE `item_template` SET `dmg_min1`=2013,`dmg_max1`=2724,`dmg_type1`=0 WHERE `entry`=62185;
UPDATE `item_template` SET `armor`=1284 WHERE `entry`=62186;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=62187;
UPDATE `item_template` SET `armor`=2797 WHERE `entry`=62188;
UPDATE `item_template` SET `armor`=1665 WHERE `entry`=62193;
UPDATE `item_template` SET `armor`=3729 WHERE `entry`=62194;
UPDATE `item_template` SET `armor`=750 WHERE `entry`=62195;
UPDATE `item_template` SET `armor`=1377 WHERE `entry`=62196;
UPDATE `item_template` SET `armor`=1033 WHERE `entry`=62197;
UPDATE `item_template` SET `dmg_min1`=1339,`dmg_max1`=1811,`dmg_type1`=0 WHERE `entry`=62199;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62200;
UPDATE `item_template` SET `dmg_min1`=1339,`dmg_max1`=1811,`dmg_type1`=0 WHERE `entry`=62201;
UPDATE `item_template` SET `armor`=642 WHERE `entry`=62202;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62203;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=62204;
UPDATE `item_template` SET `armor`=642 WHERE `entry`=62206;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62207;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=62208;
UPDATE `item_template` SET `armor`=1101 WHERE `entry`=62211;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=62212;
UPDATE `item_template` SET `dmg_min1`=2499,`dmg_max1`=3381,`dmg_type1`=0 WHERE `entry`=62213;
UPDATE `item_template` SET `armor`=1101 WHERE `entry`=62215;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=62216;
UPDATE `item_template` SET `dmg_min1`=2499,`dmg_max1`=3381,`dmg_type1`=0 WHERE `entry`=62217;
UPDATE `item_template` SET `dmg_min1`=998,`dmg_max1`=1351,`dmg_type1`=0 WHERE `entry`=62218;
UPDATE `item_template` SET `dmg_min1`=998,`dmg_max1`=1351,`dmg_type1`=0 WHERE `entry`=62219;
UPDATE `item_template` SET `armor`=1530 WHERE `entry`=62220;
UPDATE `item_template` SET `armor`=1724 WHERE `entry`=62221;
UPDATE `item_template` SET `armor`=2863 WHERE `entry`=62222;
UPDATE `item_template` SET `dmg_min1`=998,`dmg_max1`=1351,`dmg_type1`=0 WHERE `entry`=62223;
UPDATE `item_template` SET `dmg_min1`=998,`dmg_max1`=1351,`dmg_type1`=0 WHERE `entry`=62224;
UPDATE `item_template` SET `armor`=1530 WHERE `entry`=62225;
UPDATE `item_template` SET `armor`=1724 WHERE `entry`=62226;
UPDATE `item_template` SET `armor`=2863 WHERE `entry`=62227;
UPDATE `item_template` SET `armor`=917 WHERE `entry`=62935;
UPDATE `item_template` SET `armor`=1308 WHERE `entry`=62936;
UPDATE `item_template` SET `armor`=1854 WHERE `entry`=62937;
UPDATE `item_template` SET `armor`=2331 WHERE `entry`=62938;
UPDATE `item_template` SET `armor`=825 WHERE `entry`=62939;
UPDATE `item_template` SET `armor`=1070 WHERE `entry`=62940;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=62941;
UPDATE `item_template` SET `armor`=2697 WHERE `entry`=62942;
UPDATE `item_template` SET `armor`=3030 WHERE `entry`=62943;
UPDATE `item_template` SET `armor`=1009 WHERE `entry`=62944;
UPDATE `item_template` SET `armor`=1902 WHERE `entry`=62945;
UPDATE `item_template` SET `armor`=1180 WHERE `entry`=62946;
UPDATE `item_template` SET `armor`=1854 WHERE `entry`=62947;
UPDATE `item_template` SET `armor`=1284 WHERE `entry`=62972;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=62973;
UPDATE `item_template` SET `armor`=3030 WHERE `entry`=62974;
UPDATE `item_template` SET `armor`=1101 WHERE `entry`=62985;
UPDATE `item_template` SET `armor`=1665 WHERE `entry`=62986;
UPDATE `item_template` SET `armor`=2331 WHERE `entry`=62987;
UPDATE `item_template` SET `armor`=1427 WHERE `entry`=62989;
UPDATE `item_template` SET `armor`=2360 WHERE `entry`=62990;
UPDATE `item_template` SET `armor`=774 WHERE `entry`=62993;
UPDATE `item_template` SET `armor`=1186 WHERE `entry`=62994;
UPDATE `item_template` SET `armor`=1101 WHERE `entry`=62999;
UPDATE `item_template` SET `armor`=1308 WHERE `entry`=63000;
UPDATE `item_template` SET `armor`=1189 WHERE `entry`=63001;
UPDATE `item_template` SET `dmg_min1`=1339,`dmg_max1`=1811,`dmg_type1`=0 WHERE `entry`=63007;
UPDATE `item_template` SET `dmg_min1`=927,`dmg_max1`=1254,`dmg_type1`=0 WHERE `entry`=63008;
UPDATE `item_template` SET `armor`=1517 WHERE `entry`=63009;
UPDATE `item_template` SET `armor`=1632 WHERE `entry`=63010;
UPDATE `item_template` SET `dmg_min1`=1339,`dmg_max1`=1811,`dmg_type1`=0 WHERE `entry`=63011;
UPDATE `item_template` SET `armor`=1517 WHERE `entry`=63013;
UPDATE `item_template` SET `armor`=1467 WHERE `entry`=63015;
UPDATE `item_template` SET `armor`=832 WHERE `entry`=63016;
UPDATE `item_template` SET `armor`=2360 WHERE `entry`=63017;
UPDATE `item_template` SET `armor`=481 WHERE `entry`=63019;
UPDATE `item_template` SET `armor`=788 WHERE `entry`=63020;
UPDATE `item_template` SET `armor`=1218 WHERE `entry`=63021;
UPDATE `item_template` SET `armor`=1218 WHERE `entry`=65279;
UPDATE `item_template` SET `dmg_min1`=525,`dmg_max1`=710,`dmg_type1`=0 WHERE `entry`=65287;
UPDATE `item_template` SET `armor`=1433 WHERE `entry`=65299;
UPDATE `item_template` SET `dmg_min1`=1153,`dmg_max1`=1560,`dmg_type1`=0 WHERE `entry`=65318;
UPDATE `item_template` SET `armor`=2277 WHERE `entry`=65346;
UPDATE `item_template` SET `armor`=797 WHERE `entry`=71267;
UPDATE `item_template` SET `armor`=797 WHERE `entry`=71268;
UPDATE `item_template` SET `armor`=797 WHERE `entry`=71269;
UPDATE `item_template` SET `armor`=797 WHERE `entry`=71270;
