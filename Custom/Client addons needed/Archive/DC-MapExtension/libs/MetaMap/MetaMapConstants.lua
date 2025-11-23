
local cLocale = strsub(GetLocale(), 1, 2);
if(cLocale == "de" or cLocale == "fr" or cLocale == "es" or cLocale == "ru") then
	MetaMap_Locale = strsub(GetLocale(), 1, 2);
else
	MetaMap_Locale = "en";
end

METAMAP_WLK_INFO = "Northrend Dungeon"; --WotLK Dungeon info: needs localization

MetaMap_Colors = {}
MetaMap_Colors[0] = {r = 1.0, g = 0.82, b = 0.0}
MetaMap_Colors[1] = {r = 0.55, g = 0.46, b = 0.04}
MetaMap_Colors[2] = {r = 1.0, g = 0.0, b = 0.0}
MetaMap_Colors[3] = {r = 0.56, g = 0.0, b = 0.0}
MetaMap_Colors[4] = {r = 0.0, g = 1.0, b = 0.0}
MetaMap_Colors[5] = {r = 0.0, g = 0.39, b = 0.05}
MetaMap_Colors[6] = {r = 0.42, g = 0.47, b = 0.87}
MetaMap_Colors[7] = {r = 0.25, g = 0.35, b = 0.66}
MetaMap_Colors[8] = {r = 1.0, g = 1.0, b = 1.0}
MetaMap_Colors[9] = {r = 0.65, g = 0.65, b = 0.65}

MetaMap_MapScale = {};
MetaMap_MapScale.cityscale    = {};
MetaMap_MapScale.cityscale[0] = 1.565;
MetaMap_MapScale.cityscale[1] = 1.687;
MetaMap_MapScale.cityscale[2] = 1.882;
MetaMap_MapScale.cityscale[3] = 2.210;
MetaMap_MapScale.cityscale[4] = 2.575;
MetaMap_MapScale.cityscale[5] = 2.651;
MetaMap_MapScale[1]    = {};
MetaMap_MapScale[1][0] = {xscale = 11016.6, yscale = 7399.9};
MetaMap_MapScale[1][1] = {xscale = 12897.3, yscale = 8638.1};
MetaMap_MapScale[1][2] = {xscale = 15478.8, yscale = 10368.0};
MetaMap_MapScale[1][3] = {xscale = 19321.8, yscale = 12992.7};
MetaMap_MapScale[1][4] = {xscale = 25650.4, yscale = 17253.2};
MetaMap_MapScale[1][5] = {xscale = 38787.7, yscale = 26032.1};
MetaMap_MapScale[2]    = {};
MetaMap_MapScale[2][0] = {xscale = 10448.3, yscale = 7072.7};
MetaMap_MapScale[2][1] = {xscale = 12160.5, yscale = 8197.8};
MetaMap_MapScale[2][2] = {xscale = 14703.1, yscale = 9825.0};
MetaMap_MapScale[2][3] = {xscale = 18568.7, yscale = 12472.2};
MetaMap_MapScale[2][4] = {xscale = 24390.3, yscale = 15628.5};
MetaMap_MapScale[2][5] = {xscale = 37012.2, yscale = 25130.6};
--Outlands scaling
MetaMap_MapScale[3]    = {};
MetaMap_MapScale[3][0] = {xscale = 10448.3, yscale = 7072.7};
MetaMap_MapScale[3][1] = {xscale = 12160.5, yscale = 8197.8};
MetaMap_MapScale[3][2] = {xscale = 14703.1, yscale = 9825.0};
MetaMap_MapScale[3][3] = {xscale = 18568.7, yscale = 12472.2};
MetaMap_MapScale[3][4] = {xscale = 24390.3, yscale = 15628.5};
MetaMap_MapScale[3][5] = {xscale = 37012.2, yscale = 25130.6};
--Northrend scaling (just copied from Outland values, so it may be wrong)
MetaMap_MapScale[4]    = {};
MetaMap_MapScale[4][0] = {xscale = 10448.3, yscale = 7072.7};
MetaMap_MapScale[4][1] = {xscale = 12160.5, yscale = 8197.8};
MetaMap_MapScale[4][2] = {xscale = 14703.1, yscale = 9825.0};
MetaMap_MapScale[4][3] = {xscale = 18568.7, yscale = 12472.2};
MetaMap_MapScale[4][4] = {xscale = 24390.3, yscale = 15628.5};
MetaMap_MapScale[4][5] = {xscale = 37012.2, yscale = 25130.6};

