-- =============================================================================
-- Legion Dalaran (map 1413) -- Phase D: per-NPC gossip
-- =============================================================================
-- Source: LegionCore 7.3.5 zone 7502 gossip chain, with the menu bodies rebuilt
-- from that dump's broadcast_text (LegionCore's npc_text stores only ids).
--
-- 150 NPCs get a menu. Where the source menu id already exists here and is
-- in the stock WotLK id space it is REUSED (24 NPCs) -- that is literally the
-- same menu, and it leaves the Phase A choices in place. Everything else is
-- imported under fresh ids (8006000+ for menus, 8007000+ for texts) because retail
-- ids in the 20000+ range are already taken here by unrelated content (21017 /
-- 21043 / 21068 are our Lunar Festival "Where is Elder ...?" menus).
--
-- Dropped on purpose:
--   * source menus above 25000 -- those are LegionCore's OWN server menus
--     (test arenas, reward previews, Warsong Gulch tables, "Transfer me to
--     Illidari Bastion"), not Dalaran content
--   * gossip option types above 15 (post-3.3.5 option kinds)
--   * plain-gossip options that open no submenu and show no POI -- those are
--     driven by server scripts we do not have, so they would be buttons that
--     silently do nothing. Structural options (vendor / trainer / banker /
--     innkeeper / questgiver / ...) are handled generically by the core and stay.
-- POI links are kept only for the 5118-5161 set imported in Phase B.
-- Dropped this run: {'script_driven_no_target': 192, 'option_type_post_335': 5, 'dead_end': 2}
--
-- Safe to re-run. Requires a worldserver restart.
-- =============================================================================

-- ---------- 1. menu bodies ----------
DELETE FROM `npc_text` WHERE `ID` BETWEEN 8007000 AND 8007128;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`, `text4_0`, `text4_1`, `BroadcastTextID4`, `lang4`, `Probability4`, `text5_0`, `text5_1`, `BroadcastTextID5`, `lang5`, `Probability5`) VALUES (8007000, 'Ahoy!', 'Ahoy!', 0, 0, 1, 'Avast!', 'Avast!', 0, 0, 1, 'Arr!', 'Arr!', 0, 0, 1, 'Yarr!', 'Yarr!', 0, 0, 1, 'Blow me down!', 'Blow me down!', 0, 0, 1, 'Gangway!', 'Gangway!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007001, 'May the spirits be with you.', 'May the spirits be with you.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007002, 'I have no time for a sermon now, $c. Seek your knowledge elsewhere.', 'I have no time for a sermon now, $c. Seek your knowledge elsewhere.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007003, 'Greetings, $n. You were not followed here, I trust?', 'Greetings, $n. You were not followed here, I trust?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007004, 'I apologize, $c. I mistook you for someone with a spine. Begone; our secrets are not for untrained ears.', 'I apologize, $c. I mistook you for someone with a spine. Begone; our secrets are not for untrained ears.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007005, 'We have little to discuss, $c. Perhaps you should seek other, more like-minded individuals.', 'We have little to discuss, $c. Perhaps you should seek other, more like-minded individuals.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007006, 'Remember to always show your respect for the elements of the world.', 'Remember to always show your respect for the elements of the world.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007007, 'I cannot train a $c such as yourself.', 'I cannot train a $c such as yourself.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007008, 'I train only warriors, $c. You\'ll have to look elsewhere.', 'I train only warriors, $c. You\'ll have to look elsewhere.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007009, '$n, how may I further your training in the eyes of the Earth Mother?', '$n, how may I further your training in the eyes of the Earth Mother?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007010, 'May the Light protect you this day.', 'May the Light protect you this day.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007011, 'Do not turn your back on the Light, $c, it may be the one thing that saves you some day.', 'Do not turn your back on the Light, $c, it may be the one thing that saves you some day.', 0, 7, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007012, 'The darkness does not embrace you, $c.  Cease your prattle and remove yourself from my sight!  Be gone!', 'The darkness does not embrace you, $c.  Cease your prattle and remove yourself from my sight!  Be gone!', 0, 7, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007013, 'Greetings.  You seek instruction in the art of war?', 'Greetings.  Do you seek instruction in art of war?', 0, 7, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007014, 'We are but darkness and shadows. Eternal. Invisible.', 'We are but darkness and shadows. Eternal. Invisible.', 0, 7, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007015, 'Our master Malfurion has returned from the Dreaming, $c.  His is the light of a beacon that shows the way for us, and we must do everything in our power to preserve that light.', 'Our master Malfurion has returned from the Dreaming, $c.  His is the light of a beacon that shows the way for us, and we must do everything in our power to preserve that light.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007016, 'I\'m very sorry, but I no longer have relics to sell you. Their magic seems to have extinguished! Perhaps I\'ll go into dancing full time now, it would be a nice change of pace.', 'I\'m very sorry, but I no longer have relics to sell you. Their magic seems to have extinguished! Perhaps I\'ll go into dancing full time now, it would be a nice change of pace.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007017, 'Ya got the goods, mon. I be able to turn dem inta Dingy Iron Coins for ya. I got my ways. See me lata and spend dem coins on someting fancy!', 'Ya got the goods, mon. I be able to turn dem inta Dingy Iron Coins for ya. I got my ways. See me lata and spend dem coins on someting fancy!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007018, 'Together, we will reseal the Tomb of Sargeras and defeat the Burning Legion.', 'Together, we will reseal the Tomb of Sargeras and defeat the Burning Legion.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007019, 'How may I help you?', 'How may I help you?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007020, 'Welcome to Cartier and Company Fine Jewelry, $c. I can tell you\'re a customer with an appreciation for the finer things.$b$bWhat can I show you today?', 'Welcome to Cartier and Company Fine Jewelry, $c. I can tell you\'re a customer with an appreciation for the finer things.$b$bWhat can I show you today?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007021, 'Stay out of Violet Hold if you know what\'s good for you, $r. I don\'t like the look of some of the creatures they\'re storing in there.', 'Stay out of Violet Hold if you know what\'s good for you, $r. I don\'t like the look of some of the creatures they\'re storing in there.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007022, 'It is very good to see you, $n.', 'It is very good to see you, $n.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007023, 'Are you ready to fly? You\'ll have our fastest mount.', 'Are you ready to fly? You\'ll have our fastest mount.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007024, 'I have a wide selection of recipes available.', 'I have a wide selection of recipes available.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007025, 'View available missions.', 'View available missions.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007026, 'It\'s great that a hero like you is helping out us little enchanters! I don\'t mean we\'re little, as in short. Archmage Starsinger is actually quite tall.$b$bI mean... aw, nevermind!', 'It\'s great that a hero like you is helping out us little enchanters! I don\'t mean we\'re little, as in short. Archmage Starsinger is actually quite tall.$b$bI mean... aw, nevermind!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007027, 'The service in this place is terrible. TERRIBLE!', 'The service in this place is terrible. TERRIBLE!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007028, 'No matter how much I feed them, your pets keep wandering into the town hall and begging for scraps.', 'No matter how much I feed them, your pets keep wandering into the town hall and begging for scraps.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007029, 'Whatcha need?', 'Whatcha need?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007030, 'If yer looking for mail armor, look no further! I\'ve got the best in town!', 'If yer looking for mail armor, look no further! I\'ve got the best in town!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007031, 'Welcome to Tanks for Everything. We have the finest in all your blacksmithing and mining needs.', 'Welcome to Tanks for Everything. We have the finest in all your blacksmithing and mining needs.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007032, 'Our defeat at the Broken Shore was a disaster. What\'s left of the Alliance and Horde are at one another\'s throats.$b$b$C, heroes like you may be our last great hope. Stay strong, and do not give up.', 'Our defeat at the Broken Shore was a disaster. What\'s left of the Alliance and Horde are at one another\'s throats.$b$b$C, heroes like you may be our last great hope. Stay strong, and do not give up.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007033, 'You have come, just as Emmarel said you would.', 'You have come, just as Emmarel said you would.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007034, 'The Light will guide us to victory.', 'The Light will guide us to victory.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007035, 'What\'cha lookin\' for, stranger?', 'What\'cha lookin\' for, stranger?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007036, 'My husband is always running off without cleaning up after himself, leaving me to clean up after him.$b$bIf you see him around Dalaran, could you let him know that I love him more than he loves me?', 'My husband is always running off without cleaning up after himself, leaving me to clean up after him.$b$bIf you see him around Dalaran, could you let him know that I love him more than he loves me?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007037, 'If you got some springs loose, I can probably show you how to fix \'em up!', 'If you got some springs loose, I can probably show you how to fix \'em up!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007038, 'Can I interest you in a new trinket?', 'Can I interest you in a new trinket?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007039, 'You have chosen well. Such a weapon will strike fear into the hearts of our foes!', 'You have chosen well. Such a weapon will strike fear into the hearts of our foes!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007040, 'The Kirin Tor have established a portal in a chamber beneath the city to Dalaran\'s former home in the Hillsbrad Foothills - Light\'s Hope is a short ride from there.$B$BThere are teleportation pads in Runeweaver Square that will take you to the chamber. I have marked one on your map.', 'The Kirin Tor have established a portal in a chamber beneath the city to Dalaran\'s former home in the Hillsbrad Foothills - Light\'s Hope is a short ride from there.$B$BThere are teleportation pads in Runeweaver Square that will take you to the chamber. I have marked one on your map.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007041, 'We are indomitable. We are Illidari.', 'We are indomitable. We are Illidari.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007042, 'What\'s the matter? Never seen a princess who knows how to twist a blade?', 'What\'s the matter? Never seen a princess who knows how to twist a blade?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007043, 'Greetings, Master $n. What are we cooking today?', 'Greetings, Master $n. What are we cooking today?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007044, 'All\'s fair in love and business.', 'All\'s fair in love and business.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007045, 'I don\'t trust your kind, "demon hunter".$B$BYou and the Legion are one and the same in my book.', 'I don\'t trust your kind, "demon hunter".$B$BYou and the Legion are one and the same in my book.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007046, 'Is that a threat?$B$BNeed I remind you that you are surrounded by my guards in my prison.', 'Is that a threat?$B$BNeed I remind you that you are surrounded by my guards in my prison.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`) VALUES (8007047, 'I notice you\'re not wearing any earrings. Could I interest you in pair of bolt-action carbine hoops? They\'re not very rusty!', 'I notice you\'re not wearing any earrings. Could I interest you in pair of bolt-action carbine hoops? They\'re not very rusty!', 0, 0, 1, 'This Oshenko fella\' is always using "screwdrivers" on his screws. Hasn\'t he ever heard of a hammer?', 'This Oshenko fella\' is always using "screwdrivers" on his screws. Hasn\'t he ever heard of a hammer?', 0, 0, 1, 'Hmm... you didn\'t see any nuclear bombs on your way in, did you? No? Alright, I\'ll keep looking.', 'Hmm... you didn\'t see any nuclear bombs on your way in, did you? No? Alright, I\'ll keep looking.', 0, 0, 1, 'I haven\'t exploded anybody yet today. It\'s a good day!', 'I haven\'t exploded anybody yet today. It\'s a good day!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007048, 'The Skyfire is ready for action.', 'The Skyfire is ready for action.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007049, 'I\'m grateful Lady Shadewarden found you, $n. We have a chance to strike a major blow against the Legion!', 'I\'m grateful Lady Shadewarden found you, $n. We have a chance to strike a major blow against the Legion!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007050, 'So that lass Emmarel Shadewarden sent you my way? Seems she\'s good as her word, that one.$b$bDon\'t know a thing \'bout this Unseen Path she\'s part of, but I\'m willin\' to hear her out.$b$bI may not be used to workin\' with you Horde folk, but the Legion\'s got it in for all of us, dwarf and $r alike.$b$bTime to put differences aside, I say!', 'So that lass Emmarel Shadewarden sent you my way? Seems she\'s good as her word, that one.$b$bDon\'t know a thing \'bout this Unseen Path she\'s part of, but I\'m willin\' to hear her out.$b$bI may not be used to workin\' with you Horde folk, but the Legion\'s got it in for all of us, dwarf and $r alike.$b$bTime to put differences aside, I say!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007051, 'Good to see you, friend.', 'Good to see you, friend.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007052, 'Desmond seems to have crossed someone he shouldn\'t have.', 'Desmond seems to have crossed someone he shouldn\'t have.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007053, 'I carry only the highest quality products.', 'I carry only the highest quality products.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007054, 'Yes, I\'m a druid and... well... I\'m kind of stuck like this for a while.$b$bWhile patrolling the sea around the Broken Shore, an infernal crashed into the water right on top of me. The blast instantly knocked me unconscious.\n$b$bWhen I woke I was here in the care of the nurses. They say after a few days I should have the strength to shift back. In the meantime, I\'m stuck in this contraption to keep me from drying out.\n$b$bDo me a favor. Don\'t mention this to any of the other druids. They\'ll never let me live it down!', 'Yes, I\'m a druid and... well... I\'m kind of stuck like this for a while.$b$bWhile patrolling the sea around the Broken Shore, an infernal crashed into the water right on top of me. The blast instantly knocked me unconscious.\n$b$bWhen I woke I was here in the care of the nurses. They say after a few days I should have the strength to shift back. In the meantime, I\'m stuck in this contraption to keep me from drying out.\n$b$bDo me a favor. Don\'t mention this to any of the other druids. They\'ll never let me live it down!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007055, 'If you can pay, I can supply.', 'If you can pay, I can supply.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007056, 'The Uncrowned will do what no others can: finish this war.', 'The Uncrowned will do what no others can: finish this war.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007057, 'What can I do for ya?', 'What can I do for ya?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007058, 'Jorach spoke highly of you. He\'s a good friend to have.', 'Jorach spoke highly of you. He\'s a good friend to have.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007059, 'When that brute Kraggosh and his overseers moved into the Undercity, we were forced to do our real work in secret.$B$BSurely you can see how such an arrangement inevitably led me here.', 'When that brute Kraggosh and his overseers moved into the Undercity, we were forced to do our real work in secret.$B$BSurely you can see how such an arrangement inevitably led me here.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007060, 'Just... resting my eyes... for a moment...', 'Just... resting my eyes... for a moment...', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007061, '<If you had an herb, you could plant it here.>', '<Plant a flower?>', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007062, '<The beast looks at you for a moment and neighs.>', '<The beast looks at you for a moment and neighs.>', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007063, 'I can find any tool... for the right price.', 'I can find any tool... for the right price.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007064, '<You see a great blue dragon, resting languidly atop the greenhouse. She seems to be a memory from your staff, Ebonchill, and not part of this world. To your surprise, the mighty creature turns to face you, speaking slowly:>$b$bThe great Alodi returns, seeking ever more power. Tell me, mage, has the Council considered the impact of granting so much magical energy to a single mortal, hmmmm?$b$bAnd what if their beloved Guardian should ever betray them?$b$bI will be watching you...', '<You see a great blue dragon, resting languidly atop the greenhouse. She seems to be a memory from your staff, Ebonchill, and not part of this world. To your surprise, the mighty creature turns to face you, speaking slowly:>$b$bThe great Alodi returns, seeking ever more power. Tell me, mage, has the Council considered the impact of granting so much magical energy to a single mortal, hmmmm?$b$bAnd what if their beloved Guardian should ever betray them?$b$bI will be watching you...', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007065, 'I am Tyr\'s Guard. We are a secret order of paladins that have been guarding a great secret for a very long time. Unfortunately current events have caused us to end our secrecy.', 'I am Tyr\'s Guard. We are a secret order of paladins that have been guarding a great secret for a very long time. Unfortunately current events have caused us to end our secrecy.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007066, 'Here in the big city, Jabrul can finally focus on gems and gems alone.', 'Here in the big city, Jabrul can finally focus on gems and gems alone.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007067, 'Glad to see you.', 'Glad to see you.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007068, 'You... you walk in the path of the Light.\n\nWhat guides you here this day?', 'You... you walk in the path of the Light.\n\nWhat guides you here this day?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007069, 'No offense, but I don\'t have time to chat. I have a shield to find!', 'No offense, but I don\'t have time to chat. I have a shield to find!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007070, 'Recent events weigh heavily on me. There is something I must do.', 'Recent events weigh heavily on me. There is something I must do.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007071, 'That battle, I can find no glory in it. Too many died, but I did not. The anger within me grows every minute I stare at that storm.\n\nI will return to the Broken Shore, for those under my command. I will kill demons until their glory is found and my honor restored. Do not seek to counsel against this, I am set in my ways.', 'That battle, I can find no glory in it. Too many died, but I did not. The anger within me grows every minute I stare at that storm.\n\nI will return to the Broken Shore, for those under my command. I will kill demons until their glory is found and my honor restored. Do not seek to counsel against this, I am set in my ways.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007072, 'I can reflow the venom within your blades to unlock new power wthin.\n\nThere\'s no charge for you, of course, but beware that some strength is lost in the process.', 'I can reflow the venom within your blades to unlock new power wthin.\n\nThere\'s no charge for you, of course, but beware that some strength is lost in the process.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007073, 'You want a job done? I can get a job done.', 'You want a job done? I can get a job done.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007074, 'The seas be calling!', 'The seas be calling!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007075, 'We work in the shadows.', 'We work in the shadows.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007076, 'Welcome to our humble clinic. Are there wounds you need treated or are you here for supplies?', 'Welcome to our humble clinic. Are there wounds you need treated or are you here for supplies?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007077, 'Hey Boss. Need anything?', 'Hey Boss. Need anything?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007078, 'In the past I have guided my husband Go\'el along the path of the shaman. But for his next trial, he walks alone. What of you? What is your path?$b$bWill you be a force of nature, laying waste to our foes? A font of wisdom, discerning and fulfilling the will of the spirits? A healer, soothing the troubled and lifting up the meek? I tell you the truth, $n:$b$bA true shaman must be all of these things.', 'In the past I have guided my husband Go\'el along the path of the shaman. But for his next trial, he walks alone. What of you? What is your path?$b$bWill you be a force of nature, laying waste to our foes? A font of wisdom, discerning and fulfilling the will of the spirits? A healer, soothing the troubled and lifting up the meek? I tell you the truth, $n:$b$bA true shaman must be all of these things.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007079, 'Have you come to a decision yet, $ct?$b$bI would give you guidance, but in this, you must look within.', 'Have you come to a decision yet, $ct?$b$bI would give you guidance, but in this, you must look within.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007080, 'Nothing like some kafa to get you started in the morning, or an icy Highmountain Refresher after a long day on the battlefield. I like Spiced Tea as a nightcap, myself. Have you tried the honey croissants? Deee-licious!$B$BAt least that\'s what I say. But you know... I\'m not really here for the coffee.', 'Nothing like some kafa to get you started in the morning, or an icy Highmountain Refresher after a long day on the battlefield. I like Spiced Tea as a nightcap, myself. Have you tried the honey croissants? Deee-licious!$B$BAt least that\'s what I say. But you know... I\'m not really here for the coffee.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007081, 'Oh, hello, welcome to Dalaran. I tend to the lamps.', 'Oh, hello, welcome to Dalaran. I tend to the lamps.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007082, 'Looking for a Seal of Broken Fate?', 'Looking for a Seal of Broken Fate?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007083, 'Hello there. Good news! My books have arrived at last, well most of them.\n\nYou still look confused, so let me explain again. You see, when we last teleported Dalaran, some of my books were damaged. And so this time I had them fly to our new location. Yes, fly.\n\nUnfortunately, they were halfway over Khaz Modan when we teleported again. Most just arrived last week and are settling back in around the city. A few of them are still on loan to some colleagues, and should return themselves soon. Actually, if they are out much longer I might have to go investigate.', 'Hello there. Good news! My books have arrived at last, well most of them.\n\nYou still look confused, so let me explain again. You see, when we last teleported Dalaran, some of my books were damaged. And so this time I had them fly to our new location. Yes, fly.\n\nUnfortunately, they were halfway over Khaz Modan when we teleported again. Most just arrived last week and are settling back in around the city. A few of them are still on loan to some colleagues, and should return themselves soon. Actually, if they are out much longer I might have to go investigate.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007084, 'Naw, Wintron can handle it.\n\nThank you though!\n\nIt was a pleasure meeting you.', 'Naw, Wintron can handle it.\n\nThank you though!\n\nIt was a pleasure meeting you.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007085, 'Oh hiya, toots. You need anything, or ya want me to have someone get ya something.\n\nOr, ya know, if ya just want to talk, Nikki\'s here for ya.', 'Oh hiya, toots. You need anything, or ya want me to have someone get ya something.\n\nOr, ya know, if ya just want to talk, Nikki\'s here for ya.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007086, 'Hiya, $n! How can I help you today?', 'Hiya, $n! How can I help you today?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007087, 'What can I do for ya?', 'What can I do for ya?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007088, 'What do you seek?', 'What do you seek?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007089, 'Greetings.', 'Greetings.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007090, 'How can me help ye, Shadow $n?', 'How can me help ye, Shadow $n?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007091, 'The Shattered Hand will see the Horde to its former glory.', 'The Shattered Hand will see the Horde to its former glory.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007092, 'Something I can help you with?', 'Something I can help you with?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007093, 'What do you seek?', 'What do you seek?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007094, 'Tell me, $c, have you explored the wondrous goods that Dalaran has to offer? If you can\'t find what you\'re looking for, chances I know someone who can help.', 'Tell me, $c, have you explored the wondrous goods that Dalaran has to offer? If you can\'t find what you\'re looking for, chances I know someone who can help.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007095, 'I told them this would happen. \n\nI TOLD them. \n\nDid they listen?!', 'I told them this would happen. \n\nI TOLD them. \n\nDid they listen?!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007096, '<Saying nothing, he eyes you warily.>', '<Saying nothing, she eyes you warily.>', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007097, 'The dreadlord Kathra\'natir is defeated, but only for now. If we wish to save Azeroth from his evil, we must reform the Tirisgarde. \n\nThen we can hunt him down in the Twisting Nether before he has a chance to share his secrets with the Burning Legion.', 'The dreadlord Kathra\'natir is defeated, but only for now. If we wish to save Azeroth from his evil, we must reform the Tirisgarde. \n\nThen we can hunt him down in the Twisting Nether before he has a chance to share his secrets with the Burning Legion.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007098, 'Yes, $n?', 'Yes, $n?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007099, 'Any information you can find on Arrexis, how he died, and the whereabouts of Ebonchill would be greatly appreciated.', 'Any information you can find on Arrexis, how he died, and the whereabouts of Ebonchill would be greatly appreciated.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007100, 'Do you wish to hear a tale from the past, $n?', 'Do you wish to hear a tale from the past, $n?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007101, 'I do not believe you possess the mental acuity to grasp the nature of portal magic.', 'I do not believe you possess the mental acuity to grasp the nature of portal magic.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007102, 'Hey there, $n! You lookin\' to obliterate some gear? Maybe use some Obliterum to make the gear you\'re wearin\' more powerful? Then I\'m your dwarf! Ask away!', 'Hey there, $n! You lookin\' to obliterate some gear? Maybe use some Obliterum to make the gear you\'re wearin\' more powerful? Then I\'m your dwarf! Ask away!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007103, 'Welcome to Dalaran, traveler.$B$BIs there something I might help you find?', 'Welcome to Dalaran, traveler.$B$BIs there something I might help you find?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007104, 'Please respect the laws of Dalaran while you are here, stranger.$B$BWere you lost? Is there something I might help you find?', 'Please respect the laws of Dalaran while you are here, stranger.$B$BWere you lost? Is there something I might help you find?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007105, 'There are many places of interest in Dalaran. Which do you seek?', 'There are many places of interest in Dalaran. Which do you seek?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007106, 'I am Xe\'ra, one of the first naaru to be forged here during the great ordering of the cosmos.', 'I am Xe\'ra, one of the first naaru to be forged here during the great ordering of the cosmos.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007107, 'Hail, champion.', 'Hail, champion.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007108, 'Welcome to the Legerdemain Lounge, $c. I do hope you\'ll enjoy your stay.', 'Welcome to the Legerdemain Lounge, $c. I do hope you\'ll enjoy your stay.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007109, 'How can I help you?', 'How can I help you?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007110, 'Good day to you.', 'Good day to you.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007111, 'Greetings.', 'Greetings.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007112, 'The Light will not abandon us.', 'The Light will not abandon us.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007113, 'We will end the Burning Legion or die trying.', 'We will end the Burning Legion or die trying.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007114, 'With the Tirisgarde at the helm, our united forces will crush the Burning Legion once and for all!', 'With the Tirisgarde at the helm, our united forces will crush the Burning Legion once and for all!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007115, 'What can I help you with?', 'What can I help you with?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007116, 'Have you figured out these runes yet? We don\'t have much time!', 'Have you figured out these runes yet? We don\'t have much time!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007117, 'We have come far together, $n.', 'We have come far together, $n.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007118, 'Now is the time when the year is new and the moon shines bright.$B$BIt is our time... when the ancients awake.', 'Now is the time when the year is new and the moon shines bright.$B$BIt is our time... when the ancients awake.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007119, 'I have all the tools necessary to adjust the appearance of your weapons and armor.\n\nShall we begin?', 'I have all the tools necessary to adjust the appearance of your weapons and armor.\n\nShall we begin?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007120, 'In days long past, we lived for the hunt.  We hunted for glory, for honor...$B$BIs it so different now?', 'In days long past, we lived for the hunt.  We hunted for glory, for honor...$B$BIs it so different now?', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007121, 'Elder Bloodhoof can be found at Bloodhoof Village in Mulgore.', 'Elder Bloodhoof can be found at Bloodhoof Village in Mulgore.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`) VALUES (8007122, 'Dance! Dance! Dance!', 'Dance! Dance! Dance!', 0, 0, 1, 'Dance like nobody\'s watching!', 'Dance like nobody\'s watching!', 0, 0, 1, 'Everybody dance... NOW!', 'Everybody dance... NOW!', 0, 0, 1, 'I love dancing!', 'I love dancing!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007123, 'Elder Ironband lives in Blackchar Cave in Searing Gorge.', 'Elder Ironband lives in Blackchar Cave in Searing Gorge.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007124, 'Elder Silvervein can be found near Thelsamar in Loch Modan.', 'Elder Silvervein can be found near Thelsamar in Loch Modan.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007125, 'Elder Windtotem is keeping company with the goblins of Ratchet on the coast of the Barrens.', 'Elder Windtotem is keeping company with the goblins of Ratchet on the coast of the Barrens.', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007126, 'I need help sorting these letters!', 'I need help sorting these letters!', 0, 0, 1);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`) VALUES (8007127, 'Still plenty of letters to sort, if you\'re up to it!$B$BOr how about something more challenging? We also receive letters without a full address on them.$B$BThink you can handle it?', 'Still plenty of letters to sort, if you\'re up to it!$B$BOr how about something more challenging? We also receive letters without a full address on them.$B$BThink you can handle it?', 0, 0, 1);

