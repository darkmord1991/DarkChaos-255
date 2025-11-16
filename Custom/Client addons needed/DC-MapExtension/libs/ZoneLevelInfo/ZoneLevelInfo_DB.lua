currentLocale = GetLocale();
currentLocaleSupported = true;

continentNumberTable = { GetMapContinents() }

zoneNumberTable = {
		 [1] = { GetMapZones(1) }
		,[2] = { GetMapZones(2) }
		,[3] = { GetMapZones(3) }
		,[4] = { GetMapZones(4) }
		}

if (currentLocale == 	"deDE") then
	zones = {
			 ["GM-Insel"] = {0,0,"N"}
			,["Mondlichtung"] = {0,0,"N"}
			,["Die Tiefenbahn"] = {0,80,"A"}
			,["Eisenschmiede"] = {0,80,"A"}
			,["Silbermond"] = {0,80,"H"}
			,["Sturmwind"] = {0,80,"A"}
			,["Unterstadt"] = {0,80,"H"}
			,["Darnassus"] = {0,80,"A"}
			,["Die Exodar"] = {0,80,"A"}
			,["Donnerfels"] = {0,80,"H"}
			,["Orgrimmar"] = {0,80,"H"}
			,["Shattrath"] = {0,80,"S"}
			,["Dalaran"] = {0,80,"S"}
			,["Dun Morogh"] = {1,10,"A"}
			,["Immersangwald"] = {1,10,"H"}
			,["Tirisfal"] = {1,10,"H"}
			,["Wald von Elwynn"] = {1,10,"A"}
			,["Azurmythosinsel"] = {1,10,"A"}
			,["Das verhüllte Meer"] = {1,10,"N"}
			,["Durotar"] = {1,10,"H"}
			,["Mulgore"] = {1,10,"H"}
			,["Teldrassil"] = {1,10,"A"}
			,["Geisterlande"] = {10,20,"H"}
			,["Loch Modan"] = {10,20,"A"}
			,["Silberwald"] = {10,20,"H"}
			,["Westfall"] = {10,20,"A"}
			,["Blutmythosinsel"] = {10,20,"A"}
			,["Dunkelküste"] = {10,20,"A"}
			,["Brachland"] = {10,25,"H"}
			,["Rotkammgebirge"] = {15,25,"A"}
			,["Steinkrallengebirge"] = {15,27,"N"}
			,["Dämmerwald"] = {18,30,"A"}
			,["Eschental"] = {18,30,"N"}
			,["Sumpfland"] = {20,30,"A"}
			,["Vorgebirge des Hügellands"] = {20,30,"N"}
			,["Tausend Nadeln"] = {25,35,"H"}
			,["Alteracgebirge"] = {30,40,"N"}
			,["Arathihochland"] = {30,40,"N"}
			,["Desolace"] = {30,40,"N"}
			,["Schlingendorntal"] = {30,45,"N"}
			,["Ödland"] = {35,45,"H"}
			,["Sümpfe des Elends"] = {35,45,"H"}
			,["Düstermarschen"] = {35,45,"N"}
			,["Feralas"] = {40,50,"N"}
			,["Tanaris"] = {40,50,"N"}
			,["Sengende Schlucht"] = {43,50,"N"}
			,["Hinterland"] = {45,50,"N"}
			,["Verwüstete Lande"] = {45,55,"A"}
			,["Azshara"] = {48,55,"N"}
			,["Krater von Un'Goro"] = {48,55,"N"}
			,["Teufelswald"] = {48,55,"N"}
			,["Brennende Steppe"] = {50,58,"N"}
			,["Westliche Pestländer"] = {51,58,"N"}
			,["Der Schwarzfels"] = {52,60,"N"}
			,["Östliche Pestländer"] = {53,60,"N"}
			,["Winterquell"] = {53,60,"N"}
			,["Pestländer: Die Scharlachrote Enklave"] = {55,58,"N"}
			,["Gebirgspass der Totenwinde"] = {55,60,"N"}
			,["Silithus"] = {55,60,"N"}
			,["Höllenfeuerhalbinsel"] = {58,63,"N"}
			,["Zangarmarschen"] = {60,64,"N"}
			,["Wälder von Terokkar"] = {62,65,"N"}
			,["Nagrand"] = {64,67,"N"}
			,["Schergrat"] = {65,68,"N"}
			,["Nethersturm"] = {67,70,"N"}
			,["Schattenmondtal"] = {67,70,"N"}
			,["Boreanische Tundra"] = {68,72,"N"}
			,["Der heulende Fjord"] = {68,72,"N"}
			,["Insel von Quel'Danas"] = {70,70,"N"}
			,["Drachenöde"] = {71,74,"N"}
			,["Grizzlyhügel"] = {73,75,"N"}
			,["Kristallsangwald"] = {74,76,"N"}
			,["Zul'Drak"] = {74,77,"N"}
			,["Sholazarbecken"] = {76,78,"N"}
			,["Die Sturmgipfel"] = {77,80,"N"}
			,["Eiskrone"] = {77,80,"N"}
			,["Hrothgars Landestelle"] = {77,80,"N"}
			,["Tausendwintersee"] = {77,80,"N"}
	}