--- ZoneName matrix for English/German/French/Spanish exports/imports/data
MetaMap_ZoneTable = {
--- Kalimdor
	[1]  = {ztype = "SZ", en = "Ashenvale", de = "Eschental", fr = "Orneval", es = "Ashenvale", ru = "Ясеневый лес", llvl = 18, hlvl = 30, faction = "Contested", scale = 0.15670371525706, xoffset = 0.41757282062541, yoffset = 0.33126468682991},
	[2]  = {ztype = "SZ", en = "Azshara", de = "Azshara", fr = "Azshara", es = "Azshara", ru = "Азшара", llvl = 45, hlvl = 55, faction = "Contested", scale = 0.13779501505279, xoffset = 0.55282036918049, yoffset = 0.30400571307545},
	[3]  = {ztype = "SZ", en = "Darkshore", de = "Dunkelk\195\188ste", fr = "Sombrivage", es = "Darkshore", ru = "Темные берега", llvl = 10, hlvl = 20, faction = "Alliance", scale = 0.17799008894522, xoffset = 0.38383175154516, yoffset = 0.18206216123156},
	[4]  = {ztype = "SZ", en = "Darnassus", de = "Darnassus", fr = "Darnassus", es = "Darnassus", ru = "Дарнас", llvl = 0, hlvl = 0, faction = "Alliance", scale = 0.02876626176374, xoffset = 0.38392150175204, yoffset = 0.10441296545475},
	[5]  = {ztype = "SZ", en = "Desolace", de = "Desolace", fr = "D\195\169solace", es = "Desolace", ru = "Пустоши", llvl = 30, hlvl = 40, faction = "Contested", scale = 0.12219839120669, xoffset = 0.34873187115693, yoffset = 0.50331046935371},
	[6]  = {ztype = "SZ", en = "Durotar", de = "Durotar", fr = "Durotar", es = "Durotar", ru = "Дуротар", llvl = 1, hlvl = 10, faction = "Horde", scale = 0.14368294970080, xoffset = 0.51709782709100, yoffset = 0.44802818134926},
	[7]  = {ztype = "SZ", en = "Dustwallow Marsh", de = "D\195\188stermarschen", fr = "Mar\195\169cage d'\195\130prefange", es = "Dustwallow Marsh", ru = "Пылевые топи", llvl = 35, hlvl = 45, faction = "Contested", scale = 0.14266384095509, xoffset = 0.49026338351379, yoffset = 0.60461876174686},
	[8]  = {ztype = "SZ", en = "Felwood", de = "Teufelswald", fr = "Gangrebois", es = "Felwood", ru = "Оскверненный лес", llvl = 48, hlvl = 55, faction = "Contested", scale = 0.15625084006464, xoffset = 0.41995800144849, yoffset = 0.23097545880609},
	[9]  = {ztype = "SZ", en = "Feralas", de = "Feralas", fr = "F\195\169ralas", es = "Feralas", ru = "Фералас", llvl = 40, hlvl = 50, faction = "Contested", scale = 0.18885970960818, xoffset = 0.31589651244686, yoffset = 0.61820581746798},
	[10] = {ztype = "SZ", en = "Moonglade", de = "Mondlichtung", fr = "Reflet-de-Lune", es = "Moonglade", ru = "Лунная поляна", llvl = 1, hlvl = 60, faction = "Contested", scale = 0.06292695969921, xoffset = 0.50130287793373, yoffset = 0.17560823085517},
	[11] = {ztype = "SZ", en = "Mulgore", de = "Mulgore", fr = "Mulgore", es = "Mulgore", ru = "Мулгор", llvl = 1, hlvl = 10, faction = "Horde", scale = 0.13960673216274, xoffset = 0.40811854919226, yoffset = 0.53286226907346},
	[12] = {ztype = "SZ", en = "Orgrimmar", de = "Orgrimmar", fr = "Orgrimmar", es = "Orgrimmar", ru = "Оргриммар", llvl = 0, hlvl = 0, faction = "Horde", scale = 0.03811449638057, xoffset = 0.56378554142668, yoffset = 0.42905218646258},
	[13] = {ztype = "SZ", en = "Silithus", de = "Silithus", fr = "Silithus", es = "Silithus", ru = "Силитус", llvl = 55, hlvl = 60, faction = "Contested", scale = 0.09468465888932, xoffset = 0.39731975488374, yoffset = 0.76460608512626},
	[14] = {ztype = "SZ", en = "Stonetalon Mountains", de = "Steinkrallengebirge", fr = "Les Serres-Rocheuses", es = "Stonetalon Mountains", ru = "Когтистые горы", llvl = 15, hlvl = 27, faction = "Contested", scale = 0.13272833611061, xoffset = 0.37556627748617, yoffset = 0.40285135292988},
	[15] = {ztype = "SZ", en = "Tanaris", de = "Tanaris", fr = "Tanaris", es = "Tanaris", ru = "Танарис", llvl = 40, hlvl = 50, faction = "Contested", scale = 0.18750104661175, xoffset = 0.46971301480866, yoffset = 0.76120931364891},
	[16] = {ztype = "SZ", en = "Teldrassil", de = "Teldrassil", fr = "Teldrassil", es = "Teldrassil", ru = "Тельдрассил", llvl = 1, hlvl = 10, faction = "Alliance", scale = 0.13836131003639, xoffset = 0.36011098024729, yoffset = 0.03948322979210},
	[17] = {ztype = "SZ", en = "The Barrens", de = "Brachland", fr = "Les Tarides", es = "The Barrens", ru = "Степи", llvl = 10, hlvl = 25, faction = "Horde", scale = 0.27539211944292, xoffset = 0.39249347333450, yoffset = 0.45601063260257},
	[18] = {ztype = "SZ", en = "Thousand Needles", de = "Tausend Nadeln", fr = "Mille pointes", es = "Thousand Needles", ru = "Тысяча Игл", llvl = 25, hlvl = 35, faction = "Contested", scale = 0.11956582877920, xoffset = 0.47554411191734, yoffset = 0.68342356389650},
	[19] = {ztype = "SZ", en = "Thunder Bluff", de = "Donnerfels", fr = "Les Pitons du Tonnerre", es = "Thunder Bluff", ru = "Громовой Утес", llvl = 0, hlvl = 0, faction = "Horde", scale = 0.02836291430658, xoffset = 0.44972878210917, yoffset = 0.55638479002362},
	[20] = {ztype = "SZ", en = "Un'Goro Crater", de = "Krater von Un'Goro", fr = "Crat\195\168re d'Un'Goro", es = "Un'Goro Crater", ru = "Кратер Ун'Горо", llvl = 48, hlvl = 55, faction = "Contested", scale = 0.10054401185671, xoffset = 0.44927594451520, yoffset = 0.76494573629405},
	[21] = {ztype = "SZ", en = "Winterspring", de = "Winterquell", fr = "Berceau-de-l'Hiver", es = "Winterspring", ru = "Зимние Ключи", llvl = 55, hlvl = 60, faction = "Contested", scale = 0.19293573573141, xoffset = 0.47237382938446, yoffset = 0.17390990272233},
	[22] = {ztype = "SZ", en = "Eversong Woods", de = "Immersangwald", fr = "Bois des Chants \195\169ternels", es = "Eversong Woods", ru = "Леса Вечной Песни", llvl = 1, hlvl = 10, faction = "Horde", scale = 0.09517074521836, xoffset = 0.48982154167011, yoffset = 0.76846519986510},
	[23] = {ztype = "SZ", en = "Ghostlands", de = "Geisterlande", fr = "Les Terres fant\195\180mes", es = "Ghostlands", ru = "Призрачные земли", llvl = 10, hlvl = 20, faction = "Horde", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[24] = {ztype = "SZ", en = "Silvermoon City", de = "Silbermond", fr = "Lune-d'argent", es = "Silvermoon City", ru = "Луносвет", llvl = 0, hlvl = 0, faction = "Horde", scale = 0.02727719546939, xoffset = 0.42973999245660, yoffset = 0.23815358517831},
--- Eastern Kingdoms
	[30] = {ztype = "SZ", en = "Alterac Mountains", de = "Alteracgebirge", fr = "Montagnes d'Alterac", es = "Alterac Mountains", ru = "Альтеракские горы", llvl = 30, hlvl = 40, faction = "Contested", scale = 0.07954563533736, xoffset = 0.43229874660542, yoffset = 0.25425926375262},
	[31] = {ztype = "SZ", en = "Arathi Highlands", de = "Arathihochland", fr = "Hautes-terres d'Arathi", es = "Arathi Highlands", ru = "Нагорье Арати", llvl = 30, hlvl = 40, faction = "Contested", scale = 0.10227310921644, xoffset = 0.47916793249546, yoffset = 0.32386170078419},
	[32] = {ztype = "SZ", en = "Badlands", de = "\195\150dland", fr = "Terres ingrates", es = "Badlands", ru = "Бесплодные земли", llvl = 35, hlvl = 45, faction = "Contested", scale = 0.07066771883566, xoffset = 0.51361415033147, yoffset = 0.56915717993261},
	[33] = {ztype = "SZ", en = "Blasted Lands", de = "Verw\195\188stete Lande", fr = "Terres foudroy\195\169es", es = "Badlands", ru = "Выжженные земли", llvl = 45, hlvl = 55, faction = "Contested", scale = 0.09517074521836, xoffset = 0.48982154167011, yoffset = 0.76846519986510},
	[34] = {ztype = "SZ", en = "Burning Steppes", de = "Brennende Steppe", fr = "Steppes ardentes", es = "Burning Steppes", ru = "Пылающие степи", llvl = 50, hlvl = 58, faction = "Contested", scale = 0.08321525646393, xoffset = 0.04621224670174, yoffset = 0.61780780524905},
	[35] = {ztype = "SZ", en = "Deadwind Pass", de = "Gebirgspass der Totenwinde", fr = "D\195\169fil\195\169 de Deuillevent", es = "Deadwind Pass", ru = "Перевал Мертвого Ветра", llvl = 55, hlvl = 60, faction = "Contested", scale = 0.07102298961531, xoffset = 0.47822105868635, yoffset = 0.73863555048516},
	[36] = {ztype = "SZ", en = "Dun Morogh", de = "Dun Morogh", fr = "Dun Morogh", es = "Dun Morogh", ru = "Дун Морог", llvl = 1, hlvl = 10, faction = "Alliance", scale = 0.13991525534426, xoffset = 0.40335096278072, yoffset = 0.48339696712179},
	[37] = {ztype = "SZ", en = "Duskwood", de = "D\195\164mmerwald", fr = "Bois de la P\195\169nombre", es = "Duskwood", ru = "Сумеречный лес", llvl = 18, hlvl = 30, faction = "Contested", scale = 0.07670475476181, xoffset = 0.43087243362495, yoffset = 0.73224350550454},
	[38] = {ztype = "SZ", en = "Eastern Plaguelands", de = "\195\150stliche Pestl\195\164nder", fr = "Maleterres de l'est", es = "Eastern Plaguelands", ru = "Восточные Чумные земли", llvl = 53, hlvl = 60, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[39] = {ztype = "SZ", en = "Elwynn Forest", de = "Wald von Elwynn", fr = "For\195\170t d'Elwynn", es = "Elwynn Forest", ru = "Элвиннский лес", llvl = 1, hlvl = 10, faction = "Alliance", scale = 0.09860350595046, xoffset = 0.41092682316676, yoffset = 0.65651531970162},
	[40] = {ztype = "SZ", en = "Hillsbrad Foothills", de = "Vorgebirge des H\195\188gellands", fr = "Contreforts de Hautebrande", es = "Hillsbrad Foothills", ru = "Предгорья Хилсбрада", llvl = 20, hlvl = 30, faction = "Contested", scale = 0.09090931690055, xoffset = 0.42424361247460, yoffset = 0.30113436864162},
	[41] = {ztype = "SZ", en = "Ironforge", de = "Eisenschmiede", fr = "Forgefer", es = "Ironforge", ru = "Стальгорн", llvl = 0, hlvl = 0, faction = "Alliance", scale = 0.02248317426784, xoffset = 0.47481923366335, yoffset = 0.51289242617182},
	[42] = {ztype = "SZ", en = "Loch Modan", de = "Loch Modan", fr = "Loch Modan", es = "Loch Modan", ru = "Лок Модан", llvl = 10, hlvl = 20, faction = "Alliance", scale = 0.07839152145224, xoffset = 0.51118749188138, yoffset = 0.50940913489577},
	[43] = {ztype = "SZ", en = "Redridge Mountains", de = "Rotkammgebirge", fr = "Les Carmines", es = "Redridge Mountains", ru = "Красногорье", llvl = 15, hlvl = 25, faction = "Contested", scale = 0.06170112311456, xoffset = 0.49917278340928, yoffset = 0.68359285304999},
	[44] = {ztype = "SZ", en = "Searing Gorge", de = "Sengende Schlucht", fr = "Gorge des Vents br\195\187lants", es = "Searing Gorge", ru = "Тлеющее ущелье", llvl = 43, hlvl = 50, faction = "Contested", scale = 0.06338794005823, xoffset = 0.46372051266487, yoffset = 0.57812379382509},
	[45] = {ztype = "SZ", en = "Silverpine Forest", de = "Silberwald", fr = "For\195\170t des Pins argent\195\169s", es = "Silverpine Forest", ru = "Серебряный бор", llvl = 10, hlvl = 20, faction = "Horde", scale = 0.11931848806212, xoffset = 0.35653502290090, yoffset = 0.24715695496522},
	[46] = {ztype = "SZ", en = "Stormwind City", de = "Sturmwind", fr = "Hurlevent", es = "Stormwind City", ru = "Штормград", llvl = 0, hlvl = 0, faction = "Alliance", scale = 0.13819701270887, xoffset = 0.41531450060561, yoffset = 0.67097280492581},
	[47] = {ztype = "SZ", en = "Stranglethorn Vale", de = "Schlingendorntal", fr = "Vall\195\169e de Strangleronce", es = "Stranglethorn Vale", ru = "Тернистая долина", llvl = 30, hlvl = 45, faction = "Contested", scale = 0.18128603034401, xoffset = 0.39145470225916, yoffset = 0.79412224886668},
	[48] = {ztype = "SZ", en = "Swamp of Sorrows", de = "S\195\188mpfe des Elends", fr = "Marais des Chagrins", es = "Swamp of Sorrows", ru = "Болото Печали", llvl = 35, hlvl = 45, faction = "Contested", scale = 0.06516347991404, xoffset = 0.51769795272070, yoffset = 0.72815974701615},
	[49] = {ztype = "SZ", en = "The Hinterlands", de = "Hinterland", fr = "Les Hinterlands", es = "The Hinterlands", ru = "Внутренние земли", llvl = 40, hlvl = 50, faction = "Contested", scale = 0.10937523495111, xoffset = 0.49929119700867, yoffset = 0.25567971676068},
	[50] = {ztype = "SZ", en = "Tirisfal Glades", de = "Tirisfal", fr = "Clairi\195\168res de Tirisfal", es = "Tirisfal Glades", ru = "Тирисфальские леса", llvl = 1, hlvl = 10, faction = "Horde", scale = 0.12837403412087, xoffset = 0.36837217317549, yoffset = 0.15464954319582},
	[51] = {ztype = "SZ", en = "Undercity", de = "Unterstadt", fr = "Fossoyeuse", es = "Undercity", ru = "Подгород", llvl = 0, hlvl = 0, faction = "Horde", scale = 0.02727719546939, xoffset = 0.42973999245660, yoffset = 0.23815358517831},
	[52] = {ztype = "SZ", en = "Western Plaguelands", de = "Westliche Pestl\195\164nder", fr = "Maleterres de l'ouest", es = "Western Plaguelands", ru = "Западные Чумные земли", llvl = 51, hlvl = 58, faction = "Contested", scale = 0.12215946583965, xoffset = 0.44270955019641, yoffset = 0.17471356786018},
	[53] = {ztype = "SZ", en = "Westfall", de = "Westfall", fr = "Marche de l'Ouest", es = "Westfall", ru = "Западный Край", llvl = 10, hlvl = 20, faction = "Alliance", scale = 0.09943208435841, xoffset = 0.36884571674582, yoffset = 0.71874918595783},
	[54] = {ztype = "SZ", en = "Wetlands", de = "Sumpfland", fr = "Les Paluns", es = "Wetlands", ru = "Болотина", llvl = 20, hlvl = 30, faction = "Contested", scale = 0.11745423014662, xoffset = 0.46561438951659, yoffset = 0.40971063365152},
	[55] = {ztype = "SZ", en = "Azuremyst Isle", de = "Azurmythosinsel", fr = "Ile de Brume-azur", es = "Azuremyst Isle", ru = "Остров Лазурной Дымки", llvl = 1, hlvl = 10, faction = "Alliance", scale = 0.09860350595046, xoffset = 0.41092682316676, yoffset = 0.65651531970162},
	[56] = {ztype = "SZ", en = "Bloodmyst Isle", de = "Blutmythosinsel", fr = "Ile de Brume-sang", es = "Bloodmyst Isle", ru = "Остров Кровавой Дымки", llvl = 10, hlvl = 20, faction = "Alliance", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[57] = {ztype = "SZ", en = "The Exodar", de = "Die Exodar", fr = "L'Exodar", es = "The Exodar", ru = "Экзодар", llvl = 0, hlvl = 0, faction = "Alliance", scale = 0.02727719546939, xoffset = 0.42973999245660, yoffset = 0.23815358517831},
--- Outlands
	[60] = {ztype = "SZ", en = "Hellfire Peninsula", de = "H\195\182llenfeuerhalbinsel", fr = "P\195\169ninsule des Flammes infernales", es = "Hellfire Peninsula", ru = "Полуостров Адского Пламени", llvl = 58, hlvl = 63, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[61] = {ztype = "SZ", en = "Blade's Edge Mountains", de = "Schergrat", fr = "Les Tranchantes", es = "Blade's Edge Mountains", ru = "Острогорье", llvl = 65, hlvl = 68, faction = "Contested", scale = 0.09517074521836, xoffset = 0.48982154167011, yoffset = 0.76846519986510},
	[62] = {ztype = "SZ", en = "Nagrand", de = "Nagrand", fr = "Nagrand", es = "Nagrand", ru = "Награнд", llvl = 64, hlvl = 67, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[63] = {ztype = "SZ", en = "Netherstorm", de = "Nethersturm", fr = "Raz-de-N\195\169ant", es = "Netherstorm", ru = "Пустоверть", llvl = 67, hlvl = 70, faction = "Neutral", scale = 0.09468465888932, xoffset = 0.39731975488374, yoffset = 0.76460608512626},
	[64] = {ztype = "SZ", en = "Shadowmoon Valley", de = "Schattenmondtal", fr = "Vall\195\169e d'Ombrelune", es = "Shadowmoon Valley", ru = "Долина Призрачной Луны", llvl = 67, hlvl = 70, faction = "Contested", scale = 0.13779501505279, xoffset = 0.55282036918049, yoffset = 0.30400571307545},
	[65] = {ztype = "SZ", en = "Shattrath City", de = "Shattrath", fr = "Shattrath", es = "Shattrath City", ru = "Шаттрат", llvl = 0, hlvl = 0, faction = "Neutral", scale = 0.02836291430658, xoffset = 0.44972878210917, yoffset = 0.55638479002362},
	[66] = {ztype = "SZ", en = "Terokkar Forest", de = "W\195\164lder von Terokkar", fr = "For\195\170t de Terokkar", es = "Terokkar Forest", ru = "Лес Тероккар", llvl = 62, hlvl = 65, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[67] = {ztype = "SZ", en = "Zangarmarsh", de = "Zangarmarschen", fr = "Mar\195\169cage de Zangar", es = "Zangarmarsh", ru = "Зангартопь", llvl = 60, hlvl = 64, faction = "Contested", scale = 0.15670371525706, xoffset = 0.41757282062541, yoffset = 0.33126468682991},
--- BattleGrounds
	[70] = {ztype = "BG", mapid = "443", en = "Warsong Gulch", de = "Kriegshymnenschlucht", fr = "Goulet des Chanteguerres", es = "Garganta Grito de Guerra", ru = "Ущелье Песни Войны", llvl = 10, hlvl = 60, faction = "Contested", scale = 0.035, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
	[71] = {ztype = "BG", mapid = "401", en = "Alterac Valley", de = "Alteractal", fr = "Vall\195\169e d\226\128\153Alterac", es = "Valle de Alterac", ru = "Альтеракская долина", llvl = 51, hlvl = 60, faction = "Contested", scale = 0.13, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
	[72] = {ztype = "BG", mapid = "461", en = "Arathi Basin", de = "Arathibecken", fr = "Bassin d\226\128\153Arathi", es = "Cuenca de Arathi", ru = "Низина Арати", llvl = 20, hlvl = 60, faction = "Contested", scale = 0.045, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
	[73] = {ztype = "BG", mapid = "482", en = "Eye of the Storm", de = "Auge des Sturms", fr = "L’\197\147il du cyclone ", es = "Eye of the Storm", ru = "Око Бури", llvl = 61, hlvl = 69, faction = "Contested", scale = 0.045, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
	[74] = {ztype = "BG", mapid = "512", en = "Strand of the Ancients", de = "", fr = "", es = "", ru = "Остров Завоеваний", llvl = 71, hlvl = 80, faction = "Contested", scale = 0.045, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
	[75] = {ztype = "BG", mapid = "540", en = "Isle of Conquest", de = "", fr = "", es = "", ru = "Остров Завоеваний", llvl = 71, hlvl = 80, faction = "Contested", scale = 0.045, xoffset = 0.41757282062541, yoffset = 0.33126468682991, xscale = 12897.3, yscale = 8638.1},
--- Instances
	[80] = {ztype = "DN", en = "Blackfathom Deeps", de = "Die tiefschwarze Grotte", fr = "Profondeurs de Brassenoire", es = "Cavernas de Brazanegra", ru = "Непроглядная Пучина", Continent = 1, Location = 1,  LevelRange = "24-32", PlayerLimit = "10", infoline = METAMAP_BFD_INFO, texture = "BlackfathomDeeps"},
	[81] = {ztype = "DN", en = "Dire Maul", de = "D\195\188sterbruch", fr = "Hache-Tripes", es = "La Masacre", ru = "Забытый Город", Continent = 1, Location = 9,  LevelRange = "56-60", PlayerLimit = "5",  infoline = METAMAP_DMC_INFO, texture = "DireMaul"},
	[82] = {ztype = "DN", en = "Dire Maul East", de = "D\195\188sterbruch Ost", fr = "Hache-Tripes Est", es = "La Masacre Este", ru = "Забытый Город -восток", Continent = 1, Location = 9,  LevelRange = "56-60", PlayerLimit = "5",  infoline = METAMAP_DMC_INFO, texture = "DireMaulEast"},
	[83] = {ztype = "DN", en = "Dire Maul North", de = "D\195\188sterbruch Nord", fr = "Hache-Tripes Nord", es = "La Masacre Norte", ru = "Забытый Город -север", Continent = 1, Location = 9,  LevelRange = "56-60", PlayerLimit = "5",  infoline = METAMAP_DMC_INFO, texture = "DireMaulNorth"},
	[84] = {ztype = "DN", en = "Dire Maul West", de = "D\195\188sterbruch West", fr = "Hache-Tripes Ouest", es = "La Masacre Oeste", ru = "Забытый Город - запад", Continent = 1, Location = 9,  LevelRange = "56-60", PlayerLimit = "5",  infoline = METAMAP_DMC_INFO, texture = "DireMaulWest"},
	[85] = {ztype = "DN", en = "Maraudon", de = "Maraudon", fr = "Maraudon", es = "Maraudon", ru = "Мародон", Continent = 1, Location = 5,  LevelRange = "46-55", PlayerLimit = "10", infoline = METAMAP_MDN_INFO, texture = "Maraudon"},
	[86] = {ztype = "DN", en = "Onyxia's Lair", de = "Onyxias Hort", fr = "Repaire d\'Onyxia", es = "Onyxia's Lair", ru = "Логово Ониксии", Continent = 1, Location = 7,  LevelRange = "80", PlayerLimit = "25", infoline = METAMAP_ONL_INFO, texture = "OnyxiasLair"},
	[87] = {ztype = "DN", en = "Ragefire Chasm", de = "Der Flammenschlund", fr = "Gouffre de Ragefeu", es = "Sima Ignea", ru = "Огненная пропасть", Continent = 1, Location = 12, LevelRange = "13-15", PlayerLimit = "10", infoline = METAMAP_RFC_INFO, texture = "RagefireChasm"},
	[88] = {ztype = "DN", en = "Razorfen Downs", de = "H\195\188gel der Klingenhauer", fr = "Souilles de Tranchebauge", es = "Zah\195\186rda Rajacieno", ru = "Курганы Иглошкурых", Continent = 1, Location = 17, LevelRange = "33-40", PlayerLimit = "10", infoline = METAMAP_RFD_INFO, texture = "RazorfenDowns"},
	[89] = {ztype = "DN", en = "Razorfen Kraul", de = "Kral der Klingenhauer", fr = "Kraal de Tranchebauge", es = "Horado Rajacieno", ru = "Лабиринты Иглошкурых", Continent = 1, Location = 17, LevelRange = "25-30", PlayerLimit = "10", infoline = METAMAP_RFK_INFO, texture = "RazorfenKraul"},
	[90] = {ztype = "DN", en = "Wailing Caverns", de = "Die H\195\182hlen des Wehklagens", fr = "Cavernes des lamentations", es = "Cuevas de los Lamentos", ru = "Пещеры Стенаний", Continent = 1, Location = 17, LevelRange = "17-24", PlayerLimit = "10", infoline = METAMAP_TWC_INFO, texture = "WailingCaverns"},
	[91] = {ztype = "DN", en = "Zul'Farrak", de = "Zul'Farrak", fr = "Zul'Farrak", es = "Zul'Farrak", ru = "Зул'Фаррак", Continent = 1, Location = 15, LevelRange = "43-47", PlayerLimit = "10", infoline = METAMAP_ZFK_INFO, texture = "ZulFarrak"},
	[92] = {ztype = "DN", en = "Ahn'Qiraj", de = "Ahn'Qiraj", fr = "Ahn'Qiraj", es = "Ahn'Qiraj", ru = "Ан'Кираж", Continent = 1, Location = 13, LevelRange = "60+", PlayerLimit = "40", infoline = METAMAP_TAQ_INFO, texture = "TempleofAhnQiraj"},
	[93] = {ztype = "DN", en = "Ruins of Ahn'Qiraj", de = "Ruinen von Ahn'Qiraj", fr = "Ruines d'Ahn'Qiraj", es = "Ruinas de Ahn'Qiraj", ru = "Руины Ан'Киража", Continent = 1, Location = 13, LevelRange = "60+", PlayerLimit = "20", infoline = METAMAP_RAQ_INFO, texture = "RuinsofAhnQiraj"},
	[94] = {ztype = "DN", en = "Blackrock Depths", de = "Schwarzfelstiefen", fr = "Profondeurs de Rochenoire", es = "Blackrock Depths", ru = "Глубины Черной горы", Continent = 2, Location = 44, LevelRange = "52+", PlayerLimit = "5",  infoline = METAMAP_BRD_INFO, texture = "BlackrockDepths"},
	[95] = {ztype = "DN", en = "Blackrock Spire", de = "Untere Schwarzfelsspitze", fr = "Pic Rochenoire", es = "Blackrock Spire", ru = "Пик Черной горы", Continent = 2, Location = 44, LevelRange = "55+", PlayerLimit = "10", infoline = METAMAP_BRS_INFO, texture = "BlackrockSpireLower"},
	[96] = {ztype = "DN", en = "Blackrock Spire Upper", de = "Obere Schwarzfelsspitze", fr = "Pic Blackrock sup\195\169rieur", es = "Blackrock Spire Upper",ru = "Пик Черной горы - верх", Continent = 2, Location = 44, LevelRange = "58+", PlayerLimit = "10", infoline = METAMAP_BSU_INFO, texture = "BlackrockSpireUpper"},
	[97] = {ztype = "DN", en = "Blackwing Lair", de = "Pechschwingenhort", fr = "Repaire de l\'Aile noire", es = "Blackwing Lair", ru = "Логово Крыла Тьмы", Continent = 2, Location = 44, LevelRange = "60+", PlayerLimit = "40", infoline = METAMAP_BWL_INFO, texture = "BlackwingLair"},
	[98] = {ztype = "DN", en = "Gnomeregan", de = "Gnomeregan", fr = "Gnomeregan", es = "Gnomeregan", ru = "Гномреган", Continent = 2, Location = 36, LevelRange = "29-38", PlayerLimit = "10", infoline = METAMAP_GNM_INFO, texture = "Gnomeregan"},
	[99] = {ztype = "DN", en = "Molten Core", de = "Geschmolzener Kern", fr = "C\197\147ur du Magma", es = "N\195\186cleo Fundido", ru = "Огненные Недра", Continent = 2, Location = 44, LevelRange = "60+", PlayerLimit = "40", infoline = METAMAP_TMC_INFO, texture = "MoltenCore"},
	[100] = {ztype = "DN", en = "Scarlet Monastery", de = "Das scharlachrote Kloster", fr = "Monast\195\168re \195\169carlate", es = "Monasterio Escarlata", ru = "Монастырь Алого ордена", Continent = 2, Location = 50, LevelRange = "34-45", PlayerLimit = "10", infoline = METAMAP_TSM_INFO, texture = "ScarletMonastery"},
	[101] = {ztype = "DN", en = "Scholomance", de = "Scholomance", fr = "Scholomance", es = "Scholomance", ru = "Некроситет", Continent = 2, Location = 52, LevelRange = "56-60", PlayerLimit = "5",  infoline = METAMAP_SLM_INFO, texture = "Scholomance"},
	[102] = {ztype = "DN", en = "Shadowfang Keep", de = "Burg Schattenfang", fr = "Donjon d\'Ombrecroc", es = "Castillo de Colmillo Oscuro", ru = "Крепость Темного Клыка", Continent = 2, Location = 45, LevelRange = "22-30", PlayerLimit = "10", infoline = METAMAP_SFK_INFO, texture = "ShadowfangKeep"},
	[103] = {ztype = "DN", en = "Stratholme", de = "Stratholme", fr = "Stratholme", es = "Stratholme", ru = "Стратхольм", Continent = 2, Location = 38, LevelRange = "55-60", PlayerLimit = "5",  infoline = METAMAP_STR_INFO, texture = "Stratholme"},
	[104] = {ztype = "DN", en = "The Deadmines", de = "Die Todesminen", fr = "Les Mortemines", es = "Las Minas de la Muerte", ru = "Мертвые копи", Continent = 2, Location = 53, LevelRange = "17-26", PlayerLimit = "10", infoline = METAMAP_TDM_INFO, texture = "TheDeadmines"},
	[105] = {ztype = "DN", en = "The Stockade", de = "Das Verlies", fr = "La Prison", es = "Mazmorras de Ventormenta", ru = "Тюрьма", Continent = 2, Location = 46, LevelRange = "23-26", PlayerLimit = "10", infoline = METAMAP_TSK_INFO, texture = "TheStockades"},
	[106] = {ztype = "DN", en = "The Temple of Atal'Hakkar", de = "Der Tempel von Atal'Hakkar", fr = "Le temple d\'Atal\'Hakkar", es = "El Templo Hundido", ru = "Храм Атал'Хаккара", Continent = 2, Location = 48, LevelRange = "45-55", PlayerLimit = "10", infoline = METAMAP_TST_INFO, texture = "TheSunkenTemple"},
	[107] = {ztype = "DN", en = "Uldaman", de = "Uldaman", fr = "Uldaman", es = "Uldaman", ru = "Ульдаман", Continent = 2, Location = 32, LevelRange = "35-47", PlayerLimit = "10", infoline = METAMAP_ULD_INFO, texture = "Uldaman"},
	[108] = {ztype = "DN", en = "Zul'Gurub", de = "Zul'Gurub", fr = "Zul'Gurub", es = "Zul'Gurub", ru = "Зул'Гуруб", Continent = 2, Location = 47, LevelRange = "60+", PlayerLimit = "20", infoline = METAMAP_ZGB_INFO, texture = "ZulGurub"},
	-- [109] = {ztype = "DN", en = "Naxxramas", de = "Naxxramas", fr = "Naxxramas", es = "Naxxramas", Continent = 2, Location = 38, LevelRange = "60+", PlayerLimit = "40", infoline = METAMAP_NAX_INFO, texture = "Naxxramas"},
	[110] = {ztype = "DN", en = "The Blood Furnace", de = "Der Blutkessel", fr = "La Fournaise du sang", es = "The Blood Furnaces", ru = "Кузня Крови", Continent = 3, Location = 60, LevelRange = "61-63", PlayerLimit = "5",  infoline = METAMAP_HFC_INFO, texture = "BloodFurnaces"},
	[111] = {ztype = "DN", en = "The Shattered Halls", de = "Die zerschmetterten Hallen", fr = "Les Salles bris\195\169es", es = "The Shattered Halls", ru = "Разрушенные залы", Continent = 3, Location = 60, LevelRange = "70", PlayerLimit = "5",  infoline = METAMAP_HFC_INFO, texture = "ShatteredHalls"},
	[112] = {ztype = "DN", en = "The Underbog", de = "Der Tiefensumpf", fr = "La Basse-tourbi\195\168re", es = "The Underbog", ru = "Нижетопь", Continent = 3, Location = 67, LevelRange = "63-65", PlayerLimit = "5",  infoline = METAMAP_CFR_INFO, texture = "TheUnderbog"},
	[113] = {ztype = "DN", en = "The Steamvault", de = "Die Dampfkammer", fr = "Le Caveau de la vapeur", es = "The Steam Vault", ru = "Паровое подземелье", Continent = 3, Location = 67, LevelRange = "68-70", PlayerLimit = "5",  infoline = METAMAP_CFR_INFO, texture = "TheSteamvault"},
	[114] = {ztype = "DN", en = "The Slave Pens", de = "Die Sklavenunterk\195\188nfte", fr = "Les enclos aux esclaves", es = "The Slave Pens", ru = "Узилище", Continent = 3, Location = 67, LevelRange = "62-64", PlayerLimit = "5",  infoline = METAMAP_CFR_INFO, texture = "TheSlavePens"},
	[115] = {ztype = "DN", en = "Magtheridons Lair", de = "Magtheridons Kammer", fr = "Le repaire de Magtheridon", es = "Magtheridons Lair", ru = "Логово Магтеридона", Continent = 3, Location = 60, LevelRange = "70+", PlayerLimit = "25",  infoline = METAMAP_MAG_INFO, texture = "MagtheridonsLair"},
	[116] = {ztype = "DN", en = "Hellfire Ramparts", de = "H\195\182llenfeuerbollwerk", fr = "Remparts des Flammes infernales", es = "Hellfire Rampart", ru = "Бастионы Адского Пламени", Continent = 3, Location = 60, LevelRange = "60-62", PlayerLimit = "5",  infoline = METAMAP_HFC_INFO, texture = "HellfireRampart"},
	[117] = {ztype = "DN", en = "Mana-Tombs", de = "Managruft", fr = "Tombes-mana", es = "Mana Tombs", ru = "Гробницы Маны", Continent = 3, Location = 66, LevelRange = "64-66", PlayerLimit = "5",  infoline = METAMAP_AUC_INFO, texture = "ManaTombs"},
	[118] = {ztype = "DN", en = "Auchenai Crypts", de = "Auchenaikrypta", fr = "Cryptes Auchena\195\175", es = "Auchenai Crypts", ru = "Аукенайские гробницы", Continent = 3, Location = 66, LevelRange = "65-67", PlayerLimit = "5",  infoline = METAMAP_AUC_INFO, texture = "AuchenaiCrypts"},
	[119] = {ztype = "DN", en = "Sethekk Halls", de = "Sethekkhallen", fr = "Les salles des Sethekk", es = "Sethekk Halls", ru = "Сетеккские залы", Continent = 3, Location = 66, LevelRange = "67-69", PlayerLimit = "5",  infoline = METAMAP_AUC_INFO, texture = "SethekkHalls"},
	[120] = {ztype = "DN", en = "Shadow Labyrinth", de = "Schattenlabyrinth", fr = "Labyrinthe des ombres", es = "Shadow Labyrinth", ru = "Темный лабиринт", Continent = 3, Location = 66, LevelRange = "70", PlayerLimit = "5",  infoline = METAMAP_AUC_INFO, texture = "ShadowLabyrinth"},
	[121] = {ztype = "DN", en = "The Arcatraz", de = "Arkatraz", fr = "L'Arcatraz", es = "Arcatraz", ru = "Аркатрац", Continent = 3, Location = 63, LevelRange = "70", PlayerLimit = "5",  infoline = METAMAP_TTK_INFO, texture = "Arcatraz"},
	[122] = {ztype = "DN", en = "The Botanica", de = "Botanikum", fr = "La Botanica", es = "Botanica", ru = "Ботаника", Continent = 3, Location = 63, LevelRange = "70", PlayerLimit = "5",  infoline = METAMAP_TTK_INFO, texture = "Botanica"},
	[123] = {ztype = "DN", en = "The Mechanar", de = "Mechanar", fr = "Le Mechanar", es = "M\195\169chanar", ru = "Механар", Continent = 3, Location = 63, LevelRange = "69-70", PlayerLimit = "5",  infoline = METAMAP_TTK_INFO, texture = "Mechanar"},
	[124] = {ztype = "DN", en = "The Black Morass", de = "Der schwarze Morast", fr = "Le Noir Mar\195\169cage", es = "The Black Morass", ru = "Черные топи", Continent = 1, Location = 15, LevelRange = "70", PlayerLimit = "5",  infoline = METAMAP_COT_INFO, texture = "BlackMorass"},
	[125] = {ztype = "DN", en = "Old Hillsbrad Foothills", de = "Vorgebirge des Alten H\195\188gellands", fr = "Contreforts de Hautebrande d'antan", es = "Old Hillsbrad Foothills", ru = "Старые предгорья Хилсбрада", Continent = 1, Location = 15, LevelRange = "66-68", PlayerLimit = "5",  infoline = METAMAP_COT_INFO, texture = "OldHillsbrad"},
	[126] = {ztype = "DN", en = "Battle for Mount Hyjal", de = "Kampf um Mount Hyjal", fr = "La bataille pour le mont Hyjal", es = "Battle for Mount Hyjal", ru = "Прошлое Хиджала", Continent = 1, Location = 15, LevelRange = "70+", PlayerLimit = "25",  infoline = METAMAP_COT_INFO, texture = "MountHyjal"},
	[127] = {ztype = "DN", en = "Karazhan", de = "Karazhan", fr = "Karazhan", es = "Karazhan", ru = "Каражан", Continent = 2, Location = 35, LevelRange = "70+", PlayerLimit = "10",  infoline = METAMAP_KZN_INFO, texture = "Karazhan"},
	[128] = {ztype = "DN", en = "Gruul's Lair", de = "Gruuls Unterschlupf", fr = "Gruul's Lair", es = "Gruul's Lair", ru = "Логово Груула", Continent = 3, Location = 61, LevelRange = "70+", PlayerLimit = "25",  infoline = METAMAP_GRL_INFO, texture = "GruulsLair"},
	[129] = {ztype = "DN", en = "Serpentshrine Cavern", de = "H\195\182hle des Schlangenschreins", fr = "Serpentshrine Cavern", es = "Serpentshrine Cavern", ru = "Змеиное святилище", Continent = 3, Location = 67, LevelRange = "70+", PlayerLimit = "25",  infoline = METAMAP_CFR_INFO, texture = "Serpentshrine"},
	[130] = {ztype = "DN", en = "The Eye of Storms", de = "Auge des Sturms", fr = "The Eye of Storms", es = "The Eye of Storms", ru = "Крепость Бурь", Continent = 3, Location = 63, LevelRange = "70+", PlayerLimit = "25",  infoline = METAMAP_TTK_INFO, texture = "EyeOfTheStorm"},
	--WotLK Dungeons
	[131] = {ztype = "DNI", mapid = "523", en = "Utgarde Keep", de = "", fr = "", es = "", ru = "Крепость Утгард", Continent = 4, Location = 204, LevelRange = "70-72", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[132] = {ztype = "DNI", mapid = "533", en = "Azjol-Nerub", de = "", fr = "", es = "", ru = "Азжол-Неруб", Continent = 4, Location = 201, LevelRange = "72-74", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[133] = {ztype = "DNI", mapid = "522", en = "Ahn'kahet", de = "", fr = "", es = "", ru = "Ан'кахет", Continent = 4, Location = 201, LevelRange = "73-75", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[134] = {ztype = "DNI", mapid = "529", en = "Ulduar", de = "", fr = "", es = "", ru = "Ульдуар", Continent = 4, Location = 200, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[135] = {ztype = "DNI", mapid = "535", en = "Naxxramas", de = "", fr = "", es = "", ru = "Наксрамас", Continent = 4, Location = 200, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[136] = {ztype = "DNI", mapid = "520", en = "The Nexus", de = "", fr = "", es = "", ru = "Нексус", Continent = 4, Location = 200, LevelRange = "70+", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[137] = {ztype = "DNI", mapid = "604", en = "Icecrown Citadel", de = "", fr = "", es = "", ru = "Цитадель Ледяной Короны", Continent = 4, Location = 200, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[138] = {ztype = "DNI", mapid = "534", en = "Drak'Tharon Keep", de = "", fr = "", es = "", ru = "Крепость Драк'Тарон", Continent = 4, Location = 203, LevelRange = "74-76", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[139] = {ztype = "DNI", mapid = "531", en = "Obsidian Sanctum", de = "", fr = "", es = "", ru = "Обсидиановое святилище", Continent = 4, Location = 201, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[140] = {ztype = "DNI", mapid = "536", en = "The Violet Hold", de = "", fr = "", es = "", ru = "Аметистовая крепость", Continent = 4, Location = 210, LevelRange = "75-77", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[141] = {ztype = "DNI", mapid = "524", en = "Utgarde Pinnacle", de = "", fr = "", es = "", ru = "Вершина Утгард", Continent = 4, Location = 204, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[142] = {ztype = "DNI", mapid = "520", en = "Nexus", de = "", fr = "", es = "", ru = "Нексус", Continent = 4, Location = 202, LevelRange = "71-73", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[143] = {ztype = "DNI", mapid = "528", en = "Oculus", de = "", fr = "", es = "", ru = "Окулус", Continent = 4, Location = 202, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[144] = {ztype = "DNI", mapid = "527", en = "Eye of Eternity", de = "", fr = "", es = "", ru = "Око Вечности", Continent = 4, Location = 202, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[145] = {ztype = "DNI", mapid = "530", en = "Gundrak", de = "", fr = "", es = "", ru = "Гундрак", Continent = 4, Location = 207, LevelRange = "76-78", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[146] = {ztype = "DNI", mapid = "526", en = "Halls of Stone", de = "", fr = "", es = "", ru = "Чертоги Камня", Continent = 4, Location = 200, LevelRange = "77-79", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[147] = {ztype = "DNI", mapid = "525", en = "Halls of Lightning", de = "", fr = "", es = "", ru = "Чертоги Молний", Continent = 4, Location = 200, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[148] = {ztype = "DNI", mapid = "542", en = "Trial of the Champion", de = "", fr = "", es = "", ru = "Испытание чемпиона", Continent = 4, Location = 208, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[149] = {ztype = "DNI", mapid = "543", en = "Trial of the Crusader", de = "", fr = "", es = "", ru = "Испытание крестоносца", Continent = 4, Location = 208, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},
	[150] = {ztype = "DNI", mapid = "602", en = "Pit of Saron", de = "", fr = "", es = "", ru = "Яма Сарона", Continent = 4, Location = 208, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[151] = {ztype = "DNI", mapid = "603", en = "Halls of Reflection", de = "", fr = "", es = "", ru = "Залы Отражений", Continent = 4, Location = 208, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[152] = {ztype = "DNI", mapid = "601", en = "The Forge of Souls", de = "", fr = "", es = "", ru = "Кузня Душ", Continent = 4, Location = 208, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[153] = {ztype = "DNI", mapid = "521", en = "The Culling of Stratholme", de = "", fr = "", es = "", ru = "Очищение Стратхольма", Continent = 4, Location = 200, LevelRange = "80", PlayerLimit = "5",  infoline = METAMAP_WLK_INFO},
	[154] = {ztype = "DNI", mapid = "532", en = "Vault of Archavon", de = "", fr = "", es = "", ru = "Склеп Аркавона", Continent = 4, Location = 209, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},

	[155] = {ztype = "DN", en = "Sunwell Plateau", de = "Sunwell Plateau", fr = "Sunwell Plateau", es = "Sunwell Plateau", ru = "Плато Солнечного Колодца", Continent = 2, Location = 157, LevelRange = "70+", PlayerLimit = "25", infoline = METAMAP_WLK_INFO, texture = "SunwellPlateau"}, 
	[156] = {ztype = "DN", en = "Magisters' Terrace", de = "Magisters' Terrace", fr = "Magisters' Terrace", es = "Magisters' Terrace", ru = "Терраса Магистров", Continent = 2, Location = 157, LevelRange = "70+", PlayerLimit = "25", infoline = METAMAP_WLK_INFO, texture = "MagistersTerrace"}, 
	[157] = {ztype = "SZ", en = "Isle of Quel'Danas", de = "Isle of Quel'Danas", fr = "Isle of Quel'Danas", es = "Isle of Quel'Danas", ru = "Остров Кель'Данас", llvl = 70, hlvl = 70, faction = "Contested", Continent = 2, LevelRange = "70+", PlayerLimit = "25", infoline = METAMAP_WLK_INFO, texture = "MagistersTerrace"}, 
	
	[158] = {ztype = "DNI", mapid = "609", en = "Ruby Sanctum", de = "", fr = "", es = "", ru = "", Continent = 4, Location = 201, LevelRange = "80", PlayerLimit = "25",  infoline = METAMAP_WLK_INFO},

--- Northrend
	[200] = {ztype = "SZ", en = "The Storm Peaks", de = "The Storm Peaks", fr = "The Storm Peaks", es = "The Storm Peaks", ru = "Грозовая Гряда", llvl = 76, hlvl = 80, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[201] = {ztype = "SZ", en = "Dragonblight", de = "Dragonblight", fr = "Dragonblight", es = "Dragonblight", ru = "Драконий Погост", llvl = 71, hlvl = 74, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[202] = {ztype = "SZ", en = "Borean Tundra", de = "Borean Tundra", fr = "Borean Tundra", es = "Borean Tundra", ru = "Борейская тундра", llvl = 68, hlvl = 72, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[203] = {ztype = "SZ", en = "Grizzly Hills", de = "Grizzly Hills", fr = "Grizzly Hills", es = "Grizzly Hills", ru = "Седые холмы", llvl = 73, hlvl = 75, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[204] = {ztype = "SZ", en = "Howling Fjord", de = "Howling Fjord", fr = "Howling Fjord", es = "Howling Fjord", ru = "Ревущий фьорд", llvl = 68, hlvl = 72, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[205] = {ztype = "SZ", en = "Crystalsong Forest", de = "Crystalsong Forest", fr = "Crystalsong Forest", es = "Crystalsong Forest", ru = "Лес Хрустальной Песни", llvl = 74, hlvl = 76, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[206] = {ztype = "SZ", en = "Sholazar Basin", de = "Sholazar Basin", fr = "Sholazar Basin", es = "Sholazar Basin", ru = "Низина Шолазар", llvl = 75, hlvl = 78, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[207] = {ztype = "SZ", en = "Zul'Drak", de = "Zul'Drak", fr = "Zul'Drak", es = "Zul'Drak", ru = "Зул'Драк", llvl = 74, hlvl = 77, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[208] = {ztype = "SZ", en = "Icecrown", de = "Icecrown", fr = "Icecrown", es = "Icecrown", ru = "Ледяная Корона", llvl = 77, hlvl = 80, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[209] = {ztype = "SZ", en = "Wintergrasp", de = "Wintergrasp", fr = "Wintergrasp", es = "Wintergrasp", ru = "Озеро Ледяных Оков", llvl = 68, hlvl = 80, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[210] = {ztype = "SZ", en = "Dalaran", de = "Dalaran", fr = "Dalaran", es = "Dalaran", ru = "Даларан", llvl = 68, hlvl = 80, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},
	[211] = {ztype = "SZ", en = "Hrothgar's Landing", de = "Hrothgar's Landing", fr = "Hrothgar's Landing", es = "Hrothgar's Landing", ru = "Лагерь Хротгара", llvl = 80, hlvl = 80, faction = "Contested", scale = 0.10996723642661, xoffset = 0.51663255550387, yoffset = 0.15624753972085},

	
	}

for index, zoneTable in pairs(MetaMap_ZoneTable) do
	if((zoneTable.ztype == "DN") or (zoneTable.ztype == "DNI")) then
		zoneTable.Location = MetaMap_ZoneTable[zoneTable.Location][MetaMap_Locale];
	end
end