-- ---------- 2. menus ----------
DELETE FROM `gossip_menu` WHERE `MenuID` IN (8006000, 8006001, 8006002, 8006003, 8006004, 8006005, 8006006, 8006007, 8006008, 8006009, 8006010, 8006011, 8006012, 8006013, 8006014, 8006015, 8006016, 8006017, 8006018, 8006019, 8006020, 8006021, 8006022, 8006023, 8006024, 8006025, 8006026, 8006027, 8006028, 8006029, 8006030, 8006031, 8006032, 8006033, 8006034, 8006035, 8006036, 8006037, 8006038, 8006039, 8006040, 8006041, 8006042, 8006043, 8006044, 8006045, 8006046, 8006047, 8006048, 8006049, 8006050, 8006051, 8006052, 8006053, 8006054, 8006055, 8006056, 8006057, 8006058, 8006059, 8006060, 8006061, 8006062, 8006063, 8006064, 8006065, 8006066, 8006067, 8006068, 8006069, 8006070, 8006071, 8006072, 8006073, 8006074, 8006075, 8006076, 8006077, 8006078, 8006079, 8006080, 8006081, 8006082, 8006083, 8006084, 8006085, 8006086, 8006087, 8006088, 8006089, 8006090, 8006091, 8006092, 8006093, 8006094, 8006095, 8006096, 8006097, 8006098, 8006099, 8006100, 8006101, 8006102, 8006103, 8006104, 8006105, 8006106, 8006107, 8006108, 8006109, 8006110, 8006111, 8006112, 8006113, 8006114, 8006115, 8006116, 8006117, 8006118, 8006119, 8006120, 8006121, 8006122, 8006123, 8006124);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(8006000, 8007000),
(8006001, 8007001),
(8006002, 8007002),
(8006003, 8007003),
(8006004, 8007004),
(8006005, 8007005),
(8006006, 8007006),
(8006007, 8007007),
(8006008, 8007008),
(8006009, 8007009),
(8006010, 8007010),
(8006011, 8007011),
(8006012, 8007012),
(8006013, 8007013),
(8006014, 8007014),
(8006015, 8007015),
(8006016, 8007016),
(8006017, 8007017),
(8006018, 8007018),
(8006019, 8007019),
(8006020, 8007019),
(8006021, 8007020),
(8006022, 8007021),
(8006023, 8007022),
(8006024, 8007023),
(8006025, 8007024),
(8006026, 8007025),
(8006027, 8007026),
(8006028, 8007027),
(8006029, 8007028),
(8006030, 8007029),
(8006031, 8007030),
(8006032, 8007031),
(8006033, 8007032),
(8006034, 8007033),
(8006035, 8007034),
(8006036, 8007035),
(8006037, 8007036),
(8006038, 8007037),
(8006039, 8007038),
(8006040, 8007039),
(8006041, 8007040),
(8006042, 8007041),
(8006043, 8007042),
(8006044, 8007043),
(8006045, 8007044),
(8006046, 8007045),
(8006047, 8007046),
(8006048, 8007047),
(8006049, 8007048),
(8006050, 8007049),
(8006051, 8007050),
(8006052, 8007051),
(8006053, 8007052),
(8006054, 8007053),
(8006055, 8007054),
(8006056, 8007055),
(8006057, 8007056),
(8006058, 8007057),
(8006059, 8007058),
(8006060, 8007059),
(8006061, 8007060),
(8006062, 8007061),
(8006063, 8007062),
(8006064, 8007063),
(8006065, 8007064),
(8006066, 8007065),
(8006067, 8007066),
(8006068, 8007067),
(8006069, 8007068),
(8006070, 8007069),
(8006071, 8007070),
(8006072, 8007071),
(8006073, 8007072),
(8006074, 8007073),
(8006075, 8007074),
(8006076, 8007075),
(8006077, 8007076),
(8006078, 8007077),
(8006079, 8007078),
(8006079, 8007079),
(8006080, 8007080),
(8006081, 8007081),
(8006082, 8007082),
(8006083, 8007083),
(8006084, 8007084),
(8006085, 8007085),
(8006086, 8007086),
(8006087, 8007087),
(8006088, 8007088),
(8006089, 8007089),
(8006090, 8007090),
(8006091, 8007091),
(8006092, 8007092),
(8006093, 8007093),
(8006094, 8007094),
(8006095, 8007095),
(8006096, 8007096),
(8006097, 8007097),
(8006097, 8007098),
(8006097, 8007099),
(8006098, 8007019),
(8006099, 8007100),
(8006100, 8007101),
(8006101, 8007102),
(8006102, 8007103),
(8006102, 8007104),
(8006103, 8007105),
(8006104, 8007106),
(8006105, 8007107),
(8006106, 8007108),
(8006107, 8007109),
(8006108, 8007110),
(8006109, 8007111),
(8006110, 8007112),
(8006111, 8007113),
(8006112, 8007114),
(8006113, 8007115),
(8006114, 8007116),
(8006115, 8007117),
(8006116, 8007118),
(8006117, 8007119),
(8006118, 8007120),
(8006119, 8007121),
(8006120, 8007122),
(8006121, 8007123),
(8006122, 8007124),
(8006123, 8007125),
(8006124, 8007126),
(8006124, 8007127);

