--[[
	DC-Talents - C_Traits / C_ClassTalents / specialization API over WotLK talents.

	The retail talent frame is a generic node-graph renderer: everything it knows comes from these
	APIs. The WotLK talent model maps onto them like this:

	  talent (Talent.dbc id)         -> node, entry and definition (all use the talent id)
	  three talent trees of a class  -> one trait tree (treeID 1000 + classID); hunter pet -> 2000 + tabID
	  tier / column                  -> posX / posY (DC/Layout.lua places three trees side by side)
	  prerequisite talent            -> edge from the prerequisite to the dependent (RequiredForAvailability)
	  "5 points per tier" rule       -> one gate condition per tree and tier (a tier unlocks when the
	                                    ranks in LOWER tiers of that tree reach 5 x tier), see IsGateMet
	  talent points                  -> currency 1; currencies 11..13 track points spent per tree
	  talent group 1 / 2 (dual spec) -> live configs 1 / 2; the active one is C_ClassTalents' active config
	  saved loadouts                 -> configs 1000 + id, stored in DCTalentsDB (DC/Loadouts.lua)

	Staging is ours (retail semantics, including refunds of learned ranks and shift-refunds that clear
	dependents). Commit goes through the DC server message (DC/Server.lua: atomic reset + relearn, free,
	out of combat). Without that module, additions still commit through the stock 3.3.5 preview-talent
	path (AddPreviewTalentPoints + LearnPreviewTalents = one CMSG_LEARN_PREVIEW_TALENTS packet).
]]

local _, ns = ...
setfenv(1, ns.env)

local compat = ns.compat
local G = ns.realG

local Traits = {}
ns.Traits = Traits

local CURRENCY_POINTS = 1
local CURRENCY_TAB_BASE = 10
local CONDITION_TAB_BASE = 100
-- Player trees unlock a tier per 5 points, hunter pet trees per 3 (Player::LearnPetTalent).
local POINTS_PER_TIER = 5
local PET_POINTS_PER_TIER = 3

local CONFIG_PET = 50
local CONFIG_LOADOUT_BASE = 1000
local TREE_CLASS_BASE = 1000
local TREE_PET_BASE = 2000
-- Class-wide synthetic spec id (9000 + classID): fits the 16-bit spec field of retail loadout
-- strings, and both talent groups share it, so a string exported on one group imports on the other.
local SPEC_BASE = 9000

Traits.CURRENCY_POINTS = CURRENCY_POINTS
Traits.CURRENCY_TAB_BASE = CURRENCY_TAB_BASE
Traits.CONFIG_PET = CONFIG_PET
Traits.CONFIG_LOADOUT_BASE = CONFIG_LOADOUT_BASE
Traits.POINTS_PER_TIER = POINTS_PER_TIER

local function PointsPerTier(tree)
	return tree.isPet and PET_POINTS_PER_TIER or POINTS_PER_TIER
end
Traits.PointsPerTier = PointsPerTier

local INSPECT_CONFIG = Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
local VIEW_CONFIG = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID

local EventsFire = function(...)
	ns.Events.Fire(...)
end

-- ----------------------------------------------------------------------------
-- Tree model (built lazily from the client API; stable for the session)
-- ----------------------------------------------------------------------------

local trees = {}

local function PlayerClassID()
	local _, _, classID = compat.UnitClass("player")
	return classID
end

local function ParseTalentLink(link)
	return link and tonumber(link:match("talent:(%d+)"))
end