elseif (currentLocale == "esES" or currentLocale == "esMX") then
	if (currentLocale == 	"enMX") then
		currentLocale = "enES";
		currentLocaleSupported = false;
	end
	zones = {
			 ["Claro de la Luna"] = {0,0,"N"}
			,["Isla de los MJ"] = {0,0,"N"}
			,["Ciudad de Lunargenta"] = {0,80,"H"}
			,["Ciudad de Ventormenta"] = {0,80,"A"}
			,["Entrañas"] = {0,80,"H"}
			,["Forjaz"] = {0,80,"A"}
			,["Tranvía Subterráneo"] = {0,80,"A"}
			,["Cima del Trueno"] = {0,80,"H"}
			,["Darnassus"] = {0,80,"A"}
			,["El Exodar"] = {0,80,"A"}
			,["Orgrimmar"] = {0,80,"H"}
			,["Ciudad de Shattrath"] = {0,80,"S"}
			,["Dalaran"] = {0,80,"S"}
			,["Bosque Canción Eterna"] = {1,10,"H"}
			,["Bosque de Elwynn"] = {1,10,"A"}
			,["Claros de Tirisfal"] = {1,10,"H"}
			,["Dun Morogh"] = {1,10,"A"}
			,["Durotar"] = {1,10,"H"}
			,["Isla Bruma Azur"] = {1,10,"A"}
			,["Mar de la Bruma"] = {1,10,"N"}
			,["Mulgore"] = {1,10,"H"}
			,["Teldrassil"] = {1,10,"A"}
			,["Bosque de Argénteos"] = {10,20,"H"}
			,["Loch Modan"] = {10,20,"A"}
			,["Páramos de Poniente"] = {10,20,"A"}
			,["Tierras Fantasma"] = {10,20,"H"}
			,["Costa Oscura"] = {10,20,"A"}
			,["Isla Bruma de Sangre"] = {10,20,"A"}
			,["Los Baldíos"] = {10,25,"H"}
			,["Montañas Crestagrana"] = {15,25,"A"}
			,["Sierra Espolón"] = {15,27,"N"}
			,["Bosque del Ocaso"] = {18,30,"A"}
			,["Vallefresno"] = {18,30,"N"}
			,["Laderas de Trabalomas"] = {20,30,"N"}
			,["Los Humedales"] = {20,30,"A"}
			,["Las Mil Agujas"] = {25,35,"H"}
			,["Montañas de Alterac"] = {30,40,"N"}
			,["Tierras Altas de Arathi"] = {30,40,"N"}
			,["Desolace"] = {30,40,"N"}
			,["Vega de Tuercespina"] = {30,45,"N"}
			,["Pantano de las Penas"] = {35,45,"H"}
			,["Tierras Inhóspitas"] = {35,45,"H"}
			,["Marjal Revolcafango"] = {35,45,"N"}
			,["Feralas"] = {40,50,"N"}
			,["Tanaris"] = {40,50,"N"}
			,["La Garganta de Fuego"] = {43,50,"N"}
			,["Tierras del Interior"] = {45,50,"N"}
			,["Las Tierras Devastadas"] = {45,55,"A"}
			,["Azshara"] = {48,55,"N"}
			,["Cráter de Un'Goro"] = {48,55,"N"}
			,["Frondavil"] = {48,55,"N"}
			,["Las Estepas Ardientes"] = {50,58,"N"}
			,["Tierras de la Peste del Oeste"] = {51,58,"N"}
			,["Montaña Roca Negra"] = {52,60,"N"}
			,["Tierras de la Peste del Este"] = {53,60,"N"}
			,["Cuna del Invierno"] = {53,60,"N"}
			,["Tierras de la Peste: El Enclave Escarlata"] = {55,58,"N"}
			,["Paso de la Muerte"] = {55,60,"N"}
			,["Silithus"] = {55,60,"N"}
			,["Península del Fuego Infernal"] = {58,63,"N"}
			,["Marisma de Zangar"] = {60,64,"N"}
			,["Bosque de Terokkar"] = {62,65,"N"}
			,["Nagrand"] = {64,67,"N"}
			,["Montañas Filospada"] = {65,68,"N"}
			,["Tormenta Abisal"] = {67,70,"N"}
			,["Valle Sombraluna"] = {67,70,"N"}
			,["Fiordo Aquilonal"] = {68,72,"N"}
			,["Tundra Boreal"] = {68,72,"N"}
			,["Isla de Quel'Danas"] = {70,70,"N"}
			,["Cementerio de Dragones"] = {71,74,"N"}
			,["Colinas Pardas"] = {73,75,"N"}
			,["Bosque Canto de Cristal"] = {74,76,"N"}
			,["Zul'Drak"] = {74,77,"N"}
			,["Cuenca de Sholazar"] = {76,78,"N"}
			,["Conquista del Invierno"] = {77,80,"N"}
			,["Corona de Hielo"] = {77,80,"N"}
			,["Desembarco de Hrothgar"] = {77,80,"N"}
			,["Las Cumbres Tormentosas"] = {77,80,"N"}
	}


