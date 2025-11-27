--[[
	DC-ItemUpgrade - Costs Module
	Upgrade cost tables and calculations for tier-based upgrades
--]]

local DC = DarkChaos_ItemUpgrade;

--[[=====================================================
	UPGRADE COST TABLES
=======================================================]]

DC.upgradeCosts = {};

function DarkChaos_ItemUpgrade_InitializeCosts()
	-- Tier 1: 5-30 tokens
	DC.upgradeCosts[1] = {
		[1]={tokens=5,essence=0}, [2]={tokens=5,essence=0}, [3]={tokens=5,essence=0},
		[4]={tokens=10,essence=0}, [5]={tokens=10,essence=0}, [6]={tokens=10,essence=0},
		[7]={tokens=15,essence=0}, [8]={tokens=15,essence=0}, [9]={tokens=15,essence=0},
		[10]={tokens=20,essence=0}, [11]={tokens=20,essence=0}, [12]={tokens=20,essence=0},
		[13]={tokens=25,essence=0}, [14]={tokens=25,essence=0}, [15]={tokens=30,essence=0},
	};

	-- Tier 2: 10-35 tokens
	DC.upgradeCosts[2] = {
		[1]={tokens=10,essence=0}, [2]={tokens=10,essence=0}, [3]={tokens=10,essence=0},
		[4]={tokens=15,essence=0}, [5]={tokens=15,essence=0}, [6]={tokens=15,essence=0},
		[7]={tokens=20,essence=0}, [8]={tokens=20,essence=0}, [9]={tokens=20,essence=0},
		[10]={tokens=25,essence=0}, [11]={tokens=25,essence=0}, [12]={tokens=25,essence=0},
		[13]={tokens=30,essence=0}, [14]={tokens=30,essence=0}, [15]={tokens=35,essence=0},
	};

	-- Tier 3: 15-40 tokens
	DC.upgradeCosts[3] = {
		[1]={tokens=15,essence=0}, [2]={tokens=15,essence=0}, [3]={tokens=15,essence=0},
		[4]={tokens=20,essence=0}, [5]={tokens=20,essence=0}, [6]={tokens=20,essence=0},
		[7]={tokens=25,essence=0}, [8]={tokens=25,essence=0}, [9]={tokens=25,essence=0},
		[10]={tokens=30,essence=0}, [11]={tokens=30,essence=0}, [12]={tokens=30,essence=0},
		[13]={tokens=35,essence=0}, [14]={tokens=35,essence=0}, [15]={tokens=40,essence=0},
	};

	-- Tier 4: 20-50 tokens
	DC.upgradeCosts[4] = {
		[1]={tokens=20,essence=0}, [2]={tokens=20,essence=0}, [3]={tokens=20,essence=0},
		[4]={tokens=25,essence=0}, [5]={tokens=25,essence=0}, [6]={tokens=25,essence=0},
		[7]={tokens=30,essence=0}, [8]={tokens=30,essence=0}, [9]={tokens=30,essence=0},
		[10]={tokens=35,essence=0}, [11]={tokens=35,essence=0}, [12]={tokens=35,essence=0},
		[13]={tokens=40,essence=0}, [14]={tokens=40,essence=0}, [15]={tokens=50,essence=0},
	};

	-- Tier 5: 30-60 tokens + 10-40 essence
	DC.upgradeCosts[5] = {
		[1]={tokens=30,essence=10}, [2]={tokens=30,essence=10}, [3]={tokens=30,essence=10},
		[4]={tokens=35,essence=15}, [5]={tokens=35,essence=15}, [6]={tokens=35,essence=15},
		[7]={tokens=40,essence=20}, [8]={tokens=40,essence=20}, [9]={tokens=40,essence=20},
		[10]={tokens=45,essence=25}, [11]={tokens=45,essence=25}, [12]={tokens=45,essence=25},
		[13]={tokens=50,essence=30}, [14]={tokens=50,essence=30}, [15]={tokens=60,essence=40},
	};
end

--[[=====================================================
	COST FUNCTIONS
=======================================================]]

function DarkChaos_ItemUpgrade_GetCost(tier, level)
	if not DC.upgradeCosts[tier] or not DC.upgradeCosts[tier][level] then
		return nil;
	end
	return DC.upgradeCosts[tier][level];
end

function DarkChaos_ItemUpgrade_ComputeCostTotals(tier, currentLevel, targetLevel)
	local totals = { tokens = 0, essence = 0 };
	if not tier or not targetLevel or not currentLevel or targetLevel <= currentLevel then
		return totals, nil;
	end

	local missingLevel = nil;

	for level = currentLevel + 1, targetLevel do
		local cost = DarkChaos_ItemUpgrade_GetCost(tier, level);
		if not cost then
			missingLevel = level;
			break;
		end
		totals.tokens = totals.tokens + (cost.tokens or 0);
		totals.essence = totals.essence + (cost.essence or 0);
	end

	return totals, missingLevel;
end

--[[=====================================================
	HEIRLOOM COST TABLES
=======================================================]]

-- Heirloom essence costs per level (for stat package upgrades)
DC.heirloomCosts = {
	[1] = { essence = 5 },
	[2] = { essence = 10 },
	[3] = { essence = 15 },
	[4] = { essence = 20 },
	[5] = { essence = 30 },
	[6] = { essence = 40 },
	[7] = { essence = 50 },
	[8] = { essence = 65 },
	[9] = { essence = 80 },
	[10] = { essence = 100 },
	[11] = { essence = 120 },
	[12] = { essence = 145 },
	[13] = { essence = 170 },
	[14] = { essence = 200 },
	[15] = { essence = 250 },
};

function DarkChaos_ItemUpgrade_GetHeirloomCost(level)
	return DC.heirloomCosts[level];
end

function DarkChaos_ItemUpgrade_ComputeHeirloomCostTotals(currentLevel, targetLevel)
	local totals = { essence = 0 };
	if not targetLevel or not currentLevel or targetLevel <= currentLevel then
		return totals;
	end

	for level = currentLevel + 1, targetLevel do
		local cost = DarkChaos_ItemUpgrade_GetHeirloomCost(level);
		if cost then
			totals.essence = totals.essence + (cost.essence or 0);
		end
	end

	return totals;
end

-- Initialize costs
DarkChaos_ItemUpgrade_InitializeCosts();