-- ---------- 3. options ----------
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (8006000, 8006001, 8006002, 8006003, 8006004, 8006005, 8006006, 8006007, 8006008, 8006009, 8006010, 8006011, 8006012, 8006013, 8006014, 8006015, 8006016, 8006017, 8006018, 8006019, 8006020, 8006021, 8006022, 8006023, 8006024, 8006025, 8006026, 8006027, 8006028, 8006029, 8006030, 8006031, 8006032, 8006033, 8006034, 8006035, 8006036, 8006037, 8006038, 8006039, 8006040, 8006041, 8006042, 8006043, 8006044, 8006045, 8006046, 8006047, 8006048, 8006049, 8006050, 8006051, 8006052, 8006053, 8006054, 8006055, 8006056, 8006057, 8006058, 8006059, 8006060, 8006061, 8006062, 8006063, 8006064, 8006065, 8006066, 8006067, 8006068, 8006069, 8006070, 8006071, 8006072, 8006073, 8006074, 8006075, 8006076, 8006077, 8006078, 8006079, 8006080, 8006081, 8006082, 8006083, 8006084, 8006085, 8006086, 8006087, 8006088, 8006089, 8006090, 8006091, 8006092, 8006093, 8006094, 8006095, 8006096, 8006097, 8006098, 8006099, 8006100, 8006101, 8006102, 8006103, 8006104, 8006105, 8006106, 8006107, 8006108, 8006109, 8006110, 8006111, 8006112, 8006113, 8006114, 8006115, 8006116, 8006117, 8006118, 8006119, 8006120, 8006121, 8006122, 8006123, 8006124);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`) VALUES
(8006017, 1, 0, 'Show me your products!', 0, 3, 128, 0, 0),
(8006019, 0, 0, 'May I have a look at the product?', 0, 3, 128, 0, 0),
(8006020, 0, 0, 'I would like to buy something from you.', 0, 3, 128, 0, 0),
(8006021, 0, 0, 'Show me the most expensive that you have.', 0, 3, 128, 0, 0),
(8006024, 0, 0, 'I need a transport.', 0, 4, 8192, 0, 0),
(8006025, 0, 0, 'I want to buy something from you.', 0, 3, 128, 0, 0),
(8006029, 3, 0, 'Any pet stuff for sale?', 0, 3, 128, 0, 0),
(8006030, 2, 0, 'Any pet stuff for sale?', 0, 3, 128, 0, 0),
(8006031, 0, 0, 'I want to take a look at your products.', 0, 3, 128, 0, 0),
(8006032, 0, 0, 'I want to take a look at your products.', 0, 3, 128, 0, 0),
(8006036, 0, 0, 'I want to buy something.', 0, 3, 128, 0, 0),
(8006038, 1, 0, 'Train me in engineering.', 0, 5, 16, 0, 0),
(8006039, 1, 0, 'I would like to buy something from you.', 0, 3, 128, 0, 0),
(8006044, 14, 0, 'What recipes do you sell?', 0, 3, 128, 0, 0),
(8006046, 1, 0, 'Let us in - or I\'ll show you how we are different, and you won’t like it.', 0, 1, 1, 8006047, 0),
(8006048, 0, 0, 'May I have a look at the product?', 0, 3, 128, 0, 0),
(8006054, 2, 0, 'Show me the latest arrivals.', 0, 3, 128, 0, 0),
(8006064, 1, 0, 'Show me the latest arrivals.', 0, 3, 128, 0, 0),
(8006067, 0, 0, 'I would like to buy something from you.', 0, 3, 128, 0, 0),
(8006071, 0, 0, 'What must you do?', 0, 1, 1, 8006072, 0),
(8006077, 0, 0, 'I want to buy something from you.', 0, 3, 128, 0, 0),
(8006078, 1, 0, 'Do you have any completed artifact research?', 0, 3, 128, 0, 0),
(8006081, 1, 0, 'May I have a look at the product?', 0, 3, 128, 0, 0),
(8006086, 0, 0, 'Let\'s see what you have.', 0, 3, 128, 0, 0),
(8006098, 0, 0, 'May I have a look at the product?', 0, 3, 128, 0, 0),
(8006106, 1, 0, 'Let me take a look at your products.', 0, 3, 128, 0, 0),
(8006107, 0, 0, 'I need to use the services of a bank.', 0, 9, 1, 0, 0),
(8006108, 0, 0, 'I need to use the services of a bank.', 0, 9, 1, 0, 0),
(8006109, 0, 0, 'I need to use the services of a bank.', 0, 9, 1, 0, 0),
(8006113, 0, 0, 'Let me take a look at your products.', 0, 3, 128, 0, 0),
(8006116, 1, 0, 'Where is Elder Bronzebeard?', 0, 1, 1, 8006120, 0),
(8006116, 2, 0, 'Where is Elder Ironband?', 0, 1, 1, 8006121, 0),
(8006116, 3, 0, 'Where is Elder Silvervein?', 0, 1, 1, 8006122, 0),
(8006117, 1, 0, 'I would like to buy something from you.', 0, 3, 128, 0, 0),
(8006118, 1, 0, 'Where is Elder Bloodhoof?', 0, 1, 1, 8006119, 0),
(8006118, 4, 0, 'Where is Elder Ironband?', 0, 1, 1, 8006121, 0),
(8006118, 5, 0, 'Where is Elder Windtotem?', 0, 1, 1, 8006123, 0);

-- ---------- 4. attach menus to the NPCs ----------
UPDATE `creature_template` SET `gossip_menu_id` = 10656 WHERE `entry` = 3500030;
UPDATE `creature_template` SET `gossip_menu_id` = 8006018 WHERE `entry` = 3500043;
UPDATE `creature_template` SET `gossip_menu_id` = 8006035 WHERE `entry` = 3500044;
UPDATE `creature_template` SET `gossip_menu_id` = 8006023 WHERE `entry` = 3500045;
UPDATE `creature_template` SET `gossip_menu_id` = 8006105 WHERE `entry` = 3500046;
UPDATE `creature_template` SET `gossip_menu_id` = 8006033 WHERE `entry` = 3500053;
UPDATE `creature_template` SET `gossip_menu_id` = 8006032 WHERE `entry` = 3500057;
UPDATE `creature_template` SET `gossip_menu_id` = 8006025 WHERE `entry` = 3500060;
UPDATE `creature_template` SET `gossip_menu_id` = 8006019 WHERE `entry` = 3500062;
UPDATE `creature_template` SET `gossip_menu_id` = 8006064 WHERE `entry` = 3500069;
UPDATE `creature_template` SET `gossip_menu_id` = 8006020 WHERE `entry` = 3500071;
UPDATE `creature_template` SET `gossip_menu_id` = 8006021 WHERE `entry` = 3500072;
UPDATE `creature_template` SET `gossip_menu_id` = 8006077 WHERE `entry` = 3500073;
UPDATE `creature_template` SET `gossip_menu_id` = 8006098 WHERE `entry` = 3500074;
UPDATE `creature_template` SET `gossip_menu_id` = 8006048 WHERE `entry` = 3500078;
UPDATE `creature_template` SET `gossip_menu_id` = 8006036 WHERE `entry` = 3500079;
UPDATE `creature_template` SET `gossip_menu_id` = 8006071 WHERE `entry` = 3500084;
UPDATE `creature_template` SET `gossip_menu_id` = 8006043 WHERE `entry` = 3500087;
UPDATE `creature_template` SET `gossip_menu_id` = 8006058 WHERE `entry` = 3500088;
UPDATE `creature_template` SET `gossip_menu_id` = 8006022 WHERE `entry` = 3500090;
UPDATE `creature_template` SET `gossip_menu_id` = 8006000 WHERE `entry` = 3500093;
UPDATE `creature_template` SET `gossip_menu_id` = 8006037 WHERE `entry` = 3500097;
UPDATE `creature_template` SET `gossip_menu_id` = 8006046 WHERE `entry` = 3500099;
UPDATE `creature_template` SET `gossip_menu_id` = 10180 WHERE `entry` = 3500102;
UPDATE `creature_template` SET `gossip_menu_id` = 9821 WHERE `entry` = 3500104;
UPDATE `creature_template` SET `gossip_menu_id` = 8006049 WHERE `entry` = 3500112;
UPDATE `creature_template` SET `gossip_menu_id` = 9781 WHERE `entry` = 3500123;
UPDATE `creature_template` SET `gossip_menu_id` = 8006054 WHERE `entry` = 3500124;
UPDATE `creature_template` SET `gossip_menu_id` = 8006100 WHERE `entry` = 3500127;
UPDATE `creature_template` SET `gossip_menu_id` = 9733 WHERE `entry` = 3500129;
UPDATE `creature_template` SET `gossip_menu_id` = 10139 WHERE `entry` = 3500135;
UPDATE `creature_template` SET `gossip_menu_id` = 8006106 WHERE `entry` = 3500144;
UPDATE `creature_template` SET `gossip_menu_id` = 8006102 WHERE `entry` = 3500148;
UPDATE `creature_template` SET `gossip_menu_id` = 9838 WHERE `entry` = 3500149;
UPDATE `creature_template` SET `gossip_menu_id` = 9832 WHERE `entry` = 3500150;
UPDATE `creature_template` SET `gossip_menu_id` = 8006024 WHERE `entry` = 3500151;
UPDATE `creature_template` SET `gossip_menu_id` = 8006107 WHERE `entry` = 3500152;
UPDATE `creature_template` SET `gossip_menu_id` = 8006108 WHERE `entry` = 3500153;
UPDATE `creature_template` SET `gossip_menu_id` = 8006109 WHERE `entry` = 3500154;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500165;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500166;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500167;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500168;
UPDATE `creature_template` SET `gossip_menu_id` = 8006103 WHERE `entry` = 3500169;
UPDATE `creature_template` SET `gossip_menu_id` = 8006102 WHERE `entry` = 3500170;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500171;
UPDATE `creature_template` SET `gossip_menu_id` = 10085 WHERE `entry` = 3500172;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500173;
UPDATE `creature_template` SET `gossip_menu_id` = 10065 WHERE `entry` = 3500174;
UPDATE `creature_template` SET `gossip_menu_id` = 8006102 WHERE `entry` = 3500175;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500176;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500177;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500178;
UPDATE `creature_template` SET `gossip_menu_id` = 8006015 WHERE `entry` = 3500179;
UPDATE `creature_template` SET `gossip_menu_id` = 8006007 WHERE `entry` = 3500180;
UPDATE `creature_template` SET `gossip_menu_id` = 8006010 WHERE `entry` = 3500181;
UPDATE `creature_template` SET `gossip_menu_id` = 8006011 WHERE `entry` = 3500182;
UPDATE `creature_template` SET `gossip_menu_id` = 8006014 WHERE `entry` = 3500183;
UPDATE `creature_template` SET `gossip_menu_id` = 8006006 WHERE `entry` = 3500184;
UPDATE `creature_template` SET `gossip_menu_id` = 8006012 WHERE `entry` = 3500185;
UPDATE `creature_template` SET `gossip_menu_id` = 8006013 WHERE `entry` = 3500186;
UPDATE `creature_template` SET `gossip_menu_id` = 8006009 WHERE `entry` = 3500187;
UPDATE `creature_template` SET `gossip_menu_id` = 8006005 WHERE `entry` = 3500188;
UPDATE `creature_template` SET `gossip_menu_id` = 8006002 WHERE `entry` = 3500189;
UPDATE `creature_template` SET `gossip_menu_id` = 8006003 WHERE `entry` = 3500190;
UPDATE `creature_template` SET `gossip_menu_id` = 8006001 WHERE `entry` = 3500191;
UPDATE `creature_template` SET `gossip_menu_id` = 8006004 WHERE `entry` = 3500192;
UPDATE `creature_template` SET `gossip_menu_id` = 8006008 WHERE `entry` = 3500193;
UPDATE `creature_template` SET `gossip_menu_id` = 9825 WHERE `entry` = 3500194;
UPDATE `creature_template` SET `gossip_menu_id` = 10854 WHERE `entry` = 3500195;
UPDATE `creature_template` SET `gossip_menu_id` = 8006031 WHERE `entry` = 3500207;
UPDATE `creature_template` SET `gossip_menu_id` = 8006016 WHERE `entry` = 3500213;
UPDATE `creature_template` SET `gossip_menu_id` = 8006056 WHERE `entry` = 3500214;
UPDATE `creature_template` SET `gossip_menu_id` = 8006039 WHERE `entry` = 3500215;
UPDATE `creature_template` SET `gossip_menu_id` = 8006081 WHERE `entry` = 3500222;
UPDATE `creature_template` SET `gossip_menu_id` = 8006113 WHERE `entry` = 3500223;
UPDATE `creature_template` SET `gossip_menu_id` = 8006027 WHERE `entry` = 3500239;
UPDATE `creature_template` SET `gossip_menu_id` = 8006028 WHERE `entry` = 3500247;
UPDATE `creature_template` SET `gossip_menu_id` = 8006085 WHERE `entry` = 3500248;
UPDATE `creature_template` SET `gossip_menu_id` = 8006026 WHERE `entry` = 3500249;
UPDATE `creature_template` SET `gossip_menu_id` = 8006059 WHERE `entry` = 3500251;
UPDATE `creature_template` SET `gossip_menu_id` = 8006029 WHERE `entry` = 3500257;
UPDATE `creature_template` SET `gossip_menu_id` = 8006042 WHERE `entry` = 3500262;
UPDATE `creature_template` SET `gossip_menu_id` = 8006042 WHERE `entry` = 3500263;
UPDATE `creature_template` SET `gossip_menu_id` = 8006084 WHERE `entry` = 3500268;
UPDATE `creature_template` SET `gossip_menu_id` = 8006079 WHERE `entry` = 3500270;
UPDATE `creature_template` SET `gossip_menu_id` = 8006117 WHERE `entry` = 3500275;
UPDATE `creature_template` SET `gossip_menu_id` = 8006034 WHERE `entry` = 3500276;
UPDATE `creature_template` SET `gossip_menu_id` = 8006050 WHERE `entry` = 3500277;
UPDATE `creature_template` SET `gossip_menu_id` = 8006067 WHERE `entry` = 3500281;
UPDATE `creature_template` SET `gossip_menu_id` = 8006051 WHERE `entry` = 3500283;
UPDATE `creature_template` SET `gossip_menu_id` = 8006057 WHERE `entry` = 3500293;
UPDATE `creature_template` SET `gossip_menu_id` = 8006044 WHERE `entry` = 3500295;
UPDATE `creature_template` SET `gossip_menu_id` = 8006040 WHERE `entry` = 3500303;
UPDATE `creature_template` SET `gossip_menu_id` = 8006045 WHERE `entry` = 3500308;
UPDATE `creature_template` SET `gossip_menu_id` = 8006078 WHERE `entry` = 3500317;
UPDATE `creature_template` SET `gossip_menu_id` = 8006097 WHERE `entry` = 3500318;
UPDATE `creature_template` SET `gossip_menu_id` = 8006116 WHERE `entry` = 3500320;
UPDATE `creature_template` SET `gossip_menu_id` = 8006017 WHERE `entry` = 3500333;
UPDATE `creature_template` SET `gossip_menu_id` = 8006060 WHERE `entry` = 3500335;
UPDATE `creature_template` SET `gossip_menu_id` = 8006124 WHERE `entry` = 3500339;
UPDATE `creature_template` SET `gossip_menu_id` = 10043 WHERE `entry` = 3500340;
UPDATE `creature_template` SET `gossip_menu_id` = 8006052 WHERE `entry` = 3500347;
UPDATE `creature_template` SET `gossip_menu_id` = 8006053 WHERE `entry` = 3500353;
UPDATE `creature_template` SET `gossip_menu_id` = 8006068 WHERE `entry` = 3500359;
UPDATE `creature_template` SET `gossip_menu_id` = 8006055 WHERE `entry` = 3500362;
UPDATE `creature_template` SET `gossip_menu_id` = 8006076 WHERE `entry` = 3500376;
UPDATE `creature_template` SET `gossip_menu_id` = 8006088 WHERE `entry` = 3500379;
UPDATE `creature_template` SET `gossip_menu_id` = 8006086 WHERE `entry` = 3500381;
UPDATE `creature_template` SET `gossip_menu_id` = 8006090 WHERE `entry` = 3500382;
UPDATE `creature_template` SET `gossip_menu_id` = 8006087 WHERE `entry` = 3500383;
UPDATE `creature_template` SET `gossip_menu_id` = 8006092 WHERE `entry` = 3500384;
UPDATE `creature_template` SET `gossip_menu_id` = 8006091 WHERE `entry` = 3500385;
UPDATE `creature_template` SET `gossip_menu_id` = 8006089 WHERE `entry` = 3500386;
UPDATE `creature_template` SET `gossip_menu_id` = 8006074 WHERE `entry` = 3500389;
UPDATE `creature_template` SET `gossip_menu_id` = 8006093 WHERE `entry` = 3500391;
UPDATE `creature_template` SET `gossip_menu_id` = 8006061 WHERE `entry` = 3500394;
UPDATE `creature_template` SET `gossip_menu_id` = 2189 WHERE `entry` = 3500396;
UPDATE `creature_template` SET `gossip_menu_id` = 8006075 WHERE `entry` = 3500411;
UPDATE `creature_template` SET `gossip_menu_id` = 8006041 WHERE `entry` = 3500415;
UPDATE `creature_template` SET `gossip_menu_id` = 8006066 WHERE `entry` = 3500418;
UPDATE `creature_template` SET `gossip_menu_id` = 8006062 WHERE `entry` = 3500420;
UPDATE `creature_template` SET `gossip_menu_id` = 8006063 WHERE `entry` = 3500421;
UPDATE `creature_template` SET `gossip_menu_id` = 8006065 WHERE `entry` = 3500429;
UPDATE `creature_template` SET `gossip_menu_id` = 8006069 WHERE `entry` = 3500446;
UPDATE `creature_template` SET `gossip_menu_id` = 8006070 WHERE `entry` = 3500447;
UPDATE `creature_template` SET `gossip_menu_id` = 8006073 WHERE `entry` = 3500465;
UPDATE `creature_template` SET `gossip_menu_id` = 8006082 WHERE `entry` = 3500478;
UPDATE `creature_template` SET `gossip_menu_id` = 10096 WHERE `entry` = 3500479;
UPDATE `creature_template` SET `gossip_menu_id` = 8006080 WHERE `entry` = 3500484;
UPDATE `creature_template` SET `gossip_menu_id` = 8006083 WHERE `entry` = 3500488;
UPDATE `creature_template` SET `gossip_menu_id` = 8006104 WHERE `entry` = 3500503;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500505;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500506;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500507;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500508;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500510;
UPDATE `creature_template` SET `gossip_menu_id` = 8006096 WHERE `entry` = 3500511;
UPDATE `creature_template` SET `gossip_menu_id` = 8006094 WHERE `entry` = 3500512;
UPDATE `creature_template` SET `gossip_menu_id` = 8006095 WHERE `entry` = 3500513;
UPDATE `creature_template` SET `gossip_menu_id` = 8006099 WHERE `entry` = 3500516;
UPDATE `creature_template` SET `gossip_menu_id` = 8006101 WHERE `entry` = 3500523;
UPDATE `creature_template` SET `gossip_menu_id` = 8006030 WHERE `entry` = 3500527;
UPDATE `creature_template` SET `gossip_menu_id` = 8006114 WHERE `entry` = 3500531;
UPDATE `creature_template` SET `gossip_menu_id` = 8006111 WHERE `entry` = 3500532;
UPDATE `creature_template` SET `gossip_menu_id` = 8006110 WHERE `entry` = 3500533;
UPDATE `creature_template` SET `gossip_menu_id` = 8006112 WHERE `entry` = 3500539;
UPDATE `creature_template` SET `gossip_menu_id` = 8006115 WHERE `entry` = 3500549;
UPDATE `creature_template` SET `gossip_menu_id` = 8006118 WHERE `entry` = 3500567;
UPDATE `creature_template` SET `gossip_menu_id` = 8006038 WHERE `entry` = 3500571;