elseif (currentLocale == "frFR") then
	zones = {
			 ["Île des MJ"] = {0,0,"N"}
			,["Reflet-de-Lune"] = {0,0,"N"}
			,["Forgefer"] = {0,80,"A"}
			,["Fossoyeuse"] = {0,80,"H"}
			,["Hurlevent"] = {0,80,"A"}
			,["Lune-d'argent"] = {0,80,"H"}
			,["Tram des profondeurs"] = {0,80,"A"}
			,["Darnassus"] = {0,80,"A"}
			,["Les Pitons du Tonnerre"] = {0,80,"H"}
			,["L'Exodar"] = {0,80,"A"}
			,["Orgrimmar"] = {0,80,"H"}
			,["Shattrath"] = {0,80,"S"}
			,["Dalaran"] = {0,80,"S"}
			,["Bois des Chants éternels"] = {1,10,"H"}
			,["Clairières de Tirisfal"] = {1,10,"H"}
			,["Dun Morogh"] = {1,10,"A"}
			,["Forêt d'Elwynn"] = {1,10,"A"}
			,["Durotar"] = {1,10,"H"}
			,["Île de Brume-azur"] = {1,10,"A"}
			,["La Mer voilée"] = {1,10,"N"}
			,["Mulgore"] = {1,10,"H"}
			,["Teldrassil"] = {1,10,"A"}
			,["Forêt des Pins argentés"] = {10,20,"H"}
			,["Les Terres fantômes"] = {10,20,"H"}
			,["Loch Modan"] = {10,20,"A"}
			,["Marche de l'Ouest"] = {10,20,"A"}
			,["Île de Brume-sang"] = {10,20,"A"}
			,["Sombrivage"] = {10,20,"A"}
			,["Les Tarides"] = {10,25,"H"}
			,["Les Carmines"] = {15,25,"A"}
			,["Les Serres-Rocheuses"] = {15,27,"N"}
			,["Bois de la Pénombre"] = {18,30,"A"}
			,["Orneval"] = {18,30,"N"}
			,["Contreforts de Hautebrande"] = {20,30,"N"}
			,["Les Paluns"] = {20,30,"A"}
			,["Mille pointes"] = {25,35,"H"}
			,["Hautes-terres d'Arathi"] = {30,40,"N"}
			,["Montagnes d'Alterac"] = {30,40,"N"}
			,["Désolace"] = {30,40,"N"}
			,["Vallée de Strangleronce"] = {30,45,"N"}
			,["Marais des Chagrins"] = {35,45,"H"}
			,["Terres ingrates"] = {35,45,"H"}
			,["Marécage d'Âprefange"] = {35,45,"N"}
			,["Féralas"] = {40,50,"N"}
			,["Tanaris"] = {40,50,"N"}
			,["Gorge des Vents brûlants"] = {43,50,"N"}
			,["Les Hinterlands"] = {45,50,"N"}
			,["Terres foudroyées"] = {45,55,"A"}
			,["Azshara"] = {48,55,"N"}
			,["Cratère d'Un'Goro"] = {48,55,"N"}
			,["Gangrebois"] = {48,55,"N"}
			,["Steppes ardentes"] = {50,58,"N"}
			,["Maleterres de l'ouest"] = {51,58,"N"}
			,["Mont Rochenoire"] = {52,60,"N"}
			,["Maleterres de l'est"] = {53,60,"N"}
			,["Berceau-de-l'Hiver"] = {53,60,"N"}
			,["Maleterres : l'enclave Écarlate"] = {55,58,"N"}
			,["Défilé de Deuillevent"] = {55,60,"N"}
			,["Silithus"] = {55,60,"N"}
			,["Péninsule des Flammes infernales"] = {58,63,"N"}
			,["Marécage de Zangar"] = {60,64,"N"}
			,["Forêt de Terokkar"] = {62,65,"N"}
			,["Nagrand"] = {64,67,"N"}
			,["Les Tranchantes"] = {65,68,"N"}
			,["Raz-de-Néant"] = {67,70,"N"}
			,["Vallée d'Ombrelune"] = {67,70,"N"}
			,["Fjord Hurlant"] = {68,72,"N"}
			,["Toundra Boréenne"] = {68,72,"N"}
			,["Île de Quel'Danas"] = {70,70,"N"}
			,["Désolation des dragons"] = {71,74,"N"}
			,["Les Grisonnes"] = {73,75,"N"}
			,["Forêt du Chant de cristal"] = {74,76,"N"}
			,["Zul'Drak"] = {74,77,"N"}
			,["Bassin de Sholazar"] = {76,78,"N"}
			,["Accostage de Hrothgar"] = {77,80,"N"}
			,["Joug-d'hiver"] = {77,80,"N"}
			,["La Couronne de glace"] = {77,80,"N"}
			,["Les pics Foudroyés"] = {77,80,"N"}
	}


