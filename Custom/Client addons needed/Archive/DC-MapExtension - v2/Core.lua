local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

local function Trim(str)
    if not str then
        return ""
    end
    return str:match("^%s*(.-)%s*$")
end

Addon.version = "0.1.0-dev"
Addon.defaults = {
    profile = {
        debug = false,
        layers = {},
        modules = {
            AtlasManager = {enabled = true},
            TextureController = {enabled = true},
            POIManager = {enabled = true},
            HotspotOverlay = {enabled = true},
            DungeonAtlas = {enabled = true},
            ZoneInfo = {enabled = true},
        },
    },
}

Addon.charDefaults = {
    profile = {
        lastMapID = nil,
        lastLayerSelection = {},
    },
}

Addon.constants = {
    SlashCommand = "dcmap",
    DebugSlash = "dcmapdebug",
    AddonName = ADDON_NAME,
}

Addon.debugger = _G.DC_DebugUtils or {}

local function GetDefaultModuleFlag(name)
    local defaults = Addon.defaults.profile.modules[name]
    if defaults and defaults.enabled ~= nil then
        return defaults.enabled
    end
    return true
end

function Addon:AttachModuleReferences()
    for name, module in self:IterateModules() do
        if type(name) == "string" and module then
            self[name] = module
        end
    end
    self:SendMessage("DCMAP_MODULE_LIST_CHANGED")
end

function Addon:GetDesiredModuleState(name)
    if not self.db then
        return GetDefaultModuleFlag(name)
    end
    local entry = self.db.profile.modules[name]
    if entry and entry.enabled ~= nil then
        return entry.enabled
    end
    return GetDefaultModuleFlag(name)
end

function Addon:IsModuleEnabled(name)
    local module = self:GetModule(name, true)
    if not module then
        return false
    end
    return module:IsEnabled()
end

function Addon:ApplyModuleState(name)
    local module = self:GetModule(name, true)
    if not module then
        return
    end
    local shouldEnable = self:GetDesiredModuleState(name)
    if shouldEnable and not module:IsEnabled() then
        module:Enable()
    elseif not shouldEnable and module:IsEnabled() then
        module:Disable()
    end
end

function Addon:ApplyAllModuleStates()
    self:AttachModuleReferences()
    for name in self:IterateModules() do
        if name ~= "ConfigUI" then
            self:ApplyModuleState(name)
        end
    end
end

function Addon:SetModuleEnabled(name, enabled)
    if not self.db then
        return
    end
    self.db.profile.modules[name] = self.db.profile.modules[name] or {}
    local desired = enabled and true or false
    self.db.profile.modules[name].enabled = desired
    local previous = self:IsModuleEnabled(name)
    self:ApplyModuleState(name)
    local current = self:IsModuleEnabled(name)
    if previous ~= current then
        self:SendMessage("DCMAP_MODULE_TOGGLED", name, current)
    end
end

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("DCMapExtensionDB", self.defaults, true)
    self.charDB = LibStub("AceDB-3.0"):New("DCMapExtensionCharDB", self.charDefaults, true)
    self.debugEnabled = self.db.profile.debug

    self:RegisterChatCommand(self.constants.SlashCommand, "HandleSlashCommand")
    self:RegisterChatCommand(self.constants.DebugSlash, "HandleDebugSlash")

    self:SendMessage("DCMAP_EXTENSION_INITIALIZED")
end

function Addon:OnEnable()
    self:SendMessage("DCMAP_EXTENSION_ENABLED")
    self:Debug("Addon enabled (version", self.version .. ")")
    
    self:ApplyAllModuleStates()

    local configModule = self:GetModule("ConfigUI", true)
    if configModule then
        if not configModule:IsEnabled() then
            configModule:Enable()
        end
        if configModule.SetupOptions then
            configModule:SetupOptions()
        end
    else
        self:Print("ConfigUI module not found. /dcmap config is unavailable.")
    end
end

function Addon:IsDebugEnabled()
    return self.debugEnabled
