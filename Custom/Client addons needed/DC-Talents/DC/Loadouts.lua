--[[
	DC-Talents - saved loadouts (the "configs" of C_ClassTalents).

	Retail keeps loadouts on the server; here they live in saved variables, per class and shared by
	all characters of that class (the DC-QOS talent manager did the same):

	  DCTalentsDB.classes[CLASS] = { nextID, order = { ids }, loadouts = { [id] = loadout } }
	  loadout = { id, name, ranks = { [talentID] = rank }, glyphs = { major = {...}, minor = {...} },
	              created, modified, favorite, source }
	  DCTalentsCharDB.lastSelected[talentGroup] = configID     (1000 + loadout id)

	C_ClassTalents calls land here (DC/Traits.lua). Old DC-QOS templates (DCQoSDB.talentTemplates,
	ranks keyed by tab and client index) are converted once per class to talent-id keyed loadouts.
]]

local _, ns = ...
setfenv(1, ns.env)

local G = ns.realG

local Loadouts = {}
ns.Loadouts = Loadouts

local MAX_LOADOUTS = Constants.TraitConsts.MAX_COMBAT_TRAIT_CONFIGS or 40
local CONFIG_BASE = ns.Traits.CONFIG_LOADOUT_BASE

local db, charDB

function ns.GetDB()
	return db
end

function ns.GetCharDB()
	return charDB
end

local function ClassFile()
	local _, classFile = G.UnitClass("player")
	return classFile
end

local function ClassData(create)
	if not db then
		return nil
	end
	local classFile = ClassFile()
	if not classFile then
		return nil
	end
	local data = db.classes[classFile]
	if not data and create ~= false then
		data = { nextID = 1, order = {}, loadouts = {} }
		db.classes[classFile] = data
	end
	return data
end

local function Fire(event, ...)
	ns.Events.Fire(event, ...)
end

-- Retail fires the create events when the server answers; do the same one frame later so callers
-- finish their own bookkeeping first (ClassTalentsFrame:OnTraitConfigCreateStarted).
local function FireNextFrame(event, ...)
	local args = { n = select("#", ...), ... }
	G.C_Timer.After(0, function()
		Fire(event, unpack(args, 1, args.n))
	end)
end

function Loadouts.Get(id)
	local data = ClassData(false)
	return data and data.loadouts[id] or nil
end

function Loadouts.GetByConfigID(configID)
	if not configID or configID < CONFIG_BASE then
		return nil
	end
	return Loadouts.Get(configID - CONFIG_BASE)
end

function Loadouts.ConfigIDFor(loadout)
	return loadout and (CONFIG_BASE + loadout.id) or nil
end