elseif (currentLocale == "ruRU") then
	zones = {
			 ["Лунная поляна"] = {0,0,"N"}
			,["Остров ГМ"] = {0,0,"N"}
			,["Луносвет"] = {0,80,"H"}
			,["Подгород"] = {0,80,"H"}
			,["Подземный поезд"] = {0,80,"A"}
			,["Стальгорн"] = {0,80,"A"}
			,["Штормград"] = {0,80,"A"}
			,["Громовой Утес"] = {0,80,"H"}
			,["Дарнас"] = {0,80,"A"}
			,["Оргриммар"] = {0,80,"H"}
			,["Экзодар"] = {0,80,"A"}
			,["Шаттрат"] = {0,80,"S"}
			,["Даларан"] = {0,80,"S"}
			,["Дун Морог"] = {1,10,"A"}
			,["Леса Вечной Песни"] = {1,10,"H"}
			,["Тирисфальские леса"] = {1,10,"H"}
			,["Элвиннский лес"] = {1,10,"A"}
			,["Дуротар"] = {1,10,"H"}
			,["Мулгор"] = {1,10,"H"}
			,["Остров Лазурной Дымки"] = {1,10,"A"}
			,["Сокрытое море"] = {1,10,"N"}
			,["Тельдрассил"] = {1,10,"A"}
			,["Западный Край"] = {10,20,"A"}
			,["Лок Модан"] = {10,20,"A"}
			,["Призрачные земли"] = {10,20,"H"}
			,["Серебряный бор"] = {10,20,"H"}
			,["Остров Кровавой Дымки"] = {10,20,"A"}
			,["Темные берега"] = {10,20,"A"}
			,["Степи"] = {10,25,"H"}
			,["Красногорье"] = {15,25,"A"}
			,["Когтистые горы"] = {15,27,"N"}
			,["Сумеречный лес"] = {18,30,"A"}
			,["Ясеневый лес"] = {18,30,"N"}
			,["Болотина"] = {20,30,"A"}
			,["Предгорья Хилсбрада"] = {20,30,"N"}
			,["Тысяча Игл"] = {25,35,"H"}
			,["Альтеракские горы"] = {30,40,"N"}
			,["Нагорье Арати"] = {30,40,"N"}
			,["Пустоши"] = {30,40,"N"}
			,["Тернистая долина"] = {30,45,"N"}
			,["Бесплодные земли"] = {35,45,"H"}
			,["Болото Печали"] = {35,45,"H"}
			,["Пылевые топи"] = {35,45,"N"}
			,["Танарис"] = {40,50,"N"}
			,["Фералас"] = {40,50,"N"}
			,["Тлеющее ущелье"] = {43,50,"N"}
			,["Внутренние земли"] = {45,50,"N"}
			,["Выжженные земли"] = {45,55,"A"}
			,["Азшара"] = {48,55,"N"}
			,["Кратер Ун'Горо"] = {48,55,"N"}
			,["Оскверненный лес"] = {48,55,"N"}
			,["Пылающие степи"] = {50,58,"N"}
			,["Западные Чумные земли"] = {51,58,"N"}
			,["Черная гора"] = {52,60,"N"}
			,["Восточные Чумные земли"] = {53,60,"N"}
			,["Зимние Ключи"] = {53,60,"N"}
			,["Чумные земли: Анклав Алого ордена"] = {55,58,"N"}
			,["Перевал Мертвого Ветра"] = {55,60,"N"}
			,["Силитус"] = {55,60,"N"}
			,["Полуостров Адского Пламени"] = {58,63,"N"}
			,["Зангартопь"] = {60,64,"N"}
			,["Лес Тероккар"] = {62,65,"N"}
			,["Награнд"] = {64,67,"N"}
			,["Острогорье"] = {65,68,"N"}
			,["Долина Призрачной Луны"] = {67,70,"N"}
			,["Пустоверть"] = {67,70,"N"}
			,["Борейская тундра"] = {68,72,"N"}
			,["Ревущий фьорд"] = {68,72,"N"}
			,["Остров Кель'Данас"] = {70,70,"N"}
			,["Драконий Погост"] = {71,74,"N"}
			,["Седые холмы"] = {73,75,"N"}
			,["Лес Хрустальной Песни"] = {74,76,"N"}
			,["Зул'Драк"] = {74,77,"N"}
			,["Низина Шолазар"] = {76,78,"N"}
			,["Грозовая Гряда"] = {77,80,"N"}
			,["Лагерь Хротгара"] = {77,80,"N"}
			,["Ледяная Корона"] = {77,80,"N"}
			,["Озеро Ледяных Оков"] = {77,80,"N"}
	}


