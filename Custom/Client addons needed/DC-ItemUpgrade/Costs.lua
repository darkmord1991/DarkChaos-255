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
	-- NOTE: These are an OFFLINE FALLBACK only. The server (dc_item_upgrade_costs
	-- DB table) is authoritative and its values are used whenever DCProtocol is
	-- available. Keep these in sync with that table to avoid a wrong fallback.
	-- Tier 1 (Leveling): token_cost = level * 10
	DC.upgradeCosts[1] = {
		[1]={tokens=10,essence=0}, [2]={tokens=20,essence=0}, [3]={tokens=30,essence=0},
		[4]={tokens=40,essence=0}, [5]={tokens=50,essence=0}, [6]={tokens=60,essence=0},
		[7]={tokens=70,essence=0}, [8]={tokens=80,essence=0}, [9]={tokens=90,essence=0},
		[10]={tokens=100,essence=0}, [11]={tokens=110,essence=0}, [12]={tokens=120,essence=0},
		[13]={tokens=130,essence=0}, [14]={tokens=140,essence=0}, [15]={tokens=150,essence=0},
	};

	-- Tier 2 (Heroic): token_cost = level * 15
	DC.upgradeCosts[2] = {
		[1]={tokens=15,essence=0}, [2]={tokens=30,essence=0}, [3]={tokens=45,essence=0},
		[4]={tokens=60,essence=0}, [5]={tokens=75,essence=0}, [6]={tokens=90,essence=0},
		[7]={tokens=105,essence=0}, [8]={tokens=120,essence=0}, [9]={tokens=135,essence=0},
		[10]={tokens=150,essence=0}, [11]={tokens=165,essence=0}, [12]={tokens=180,essence=0},
		[13]={tokens=195,essence=0}, [14]={tokens=210,essence=0}, [15]={tokens=225,essence=0},
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
	Keyed by tier ID so each heirloom tier has its own
	essence curve.  Add a new subtable when registering a
	new heirloom tier in DC.HEIRLOOM_TIERS.
=======================================================]]

DC.heirloomCosts = {
	-- Tier 3: Heirloom Adventurer's Shirt — 15 levels.
	-- Values kept in sync with dc_heirloom_upgrade_costs (server is authoritative).
	[3] = {
		[1]  = { tokens = 0, essence = 50   },
		[2]  = { tokens = 0, essence = 75   },
		[3]  = { tokens = 0, essence = 100  },
		[4]  = { tokens = 0, essence = 150  },
		[5]  = { tokens = 1, essence = 200  },
		[6]  = { tokens = 1, essence = 275  },
		[7]  = { tokens = 1, essence = 350  },
		[8]  = { tokens = 2, essence = 450  },
		[9]  = { tokens = 2, essence = 575  },
		[10] = { tokens = 3, essence = 725  },
		[11] = { tokens = 3, essence = 900  },
		[12] = { tokens = 4, essence = 1100 },
		[13] = { tokens = 4, essence = 1350 },
		[14] = { tokens = 5, essence = 1650 },
		[15] = { tokens = 5, essence = 2050 },
	},
	-- Tier 10: Frontier Heirloom (Heartstone of Nordrassil) — 15 stages.
	[10] = {
		[1]  = { tokens = 0, essence = 50   },
		[2]  = { tokens = 0, essence = 75   },
		[3]  = { tokens = 0, essence = 100  },
		[4]  = { tokens = 0, essence = 150  },
		[5]  = { tokens = 1, essence = 200  },
		[6]  = { tokens = 1, essence = 275  },
		[7]  = { tokens = 1, essence = 350  },
		[8]  = { tokens = 2, essence = 450  },
		[9]  = { tokens = 2, essence = 575  },
		[10] = { tokens = 3, essence = 725  },
		[11] = { tokens = 3, essence = 900  },
		[12] = { tokens = 4, essence = 1100 },
		[13] = { tokens = 4, essence = 1350 },
		[14] = { tokens = 5, essence = 1650 },
		[15] = { tokens = 5, essence = 2050 },
	},
};

-- Returns the cost entry for one upgrade level within the given heirloom tier.
-- Falls back to tier 3 if the requested tier has no table.
function DarkChaos_ItemUpgrade_GetHeirloomCost(tier, level)
	local tierTable = DC.heirloomCosts[tonumber(tier)] or DC.heirloomCosts[3];
	return tierTable and tierTable[tonumber(level)];
end

-- Returns { essence = N, tokens = N } summed from currentLevel+1 to targetLevel.
function DarkChaos_ItemUpgrade_ComputeHeirloomCostTotals(tier, currentLevel, targetLevel)
	local totals = { essence = 0, tokens = 0 };
	if not targetLevel or not currentLevel or targetLevel <= currentLevel then
		return totals;
	end

	for level = currentLevel + 1, targetLevel do
		local cost = DarkChaos_ItemUpgrade_GetHeirloomCost(tier, level);
		if cost then
			totals.essence = totals.essence + (cost.essence or 0);
			totals.tokens  = totals.tokens  + (cost.tokens  or 0);
		end
	end

	return totals;
end

-- Initialize costs
DarkChaos_ItemUpgrade_InitializeCosts();