function Loadouts.GetConfigIDs()
	local list = {}
	local data = ClassData(false)
	if data then
		for _, id in ipairs(data.order) do
			if data.loadouts[id] then
				list[#list + 1] = CONFIG_BASE + id
			end
		end
	end
	return list
end

function Loadouts.Count()
	local data = ClassData(false)
	return data and #data.order or 0
end

function Loadouts.CanCreate()
	return db ~= nil and Loadouts.Count() < MAX_LOADOUTS
end

function Loadouts.GetLastSelected(group)
	local configID = charDB and charDB.lastSelected[group or 1]
	if configID and Loadouts.GetByConfigID(configID) then
		return configID
	end
	return nil
end

function Loadouts.SetLastSelected(group, configID)
	if charDB then
		charDB.lastSelected[group or 1] = configID
	end
	Fire("SELECTED_LOADOUT_CHANGED")
end

-- Glyphs are part of a DC loadout (retail has none in its talent frame): per kind, one entry per
-- socket of that kind in socket order, 0 = empty (the DC-QOS format, so migrated sets line up).
function Loadouts.SnapshotGlyphs()
	local glyphs = { major = {}, minor = {} }
	for socket = 1, (G.GetNumGlyphSockets and G.GetNumGlyphSockets() or 6) do
		local enabled, glyphType, glyphSpellID = G.GetGlyphSocketInfo(socket)
		local list = (glyphType == 1) and glyphs.major or glyphs.minor
		list[#list + 1] = (enabled and glyphSpellID) or 0
	end
	return glyphs
end

local function ActiveRanks(effective)
	local traits = ns.Traits
	local treeID = traits.GetPlayerTreeID()
	local tree = treeID and traits.GetTree(treeID)
	local config = traits.GetConfig(traits.GetActiveConfigID())
	local ranks = {}
	if tree and config then
		for _, node in pairs(tree.nodes) do
			local rank = effective and traits.EffectiveRank(config, node) or traits.CommittedRank(config, node)
			if rank > 0 then
				ranks[node.id] = rank
			end
		end
	end
	return ranks
end
Loadouts.ActiveRanks = ActiveRanks

local function UniqueName(name)
	local data = ClassData()
	local base = (name and name ~= "") and name or (ns.L and ns.L.NEW_LOADOUT or "New Loadout")
	local candidate, suffix = base, 2
	local taken = {}
	for _, loadout in pairs(data.loadouts) do
		taken[loadout.name] = true
	end
	while taken[candidate] do
		candidate = ("%s (%d)"):format(base, suffix)
		suffix = suffix + 1
	end
	return candidate
end

function Loadouts.Create(name, ranks, glyphs, source)
	local data = ClassData()
	if not data or #data.order >= MAX_LOADOUTS then
		return nil
	end
	local id = data.nextID
	data.nextID = id + 1
	local now = G.time()
	local loadout = {
		id = id,
		name = UniqueName(name),
		ranks = ranks or {},
		glyphs = glyphs,
		created = now,
		modified = now,
		source = source,
	}
	data.loadouts[id] = loadout
	data.order[#data.order + 1] = id
	return loadout
end

-- C_ClassTalents.RequestNewConfig: the new loadout takes the current build, staged changes included
-- (retail's "the new config will have all the state of the current config").
function Loadouts.CreateFromActive(name)
	local loadout = Loadouts.Create(name, ActiveRanks(true), Loadouts.SnapshotGlyphs(), "new")
	if not loadout then
		return false
	end
	local configID = CONFIG_BASE + loadout.id
	FireNextFrame("TRAIT_CONFIG_CREATED", ns.compat.C_Traits.GetConfigInfo(configID))
	FireNextFrame("TRAIT_CONFIG_LIST_UPDATED")
	return true
end

function Loadouts.CreateFromEntries(entries, name)
	local ranks = {}
	for _, entry in ipairs(entries or {}) do
		if entry.nodeID and (entry.ranksPurchased or 0) > 0 then
			ranks[entry.nodeID] = entry.ranksPurchased
		end
	end
	local loadout = Loadouts.Create(name, ranks, nil, "import")
	if not loadout then
		return false, ns.L and ns.L.ERR_TOO_MANY_LOADOUTS or nil
	end
	local configID = CONFIG_BASE + loadout.id
	FireNextFrame("TRAIT_CONFIG_CREATED", ns.compat.C_Traits.GetConfigInfo(configID))
	FireNextFrame("TRAIT_CONFIG_LIST_UPDATED")
	return true
end

function Loadouts.CreateFromRanks(name, ranks, glyphs, source)
	local loadout = Loadouts.Create(name, ranks, glyphs, source)
	if loadout then
		local configID = CONFIG_BASE + loadout.id
		FireNextFrame("TRAIT_CONFIG_CREATED", ns.compat.C_Traits.GetConfigInfo(configID))
		FireNextFrame("TRAIT_CONFIG_LIST_UPDATED")
	end
	return loadout
end

function Loadouts.SaveActiveInto(configID)
	local loadout = Loadouts.GetByConfigID(configID)
	if not loadout then
		return false
	end
	loadout.ranks = ActiveRanks(false)
	loadout.glyphs = Loadouts.SnapshotGlyphs()
	loadout.modified = G.time()
	Fire("TRAIT_CONFIG_UPDATED", configID)
	return true
end

-- A commit made with a loadout selected saves the committed build into that loadout (retail).
function Loadouts.OnCommitted(savedConfigID, ranks)
	local loadout = Loadouts.GetByConfigID(savedConfigID)
	if not loadout then
		return
	end
	loadout.ranks = {}
	for talentID, rank in pairs(ranks or {}) do
		loadout.ranks[talentID] = rank
	end
	loadout.glyphs = Loadouts.SnapshotGlyphs()
	loadout.modified = G.time()
end

function Loadouts.Rename(configID, name)
	local loadout = Loadouts.GetByConfigID(configID)
	if not loadout or not name or name == "" then
		return false
	end
	loadout.name = name
	loadout.modified = G.time()
	Fire("TRAIT_CONFIG_LIST_UPDATED")
	return true
end

function Loadouts.Delete(configID)
	local data = ClassData(false)
	local loadout = Loadouts.GetByConfigID(configID)
	if not data or not loadout then
		return false
	end
	data.loadouts[loadout.id] = nil
	for index, id in ipairs(data.order) do
		if id == loadout.id then
			table.remove(data.order, index)
			break
		end
	end
	if charDB then
		for group, selected in pairs(charDB.lastSelected) do
			if selected == configID then
				charDB.lastSelected[group] = nil
			end
		end
	end
	Fire("TRAIT_CONFIG_DELETED", configID)
	Fire("TRAIT_CONFIG_LIST_UPDATED")
	return true
end

function Loadouts.SetFavorite(configID, favorite)
	local loadout = Loadouts.GetByConfigID(configID)
	if loadout then
		loadout.favorite = favorite and true or nil
		Fire("TRAIT_CONFIG_LIST_UPDATED")
	end
end

function Loadouts.MoveTo(configID, position)
	local data = ClassData(false)
	local loadout = Loadouts.GetByConfigID(configID)
	if not data or not loadout then
		return
	end
	for index, id in ipairs(data.order) do
		if id == loadout.id then
			table.remove(data.order, index)
			break
		end
	end
	position = math.max(1, math.min(position, #data.order + 1))
	table.insert(data.order, position, loadout.id)
	Fire("TRAIT_CONFIG_LIST_UPDATED")
end

-- Retail loadout string of a config (the same bit stream ClassTalentImportExportMixin writes).
function Loadouts.GenerateImportString(configID)
	local traits = ns.Traits
	local treeID = traits.GetPlayerTreeID()
	if not treeID then
		return ""
	end
	local mixin = ClassTalentImportExportMixin
	local stream = ExportUtil.MakeExportDataStream()
	local fake = setmetatable({}, { __index = mixin })
	-- Class-wide spec id, like the export button (DC/Overrides.lua): imports on either talent group.
	fake:WriteLoadoutHeader(stream, ns.compat.C_Traits.GetLoadoutSerializationVersion(), traits.ClassSpecID(), ns.compat.C_Traits.GetTreeHash(treeID))
	fake:WriteLoadoutContent(stream, configID, treeID)
	return stream:GetExportString()
end

-- ----------------------------------------------------------------------------
-- DC-QOS migration
-- ----------------------------------------------------------------------------

local function MapClientTalentsToIDs(talents)
	local ranks = {}
	if type(talents) ~= "table" then
		return ranks
	end
	for tab = 1, (G.GetNumTalentTabs(false, false) or 0) do
		local tabRanks = talents[tab]
		if type(tabRanks) == "table" then
			for index, rank in pairs(tabRanks) do
				if type(index) == "number" and type(rank) == "number" and rank > 0 then
					local link = G.GetTalentLink(tab, index, false, false)
					local talentID = link and tonumber(link:match("talent:(%d+)"))
					if talentID then
						ranks[talentID] = rank
					end
				end
			end
		end
	end
	return ranks
end

function Loadouts.MigrateFromDCQoS()
	local classFile = ClassFile()
	if not db or not classFile or db.migratedQoS[classFile] then
		return 0
	end
	-- Needs the client's talent data (the tab/index -> talent id mapping).
	if (G.GetNumTalentTabs(false, false) or 0) == 0 or not G.GetTalentLink(1, 1, false, false) then
		return 0
	end

	local qos = G.DCQoSDB
	local templates = qos and qos.talentTemplates and qos.talentTemplates[classFile]
	local migrated = 0
	local nameToConfig = {}
	if type(templates) == "table" then
		local names = {}
		for name in pairs(templates) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local template = templates[name]
			if type(template) == "table" and type(template.talents) == "table" and not template.isBackup then
				local loadout = Loadouts.Create(template.name or name, MapClientTalentsToIDs(template.talents), template.glyphs, "dcqos")
				if loadout then
					loadout.created = template.created or loadout.created
					loadout.modified = template.modified or loadout.modified
					nameToConfig[name] = CONFIG_BASE + loadout.id
					migrated = migrated + 1
				end
			end
		end
	end

	-- The character's active loadout per talent group, if DC-QOS remembered one.
	local state = qos and qos.talentLoadoutState
	if type(state) == "table" and charDB then
		local playerName = G.UnitName("player")
		for key, entry in pairs(state) do
			if type(key) == "string" and playerName and key:find(playerName, 1, true) == 1 and type(entry) == "table" and type(entry.activeBySpec) == "table" then
				for group, name in pairs(entry.activeBySpec) do
					local configID = nameToConfig[name]
					if configID and not charDB.lastSelected[group] then
						charDB.lastSelected[group] = configID
					end
				end
			end
		end
	end

	db.migratedQoS[classFile] = true
	if migrated > 0 then
		Fire("TRAIT_CONFIG_LIST_UPDATED")
	end
	return migrated
end

-- ----------------------------------------------------------------------------
-- Saved variables
-- ----------------------------------------------------------------------------

-- Saved variables are real globals: read and write them through _G, never through our environment.
function Loadouts.OnVariablesLoaded()
	if type(G.DCTalentsDB) ~= "table" then
		G.DCTalentsDB = {}
	end
	if type(G.DCTalentsCharDB) ~= "table" then
		G.DCTalentsCharDB = {}
	end
	db = G.DCTalentsDB
	charDB = G.DCTalentsCharDB

	db.version = db.version or 1
	db.classes = db.classes or {}
	db.migratedQoS = db.migratedQoS or {}
	db.cvarBits = db.cvarBits or {}
	db.settings = db.settings or {}
	charDB.lastSelected = charDB.lastSelected or {}
	charDB.settings = charDB.settings or {}
end