else
	if (currentLocale ~= 	"enUS") then
		currentLocale = "enUS";
		currentLocaleSupported = false;
	end

	zones = {
			 ["GM Island"] = {0,0,"N"}
			,["Moonglade"] = {0,0,"N"}
			,["Deeprun Tram"] = {0,80,"A"}
			,["Ironforge"] = {0,80,"A"}
			,["Silvermoon City"] = {0,80,"H"}
			,["Stormwind City"] = {0,80,"A"}
			,["Undercity"] = {0,80,"H"}
			,["Darnassus"] = {0,80,"A"}
			,["Orgrimmar"] = {0,80,"H"}
			,["The Exodar"] = {0,80,"A"}
			,["Thunder Bluff"] = {0,80,"H"}
			,["Shattrath City"] = {0,80,"S"}
			,["Dalaran"] = {0,80,"S"}
			,["Dun Morogh"] = {1,10,"A"}
			,["Elwynn Forest"] = {1,10,"A"}
			,["Eversong Woods"] = {1,10,"H"}
			,["Tirisfal Glades"] = {1,10,"H"}
			,["Azuremyst Isle"] = {1,10,"A"}
			,["Durotar"] = {1,10,"H"}
			,["Mulgore"] = {1,10,"H"}
			,["Teldrassil"] = {1,10,"A"}
			,["The Veiled Sea"] = {1,10,"N"}
			,["Ghostlands"] = {10,20,"H"}
			,["Loch Modan"] = {10,20,"A"}
			,["Silverpine Forest"] = {10,20,"H"}
			,["Westfall"] = {10,20,"A"}
			,["Bloodmyst Isle"] = {10,20,"A"}
			,["Darkshore"] = {10,20,"A"}
			,["The Barrens"] = {10,25,"H"}
			,["Redridge Mountains"] = {15,25,"A"}
			,["Stonetalon Mountains"] = {15,27,"N"}
			,["Duskwood"] = {18,30,"A"}
			,["Ashenvale"] = {18,30,"N"}
			,["Hillsbrad Foothills"] = {20,30,"N"}
			,["Wetlands"] = {20,30,"A"}
			,["Thousand Needles"] = {25,35,"H"}
			,["Alterac Mountains"] = {30,40,"N"}
			,["Arathi Highlands"] = {30,40,"N"}
			,["Desolace"] = {30,40,"N"}
			,["Stranglethorn Vale"] = {30,45,"N"}
			,["Badlands"] = {35,45,"H"}
			,["Swamp of Sorrows"] = {35,45,"H"}
			,["Dustwallow Marsh"] = {35,45,"N"}
			,["Feralas"] = {40,50,"N"}
			,["Tanaris"] = {40,50,"N"}
			,["Searing Gorge"] = {43,50,"N"}
			,["The Hinterlands"] = {45,50,"N"}
			,["Blasted Lands"] = {45,55,"A"}
			,["Azshara"] = {48,55,"N"}
			,["Felwood"] = {48,55,"N"}
			,["Un'Goro Crater"] = {48,55,"N"}
			,["Burning Steppes"] = {50,58,"N"}
			,["Western Plaguelands"] = {51,58,"N"}
			,["Blackrock Mountain"] = {52,60,"N"}
			,["Eastern Plaguelands"] = {53,60,"N"}
			,["Winterspring"] = {53,60,"N"}
			,["Plaguelands: The Scarlet Enclave"] = {55,58,"N"}
			,["Deadwind Pass"] = {55,60,"N"}
			,["Silithus"] = {55,60,"N"}
			,["Hellfire Peninsula"] = {58,63,"N"}
			,["Zangarmarsh"] = {60,64,"N"}
			,["Terokkar Forest"] = {62,65,"N"}
			,["Nagrand"] = {64,67,"N"}
			,["Blade's Edge Mountains"] = {65,68,"N"}
			,["Netherstorm"] = {67,70,"N"}
			,["Shadowmoon Valley"] = {67,70,"N"}
			,["Borean Tundra"] = {68,72,"N"}
			,["Howling Fjord"] = {68,72,"N"}
			,["Isle of Quel'Danas"] = {70,70,"N"}
			,["Dragonblight"] = {71,74,"N"}
			,["Grizzly Hills"] = {73,75,"N"}
			,["Crystalsong Forest"] = {74,76,"N"}
			,["Zul'Drak"] = {74,77,"N"}
			,["Sholazar Basin"] = {76,78,"N"}
			,["Hrothgar's Landing"] = {77,80,"N"}
			,["Icecrown"] = {77,80,"N"}
			,["The Storm Peaks"] = {77,80,"N"}
			,["Wintergrasp"] = {77,80,"N"}
	}
end



for ckey, continent in next, continentNumberTable do
	zones[continent]={0,0,"C"};
end




-------------------------------
-- Database validation

missingZones = false;
for ckey, mapContinents in next, zoneNumberTable do
	for zkey, mapZoneName in next, mapContinents do
		if (not zones[mapZoneName]) then
			zones[mapZoneName] = {-1,-1,"X"};
			if (currentLocaleSupported) then
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600ZoneLevelInfo ERROR - zone ["..ckey..":"..zkey..":"..mapZoneName.."] not known.");
			end
			missingZones = true;
		end
	end
end

if (missingZones) then
	if (currentLocaleSupported) then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600ZoneLevelInfo ERROR - one or more missing zones. ZoneLevelInfo is out of date or has a bug. Please report on Curse with the missing zones if this is the current game release version.");
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF6600ZoneLevelInfo ERROR - your locale ["..GetLocale().."] is not supported. Loaded ["..currentLocale.."].");
	end
end
