-- ============================================================================================
-- Timbermaw Hold (map 819) -- 3/3: quests, camp NPCs, encounters, texts, trash AI
--
-- Source: tortoise-wow (Turtle 1.18.1 restoration), map 819 data as of 2026-10-27, converted by
-- Custom/TimbermawHold/tortoise_port/gen_timbermaw_sql.py -- regenerate, do not hand-edit.
--
-- Quests 700769-700783 are Turtle's raid quests (DungeonQuest band). Narkogg, Kathor and Nathok stand
-- at the Timbermaw camp on map 750 next to Gorn One Eye. Turtle's chains through Swamp of Sorrows,
-- Zul'Gurub and Moonwhisper Coast were not ported; their raid steps were re-homed to the camp.
-- The previous quests 700760-700768 are retired: no longer offered, still turn-in-able at the
-- Timbermaw Gatekeeper so nobody is left holding a dead quest.
-- ============================================================================================

REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `StartItem`, `Flags`, `RewardItem1`, `RewardAmount1`, `RewardItem2`, `RewardAmount2`, `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`, `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`, `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`, `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`, `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`, `RewardChoiceItemID6`, `RewardChoiceItemQuantity6`, `RewardFactionID1`, `RewardFactionOverride1`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGo2`, `RequiredNpcOrGoCount1`, `RequiredNpcOrGoCount2`, `RequiredItemId1`, `RequiredItemId2`, `RequiredItemId3`, `RequiredItemId4`, `RequiredItemCount1`, `RequiredItemCount2`, `RequiredItemCount3`, `RequiredItemCount4`, `ObjectiveText1`, `VerifiedBuild`) VALUES
(700769, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576, 50000, 0, 'Proof of Conviction', 'Present Narkogg the Dark at the Timbermaw camp before the hold with proof of slaying Karrsh the Sentinel in Timbermaw Hold.', 'You stand before Narkogg the Dark, speaker of the remaining Timbermaw of Ursolan. My brethren and I are splintered and on the brink of extinction. Darkness has befallen Timbermaw Hold and we are powerless in front of the wave of corruption seeping out of its gates. If we ever wish to rid it off its muck, then allies are what we desperately need. Will you and your kind be the ones to aid us in our endeavour? For that I need proof.$B$BEnter the tunnels of our old home and break through the gateway. Slay Karrsh the Sentinel; once a proud defender, now a maddened savage seeking nothing but blood. His rampage needs to be stopped.', '', 0, 0, 0, 0, 410325, 0, 0, 0, 1, 0, 0, 0, '', 0),
(700770, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576, 100000, 0, 'The Corruption of Timbermaw Hold', 'Collect Withermaw Totems from Withermaw Shaman inside Timbermaw Hold and bring them to Narkogg the Dark at the Timbermaw camp before the hold.', 'Our vigil over the Wilds was always ancient, but ever since the second invasion of the Burning Legion, a foul sickness has been germinating within our most hallowed sanctum. Our tribesmen succumbed to the vile influence, one after another. Now only we remain and it falls to us to liberate Timbermaw Hold from the clutches of evil. Before we can cleanse our home for good, we first need to understand what we are dealing with. Studying it inside the caverns is far too dangerous, so we need a substitute instead.$B$BReturn to Timbermaw Hold and gather the totems of the misguided shaman, with them we can find a way to battle the ailment plaguing my people.', '', 0, 0, 0, 0, 410326, 0, 0, 0, 5, 0, 0, 0, '', 0),
(700771, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576, 100000, 0, 'Ancient Furbolg Remedies', 'Narkogg the Dark at the Timbermaw camp before the hold requires specific materials for the purification salve. Bring them to him.', 'Over the millennia that we have lived on Kalimdor, my people developed countless concoctions and salves for medicinal and spiritual healing. However, to cleanse these wicked totems, a wholly new mixture has to be created.$B$BIn the lands blessed by the wilds, the place your kind calls Un''goro Crater, a beast by the name of Rotvine, laden with natural energies and powerful dew, resides. Rumor has it the river''s end in the northwest is its home. Bring me its dewladen heart.$B$BOn the southern shores of the Isle of Dread in Feralas you will find a primordial being, a sea giant from olden times. He held watch over the tides of the Veiled Sea, but has reached a point where his mind can''t discern between friend or foe anymore. Lay him to rest and deliver me his tongue.$B$BThe Vials of Purification lay with Tidelord Rrurgaz. Once a relic of the night elves on ancient  Kalimdor, it fell into the hands of the Shahraz naga who scheme on Alcaz Island, northeast of the shores of Dustwallow Marsh.', '', 0, 0, 0, 0, 410327, 410328, 410329, 0, 1, 1, 1, 0, '', 0),
(700772, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 410334, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576, 100000, 0, 'Unbridled Darkness', 'Retrieve Narkogg''s Medicine Pouch and the Putrid Flower from within Timbermaw Hold for Narkogg the Dark at the Timbermaw camp before the hold.', 'It seems I underestimated the Withermaw. Whatever has taken hold in these totems is not only of demonic origin. I fear what we have is not enough to break the curse put on them.$B$B$N, if we want to succeed, we need to venture into Timbermaw Hold once more. Deep within Timbermaw Village, the Grotto of Dreams lies. Formerly used by our spiritualists for communion with the Emerald Dream, it now houses a sinister miasma. When we fled our old home, I abandonded my medicine pouch there. I need the implement found within to conjure a more fitting spell. Furthermore, a sample of the defilement found within Timbermaw Hold. Mixed into the salve, it will act as an antidote to the malediction inside the totems, if you will. Certainly you will find such a sample inside the many crevices found along the waterways inside.', '', 0, 0, 0, 0, 410330, 410331, 0, 0, 1, 1, 0, 0, '', 0),
(700773, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 576, 200000, 0, 'What Remains', 'Slay Ursol in Timbermaw Hold. Report to Narkogg the Dark at the Timbermaw camp before the hold afterwards.', '$N, your loyalty and determination to our cause knows no bounds. With remarkable bravery have you faced the twisted Withermaw and stopped their machinations. The strength and willpower you and your allies displayed is exactly why it is you that I will ask of the impossible.$B$BAs I explained to you before, Timbermaw Hold is a sacred site for all Furbolgs. It is where we venerate the remains of the Wild God Ursol, which we have guarded for millenia since his fall at the hands of the Burning Legion during the War of the Ancient. I was not present at his resting place when the Withermaw took over, yet I fear the body of the ancient guardian fell victim to the corruption.$B$BCourageous ally of ours, please return to Timbermaw Hold and see what has become of our great god. Should the foulness have taken control of his carcass, then... Gather your might and let him return to the Emerald Dream once more.', '', 4010007, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(700774, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 0, 0, 0, 0, 410271, 1, 410272, 1, 410273, 1, 0, 0, 0, 0, 0, 0, 576, 50000, 0, 'Hide of a Wild God', 'Bring the Hide of Ursol to Kathor the Brave at the Timbermaw camp.', 'The fetid hide of Ursol is all you could rescue of the fallen god''s carcass. Torn and ridden with maggots, you decide to bring it to the furbolg of Ursolan, so that they may cleanse the only remains of their progenitor god.', '', 0, 0, 0, 0, 410334, 410335, 0, 0, 1, 1, 0, 0, '', 0),
(700775, 2, -1, 128, 5640, 62, 0, 0, 400000, 410332, 8, 0, 0, 0, 0, 410274, 1, 410275, 1, 410276, 1, 0, 0, 0, 0, 0, 0, 576, 200000, 0, 'Nightmare''s End', 'Deliver the Pendant of Dreams to the Great Bear Spirit in Moonglade.', 'The demigod Ursol has been slain, the pendant in your hand acting as proof of your and your allies'' deed. Curious enough, there seems to be no trace of the Nightmare''s influence on the pristine jade stone you''ve found on the wild god''s body.$B$BLosing yourself in the stone''s hum, you see a bear''s silhouette in the woods of the tranquil Moonglade before you.', '', 0, 0, 0, 0, 410332, 0, 0, 0, 1, 0, 0, 0, '', 0),
(700776, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 0, 0, 410291, 1, 410292, 1, 410293, 1, 410294, 1, 0, 0, 0, 0, 0, 0, 0, 'Draenethyst Recovery', 'Enter Timbermaw Hold and retrieve the corrupted draenethyst. Bring them to Nathok at the Timbermaw camp if you are successful.', 'Whatever the bearfolk intend on accomplishing with the tainted draenethyst, we cannot let it happen. It shall not be misused for nefarious reasons, and as Draenei, it is our duty to ensure it stays that way.$B$B$N, we need your aid once more. Gather brave allies and storm the bearfolk''s sanctuary. Beware: It is very likely for them to conduct sinister rituals with our crystals, from which they mayhaps acquired unforeseen strength. Once you have found the whereabouts of the defiled crystals, punish the perpetrators and return with the remaining draenethyst back to the village. I will prepare a method to cleanse them of their impurities.', '', 0, 0, 0, 0, 410333, 0, 0, 0, 1, 0, 0, 0, '', 0),
(700777, 2, -1, 128, 5640, 62, 0, 0, 400000, 0, 8, 300311, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 'Loktanag the Pure', 'Vanquish Loktanag the Vile inside Timbermaw Hold and return to Nathok at the Timbermaw camp.', 'Perhaps you have felt it yourself or encountered one of its manifestations already, but there is an infestation running rampant in the woods of Kalimdor. It infects the flora and fauna, rendering them to madness, attacking friend and foe alike. Sinister whispers hush among the spirits of nature, rallying the defenders of balance against said corruption.$B$BOne of them is the noble Loktanag, the living embodiment of growth and adaptivity. They sensed a disturbance within the deep underbelly of Mount Hyjal, inside the sacred halls of Timbermaw Hold. Venturing far into the furbolg''s hallowed home, Loktanag tried to halt the spread of the miasma, yet it appears their power was not enough. Now the spirits mourn their rotting body, oozing toxic sludge and permeating the very corruption they wished to stop.$B$B$N, I ask you to lay Loktanag to rest. A noble creature such as them should return to the cycle once more. Balance must be restored.', '', 4010005, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', 0),
(700778, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410295, 1, 410301, 1, 410307, 1, 410313, 1, 410319, 1, 0, 0, 0, 0, 0, 'Guile of Nature', 'Bring Kathor the Brave a ritualistic headdress from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BThe ritualistic headdress grants a link to the wisdom of the natural spirits, enlightening those wearing it to make the right decisions to the betterment of all. Bring me the headdress and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410279, 300311, 0, 0, 1, 100, 0, 0, '', 0),
(700779, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410296, 1, 410302, 1, 410308, 1, 410314, 1, 410320, 1, 0, 0, 0, 0, 0, 'Burden of Nature', 'Bring Kathor the Brave a ritualistic mantle from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BThe ritualistic mantle is adorned with lanterns and heavy drapes hanging over the shoulders of our spiritualists. With them, they symbolically carry the burdens of our forefathers, as well as the uncertainties of the future. Bring me the mantle and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410280, 300311, 0, 0, 1, 100, 0, 0, '', 0),
(700780, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410297, 1, 410303, 1, 410309, 1, 410315, 1, 410321, 1, 0, 0, 0, 0, 0, 'Embrace of Nature', 'Bring Kathor the Brave a ritualistic tunic from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BThe ritualistic tunic wraps itself around its wearer like a mother''s warm cradle. Just as nature offers its plentiful bounties to those cherishing and preserving it. With it, the shaman becomes one with the breath of life whispering throughout nature''s forests. Bring me the tunic and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410281, 300311, 0, 0, 1, 100, 0, 0, '', 0),
(700781, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410298, 1, 410304, 1, 410310, 1, 410316, 1, 410322, 1, 0, 0, 0, 0, 0, 'Grasp of Nature', 'Bring Kathor the Brave a ritualistic gloves from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BLike the strength and resilience offered by the earth, so too do the ritualistic gloves offer nature''s protection to the wearer - much like a cooling coat of mud on a hot summer''s day or the comforting shelter of a cave during a roaring thunderstorm. Bring me the gloves and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410282, 300311, 0, 0, 1, 100, 0, 0, '', 0),
(700782, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410299, 1, 410305, 1, 410311, 1, 410317, 1, 410323, 1, 0, 0, 0, 0, 0, 'Vigor of Nature', 'Bring Kathor the Brave a ritualistic leggings from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BThe ritualistic leggings represent the lifeforce of nature''s verdure. Imbued with the wild''s blessings and boons, they allow our shamans to be one with the spirits and heed their calls. Bring me the leggings and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410283, 300311, 0, 0, 1, 100, 0, 0, '', 0),
(700783, 2, -1, 128, 5640, 62, 0, 0, 0, 0, 8, 0, 0, 0, 0, 410300, 1, 410306, 1, 410312, 1, 410318, 1, 410324, 1, 0, 0, 0, 0, 0, 'Path of Nature', 'Bring Kathor the Brave a ritualistic boots from within Timbermaw Hold as well as a myriad of materials.', 'For many years have we furbolgs revered the gods of nature, with the Twin Gods Ursol and Ursoc at the center of our worship. To honor their sacrifices to our world, the greatest shaman of our tribe wore a spiritual garment, spirited armor said to be in tune with the Wild Gods. Now they''re lost in the tunnels of Timbermaw, either in possession of the Withermaw or their corrupted fiends.$B$BThe ritualistic boots ground their wearer in our world, lending humility and modesty to the shaman''s mission of being an envoy of nature. Bring me a pair of boots and some materials, and I will fashion it anew so that it may aid you in your quest to liberate Timbermaw Hold.', '', 0, 0, 0, 0, 410284, 300311, 0, 0, 1, 100, 0, 0, '', 0);

DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 700769 AND 700799;
INSERT INTO `quest_template_addon` (`ID`, `MaxLevel`, `AllowableClasses`, `SourceSpellID`, `PrevQuestID`, `NextQuestID`, `ExclusiveGroup`, `BreadcrumbForQuestId`, `RewardMailTemplateID`, `RewardMailDelay`, `RequiredSkillID`, `RequiredSkillPoints`, `RequiredMinRepFaction`, `RequiredMaxRepFaction`, `RequiredMinRepValue`, `RequiredMaxRepValue`, `ProvidedItemCount`, `SpecialFlags`) VALUES
(700769, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700770, 0, 0, 0, 700769, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700771, 0, 0, 0, 700770, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700772, 0, 0, 0, 700771, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700773, 0, 0, 0, 700772, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700774, 0, 1103, 0, 700772, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700775, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700776, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700777, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700778, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700779, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700780, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700781, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700782, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(700783, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 700769 AND 700799;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(700769, 0, 0, 0, 0, 0, 0, 0, 0, 'You have returned, with Karrsh''s pendant. His death is regrettable and saddens me deeply. To see a beacon of resilience and strength rot away in such a short amount of time is terrible. Thank you for releasing him of his pain.', 0),
(700770, 0, 0, 0, 0, 0, 0, 0, 0, 'These totems are worse than I expected. The fumes they release are unbearable and simply touching them leaves burning marks upon my paws. I will have to seal them away before we can deal with them properly.', 0),
(700771, 0, 0, 0, 0, 0, 0, 0, 0, 'I am in awe at the power of these items. With the beast''s heart, we will break the foul barrier around the totems. Grammon''s tongue will let them speak true and the waters of purification will wash away all impurities.', 0),
(700772, 0, 0, 0, 0, 0, 0, 0, 0, 'What a hideous creation. Further proof that the life inside our great sanctum is rotting by the minute. Yet still, it serves a purpose. It shall pave the way for the Timbermaw to reclaim what has been torn from us by cruel malefactors. Now I can concoct a salve powerful enough to cleanse our sacred totems.$B$B$N, this humble coven expresses its gratitude towards you. Through your courage, we have made the first step in purifying Timbermaw Hold. Take this essence and use it on your delves into this den of evil. With enough of it, you may break the barrier inside and finally come to the root of it all.', 0),
(700773, 0, 0, 0, 0, 0, 0, 0, 0, 'In our ancient teachings, there is a legend that connects all furbolg tribes. It speaks of our creation, as it is said the twin gods have brought us into the world as it was still young. As juvenile cubs they frolicked through the untouched wilds of Kalimdor, rolling around in the dewladen grass of the early mornings. Laughter filled the air and their unbound energy floated all around them. Bursting with their power, the droplets of the wet grass fell onto the roots of gigantic trees, seeping through the bark and becoming one with the land. Over time, these droplets grew and took the semblance of the young ursine gods.$B$BTo us furbolgs there is nothing more important than aiding our progenitors in protecting the wild. Seeing Ursol die for a second time fills my heart with anguish and pain, a being as noble as him did not deserve this fate. $N, the Timbermaw are forever in your debt. Please take this powerful salve and cleanse the remaining corruption in Timbermaw Hold.', 0),
(700774, 0, 0, 0, 0, 0, 0, 0, 0, 'For your acts for furbolgkind, you shall be rewarded honorably: A piece of armor to your liking handcrafted with the cleansed hide, so that you may walk the wilds under Ursol''s blessing, continuing his legacy in fighting for the world he loved so much. Your presence here will remain welcoming in our retreat, as long as you remain true to our cause. Tread safely, $N.', 0),
(700775, 0, 0, 0, 0, 0, 0, 0, 0, '<Presenting the honorable spirit with the pendant, a shiver of awe travels down your spine. Silence falls over Moonglade and your surroundings dim as your focus on the ursine figure before you grows stronger. In that moment, a familiar voice rings inside your head:$B$BThank you for saving my brother. The elders of the wild offer you this in return.$B$BAt the paws of the great spirit lay trinkets, presumingly the reward for releasing Ursol from his pain. Choose wisely.>', 0),
(700776, 0, 0, 0, 0, 0, 0, 0, 0, 'The horned fiend; this satyr Selenaxx, you say? He absorbed the energy from the geode and infused his body with it, becoming one with the draenethyst?! To witness such blasphemy even in this new world. $C, the power of draenethyst is deeply alluring and requires immense willpower to not succumb to once tapped into its pulsing energy. There are... stories of Draenei falling victim to their draenethyst addiction and eventually crystalizing, ultimately becoming draenethyst themselves. Thus they return to Draenor and enter the cycle of its lifeblood.$B$BFor now, I will have to prepare the cleansing ritual for the geode shards you brought. It will take time and effort, but I and moreover the Moro''gai are deeply indebted to you. Your continued support to our tribe''s survival shall not go unrewarded. Please choose one of these bracelets, so that they may protect you against the evils yet to come.', 0),
(700777, 0, 0, 0, 0, 0, 0, 0, 0, 'A harrowed deed has been done. Loktanag''s body will decompose, become one with the earth again. I know what you have done lies heavy on our hearts, but it was necessary. With time, they will emerge again and foster the growth of nature once more.', 0),
(700778, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0),
(700779, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0),
(700780, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0),
(700781, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0),
(700782, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0),
(700783, 0, 0, 0, 0, 0, 0, 0, 0, 'There you have it, friend. Can you feel the spiritual energy coursing through? Those inexperienced will tremble at its might. So please, make good use of it against the foes of darkness.', 0);

DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 700769 AND 700799;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(700769, 0, 0, 'It may not have been long since we escaped Timbermaw Hold, but the horrors inside evolve with rapid speed. Who knows what abhorrent creatures you will face inside?', 0),
(700770, 0, 0, 'Unforeseen strength gathered within the Withermaw; their newfound power being too much for their bodies, causing them to tear apart.', 0),
(700771, 0, 0, 'My seal will not hold for long, $N. Please hasten your efforts.', 0),
(700772, 0, 0, 'Timbermaw Village will be heavily guarded. Be best prepared, for the Withermaw have abandoned all morality.', 0),
(700773, 0, 0, '<Narkogg is stuck in a praying position. Through the rough whispers of his maw you can deduce him singing a ritualistic song.>', 0),
(700774, 0, 0, 'Is this what they have done to our great god? Rotted him from the inside out, defiling his magnificent pelt and body? I dare not think about the agony he must''ve endured during his torment. A relief to hear you have dealt with the traitors and have punished them justly.$B$BThe pelt of Ursol may be tainted, but with the purification salve Narkogg is brewing, we can cleanse it from the impurities. Bring it to me, and it shall be done.', 0),
(700775, 0, 0, '<The great spirit looks at you with a venerable gaze.>', 0),
(700776, 0, 0, 'We know little about the bearfolk, they kept to themselves most of the time. For what reason we can only speculate. Was it always their goal to conspire against the Moro''gai? Is the Draenethyst''s power really all they are after?', 0),
(700777, 0, 0, 'I cannot tell what lies before you on your journey inside Timbermaw Hold. The spirits do not dare speak of that place and deny me any wisdom.', 0),
(700778, 0, 0, 'Your contributions will be rewarded tenfold.', 0),
(700779, 0, 0, 'Your contributions will be rewarded tenfold.', 0),
(700780, 0, 0, 'Your contributions will be rewarded tenfold.', 0),
(700781, 0, 0, 'Your contributions will be rewarded tenfold.', 0),
(700782, 0, 0, 'Your contributions will be rewarded tenfold.', 0),
(700783, 0, 0, 'Your contributions will be rewarded tenfold.', 0);

DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 700760 AND 700799;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(4010201, 700769),
(4010201, 700770),
(4010201, 700771),
(4010201, 700772),
(4010201, 700773),
(4010203, 700776),
(4010203, 700777),
(4010202, 700778),
(4010202, 700779),
(4010202, 700780),
(4010202, 700781),
(4010202, 700782),
(4010202, 700783);

DELETE FROM `creature_questender` WHERE `quest` BETWEEN 700769 AND 700799;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(4010201, 700769),
(4010201, 700770),
(4010201, 700771),
(4010201, 700772),
(4010201, 700773),
(4010202, 700774),
(3711956, 700775),
(4010203, 700776),
(4010203, 700777),
(4010202, 700778),
(4010202, 700779),
(4010202, 700780),
(4010202, 700781),
(4010202, 700782),
(4010202, 700783);

DELETE FROM `dc_dungeon_quest_mapping` WHERE `quest_id` BETWEEN 700769 AND 700799;
INSERT INTO `dc_dungeon_quest_mapping` (`quest_id`, `dungeon_id`, `enabled`) VALUES
(700769, 819, 1),
(700770, 819, 1),
(700771, 819, 1),
(700772, 819, 1),
(700773, 819, 1),
(700774, 819, 1),
(700775, 819, 1),
(700776, 819, 1),
(700777, 819, 1),
(700778, 819, 1),
(700779, 819, 1),
(700780, 819, 1),
(700781, 819, 1),
(700782, 819, 1),
(700783, 819, 1);

-- camp quest givers on map 750

DELETE FROM `creature` WHERE `id` BETWEEN 4010201 AND 4010203 AND `guid` BETWEEN 16622020 AND 16622022;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(16622020, 4010201, 750, 0, 0, 1, 1, 1, 7027.8, -2110.5, 587.2, 3.14, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Timbermaw camp - Narkogg the Dark (Timbermaw Hold quests)'),
(16622021, 4010202, 750, 0, 0, 1, 1, 1, 7027, -2124.5, 586.9, 3.14, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Timbermaw camp - Kathor the Brave (Timbermaw Hold quests)'),
(16622022, 4010203, 750, 0, 0, 1, 1, 0, 7030.5, -2130, 587, 3.14, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Timbermaw camp - Nathok (Timbermaw Hold quests)');

-- encounters: 9 per difficulty, bit order == boss data id in timbermaw_hold.h

DELETE FROM `instance_encounters` WHERE `entry` IN (1100, 1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108, 1218, 1219, 1220, 1221, 1222, 1223, 1224, 1115, 1116, 1225, 1226, 1227, 1228, 1229, 1230, 1231, 1117, 1118);
INSERT INTO `instance_encounters` (`entry`, `creditType`, `creditEntry`, `lastEncounterDungeon`, `comment`) VALUES
(1100, 0, 4010001, 0, 'Karrsh the Sentinel'),
(1101, 0, 4010002, 0, 'Rotgrowl and Kodiak'),
(1102, 0, 4010005, 0, 'Loktanag the Vile'),
(1103, 0, 4010004, 0, 'Ormanos the Cracked'),
(1104, 0, 4010011, 0, 'Chieftain Partath'),
(1105, 0, 4010009, 0, 'Archdruid Kronn'),
(1106, 0, 4010006, 0, 'Selenaxx Foulheart'),
(1107, 0, 4010010, 0, 'Trioch the Devourer'),
(1108, 0, 4010007, 0, 'Ursol'),
(1218, 0, 4010001, 0, 'Karrsh the Sentinel (Heroic)'),
(1219, 0, 4010002, 0, 'Rotgrowl and Kodiak (Heroic)'),
(1220, 0, 4010005, 0, 'Loktanag the Vile (Heroic)'),
(1221, 0, 4010004, 0, 'Ormanos the Cracked (Heroic)'),
(1222, 0, 4010011, 0, 'Chieftain Partath (Heroic)'),
(1223, 0, 4010009, 0, 'Archdruid Kronn (Heroic)'),
(1224, 0, 4010006, 0, 'Selenaxx Foulheart (Heroic)'),
(1115, 0, 4010010, 0, 'Trioch the Devourer (Heroic)'),
(1116, 0, 4010007, 0, 'Ursol (Heroic)'),
(1225, 0, 4010001, 0, 'Karrsh the Sentinel (Mythic)'),
(1226, 0, 4010002, 0, 'Rotgrowl and Kodiak (Mythic)'),
(1227, 0, 4010005, 0, 'Loktanag the Vile (Mythic)'),
(1228, 0, 4010004, 0, 'Ormanos the Cracked (Mythic)'),
(1229, 0, 4010011, 0, 'Chieftain Partath (Mythic)'),
(1230, 0, 4010009, 0, 'Archdruid Kronn (Mythic)'),
(1231, 0, 4010006, 0, 'Selenaxx Foulheart (Mythic)'),
(1117, 0, 4010010, 0, 'Trioch the Devourer (Mythic)'),
(1118, 0, 4010007, 0, 'Ursol (Mythic)');

-- creature_text (the C++ Talk() ids)

DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 4010001 AND 4010299;
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(4010001, 0, 0, 'None pass the Sentinel. The hold is closed to the living.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010001 group 0'),
(4010001, 1, 0, 'The brazier burns for Ursol. You will feed it.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010001 group 1'),
(4010001, 2, 0, 'Brothers! To the gate!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010001 group 2'),
(4010001, 3, 0, 'The... flame... gutters...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010001 group 3'),
(4010001, 4, 0, 'The Brazier of Corruption gutters and goes dark.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010001 group 4'),
(4010002, 0, 0, 'Kodiak! Fresh tracks. Bring them down!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010002 group 0'),
(4010002, 1, 0, 'Run, then. Kodiak loves a chase.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010002 group 1'),
(4010002, 2, 0, 'KODIAK! You will pay for that, flesh!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010002 group 2'),
(4010002, 3, 0, 'The hunt... is ended...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010002 group 3'),
(4010002, 4, 0, 'The Brazier of Defilement gutters and goes dark.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010002 group 4'),
(4010003, 0, 0, 'Kodiak roars in fury over Rotgrowl''s body!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010003 group 0'),
(4010004, 0, 0, 'Small... things... in my hall.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010004 group 0'),
(4010004, 1, 0, 'Ormanos cracks, and pieces of him tear free!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010004 group 1'),
(4010004, 2, 0, 'Crumble.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010004 group 2'),
(4010004, 3, 0, 'The stone... rests...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010004 group 3'),
(4010005, 0, 0, 'Rot takes all. Rot takes YOU.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010005 group 0'),
(4010005, 1, 0, 'Loktanag''s corruption spills out across the floor!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010005 group 1'),
(4010005, 2, 0, 'Into the soil with you.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010005 group 2'),
(4010005, 3, 0, 'The roots... wither...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010005 group 3'),
(4010006, 0, 0, 'The crystal sings for me, mortals. Can you hear it?', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010006 group 0'),
(4010006, 1, 0, 'The Corrupted Draenethyst Geode shields Selenaxx!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010006 group 1'),
(4010006, 2, 0, 'Servants of the Foulheart, to me!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010006 group 2'),
(4010006, 3, 0, 'Its song is... silent...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010006 group 3'),
(4010006, 4, 0, 'The Geode shatters and Selenaxx''s shield fails!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010006 group 4'),
(4010007, 0, 0, 'You walk into my dream... and you will never wake.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010007 group 0'),
(4010007, 1, 0, 'My sons! Defend your father!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010007 group 1'),
(4010007, 2, 0, 'The Nightmare is ETERNAL!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010007 group 2'),
(4010007, 3, 0, 'At last... the dream... is quiet...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010007 group 3'),
(4010007, 4, 0, 'The last brazier dies. The Barrier of Ursol fades, and something vast stirs above.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010007 group 4'),
(4010007, 5, 0, 'Enough! The Nightmare claims you all!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010007 group 5'),
(4010009, 0, 0, 'The dream showed me your coming. It showed me your end.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010009 group 0'),
(4010009, 1, 0, 'Shadowkeepers, rise from the dark!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010009 group 1'),
(4010009, 2, 0, 'Sleep, and do not wake.', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010009 group 2'),
(4010009, 3, 0, 'Ursol... forgive me...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010009 group 3'),
(4010009, 4, 0, 'The Brazier of Decay gutters and goes dark.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010009 group 4'),
(4010010, 0, 0, 'Trioch''s three heads turn toward you as one.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010010 group 0'),
(4010010, 1, 0, 'Trioch rears back, all three throats glowing!', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010010 group 1'),
(4010010, 3, 0, 'Trioch the Devourer collapses, its heads hissing into silence.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010010 group 3'),
(4010011, 0, 0, 'Intruders in my hold! I will crack your bones and suck the marrow!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010011 group 0'),
(4010011, 1, 0, 'Illuminators! Light the way to their deaths!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010011 group 1'),
(4010011, 2, 0, 'Hungry. Always so HUNGRY!', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010011 group 2'),
(4010011, 3, 0, 'The tribe... is... broken...', 14, 0, 100, 0, 0, 0, 0, 0, 'Timbermaw Hold - 4010011 group 3'),
(4010011, 4, 0, 'The Brazier of Putrification gutters and goes dark.', 41, 0, 100, 0, 0, 0, 0, 3, 'Timbermaw Hold - 4010011 group 4');

-- trash and add AI

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4010001 AND 4010299;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(4010012, 0, 0, 0, 0, 0, 100, 0, 2000, 2000, 6000, 6000, 0, 0, 218, 24099, 0, 9, 2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Totem of Corruption - Corruption pulse (Poison Bolt Volley)'),
(4010013, 0, 0, 0, 0, 0, 100, 0, 1000, 3000, 5000, 7000, 0, 0, 218, 34344, 0, 8832, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Shadowkeeper - Shadow Bolt'),
(4010014, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 12, 4010015, 4, 30000, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Warlock - Summon Foulheart Imp'),
(4010014, 0, 1, 0, 0, 0, 100, 0, 1000, 3000, 5000, 7000, 0, 0, 218, 34344, 0, 9203, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Foulheart Warlock - Shadow Bolt'),
(4010015, 0, 0, 0, 0, 0, 100, 0, 1000, 2000, 3000, 4000, 0, 0, 218, 20801, 0, 5856, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Imp - Firebolt'),
(4010101, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 8000, 12000, 0, 0, 11, 15284, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Enraged Withermaw - Cleave'),
(4010101, 0, 1, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Enraged Withermaw - Enrage at 30%'),
(4010102, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 7000, 10000, 0, 0, 218, 34344, 0, 6950, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Defiler - Shadow Bolt'),
(4010102, 0, 1, 0, 0, 0, 100, 0, 6000, 9000, 14000, 18000, 0, 0, 218, 15654, 0, 1011, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Defiler - Shadow Word: Pain'),
(4010103, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 7000, 10000, 0, 0, 218, 15801, 0, 8826, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Shaman - Lightning Bolt'),
(4010103, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 14000, 18000, 0, 0, 218, 15501, 0, 5617, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Shaman - Earth Shock'),
(4010103, 0, 2, 0, 14, 0, 100, 0, 400000, 40, 10000, 14000, 0, 0, 218, 15982, 0, 48000, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Shaman - Healing Wave'),
(4010104, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 14000, 20000, 0, 0, 11, 12024, 0, 0, 0, 0, 0, 5, 30, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Pathfinder - Net'),
(4010104, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 12000, 16000, 0, 0, 218, 16509, 0, 1143, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Pathfinder - Rend'),
(4010105, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 12, 4010012, 4, 30000, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Totemic - Summon Totem of Corruption'),
(4010105, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 12000, 16000, 0, 0, 218, 15501, 0, 6295, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Totemic - Earth Shock'),
(4010106, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 9000, 13000, 0, 0, 218, 13298, 0, 36, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vile Skitterer - Poison'),
(4010106, 0, 1, 0, 0, 0, 100, 0, 6000, 10000, 16000, 22000, 0, 0, 11, 12023, 0, 0, 0, 0, 0, 5, 20, 1, 0, 0, 0, 0, 0, 0, 'Vile Skitterer - Web'),
(4010107, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 10000, 14000, 0, 0, 11, 32736, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Tracker - Mortal Strike'),
(4010107, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 12024, 0, 0, 0, 0, 0, 5, 30, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Tracker - Net'),
(4010108, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 8000, 11000, 0, 0, 218, 20690, 0, 391, 2608, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Den Watcher - Moonfire'),
(4010108, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 18000, 24000, 0, 0, 218, 22415, 0, 0, 326, 0, 0, 5, 30, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Den Watcher - Entangling Roots'),
(4010109, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 12000, 16000, 0, 0, 218, 23931, 0, 2541, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Ursa - Thunderclap'),
(4010109, 0, 1, 0, 0, 0, 100, 0, 10000, 14000, 20000, 26000, 0, 0, 11, 15593, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Ursa - War Stomp'),
(4010110, 0, 0, 0, 0, 0, 100, 0, 3000, 5000, 6000, 8000, 0, 0, 218, 31608, 0, 1196, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Tainted Mass - Disease Cloud'),
(4010110, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 18000, 24000, 0, 0, 11, 7279, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Tainted Mass - Black Sludge'),
(4010111, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 8000, 12000, 0, 0, 218, 21067, 0, 3266, 362, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Corruption of Loktanag - Poison Bolt'),
(4010111, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 14000, 18000, 0, 0, 218, 16128, 0, 435, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Corruption of Loktanag - Infected Bite'),
(4010112, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 10000, 14000, 0, 0, 11, 5568, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Twisted Rumbler - Trample'),
(4010112, 0, 1, 0, 0, 0, 100, 0, 9000, 13000, 18000, 24000, 0, 0, 11, 15593, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Twisted Rumbler - War Stomp'),
(4010113, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 7000, 10000, 0, 0, 218, 34344, 0, 2088, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Foulheart Deceiver - Shadow Bolt'),
(4010113, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 20000, 26000, 0, 0, 11, 22884, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Deceiver - Psychic Scream'),
(4010114, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 9000, 13000, 0, 0, 218, 15583, 0, 334, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Satyr - Rupture'),
(4010114, 0, 1, 0, 0, 0, 100, 0, 5000, 8000, 7000, 11000, 0, 0, 11, 15582, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Satyr - Backstab'),
(4010115, 0, 0, 0, 25, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 8822, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Trickster - Stealth on reset'),
(4010115, 0, 1, 0, 0, 0, 100, 0, 4000, 7000, 14000, 20000, 0, 0, 11, 21060, 0, 0, 0, 0, 0, 5, 10, 1, 0, 0, 0, 0, 0, 0, 'Foulheart Trickster - Blind'),
(4010115, 0, 2, 0, 0, 0, 100, 0, 2000, 5000, 6000, 9000, 0, 0, 11, 15582, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Foulheart Trickster - Backstab'),
(4010116, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 7000, 10000, 0, 0, 218, 15242, 0, 2505, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Foulheart Hellcaller - Fireball'),
(4010116, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 18000, 24000, 0, 0, 218, 19717, 0, 334, 0, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Foulheart Hellcaller - Rain of Fire'),
(4010117, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 8000, 12000, 0, 0, 218, 27556, 0, 2384, 476, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Son of Ursol - Rake'),
(4010117, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 14000, 18000, 0, 0, 11, 5568, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Son of Ursol - Trample'),
(4010118, 0, 0, 0, 14, 0, 100, 0, 500000, 40, 9000, 13000, 0, 0, 218, 22883, 0, 60000, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Withermaw Illuminator - Heal'),
(4010118, 0, 1, 0, 0, 0, 100, 0, 3000, 5000, 9000, 12000, 0, 0, 218, 20690, 0, 963, 6423, 0, 0, 5, 40, 1, 0, 0, 0, 0, 0, 0, 'Withermaw Illuminator - Moonfire');