local function BuildTree(isPet, inspect)
	local numTabs = G.GetNumTalentTabs(inspect, isPet) or 0
	if numTabs == 0 then
		return nil
	end

	local tree = {
		isPet = isPet,
		inspect = inspect,
		nodes = {},
		order = {},
		tabs = {},
		byPosition = {},
		gates = {},
		dependents = {},
	}

	for tab = 1, numTabs do
		local name, icon, _, background = G.GetTalentTabInfo(tab, inspect, isPet)
		local tabInfo = { index = tab, name = name, icon = icon, background = background, maxTier = 0, nodes = {} }
		tree.tabs[tab] = tabInfo
		tree.byPosition[tab] = {}

		for index = 1, (G.GetNumTalents(tab, inspect, isPet) or 0) do
			local talentName, talentIcon, tier, column, _, maxRank, isExceptional = G.GetTalentInfo(tab, index, inspect, isPet)
			local talentID = ParseTalentLink(G.GetTalentLink(tab, index, inspect, isPet))
			if talentID and talentName then
				local data = ns.TalentData and ns.TalentData[talentID]
				local node = {
					id = talentID,
					tab = tab,
					index = index,
					tier = tier,
					column = column,
					maxRank = maxRank or 1,
					name = talentName,
					icon = talentIcon,
					active = data and data[4] == 1 or (isExceptional and true or false),
					prereq = data and data[5] ~= 0 and data[5] or nil,
					prereqRank = data and data[6] or nil,
					spells = {},
				}
				if data then
					tabInfo.talentTabID = tabInfo.talentTabID or data[1]
					for i = 7, #data do
						node.spells[#node.spells + 1] = data[i]
					end
				end
				tree.nodes[talentID] = node
				tree.order[#tree.order + 1] = talentID
				tabInfo.nodes[#tabInfo.nodes + 1] = node
				tree.byPosition[tab][tier] = tree.byPosition[tab][tier] or {}
				tree.byPosition[tab][tier][column] = node
				if tier > tabInfo.maxTier then
					tabInfo.maxTier = tier
				end
			end
		end
	end

	table.sort(tree.order)

	-- Prerequisites the generated data does not know (a custom Talent.dbc): ask the client.
	for _, node in pairs(tree.nodes) do
		if not node.prereq then
			local reqTier, reqColumn = G.GetTalentPrereqs(node.tab, node.index, inspect, isPet)
			if reqTier and reqColumn then
				local prereqNode = tree.byPosition[node.tab][reqTier] and tree.byPosition[node.tab][reqTier][reqColumn]
				if prereqNode then
					node.prereq = prereqNode.id
					node.prereqRank = prereqNode.maxRank
				end
			end
		end
		if node.prereq and tree.nodes[node.prereq] then
			local list = tree.dependents[node.prereq]
			if not list then
				list = {}
				tree.dependents[node.prereq] = list
			end
			list[#list + 1] = node.id
			node.prereqRank = math.min(node.prereqRank or tree.nodes[node.prereq].maxRank, tree.nodes[node.prereq].maxRank)
		else
			node.prereq = nil
		end
	end

	-- One gate per tree and tier, anchored to the left-most talent of the tier.
	for tab, tabInfo in ipairs(tree.tabs) do
		for tier = 2, tabInfo.maxTier do
			local row = tree.byPosition[tab][tier]
			if row then
				local first
				for column = 1, 8 do
					if row[column] then
						first = row[column]
						break
					end
				end
				if first then
					tree.gates[#tree.gates + 1] = {
						topLeftNodeID = first.id,
						conditionID = CONDITION_TAB_BASE * tab + tier,
					}
				end
			end
		end
	end

	return tree
end

-- Trees are keyed by treeID. Player class tree: 1000 + classID. Pet tree: 2000 + pet talent tab.
function Traits.GetPlayerTreeID()
	local classID = PlayerClassID()
	return classID and (TREE_CLASS_BASE + classID) or nil
end

function Traits.GetTree(treeID)
	local tree = trees[treeID]
	if tree then
		return tree
	end
	if treeID == Traits.GetPlayerTreeID() then
		tree = BuildTree(false, false)
	elseif treeID and treeID >= TREE_PET_BASE then
		tree = BuildTree(true, false)
	end
	if tree then
		tree.id = treeID
		trees[treeID] = tree
	end
	return tree
end

function Traits.GetPetTreeID()
	if not G.HasPetUI or not G.HasPetUI() then
		return nil
	end
	local numTabs = G.GetNumTalentTabs(false, true) or 0
	if numTabs == 0 then
		return nil
	end
	local talentID = ParseTalentLink(G.GetTalentLink(1, 1, false, true))
	local data = talentID and ns.TalentData and ns.TalentData[talentID]
	return TREE_PET_BASE + (data and data[1] or 0)
end

function Traits.InvalidatePetTree()
	for treeID in pairs(trees) do
		if treeID >= TREE_PET_BASE then
			trees[treeID] = nil
		end
	end
end

-- ----------------------------------------------------------------------------
-- Configs
-- ----------------------------------------------------------------------------

local configs = {}
Traits.configs = configs

local function ActiveGroup()
	return G.GetActiveTalentGroup(false, false) or 1
end

local function NumGroups()
	return G.GetNumTalentGroups(false, false) or 1
end

local function GetConfig(configID)
	if configID == nil then
		return nil
	end
	local config = configs[configID]
	if config then
		return config
	end

	if configID == 1 or configID == 2 then
		config = { id = configID, kind = "live", group = configID, isPet = false, staged = {} }
	elseif configID == CONFIG_PET then
		config = { id = configID, kind = "pet", group = 1, isPet = true, staged = {} }
	elseif configID == INSPECT_CONFIG then
		config = { id = configID, kind = "inspect", group = 1, inspect = true, staged = {} }
	elseif configID == VIEW_CONFIG then
		config = { id = configID, kind = "view", group = 1, staged = {}, viewRanks = {} }
	elseif configID >= CONFIG_LOADOUT_BASE then
		local loadout = ns.Loadouts and ns.Loadouts.Get(configID - CONFIG_LOADOUT_BASE)
		if not loadout then
			return nil
		end
		config = { id = configID, kind = "loadout", loadoutID = configID - CONFIG_LOADOUT_BASE, staged = {} }
	else
		return nil
	end

	configs[configID] = config
	return config
end
Traits.GetConfig = GetConfig

local function TreeIDForConfig(config)
	if config.kind == "pet" then
		return Traits.GetPetTreeID()
	end
	return Traits.GetPlayerTreeID()
end

function Traits.GetActiveConfigID()
	return ActiveGroup()
end

-- Editable = our staging can change it. Only the active talent group (and the pet) can commit.
local function IsEditable(config)
	if config.kind == "live" then
		return config.group == ActiveGroup()
	end
	return config.kind == "pet"
end
Traits.IsEditable = IsEditable

-- ----------------------------------------------------------------------------
-- Ranks
-- ----------------------------------------------------------------------------

-- Committed rank of a node: what the client currently knows (server state).
local function CommittedRank(config, node)
	if config.kind == "view" then
		return config.viewRanks[node.id] or 0
	elseif config.kind == "loadout" then
		local loadout = ns.Loadouts and ns.Loadouts.Get(config.loadoutID)
		return loadout and loadout.ranks and loadout.ranks[node.id] or 0
	end
	local _, _, _, _, rank = G.GetTalentInfo(node.tab, node.index, config.inspect or false, config.isPet or false, config.group)
	return rank or 0
end
Traits.CommittedRank = CommittedRank

local function EffectiveRank(config, node)
	local staged = config.staged[node.id]
	if staged ~= nil then
		return staged
	end
	return CommittedRank(config, node)
end
Traits.EffectiveRank = EffectiveRank

local function RankFunction(config, excludeStaged)
	local cache = {}
	return function(node)
		local rank = cache[node]
		if rank == nil then
			rank = excludeStaged and CommittedRank(config, node) or EffectiveRank(config, node)
			cache[node] = rank
		end
		return rank
	end
end

local function PointsInTab(tree, tab, rankOf)
	local total = 0
	for _, node in ipairs(tree.tabs[tab].nodes) do
		total = total + rankOf(node)
	end
	return total
end

local function PointsBelowTier(tree, tab, tier, rankOf)
	local total = 0
	for _, node in ipairs(tree.tabs[tab].nodes) do
		if node.tier < tier then
			total = total + rankOf(node)
		end
	end
	return total
end

local function IsGateMet(tree, node, rankOf)
	if node.tier <= 1 then
		return true
	end
	return PointsBelowTier(tree, node.tab, node.tier, rankOf) >= PointsPerTier(tree) * (node.tier - 1)
end
Traits.IsGateMet = IsGateMet

local function IsPrereqMet(tree, node, rankOf)
	if not node.prereq then
		return true
	end
	local prereqNode = tree.nodes[node.prereq]
	return prereqNode == nil or rankOf(prereqNode) >= (node.prereqRank or prereqNode.maxRank)
end
Traits.IsPrereqMet = IsPrereqMet

local function TotalSpent(tree, rankOf)
	local total = 0
	for _, node in pairs(tree.nodes) do
		total = total + rankOf(node)
	end
	return total
end

-- Total talent points the group owns (spent + unspent), from the server's view.
local function TotalPoints(config, tree)
	if config.kind == "view" or config.kind == "loadout" then
		return config.viewTotal or TotalSpent(tree, RankFunction(config, true))
	end
	local unspent = G.GetUnspentTalentPoints(config.inspect or false, config.isPet or false, config.group) or 0
	return unspent + TotalSpent(tree, RankFunction(config, true))
end
Traits.TotalPoints = TotalPoints

-- A build (rank function) is valid when every purchased talent has its gate and prerequisite met.
function Traits.FindInvalidNodes(tree, rankOf)
	local invalid = {}
	for _, node in pairs(tree.nodes) do
		if rankOf(node) > 0 and (not IsGateMet(tree, node, rankOf) or not IsPrereqMet(tree, node, rankOf)) then
			invalid[#invalid + 1] = node
		end
	end
	return invalid
end

-- ----------------------------------------------------------------------------
-- Change notification
-- ----------------------------------------------------------------------------

local function NotifyTreeChanged(configID, treeID)
	local tree = treeID and Traits.GetTree(treeID)
	if tree then
		for _, nodeID in ipairs(tree.order) do
			EventsFire("TRAIT_NODE_CHANGED", nodeID)
		end
		EventsFire("TRAIT_TREE_CURRENCY_INFO_UPDATED", treeID)
	end
	if ns.OnTraitsChanged then
		ns.SafeCall(ns.OnTraitsChanged, configID, treeID)
	end
end
Traits.NotifyTreeChanged = NotifyTreeChanged

local function SetStagedRank(config, node, rank)
	local committed = CommittedRank(config, node)
	if rank == committed then
		config.staged[node.id] = nil
	else
		config.staged[node.id] = rank
	end
end

-- ----------------------------------------------------------------------------
-- C_Traits
-- ----------------------------------------------------------------------------

local C_Traits = {}
compat.C_Traits = C_Traits

function C_Traits.GetConfigInfo(configID)
	local config = GetConfig(configID)
	if not config then
		return nil
	end
	local name = ""
	if config.kind == "loadout" then
		local loadout = ns.Loadouts.Get(config.loadoutID)
		name = loadout and loadout.name or ""
	end
	local treeID = TreeIDForConfig(config)
	return {
		ID = configID,
		type = Enum.TraitConfigType.Combat,
		name = name,
		treeIDs = { treeID },
		usesSharedActionBars = true,
	}
end

function C_Traits.GetConfigIDBySystemID()
	return ActiveGroup()
end

function C_Traits.GetConfigIDByTreeID(treeID)
	if treeID and treeID >= TREE_PET_BASE then
		return CONFIG_PET
	end
	return ActiveGroup()
end

function C_Traits.GetConfigsByType()
	return { ActiveGroup() }
end

function C_Traits.GetSystemIDByTreeID()
	return 0
end

function C_Traits.GetTreeNodes(treeID)
	local tree = Traits.GetTree(treeID)
	if not tree then
		return {}
	end
	local list = {}
	for i, nodeID in ipairs(tree.order) do
		list[i] = nodeID
	end
	return list
end

function C_Traits.GetTreeInfo(configID, treeID)
	local tree = Traits.GetTree(treeID)
	if not tree then
		return nil
	end
	local gates = {}
	for i, gate in ipairs(tree.gates) do
		gates[i] = { topLeftNodeID = gate.topLeftNodeID, conditionID = gate.conditionID }
	end
	return {
		ID = treeID,
		gates = gates,
		hideSingleRankNumbers = false,
		rootNodeID = nil,
		minZoom = 1,
		maxZoom = 1,
		buttonSize = 40,
	}
end

function C_Traits.GetTreeHash(treeID)
	local tree = Traits.GetTree(treeID)
	local hash = {}
	for i = 1, 16 do
		hash[i] = 0
	end
	if tree then
		local accumulator = 0
		for i, nodeID in ipairs(tree.order) do
			local node = tree.nodes[nodeID]
			accumulator = (accumulator * 31 + nodeID * 7 + node.maxRank * 13 + node.tier * 3 + node.column) % 2147483647
			local slot = (i - 1) % 16 + 1
			hash[slot] = (hash[slot] + accumulator) % 256
		end
	end
	return hash
end

function C_Traits.GetLoadoutSerializationVersion()
	return 1
end

local function NodeInfoFor(config, tree, node, rankOf, unspent, treeID)
	local rank = rankOf(node)
	local committed = CommittedRank(config, node)
	local editable = IsEditable(config)
	local gateMet = IsGateMet(tree, node, rankOf)
	local prereqMet = IsPrereqMet(tree, node, rankOf)
	local posX, posY = ns.Layout.NodePosition(tree, node, treeID)

	local conditionIDs = {}
	if node.tier > 1 then
		conditionIDs[1] = CONDITION_TAB_BASE * node.tab + node.tier
	end

	local visibleEdges = {}
	local dependents = tree.dependents[node.id]
	if dependents then
		for _, dependentID in ipairs(dependents) do
			local dependent = tree.nodes[dependentID]
			visibleEdges[#visibleEdges + 1] = {
				targetNode = dependentID,
				type = Enum.TraitEdgeType.RequiredForAvailability,
				visualStyle = Enum.TraitEdgeVisualStyle.Straight,
				isActive = rank >= (dependent.prereqRank or node.maxRank),
			}
		end
	end

	local canRefund = editable and rank > 0 and (rank > committed or Traits.CanRemoveLearnedRanks())
	local canPurchase = editable and rank < node.maxRank and gateMet and prereqMet and unspent > 0

	return {
		ID = node.id,
		posX = posX,
		posY = posY,
		flags = 0,
		entryIDs = { node.id },
		entryIDsWithCommittedRanks = committed > 0 and { node.id } or {},
		canPurchaseRank = canPurchase,
		canRefundRank = canRefund,
		isAvailable = gateMet,
		isVisible = true,
		isDisplayError = false,
		ranksPurchased = rank,
		ranksIncreased = 0,
		entryIDToRanksIncreased = {},
		activeRank = rank,
		currentRank = rank,
		activeEntry = { entryID = node.id, rank = rank },
		nextEntry = rank < node.maxRank and { entryID = node.id, rank = rank + 1 } or nil,
		maxRanks = node.maxRank,
		type = node.maxRank > 1 and Enum.TraitNodeType.Tiered or Enum.TraitNodeType.Single,
		visibleEdges = visibleEdges,
		meetsEdgeRequirements = prereqMet,
		groupIDs = {},
		conditionIDs = conditionIDs,
		-- A purchased talent whose gate a refund took away shows as RefundInvalid (retail's
		-- "conditions no longer met" state) until it is fixed or refunded too.
		isCascadeRepurchasable = rank > 0 and not gateMet,
		cascadeRepurchaseEntryID = nil,
		subTreeID = nil,
		subTreeActive = nil,

		-- DC extras (not in the retail struct): used by the DC layer's tooltips and layout.
		dcTab = node.tab,
		dcIndex = node.index,
		dcTier = node.tier,
		dcColumn = node.column,
		dcCommittedRank = committed,
	}
end

function C_Traits.GetNodeInfo(configID, nodeID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	local node = tree and tree.nodes[nodeID]
	if not node then
		return nil
	end
	local rankOf = RankFunction(config)
	local unspent = TotalPoints(config, tree) - TotalSpent(tree, rankOf)
	return NodeInfoFor(config, tree, node, rankOf, unspent, treeID)
end

function C_Traits.GetEntryInfo(configID, entryID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config) or Traits.GetPlayerTreeID()
	local tree = treeID and Traits.GetTree(treeID)
	local node = tree and tree.nodes[entryID]
	if not node then
		return nil
	end
	return {
		definitionID = entryID,
		subTreeID = nil,
		type = node.active and Enum.TraitNodeEntryType.SpendCircle or Enum.TraitNodeEntryType.SpendSquare,
		maxRanks = node.maxRank,
		isAvailable = true,
		isDisplayError = false,
		conditionIDs = {},
	}
end

local function FindNodeAnyTree(nodeID)
	local treeID = Traits.GetPlayerTreeID()
	local tree = treeID and Traits.GetTree(treeID)
	local node = tree and tree.nodes[nodeID]
	if node then
		return node, tree
	end
	for id, petTree in pairs(trees) do
		if id >= TREE_PET_BASE and petTree.nodes[nodeID] then
			return petTree.nodes[nodeID], petTree
		end
	end
	return nil
end
Traits.FindNodeAnyTree = FindNodeAnyTree

function C_Traits.GetDefinitionInfo(definitionID)
	local node = FindNodeAnyTree(definitionID)
	if not node then
		return nil
	end
	return {
		spellID = node.spells[1],
		overrideName = node.name,
		overrideIcon = node.icon,
		overrideSubtext = nil,
		overrideDescription = nil,
		overriddenSpellID = nil,
		subType = nil,
	}
end

function C_Traits.GetConditionInfo(configID, condID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	if not tree or not condID then
		return nil
	end
	local tab = math.floor(condID / CONDITION_TAB_BASE)
	local tier = condID % CONDITION_TAB_BASE
	local tabInfo = tree.tabs[tab]
	if not tabInfo then
		return nil
	end
	local required = PointsPerTier(tree) * (tier - 1)
	local spent = PointsBelowTier(tree, tab, tier, RankFunction(config))
	return {
		condID = condID,
		ranksGranted = nil,
		isAlwaysMet = false,
		isMet = spent >= required,
		isGate = true,
		isSufficient = false,
		type = Enum.TraitConditionType.Available,
		traitCurrencyID = CURRENCY_TAB_BASE + tab,
		-- Retail semantics: the points still MISSING ("Spend 3 more points"), counting down to 0.
		spentAmountRequired = math.max(0, required - spent),
		-- %d = points still missing; the tree name is baked in (retail formats a second, empty arg).
		tooltipFormat = (ns.L and ns.L.GATE_TOOLTIP_FORMAT or "Requires %d more points spent in %s"):gsub("%%s", tabInfo.name or "", 1),
		dcTab = tab,
		dcTier = tier,
		dcSpent = spent,
		dcRequired = required,
	}
end

function C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges)
	local config = GetConfig(configID)
	local tree = treeID and Traits.GetTree(treeID)
	if not config or not tree then
		return {}
	end
	local rankOf = RankFunction(config, excludeStagedChanges)
	local total = TotalPoints(config, tree)
	local spent = TotalSpent(tree, rankOf)
	local list = {
		{ traitCurrencyID = CURRENCY_POINTS, quantity = total - spent, maxQuantity = total, spent = spent },
	}
	for tab = 1, #tree.tabs do
		list[#list + 1] = { traitCurrencyID = CURRENCY_TAB_BASE + tab, quantity = 0, maxQuantity = nil, spent = PointsInTab(tree, tab, rankOf) }
	end
	return list
end

function C_Traits.GetTraitCurrencyInfo(traitCurrencyID)
	return 0, Enum.TraitCurrencyType and Enum.TraitCurrencyType.TraitSourced or 2, nil, nil
end

function C_Traits.GetNodeCost(configID, nodeID)
	return { { ID = CURRENCY_POINTS, amount = 1 } }
end

function C_Traits.GetSubTreeInfo()
	return nil
end

function C_Traits.GetIncreasedTraitData()
	return {}
end

function C_Traits.GetTraitDescription()
	return ""
end

function C_Traits.GetTraitSystemFlags()
	return 0
end

function C_Traits.GetTraitSystemWidgetSetID()
	return nil
end

function C_Traits.GetConfigVariationID()
	return 0
end

function C_Traits.CanEditConfig(configID)
	local config = GetConfig(configID)
	return config ~= nil and IsEditable(config)
end

function C_Traits.IsReadyForCommit()
	return true
end

function C_Traits.HasValidInspectData()
	return G.GetNumTalentTabs(true, false) and G.GetNumTalentTabs(true, false) > 0
end

C_Traits.StageConfig = function() return true end
C_Traits.ClearCascadeRepurchaseHistory = function() end
C_Traits.CloseTraitSystemInteraction = function() end
C_Traits.TalentTestUnlearnSpells = function() end

local function ResolveNode(configID, nodeID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	local node = tree and tree.nodes[nodeID]
	return config, tree, node, treeID
end

function C_Traits.CanPurchaseRank(configID, nodeID)
	local info = C_Traits.GetNodeInfo(configID, nodeID)
	return info ~= nil and info.canPurchaseRank
end

function C_Traits.CanRefundRank(configID, nodeID)
	local info = C_Traits.GetNodeInfo(configID, nodeID)
	return info ~= nil and info.canRefundRank
end

function C_Traits.PurchaseRank(configID, nodeID)
	local config, tree, node, treeID = ResolveNode(configID, nodeID)
	if not node or not IsEditable(config) or Traits.IsCommitPending(config) then
		return false
	end
	local rankOf = RankFunction(config)
	local rank = rankOf(node)
	local unspent = TotalPoints(config, tree) - TotalSpent(tree, rankOf)
	if rank >= node.maxRank or unspent <= 0 or not IsGateMet(tree, node, rankOf) or not IsPrereqMet(tree, node, rankOf) then
		return false
	end
	SetStagedRank(config, node, rank + 1)
	NotifyTreeChanged(configID, treeID)
	return true
end

function C_Traits.PurchaseAllRanks(configID, nodeID)
	local purchasedAny = false
	while C_Traits.PurchaseRank(configID, nodeID) do
		purchasedAny = true
	end
	return purchasedAny
end
C_Traits.TryPurchaseAllRanks = C_Traits.PurchaseAllRanks

-- Removes ranks of every purchased talent whose gate or prerequisite no longer holds.
local function CascadeRefund(config, tree)
	local changed = true
	while changed do
		changed = false
		local rankOf = RankFunction(config)
		for _, node in ipairs(Traits.FindInvalidNodes(tree, rankOf)) do
			SetStagedRank(config, node, 0)
			changed = true
		end
	end
end

function C_Traits.RefundRank(configID, nodeID, clearEdges)
	local config, tree, node, treeID = ResolveNode(configID, nodeID)
	if not node or not IsEditable(config) or Traits.IsCommitPending(config) then
		return false
	end
	local rank = EffectiveRank(config, node)
	local committed = CommittedRank(config, node)
	if rank <= 0 or (rank <= committed and not Traits.CanRemoveLearnedRanks()) then
		return false
	end
	SetStagedRank(config, node, rank - 1)
	if clearEdges then
		CascadeRefund(config, tree)
	end
	NotifyTreeChanged(configID, treeID)
	return true
end

function C_Traits.RefundAllRanks(configID, nodeID)
	local config, tree, node, treeID = ResolveNode(configID, nodeID)
	if not node or not IsEditable(config) or Traits.IsCommitPending(config) then
		return false
	end
	local committed = CommittedRank(config, node)
	local floor = Traits.CanRemoveLearnedRanks() and 0 or committed
	if EffectiveRank(config, node) <= floor then
		return false
	end
	SetStagedRank(config, node, floor)
	NotifyTreeChanged(configID, treeID)
	return true
end

function C_Traits.SetSelection()
	return false
end

function C_Traits.CascadeRepurchaseRanks()
	return false
end

function C_Traits.TryPurchaseToNode()
	return false
end

function C_Traits.TryRefundToNode()
	return false
end

-- Resets a whole tree (currency 1) or one talent tree (currency 11..13) to zero (staged).
local function ResetRanks(configID, onlyTab)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	if not tree or not IsEditable(config) or Traits.IsCommitPending(config) then
		return false
	end
	local canRemove = Traits.CanRemoveLearnedRanks()
	for _, node in pairs(tree.nodes) do
		if not onlyTab or node.tab == onlyTab then
			SetStagedRank(config, node, canRemove and 0 or CommittedRank(config, node))
		end
	end
	if onlyTab then
		CascadeRefund(config, tree)
	end
	NotifyTreeChanged(configID, treeID)
	return true
end

function C_Traits.ResetTree(configID, treeID)
	return ResetRanks(configID, nil)
end

function C_Traits.ResetTreeByCurrency(configID, treeID, traitCurrencyID)
	if traitCurrencyID and traitCurrencyID > CURRENCY_TAB_BASE then
		return ResetRanks(configID, traitCurrencyID - CURRENCY_TAB_BASE)
	end
	return ResetRanks(configID, nil)
end

function C_Traits.ConfigHasStagedChanges(configID)
	local config = GetConfig(configID)
	return config ~= nil and next(config.staged) ~= nil
end

function C_Traits.GetStagedChanges(configID)
	local config = GetConfig(configID)
	local purchased, refunded = {}, {}
	if config then
		local treeID = TreeIDForConfig(config)
		local tree = treeID and Traits.GetTree(treeID)
		for nodeID, rank in pairs(config.staged) do
			local node = tree and tree.nodes[nodeID]
			if node then
				if rank > CommittedRank(config, node) then
					purchased[#purchased + 1] = nodeID
				else
					refunded[#refunded + 1] = nodeID
				end
			end
		end
	end
	return purchased, refunded, {}
end

function C_Traits.GetStagedChangesCost(configID)
	local config = GetConfig(configID)
	local amount = 0
	if config then
		local treeID = TreeIDForConfig(config)
		local tree = treeID and Traits.GetTree(treeID)
		for nodeID, rank in pairs(config.staged) do
			local node = tree and tree.nodes[nodeID]
			if node then
				amount = amount + (rank - CommittedRank(config, node))
			end
		end
	end
	return { { ID = CURRENCY_POINTS, amount = amount } }
end

function C_Traits.RollbackConfig(configID)
	local config = GetConfig(configID)
	if not config then
		return false
	end
	wipe(config.staged)
	NotifyTreeChanged(configID, TreeIDForConfig(config))
	return true
end

function C_Traits.CommitConfig(configID)
	return Traits.Commit(configID, nil)
end

function C_Traits.GenerateImportString(configID)
	return ns.Loadouts and ns.Loadouts.GenerateImportString(configID) or ""
end

function C_Traits.GenerateInspectImportString()
	return ns.Loadouts and ns.Loadouts.GenerateImportString(INSPECT_CONFIG) or ""
end

-- ----------------------------------------------------------------------------
-- Commit
-- ----------------------------------------------------------------------------

-- Removing learned ranks needs the DC server module (free atomic respec); without it we keep the
-- stock rule: talents can only be added.
function Traits.CanRemoveLearnedRanks()
	return ns.Server ~= nil and ns.Server.SupportsFreeRespec()
end

function Traits.IsCommitPending(config)
	return config.pendingCommit ~= nil
end

-- Target ranks of a config: every node with an effective rank > 0.
function Traits.GetTargetRanks(config, tree)
	local ranks = {}
	for _, node in pairs(tree.nodes) do
		local rank = EffectiveRank(config, node)
		if rank > 0 then
			ranks[node.id] = rank
		end
	end
	return ranks
end

local function FinishCommit(config, success, message)
	local pending = config.pendingCommit
	if not pending then
		return
	end
	config.pendingCommit = nil

	if success then
		wipe(config.staged)
		if pending.savedConfigID and ns.Loadouts then
			ns.Loadouts.OnCommitted(pending.savedConfigID, pending.ranks)
		end
		NotifyTreeChanged(config.id, pending.treeID)
		EventsFire("TRAIT_CONFIG_UPDATED", config.id)
	else
		if message and message ~= "" then
			G.UIErrorsFrame:AddMessage(message, 1.0, 0.1, 0.1, 1.0)
		end
		NotifyTreeChanged(config.id, pending.treeID)
		EventsFire("CONFIG_COMMIT_FAILED", config.id)
	end
end
Traits.FinishCommit = FinishCommit

-- Learn order for the stock preview path: tree, tier, then prerequisites first within a tier.
local function SortedForLearning(tree, nodes)
	table.sort(nodes, function(a, b)
		if a.tab ~= b.tab then
			return a.tab < b.tab
		end
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		if b.prereq == a.id then
			return true
		end
		if a.prereq == b.id then
			return false
		end
		return a.column < b.column
	end)
	return nodes
end

function Traits.Commit(configID, savedConfigID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	if not tree or not IsEditable(config) or config.pendingCommit then
		return false
	end

	if next(config.staged) == nil then
		-- Nothing to learn: committing an unchanged build just (re)selects the loadout.
		config.pendingCommit = { treeID = treeID, savedConfigID = savedConfigID, ranks = Traits.GetTargetRanks(config, tree) }
		FinishCommit(config, true)
		return true
	end

	local rankOf = RankFunction(config)
	if #Traits.FindInvalidNodes(tree, rankOf) > 0 then
		return false
	end

	local target = Traits.GetTargetRanks(config, tree)
	local removals = false
	local additions = {}
	for _, node in pairs(tree.nodes) do
		local committed = CommittedRank(config, node)
		local wanted = target[node.id] or 0
		if wanted < committed then
			removals = true
		elseif wanted > committed then
			additions[#additions + 1] = node
		end
	end

	config.pendingCommit = { treeID = treeID, savedConfigID = savedConfigID, ranks = target, started = G.GetTime() }

	if ns.Server and ns.Server.IsAvailable() then
		local sent = ns.Server.ApplyBuild(config, target, function(ok, message)
			if config.pendingCommit then
				FinishCommit(config, ok, message)
			end
		end)
		if sent then
			return true
		end
	end

	if removals then
		config.pendingCommit = nil
		G.UIErrorsFrame:AddMessage(ns.L and ns.L.ERR_REMOVE_NEEDS_SERVER or "Removing talents needs the Dark Chaos server.", 1.0, 0.1, 0.1, 1.0)
		return false
	end

	-- Stock 3.3.5 path: stage the additions in the client's preview state and learn them in one packet.
	local isPet = config.isPet or false
	G.ResetGroupPreviewTalentPoints(isPet, config.group)
	for _, node in ipairs(SortedForLearning(tree, additions)) do
		local delta = (target[node.id] or 0) - CommittedRank(config, node)
		if delta > 0 then
			G.AddPreviewTalentPoints(node.tab, node.index, delta, isPet, config.group)
		end
	end
	G.LearnPreviewTalents(isPet)
	config.pendingCommit.previewPath = true
	return true
end

-- Called when the client's talent data changed (PLAYER_TALENT_UPDATE and friends).
function Traits.OnTalentDataChanged()
	for configID, config in pairs(configs) do
		local pending = config.pendingCommit
		if pending and pending.previewPath then
			local tree = Traits.GetTree(pending.treeID)
			local done = tree ~= nil
			if tree then
				for _, node in pairs(tree.nodes) do
					if CommittedRank(config, node) ~= (pending.ranks[node.id] or 0) then
						done = false
						break
					end
				end
			end
			if done then
				FinishCommit(config, true)
			elseif G.GetTime() - (pending.started or 0) > 2 then
				FinishCommit(config, false, ns.L and ns.L.ERR_COMMIT_PARTIAL or "Some talents could not be learned.")
			end
		end

		-- Staged ranks equal to the new committed ranks are no longer changes.
		local treeID = TreeIDForConfig(config)
		local tree = treeID and Traits.GetTree(treeID)
		if tree then
			for nodeID, rank in pairs(config.staged) do
				local node = tree.nodes[nodeID]
				if not node or CommittedRank(config, node) == rank then
					config.staged[nodeID] = nil
				end
			end
		end
	end

	local playerTree = Traits.GetPlayerTreeID()
	if playerTree then
		NotifyTreeChanged(ActiveGroup(), playerTree)
	end
end

-- ----------------------------------------------------------------------------
-- C_ClassTalents
-- ----------------------------------------------------------------------------

local C_ClassTalents = {}
compat.C_ClassTalents = C_ClassTalents

function C_ClassTalents.GetActiveConfigID()
	return ActiveGroup()
end

function C_ClassTalents.GetConfigIDsBySpecID(specID)
	return ns.Loadouts and ns.Loadouts.GetConfigIDs() or {}
end

function C_ClassTalents.GetLastSelectedSavedConfigID(specID)
	return ns.Loadouts and ns.Loadouts.GetLastSelected(Traits.GroupFromSpecID(specID)) or nil
end

function C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, configID)
	if ns.Loadouts then
		ns.Loadouts.SetLastSelected(Traits.GroupFromSpecID(specID), configID)
	end
end

function C_ClassTalents.CanCreateNewConfig()
	return ns.Loadouts ~= nil and ns.Loadouts.CanCreate()
end

function C_ClassTalents.CanEditTalents()
	return true, nil
end

-- canChange, canAdd, errorMessage
function C_ClassTalents.CanChangeTalents()
	if G.UnitAffectingCombat("player") then
		return false, false, ns.L and ns.L.ERR_IN_COMBAT or G.ERR_NOT_IN_COMBAT
	end
	if G.UnitIsDeadOrGhost("player") then
		return false, false, ns.L and ns.L.ERR_DEAD or G.ERR_PLAYER_DEAD
	end
	if not Traits.CanRemoveLearnedRanks() then
		return false, true, nil
	end
	return true, true, nil
end

function C_ClassTalents.CanCommitInstantly()
	return true
end

-- Can the build still take a point? At high levels there can be more points than ranks to buy.
function Traits.CanSpendMore(configID)
	local config = GetConfig(configID)
	local treeID = config and TreeIDForConfig(config)
	local tree = treeID and Traits.GetTree(treeID)
	if not tree then
		return false
	end
	local rankOf = RankFunction(config)
	if TotalPoints(config, tree) - TotalSpent(tree, rankOf) <= 0 then
		return false
	end
	for _, node in pairs(tree.nodes) do
		if rankOf(node) < node.maxRank and IsGateMet(tree, node, rankOf) and IsPrereqMet(tree, node, rankOf) then
			return true
		end
	end
	return false
end

-- Only points that could still buy something count as unspent (retail blocks exports and nags on them).
function C_ClassTalents.HasUnspentTalentPoints()
	if (G.GetUnspentTalentPoints(false, false, ActiveGroup()) or 0) <= 0 then
		return false
	end
	return Traits.CanSpendMore(ActiveGroup())
end

function C_ClassTalents.HasUnspentHeroTalentPoints()
	return false
end

function C_ClassTalents.GetStarterBuildActive()
	return false
end

function C_ClassTalents.GetHasStarterBuild()
	return false
end

function C_ClassTalents.SetStarterBuildActive()
	return Enum.LoadConfigResult.Error
end

function C_ClassTalents.GetNextStarterBuildPurchase()
	return nil
end

function C_ClassTalents.IsConfigPopulated()
	return true
end

function C_ClassTalents.GetTraitTreeForSpec()
	return Traits.GetPlayerTreeID()
end

function C_ClassTalents.GetHeroTalentSpecsForClassSpec()
	return nil
end

function C_ClassTalents.SetUsesSharedActionBars()
end

function C_ClassTalents.RequestNewConfig(name)
	return ns.Loadouts ~= nil and ns.Loadouts.CreateFromActive(name)
end

function C_ClassTalents.SaveConfig(configID)
	return ns.Loadouts ~= nil and ns.Loadouts.SaveActiveInto(configID)
end

function C_ClassTalents.RenameConfig(configID, name)
	return ns.Loadouts ~= nil and ns.Loadouts.Rename(configID, name)
end

function C_ClassTalents.DeleteConfig(configID)
	return ns.Loadouts ~= nil and ns.Loadouts.Delete(configID)
end

function C_ClassTalents.ImportLoadout(configID, loadoutEntryInfo, name)
	if not ns.Loadouts then
		return false, nil
	end
	return ns.Loadouts.CreateFromEntries(loadoutEntryInfo, name)
end

function C_ClassTalents.CommitConfig(savedConfigID)
	return Traits.Commit(ActiveGroup(), savedConfigID)
end

-- Loads a saved loadout into the active config's staging; autoApply commits it right away.
-- Returns loadResult, changeError, newlyLearnedNodes.
function C_ClassTalents.LoadConfig(configID, autoApply)
	local loadout = ns.Loadouts and ns.Loadouts.Get(configID - CONFIG_LOADOUT_BASE)
	local activeID = ActiveGroup()
	local config = GetConfig(activeID)
	local treeID = Traits.GetPlayerTreeID()
	local tree = treeID and Traits.GetTree(treeID)
	if not loadout or not config or not tree then
		return Enum.LoadConfigResult.Error, ns.L and ns.L.ERR_LOADOUT_MISSING or ""
	end

	wipe(config.staged)
	local canRemove = Traits.CanRemoveLearnedRanks()
	local newlyLearned = {}
	local blocked = false
	for _, node in pairs(tree.nodes) do
		local wanted = loadout.ranks[node.id] or 0
		local committed = CommittedRank(config, node)
		if wanted < committed and not canRemove then
			blocked = true
			wanted = committed
		end
		if wanted ~= committed then
			config.staged[node.id] = math.min(wanted, node.maxRank)
			if wanted > committed then
				newlyLearned[#newlyLearned + 1] = node.id
			end
		end
	end

	-- Loadouts saved on another level can overspend or skip gates: keep only what is valid.
	local rankOf = RankFunction(config)
	local unspent = TotalPoints(config, tree) - TotalSpent(tree, rankOf)
	if unspent < 0 or #Traits.FindInvalidNodes(tree, rankOf) > 0 then
		wipe(config.staged)
		NotifyTreeChanged(activeID, treeID)
		return Enum.LoadConfigResult.Error, ns.L and ns.L.ERR_LOADOUT_NOT_APPLICABLE or ""
	end

	NotifyTreeChanged(activeID, treeID)

	if ns.OnLoadoutLoaded then
		ns.SafeCall(ns.OnLoadoutLoaded, configID)
	end

	if next(config.staged) == nil then
		if blocked then
			return Enum.LoadConfigResult.Error, ns.L and ns.L.ERR_REMOVE_NEEDS_SERVER or ""
		end
		return Enum.LoadConfigResult.NoChangesNecessary, nil, {}
	end

	if autoApply then
		if Traits.Commit(activeID, configID) then
			return Enum.LoadConfigResult.LoadInProgress, nil, newlyLearned
		end
		return Enum.LoadConfigResult.Error, nil
	end
	return Enum.LoadConfigResult.Ready, nil, newlyLearned
end

function C_ClassTalents.InitializeViewLoadout(specID, level)
	local config = GetConfig(VIEW_CONFIG)
	wipe(config.viewRanks)
	config.viewTotal = math.max(0, (level or G.UnitLevel("player")) - 9)
end

function C_ClassTalents.ViewLoadout(loadoutEntryInfo)
	local config = GetConfig(VIEW_CONFIG)
	wipe(config.viewRanks)
	for _, entry in ipairs(loadoutEntryInfo or {}) do
		config.viewRanks[entry.nodeID] = entry.ranksPurchased
	end
	return true
end

-- ----------------------------------------------------------------------------
-- Specializations: the two talent groups (dual spec) are the "specializations"
-- ----------------------------------------------------------------------------

-- Two kinds of spec ids:
--  * the retail spec of a talent group's primary tree (71 = Arms, ...): what the retail frame uses for
--    backgrounds, spec thumbnails and roles, so the art follows where the player spent points;
--  * a class-wide id (9000 + classID) for loadout strings, so a string exported on one talent group
--    (or with another primary tree) imports on any character of the class.
function Traits.ClassSpecID(classID)
	return SPEC_BASE + (classID or PlayerClassID() or 0)
end

-- The tree with the most points in a talent group (the first one on a tie or an empty group).
function Traits.GetPrimaryTab(group, inspect)
	local bestTab, bestPoints = 1, 0
	for tab = 1, (G.GetNumTalentTabs(inspect or false, false) or 0) do
		local _, _, points = G.GetTalentTabInfo(tab, inspect or false, false, group)
		if (points or 0) > bestPoints then
			bestTab, bestPoints = tab, points
		end
	end
	return bestTab, bestPoints
end

function Traits.SpecIDForGroup(group, inspect)
	local tab, points = Traits.GetPrimaryTab(group or ActiveGroup(), inspect)
	local specID = ns.Layout and ns.Layout.RetailSpecForTab(tab, inspect)
	return specID or Traits.ClassSpecID(), tab, points
end

function Traits.GroupFromSpecID()
	return ActiveGroup()
end

function Traits.IsDCSpecID(specID)
	return specID ~= nil and specID > SPEC_BASE and specID < SPEC_BASE + 100
end

-- Class of a spec id (retail spec or class-wide id).
function Traits.ClassIDForSpecID(specID)
	if Traits.IsDCSpecID(specID) then
		return specID - SPEC_BASE
	end
	local classFile = ns.Layout and ns.Layout.ClassByRetailSpec[specID]
	return classFile and ns.ClassIDByFile[classFile] or nil
end

compat.GetNumSpecializations = function()
	return NumGroups()
end

compat.GetSpecialization = function()
	return ActiveGroup()
end

compat.GetActiveSpecGroup = compat.GetSpecialization

-- Specialization "index" = talent group. Name = the primary tree, description = the point split.
local function SpecInfo(group)
	local specID, primaryTab, points = Traits.SpecIDForGroup(group)
	local tabName, tabIcon = G.GetTalentTabInfo(primaryTab, false, false, group)
	local groupLabel = group == 1 and (G.TALENT_SPEC_PRIMARY or "Primary Talents") or (G.TALENT_SPEC_SECONDARY or "Secondary Talents")
	local name = (points or 0) > 0 and tabName or groupLabel
	local split = ns.Layout and ns.Layout.DescribeGroup(group) or ""
	local description = ("%s|n%s"):format(groupLabel, split)
	local role = ns.Layout and ns.Layout.RoleByRetailSpec[specID] or "DAMAGER"
	local primaryStat = ns.Layout and ns.Layout.PrimaryStatByRetailSpec[specID] or 1
	return specID, name, description, tabIcon, role, primaryStat
end

compat.GetSpecializationInfo = function(index)
	if not index or index < 1 or index > NumGroups() then
		return nil
	end
	return SpecInfo(index)
end

-- A retail spec id of the player's class describes that tree; the class-wide id describes the active group.
compat.GetSpecializationInfoByID = function(specID)
	local className, classFile = G.UnitClass("player")
	if specID and not Traits.IsDCSpecID(specID) and ns.Layout then
		for tab = 1, (G.GetNumTalentTabs(false, false) or 0) do
			if ns.Layout.RetailSpecForTab(tab) == specID then
				local name, icon = G.GetTalentTabInfo(tab, false, false)
				return specID, name, "", icon, ns.Layout.RoleByRetailSpec[specID] or "DAMAGER", classFile, className
			end
		end
	end
	local id, name, description, icon, role = SpecInfo(ActiveGroup())
	return id, name, description, icon, role, classFile, className
end

compat.GetSpecializationRole = function(index)
	return select(5, SpecInfo(index or ActiveGroup()))
end

compat.GetSpecializationRoleByID = function(specID)
	return ns.Layout and ns.Layout.RoleByRetailSpec[specID] or select(5, SpecInfo(ActiveGroup()))
end

compat.GetInspectSpecialization = function(unit)
	return (Traits.SpecIDForGroup(1, true))
end

compat.GetSpecializationRoleEnum = function(index)
	local role = compat.GetSpecializationRole(index)
	local roles = Enum.LFGRole or { Tank = 0, Healer = 1, Damage = 2 }
	if role == "TANK" then
		return roles.Tank
	elseif role == "HEALER" then
		return roles.Healer
	end
	return roles.Damage
end

compat.IsSpecializationActivateSpell = function(spellID)
	return spellID == 63644 or spellID == 63645
end

compat.C_SpecializationInfo = {
	GetSpecialization = compat.GetSpecialization,
	GetSpecializationInfo = compat.GetSpecializationInfo,
	IsInitialized = function()
		return true
	end,
	CanPlayerUseTalentUI = function()
		return G.UnitLevel("player") >= 10
	end,
	-- Talents (and our specialization tab) are available from level 10, dual spec or not.
	CanPlayerUseTalentSpecUI = function()
		return G.UnitLevel("player") >= 10, nil
	end,
	SetSpecialization = function(index)
		if index and index ~= ActiveGroup() and index <= NumGroups() then
			G.SetActiveTalentGroup(index)
			return true
		end
		return false
	end,
	GetSpellsDisplay = function()
		return {}
	end,
	GetClassIDFromSpecID = function(specID)
		return Traits.ClassIDForSpecID(specID) or PlayerClassID()
	end,
	IsPetSpecialization = function()
		return false
	end,
	GetPvpTalentSlotInfo = function()
		return nil
	end,
}

-- ----------------------------------------------------------------------------
-- WotLK events -> retail events
-- ----------------------------------------------------------------------------

local eventFrame = G.CreateFrame("Frame")
local refreshPending = false

local function FlushTalentRefresh()
	refreshPending = false
	Traits.OnTalentDataChanged()
end

eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PET_TALENT_UPDATE")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
	if event == "ACTIVE_TALENT_GROUP_CHANGED" then
		for _, config in pairs(configs) do
			if config.kind == "live" then
				wipe(config.staged)
				config.pendingCommit = nil
			end
		end
		local newConfigID = ActiveGroup()
		EventsFire("ACTIVE_COMBAT_CONFIG_CHANGED", newConfigID)
		EventsFire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
		EventsFire("PLAYER_SPECIALIZATION_CHANGED", "player")
		EventsFire("TRAIT_CONFIG_LIST_UPDATED")
		FlushTalentRefresh()
	elseif event == "UNIT_PET" or event == "PET_TALENT_UPDATE" then
		if event == "UNIT_PET" and arg1 ~= "player" then
			return
		end
		Traits.InvalidatePetTree()
		local petConfig = configs[CONFIG_PET]
		if petConfig and event == "UNIT_PET" then
			-- Another pet (or none): nothing staged carries over, an unfinished commit failed.
			wipe(petConfig.staged)
			if petConfig.pendingCommit then
				FinishCommit(petConfig, false)
			end
		end
		-- New committed ranks: preview-path commits resolve and staged ranks are pruned here (server
		-- commits finish on their result, which the server sends after the talent update).
		Traits.OnTalentDataChanged()
		if ns.OnPetTalentsChanged then
			ns.SafeCall(ns.OnPetTalentsChanged)
		end
	else
		-- Several of these arrive together; coalesce them into one refresh on the next frame.
		if not refreshPending then
			refreshPending = true
			G.C_Timer.After(0, FlushTalentRefresh)
		end
	end
end)
