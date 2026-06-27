if not GetSpecializationIndex then
	function GetSpecializationIndex()
		local activeTab = GetActiveTalentGroup()
		local tabCache
		local oneSpec = false

		for i = 1, 3 do
			local _, _, pointsSpent = GetTalentTabInfo(i, nil, nil, activeTab)
			if (not tabCache) or (pointsSpent > tabCache[1]) then
				tabCache = { pointsSpent, i }
				oneSpec = false
			elseif tabCache[1] == pointsSpent then
				oneSpec = true
			end
		end

		return oneSpec and 1 or (tabCache and tabCache[2] or 1)
	end
end

if not GetNumClasses then
	function GetNumClasses()
		return S_MAX_CLASSES or MAX_CLASSES or 11
	end
end

if not GetClassInfo then
	function GetClassInfo(index, declension)
		if not index or not S_CLASS_SORT_ORDER then
			return
		end

		local classData = S_CLASS_SORT_ORDER[index]
		if not classData then
			return
		end

		local className
		if declension then
			local gender = UnitSex("player")
			if gender == 2 then
				className = LOCALIZED_CLASS_NAMES_MALE[classData[2]]
			elseif gender == 3 then
				className = LOCALIZED_CLASS_NAMES_FEMALE[classData[2]]
			end
		else
			className = LOCALIZED_CLASS_NAMES_MALE[classData[2]]
		end

		return className, classData[2], index, classData[1]
	end
end

if not GetNumSpecializationsForClassID then
	function GetNumSpecializationsForClassID(classID)
		if not classID or not S_CALSS_SPECIALIZATION_DATA then
			return 0
		end
		if S_CALSS_SPECIALIZATION_DATA[classID] then
			return #S_CALSS_SPECIALIZATION_DATA[classID]
		end
		return 0
	end
end

if not GetSpecializationInfoForClassID then
	function GetSpecializationInfoForClassID(classID, specNum)
		if not classID or not specNum or not S_CALSS_SPECIALIZATION_DATA then
			return
		end

		local specs = S_CALSS_SPECIALIZATION_DATA[classID]
		local data = specs and specs[specNum]
		if not data then
			return
		end

		return data[1], data[2], data[3], data[4], data[5], data[6], specNum
	end
end
