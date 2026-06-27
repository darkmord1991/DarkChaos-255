--	Filename:	C_CreatureInfo.lua
--	Project:	Sirus Game Interface
--	Author:		Nyll
--	E-mail:		nyll@sirus.su
--	Web:		https://sirus.su/

C_CreatureInfo = {}

function C_CreatureInfo.GetClassInfo( class )
	assert(class, "C_CreatureInfo.GetClassInfo: class must be specified.")

	local classData = S_CLASS_SORT_ORDER[class] or S_CLASS_DATA_LOCALIZATION_ASSOC[class]

	assert(classData, "C_CreatureInfo.GetClassInfo: class "..class.." not found.")

	local ClassInfo = {}

	ClassInfo.classFile 	= classData[2]
	ClassInfo.className 	= classData[4]
	ClassInfo.classID 		= classData[3]
	ClassInfo.classFlag 	= classData[1]
	ClassInfo.localizeName 	= {
		male = classData[4],
		female = classData[5]
	}

	return ClassInfo
end

function C_CreatureInfo.GetFactionInfo( race )
	assert(race, "C_CreatureInfo.GetFactionInfo: race must be specified.")

	if race == RACE_NAGA and InGlue() then
		race = E_CHARACTER_RACES.RACE_NAGA
	end

	local raceData = S_CHARACTER_RACES_INFO[race] or S_CHARACTER_RACES_INFO_LOCALIZATION_ASSOC[race]

	raceData = raceData or {
		raceName = "Human",
		clientFileString = "Human",
		raceID = 1,
		factionID = 1
	}

	assert(raceData, "C_CreatureInfo.GetFactionInfo: race "..race.." not found.")

	local FactionInfo = {}
	local factionTag  = PLAYER_FACTION_GROUP[raceData.factionID]

	FactionInfo.name 		= _G["FACTION_"..string.upper(factionTag)]
	FactionInfo.groupTag 	= factionTag
	FactionInfo.factionID 	= raceData.factionID

	return FactionInfo
end

function C_CreatureInfo.GetRaceInfo( race )
	assert(race, "C_CreatureInfo.GetRaceInfo: race must be specified.")

	if race == RACE_NAGA and InGlue() then
		race = E_CHARACTER_RACES.RACE_NAGA
	end

	local raceData = S_CHARACTER_RACES_INFO[race] or S_CHARACTER_RACES_INFO_LOCALIZATION_ASSOC[race]

	raceData = raceData or {
		raceName = "Human",
		clientFileString = "Human",
		raceID = 1,
		factionID = 1
	}

	assert(raceData, "C_CreatureInfo.GetRaceInfo: race "..race.." not found.")

	local RaceInfo  = {}

	RaceInfo.raceName 			= _G[raceData.raceName]
	RaceInfo.clientFileString 	= raceData.clientFileString
	RaceInfo.raceID 			= raceData.raceID
	RaceInfo.localizeName 		= {
		male = _G[raceData.overrideRaceName] or _G[raceData.raceName],
		female = _G[raceData.overrideRaceNameFemale] or _G[raceData.raceNameFemale]
	}

	return RaceInfo
end