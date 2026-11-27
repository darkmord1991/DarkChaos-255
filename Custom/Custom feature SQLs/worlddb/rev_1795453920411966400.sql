-- Names for the two custom continents and their flying spells. Re-runnable, UPDATE only.
--
--   map 750  Mount Hyjal (80-130)       -> The Sundered Wilds (80-130)
--   map 751  Plaguelands                -> The Fallen Kingdom (130-160)
--   300610   Kalimdor Flight License    -> Scorched Weather Flying
--   300611   Lordaeron Flight License   -> Plague Weather Flying
--
-- Client half: Map.dbc and Spell.dbc (Custom/DBCs, both CSVs updated) plus DC-QOS WorldMapDropdowns.lua.
-- Server half: this file and dc_flight_license.cpp (chat lines). The worldserver needs a rebuild for the chat lines.

-- 1) Spell names and descriptions on the server (the client rows are in Spell.dbc).
UPDATE `spell_dbc` SET `Name_Lang_enUS` = 'Scorched Weather Flying',
    `Description_Lang_enUS` = 'Allows you to fly in the Sundered Wilds (Darkshore, Azshara, Ashenvale, Felwood, Winterspring and Mount Hyjal) and increases your mounted and flight form speed there by 50%.'
WHERE `ID` = 300610;

UPDATE `spell_dbc` SET `Name_Lang_enUS` = 'Plague Weather Flying',
    `Description_Lang_enUS` = 'Allows you to fly in the Fallen Kingdom (Tirisfal Glades to the Eastern Plaguelands) and increases your mounted and flight form speed there by 50%.'
WHERE `ID` = 300611;

-- 2) The two breadcrumb quests (titles and text; objectives, rewards and turn-ins are unchanged).
UPDATE `quest_template` SET `LogTitle` = 'Wings over the Sundered Wilds',
    `QuestDescription` = 'Your deeds in the Sundered Wilds have not gone unnoticed, $N. The skies over Darkshore, Azshara, Ashenvale, Felwood, Winterspring and Mount Hyjal are open only to riders who have mastered Scorched Weather Flying.$B$BThe Flying Instructor beside the mount vendors in the Jade Forest teaches it, and so does every other riding trainer. With it you may take to the air over those lands, and every mount you ride there carries you half again as fast.'
WHERE `ID` = 81330;

UPDATE `quest_template` SET `LogTitle` = 'Wings over the Fallen Kingdom',
    `QuestDescription` = 'The Fallen Kingdom has tested you, $N, and you have held your ground. The skies over Tirisfal Glades, Silverpine Forest, Gilneas, Hillsbrad, Arathi and the Plaguelands are open only to riders who have mastered Plague Weather Flying.$B$BThe Flying Instructor beside the mount vendors in the Jade Forest teaches it, and so does every other riding trainer. With it you may take to the air over those lands, and every mount you ride there carries you half again as fast.'
WHERE `ID` = 81331;

UPDATE `quest_offer_reward` SET `RewardText` = 'Ready to leave the ground behind over the Sundered Wilds, $c? Train with me and the skies above Hyjal are yours.$B$BMind you, it holds only over those lands. Once one of your characters has learned it, all characters of your account receive it when they first set foot there.'
WHERE `ID` = 81330;

UPDATE `quest_offer_reward` SET `RewardText` = 'The Fallen Kingdom from above is a sight few survivors forget, $c. Train with me and its skies are yours.$B$BMind you, it holds only over those lands. Once one of your characters has learned it, all characters of your account receive it when they first set foot there.'
WHERE `ID` = 81331;

-- 3) Teleporter menu entries (Level Areas folders and the Custom Locations entries on map 751).
UPDATE `dc_teleporter` SET `name` = 'The Sundered Wilds 80 - 130' WHERE `id` = 410;
UPDATE `dc_teleporter` SET `name` = 'The Fallen Kingdom 130 - 160' WHERE `id` = 420;
UPDATE `dc_teleporter` SET `name` = 'The Fallen Kingdom (Eastern Plaguelands)' WHERE `id` = 508;
UPDATE `dc_teleporter` SET `name` = 'Undercity (Fallen Kingdom)' WHERE `id` = 509;
UPDATE `dc_teleporter` SET `name` = 'The Fallen Kingdom - 7th Legion Base Camp' WHERE `id` = 510;
