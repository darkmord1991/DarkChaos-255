-- Luacheck configuration for WoW 3.3.5a addons

std = "lua51"

-- Allow setting and accessing global variables (required for WoW addons)
ignore = {
    "11./SLASH_.*",  -- Slash command definitions
    "113",           -- Accessing undefined variable
    "211",           -- Unused local variable
    "212",           -- Unused argument
    "213",           -- Unused loop variable
    "311",           -- Value assigned to variable is unused
    "542",           -- Empty if branch
    "611",           -- Line contains only whitespace
    "612",           -- Line contains trailing whitespace
    "614",           -- Trailing whitespace in a comment
}

-- WoW API globals (commonly used functions)
read_globals = {
    -- Frame functions
    "CreateFrame",
    "GameTooltip",
    "UIParent",
    
    -- World Map
    "WorldMapFrame",
    "WorldMapDetailFrame",
    "WorldMapButton",
    "SetMapByID",
    "ToggleWorldMap",
    
    -- Minimap
    "Minimap",
    
    -- Zone functions
    "GetZoneText",
    "GetMinimapZoneText",
    "GetCurrentMapContinent",
    "GetCurrentMapZone",
    
    -- Spell/Buff functions
    "UnitBuff",
    "GetSpellTexture",
    
    -- Chat
    "DEFAULT_CHAT_FRAME",
    
    -- Utility
    "strjoin",
    "tostringall",
    "pcall",
    "GetTime",
    "GetCursorPosition",
    "GetPlayerMapPosition",
    
    -- Math
    "math",
    "string",
    "table",
    
    -- Global WoW functions
    "_G",
}

-- Addon saved variables (can be read and written)
globals = {
    "DCMapExtensionDB",
    "HotspotDisplayDB",
    "DCMapExtension_ShowStitchedMap",
    "DCMapExtension_ClearForcedMap",
    "SlashCmdList",
}

-- Files with specific rules
files["**/DC-MapExtension/*.lua"] = {
    globals = {
        "DCMapExtensionDB",
        "DCMapExtension_ShowStitchedMap",
        "DCMapExtension_ClearForcedMap",
    }
}

files["**/DC-HotspotXP/*.lua"] = {
    globals = {
        "HotspotDisplayDB",
        "SLASH_HOTSPOT1",
        "SLASH_HOTSPOT2",
        "SlashCmdList",
    }
}