end

function Addon:SetDebugEnabled(enabled)
    self.debugEnabled = enabled and true or false
    self.db.profile.debug = self.debugEnabled
    self:Print(string.format("Debug mode %s", self.debugEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
end

function Addon:Debug(...)
    if not self:IsDebugEnabled() then
        return
    end
    if self.debugger and self.debugger.PrintMulti then
        self.debugger:PrintMulti(self.constants.AddonName, true, ...)
        return
    end

    if DEFAULT_CHAT_FRAME then
        local parts = {}
        for i = 1, select('#', ...) do
            parts[i] = tostring(select(i, ...))
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[" .. self.constants.AddonName .. "]|r " .. table.concat(parts, " "))
    end
end

function Addon:GetDataSet(key)
    local data = _G.DCMapExtensionData or {}
    return data[key]
end

function Addon:GetMapBounds(mapID)
    local bounds = self:GetDataSet("MapBounds") or {}
    return bounds[mapID]
end

function Addon:GetCustomMap(mapKey)
    local maps = self:GetDataSet("CustomMaps") or {}
    return maps[mapKey]
end

function Addon:GetPOIData()
    return self:GetDataSet("POIData") or {layers = {}}
end

function Addon:GetHotspotIcons()
    return self:GetDataSet("HotspotIcons") or {}
end

function Addon:HandleSlashCommand(input)
    local msg = Trim(input)
    if msg == "" or msg == "config" then
        self:OpenConfig()
        return
    end

    if msg == "debug" then
        self:SetDebugEnabled(not self:IsDebugEnabled())
        return
    end

    if msg == "status" then
        self:PrintStatus()
        return
    end

    self:Print("Unknown subcommand. Use /" .. self.constants.SlashCommand .. " config|status|debug")
end

function Addon:HandleDebugSlash(input)
    local cleaned = Trim(input)
    if cleaned ~= "" then
        self:Debug("Debug command:", cleaned)
    end
    self:SetDebugEnabled(not self:IsDebugEnabled())
end

function Addon:OpenConfig()
    local configModule = self:GetModule("ConfigUI", true)
    if configModule and configModule.SetupOptions then
        configModule:SetupOptions()
    end

    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfigDialog then
        AceConfigDialog:Open(self.constants.AddonName)
    else
        self:Print("AceConfigDialog-3.0 is required to open the configuration UI.")
    end
end

function Addon:PrintStatus()
    local lines = {
        string.format("Version: %s", self.version),
        string.format("Debug: %s", self:IsDebugEnabled() and "ON" or "OFF"),
    }
    for _, line in ipairs(lines) do
        self:Print(line)
    end
end

function Addon:RegisterPOILayer(key, layerData)
    local manager = self:GetModule("POIManager", true)
    if manager and manager.RegisterLayer then
        manager:RegisterLayer(key, layerData)
    end
end

function Addon:GetLayerState(key)
    local manager = self:GetModule("POIManager", true)
    if manager and manager.GetLayerState then
        return manager:GetLayerState(key)
    end
    return false
end

function Addon:SetLayerState(key, enabled)
    local manager = self:GetModule("POIManager", true)
    if manager and manager.SetLayerState then
        manager:SetLayerState(key, enabled)
    end
end

function Addon:IteratePOILayers()
    local manager = self:GetModule("POIManager", true)
    if manager and manager.IterateLayers then
        return manager:IterateLayers()
    end
    local function noopIterator()
        return nil
    end
    return noopIterator, nil, nil
end

-- ========================================================================
-- ConfigUI Module (embedded to guarantee availability)
-- ========================================================================
local ConfigUIModule = Addon:NewModule("ConfigUI", "AceEvent-3.0")

function ConfigUIModule:OnInitialize()
    self.options = {
        type = "group",
        name = "DC Map Extension",
        get = function(info)
            local key = info[#info]
            if key == "debug" then
                return Addon:IsDebugEnabled()
            end
            return Addon.db and Addon.db.profile[key]
        end,
        set = function(info, value)
            local key = info[#info]
            if key == "debug" then
                Addon:SetDebugEnabled(value)
                return
            end
            if Addon.db then
                Addon.db.profile[key] = value
            end
        end,
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    description = {
                        type = "description",
                        name = "Core controls for the DarkChaos map extension.",
                        order = 0,
                        fontSize = "medium",
                    },
                    debug = {
                        type = "toggle",
                        name = "Enable debug output",
                        desc = "Print verbose information to chat for troubleshooting.",
                        order = 1,
                    },
                },
            },
            modules = {
                type = "group",
                name = "Modules",
                order = 2,
                args = {},
            },
            layers = {
                type = "group",
                name = "POI Layers",
                order = 3,
                args = {},
            },
        },
    }
end

function ConfigUIModule:OnEnable()
    self:RegisterMessage("DCMAP_LAYER_UPDATED", "RefreshLayerOptions")
    self:RegisterMessage("DCMAP_LAYER_TOGGLED", "RefreshLayerOptions")
    self:RegisterMessage("DCMAP_MODULE_TOGGLED", "RefreshModuleOptions")
    self:RegisterMessage("DCMAP_MODULE_LIST_CHANGED", "RefreshModuleOptions")
end

function ConfigUIModule:SetupOptions()
    if self.optionsRegistered then
        return
    end
    if not Addon.db or not self.options then
        return
    end

    if not self.options.args.profiles then
        local AceDBOptions = LibStub("AceDBOptions-3.0", true)
        if AceDBOptions then
            self.options.args.profiles = AceDBOptions:GetOptionsTable(Addon.db)
            self.options.args.profiles.order = 99
        end
    end

    self:RefreshModuleOptions()
    self:RefreshLayerOptions()

    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfig and AceConfigDialog then
        AceConfig:RegisterOptionsTable(Addon.constants.AddonName, self.options)
        AceConfigDialog:AddToBlizOptions(Addon.constants.AddonName, "DC Map Extension")
        self.optionsRegistered = true
    end
end

function ConfigUIModule:RefreshModuleOptions()
    if not self.options or not self.options.args.modules then
        return
    end

    local group = self.options.args.modules.args
    wipe(group)

    local hasEntries = false
    for name, module in Addon:IterateModules() do
        if name ~= "ConfigUI" then
            hasEntries = true
            group[name] = {
                type = "toggle",
                name = module.displayName or module.moduleName or name,
                desc = module.description or string.format("Enable or disable the %s module.", name),
                get = function()
                    return Addon:GetDesiredModuleState(name)
                end,
                set = function(_, value)
                    Addon:SetModuleEnabled(name, value)
                end,
            }
        end
    end

    if not hasEntries then
        group.placeholder = {
            type = "description",
            name = "No optional modules registered.",
            fontSize = "medium",
        }
    end

    self:NotifyOptionsChange()
end

function ConfigUIModule:RefreshLayerOptions()
    if not self.options then
        return
    end

    local group = self.options.args.layers.args
    wipe(group)
    local hasEntries = false
    for key, layer in Addon:IteratePOILayers() do
        hasEntries = true
        group[key] = {
            type = "toggle",
            name = layer.label or key,
            desc = layer.description or "Toggle POI visibility for this layer.",
            get = function()
                return Addon:GetLayerState(key)
            end,
            set = function(_, value)
                Addon:SetLayerState(key, value)
            end,
        }
    end

    if not hasEntries then
        group.placeholder = {
            type = "description",
            name = "No layers registered yet. Modules will add layers at runtime.",
            fontSize = "medium",
        }
    end

    self:NotifyOptionsChange()
end

function ConfigUIModule:NotifyOptionsChange()
    if not self.optionsRegistered then
        return
    end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange(Addon.constants.AddonName)
    end
end

Addon.ConfigUI = ConfigUIModule
_G.DCMapExtension = Addon
