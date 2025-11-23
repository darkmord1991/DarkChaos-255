-- Debug: File is loading
DEFAULT_CHAT_FRAME:AddMessage("|cffff00ffConfigUI.lua is loading...|r")

local addonName = "DC-MapExtension"
local Addon, AceConfig, AceConfigDialog, AceDBOptions, Module

-- Wrapped in pcall to catch any errors during module creation
local success, err = pcall(function()
    Addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ConfigUI: Got addon reference|r")
    
    AceConfig = LibStub("AceConfig-3.0")
    AceConfigDialog = LibStub("AceConfigDialog-3.0")
    AceDBOptions = LibStub("AceDBOptions-3.0")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ConfigUI: Got all Ace3 libs|r")
    
    Module = Addon:NewModule("ConfigUI", "AceEvent-3.0")
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ConfigUI: Created module successfully|r")
end)

if not success then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DC-MapExtension ConfigUI load error: " .. tostring(err) .. "|r")
    return
end

if not Module then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ConfigUI: Module is nil after creation!|r")
    return
end

function Module:OnInitialize()
    Addon:Print("ConfigUI:OnInitialize called")
    self.options = {
        type = "group",
        name = "DC Map Extension",
        get = function(info)
            local key = info[#info]
            if key == "debug" then
                return Addon:IsDebugEnabled()
            end
            return Addon.db.profile[key]
        end,
        set = function(info, value)
            local key = info[#info]
            if key == "debug" then
                Addon:SetDebugEnabled(value)
                return
            end
            Addon.db.profile[key] = value
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
            layers = {
                type = "group",
                name = "POI Layers",
                order = 2,
                args = {},
            },
            -- Profiles will be added in SetupOptions when db is ready
        },
    }
end

function Module:OnEnable()
    self:RegisterMessage("DCMAP_LAYER_UPDATED", "RefreshLayerOptions")
    self:RegisterMessage("DCMAP_LAYER_TOGGLED", "RefreshLayerOptions")
end

function Module:SetupOptions()
    Addon:Print("SetupOptions called")
    if self.optionsRegistered then
        Addon:Print("Options already registered, skipping")
        return
    end
    if not Addon.db then
        Addon:Print("Warning: SetupOptions called before Addon.db exists")
        return
    end
    if not self.options then
        Addon:Print("Warning: SetupOptions called before Module:OnInitialize")
        return
    end
    Addon:Print("Registering options table with name: " .. tostring(Addon.constants.AddonName))
    
    -- Add profiles tab now that db exists
    if not self.options.args.profiles then
        self.options.args.profiles = AceDBOptions:GetOptionsTable(Addon.db)
        self.options.args.profiles.order = 99
    end
    
    self:RefreshLayerOptions()
    AceConfig:RegisterOptionsTable(Addon.constants.AddonName, self.options)
    AceConfigDialog:AddToBlizOptions(Addon.constants.AddonName, "DC Map Extension")
    self.optionsRegistered = true
    Addon:Print("Config options registered successfully")
end

function Module:RefreshLayerOptions()
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
end

Addon.ConfigUI = Module
