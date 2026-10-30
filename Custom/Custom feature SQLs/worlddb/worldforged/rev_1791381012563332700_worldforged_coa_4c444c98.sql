-- Worldforged pickups (maps 750 / 751): follow Ascension CoA commit 4c444c986 (#4984, CoA migrations
-- rev_20261006_65 .. _70), which snapped floating open-world pickups to the stock map height and re-posed
-- jewellery pickups. 87 of our 687 spawns come from pickups it touched. Ours take DC's own terrain height,
-- so 59 of them need nothing. 24 had kept CoA's old height, which CoA now confirms was floating, and
-- DC's terrain agrees with CoA's new height: they move onto DC's terrain (Z only).
-- 6900150 Giant's Storm Dagger had kept CoA's old height too, but CoA's new one is the stock shore at 1.902;
-- DC's (Cataclysm) shore is 8 yd higher there and the pickup sat 3.5 yd inside it, so it also goes onto
-- DC's terrain.
-- Kept as they are: 6900370 Floating Barrel floats on the sea at 0.0 (CoA's pass sank it to the sea floor),
-- and 6900171 Elune Tear Fragment is already on DC's terrain (CoA's new height floats 3.3 yd above it).
-- Spawn guids are unchanged, so no character's claim on a pickup moves.
--
--   spawn    template  pickup                     zone                    shipped Z ->      new Z
--   6900012  5000071   Pulsating Staff            Winterspring             689.612 ->    686.372
--   6900022  5000087   Frostsaber Halberd         Winterspring             692.534 ->    689.001
--   6900059  5000117   Fel Axe                    Felwood                  392.742 ->    388.655
--   6900070  5000146   Libram of Resolute Light   Felwood                  304.750 ->    300.337
--   6900150  5000192   Giant's Storm Dagger       Azshara                    6.370 ->      9.905
--   6900214  5000246   Stardust Scoured Helmet    Ashenvale                100.480 ->     97.064
--   6900232  5000055   Assistant's Remains        Eastern Plaguelands      149.470 ->    144.490
--   6900262  5000040   Plagued Pitchfork          Eastern Plaguelands      102.131 ->     97.484
--   6900263  5000032   Quel'thalas Relic          Eastern Plaguelands      162.160 ->    156.189
--   6900273  5000039   Impaled Corpse             Eastern Plaguelands       98.233 ->     94.698
--   6900280  5000025   Holy Sword                 Eastern Plaguelands       49.067 ->     46.117
--   6900331  5000325   Timbermaw Cache            Western Plaguelands       71.616 ->     68.158
--   6900405  5000490   Acid Bolter                Hillsbrad Foothills      154.056 ->    157.613
--   6900428  5000475   Deadman's Dagger           Hillsbrad Foothills       67.480 ->     62.329
--   6900433  5000417   Dusty Hat                  Hillsbrad Foothills       46.271 ->     42.611
--   6900457  5000449   Icecracker                 Hillsbrad Foothills      171.279 ->    168.105
--   6900472  5000462   Muckrake's Soup Scooper    Hillsbrad Foothills      154.065 ->    150.682
--   6900487  5000415   Dust-Covered Trunk         Hillsbrad Foothills       48.473 ->     43.307
--   6900547  5000583   Geo Band                   The Hinterlands          121.807 ->    118.240
--   6900550  5000542   Hexcall Gavel              The Hinterlands          112.665 ->    109.477
--   6900558  5000521   Idol of the Aerie          The Hinterlands           23.618 ->     19.983
--   6900582  5000569   Sinter Wive's Rope         The Hinterlands          123.670 ->    118.737
--   6900612  5000649   Tattered Fur Remains       Arathi Highlands          71.465 ->     63.311
--   6900630  5000632   Large Bone                 Arathi Highlands          75.185 ->     71.397
--   6900659  5000666   Scorpion Scale             Arathi Highlands          79.772 ->     75.141

UPDATE `gameobject` SET `position_z` = 686.372 WHERE `guid` = 6900012 AND `id` = 5000071;
UPDATE `gameobject` SET `position_z` = 689.001 WHERE `guid` = 6900022 AND `id` = 5000087;
UPDATE `gameobject` SET `position_z` = 388.655 WHERE `guid` = 6900059 AND `id` = 5000117;
UPDATE `gameobject` SET `position_z` = 300.337 WHERE `guid` = 6900070 AND `id` = 5000146;
UPDATE `gameobject` SET `position_z` = 9.905 WHERE `guid` = 6900150 AND `id` = 5000192;
UPDATE `gameobject` SET `position_z` = 97.064 WHERE `guid` = 6900214 AND `id` = 5000246;
UPDATE `gameobject` SET `position_z` = 144.49 WHERE `guid` = 6900232 AND `id` = 5000055;
UPDATE `gameobject` SET `position_z` = 97.484 WHERE `guid` = 6900262 AND `id` = 5000040;
UPDATE `gameobject` SET `position_z` = 156.189 WHERE `guid` = 6900263 AND `id` = 5000032;
UPDATE `gameobject` SET `position_z` = 94.698 WHERE `guid` = 6900273 AND `id` = 5000039;
UPDATE `gameobject` SET `position_z` = 46.117 WHERE `guid` = 6900280 AND `id` = 5000025;
UPDATE `gameobject` SET `position_z` = 68.158 WHERE `guid` = 6900331 AND `id` = 5000325;
UPDATE `gameobject` SET `position_z` = 157.613 WHERE `guid` = 6900405 AND `id` = 5000490;
UPDATE `gameobject` SET `position_z` = 62.329 WHERE `guid` = 6900428 AND `id` = 5000475;
UPDATE `gameobject` SET `position_z` = 42.611 WHERE `guid` = 6900433 AND `id` = 5000417;
UPDATE `gameobject` SET `position_z` = 168.105 WHERE `guid` = 6900457 AND `id` = 5000449;
UPDATE `gameobject` SET `position_z` = 150.682 WHERE `guid` = 6900472 AND `id` = 5000462;
UPDATE `gameobject` SET `position_z` = 43.307 WHERE `guid` = 6900487 AND `id` = 5000415;
UPDATE `gameobject` SET `position_z` = 118.24 WHERE `guid` = 6900547 AND `id` = 5000583;
UPDATE `gameobject` SET `position_z` = 109.477 WHERE `guid` = 6900550 AND `id` = 5000542;
UPDATE `gameobject` SET `position_z` = 19.983 WHERE `guid` = 6900558 AND `id` = 5000521;
UPDATE `gameobject` SET `position_z` = 118.737 WHERE `guid` = 6900582 AND `id` = 5000569;
UPDATE `gameobject` SET `position_z` = 63.311 WHERE `guid` = 6900612 AND `id` = 5000649;
UPDATE `gameobject` SET `position_z` = 71.397 WHERE `guid` = 6900630 AND `id` = 5000632;
UPDATE `gameobject` SET `position_z` = 75.141 WHERE `guid` = 6900659 AND `id` = 5000666;

-- Scarlet Band (Western Plaguelands): CoA swapped the upright 0.9 yd Domination necklace model for the
-- Domination ring at size 0.25 and laid it flat on the Hearthglen floor (playtest-confirmed quaternion,
-- Z 152.05). The ring model is already DC GameObjectDisplayInfo 200119, so no client change.
UPDATE `gameobject_template` SET `displayId` = 200119, `size` = 0.25 WHERE `entry` = 5000304;
UPDATE `gameobject` SET `position_z` = 152.05, `rotation0` = 0, `rotation1` = 0.707107,
    `rotation2` = 0, `rotation3` = 0.707107 WHERE `guid` = 6900318 AND `id` = 5000304;
