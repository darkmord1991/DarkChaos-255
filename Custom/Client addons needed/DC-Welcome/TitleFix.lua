--[[
    DC-Welcome: TitleFix Module
    ============================
    
    Fixes player title picker errors in 3.3.5a.
    The issue: PaperDollFrame tries to access playerTitles which is nil
    Also: GetTitleName() returns nil, causing strtrim errors
    Solution: Provide fallback title data and patch PaperDollFrame functions
    
    Previously: Stand-alone DC-TitleFix addon
    Now integrated into: DC-Welcome
    
    Author: DarkChaos-255
    Date: December 2025
]]

-- Define ALL default titles for 3.3.5a (from actual Wrath titles database)
-- These serve as fallback when server data isn't available
local DEFAULT_TITLES = {
    [0] = "No Title",
    [1] = "Private %s",
    [2] = "Corporal %s",
    [3] = "Sergeant %s",
    [4] = "Master Sergeant %s",
    [5] = "Sergeant Major %s",
    [6] = "Knight %s",
    [7] = "Knight-Lieutenant %s",
    [8] = "Knight-Captain %s",
    [9] = "Knight-Champion %s",
    [10] = "Lieutenant Commander %s",
    [11] = "Commander %s",
    [12] = "Marshal %s",
    [13] = "Field Marshal %s",
    [14] = "Grand Marshal %s",
    [15] = "Scout %s",
    [16] = "Grunt %s",
    [17] = "Sergeant %s",
    [18] = "Senior Sergeant %s",
    [19] = "First Sergeant %s",
    [20] = "Stone Guard %s",
    [21] = "Blood Guard %s",
    [22] = "Legionnaire %s",
    [23] = "Centurion %s",
    [24] = "Champion %s",
    [25] = "Lieutenant General %s",
    [26] = "General %s",
    [27] = "Warlord %s",
    [28] = "High Warlord %s",
    [42] = "Gladiator %s",
    [43] = "Duelist %s",
    [44] = "Rival %s",
    [45] = "Challenger %s",
    [46] = "Scarab Lord %s",
    [47] = "Conqueror %s",
    [48] = "Justicar %s",
    [53] = "%s, Champion of the Naaru",
    [62] = "Merciless Gladiator %s",
    [63] = "%s of the Shattered Sun",
    [64] = "%s, Hand of A'dal",
    [71] = "Vengeful Gladiator %s",
    [72] = "Battlemaster %s",
    [74] = "Elder %s",
    [75] = "Flame Warden %s",
    [76] = "Flame Keeper %s",
    [77] = "%s the Exalted",
    [78] = "%s the Explorer",
    [79] = "%s the Diplomat",
    [80] = "Brutal Gladiator %s",
    [81] = "%s the Seeker",
    [82] = "Arena Master %s",
    [83] = "Salty %s",
    [84] = "Chef %s",
    [85] = "%s the Supreme",
    [86] = "%s of the Ten Storms",
    [87] = "%s of the Emerald Dream",
    [89] = "Prophet %s",
    [90] = "%s the Malefic",
    [91] = "Stalker %s",
    [92] = "%s of the Ebon Blade",
    [93] = "Archmage %s",
    [94] = "Warbringer %s",
    [95] = "Assassin %s",
    [96] = "Grand Master Alchemist %s",
    [97] = "Grand Master Blacksmith %s",
    [98] = "Iron Chef %s",
    [99] = "Grand Master Enchanter %s",
    [100] = "Grand Master Engineer %s",
    [101] = "Doctor %s",
    [102] = "Grand Master Angler %s",
    [103] = "Grand Master Herbalist %s",
    [104] = "Grand Master Scribe %s",
    [105] = "Grand Master Jewelcrafter %s",
    [106] = "Grand Master Leatherworker %s",
    [107] = "Grand Master Miner %s",
    [108] = "Grand Master Skinner %s",
    [109] = "Grand Master Tailor %s",
    [110] = "%s of Quel'Thalas",
    [111] = "%s of Argus",
    [112] = "%s of Khaz Modan",
    [113] = "%s of Gnomeregan",
    [114] = "%s the Lion Hearted",
    [115] = "%s, Champion of Elune",
    [116] = "%s, Hero of Orgrimmar",
    [117] = "Plainsrunner %s",
    [118] = "%s of the Darkspear",
    [119] = "%s the Forsaken",
    [120] = "%s the Magic Seeker",
    [121] = "Twilight Vanquisher %s",
    [122] = "%s, Conqueror of Naxxramas",
    [123] = "%s, Hero of Northrend",
    [124] = "%s the Hallowed",
    [125] = "Loremaster %s",
    [126] = "%s of the Alliance",
    [127] = "%s of the Horde",
    [128] = "%s the Flawless Victor",
    [129] = "%s, Champion of the Frozen Wastes",
    [130] = "Ambassador %s",
    [131] = "%s the Argent Champion",
    [132] = "%s, Guardian of Cenarius",
    [133] = "Brewmaster %s",
    [134] = "Merrymaker %s",
    [135] = "%s the Love Fool",
    [137] = "Matron %s",
    [138] = "Patron %s",
    [139] = "Obsidian Slayer %s",
    [140] = "%s of the Nightfall",
    [141] = "%s the Immortal",
    [142] = "%s the Undying",
    [143] = "%s Jenkins",
    [144] = "Bloodsail Admiral %s",
    [145] = "%s the Insane",
    [146] = "%s of the Exodar",
    [147] = "%s of Darnassus",
    [148] = "%s of Ironforge",
    [149] = "%s of Stormwind",
    [150] = "%s of Orgrimmar",
    [151] = "%s of Sen'jin",
    [152] = "%s of Silvermoon",
    [153] = "%s of Thunder Bluff",
    [154] = "%s of the Undercity",
    [155] = "%s the Noble",
    [156] = "Crusader %s",
    [157] = "Deadly Gladiator %s",
    [158] = "%s, Death's Demise",
    [159] = "%s the Celestial Defender",
    [160] = "%s, Conqueror of Ulduar",
    [161] = "%s, Champion of Ulduar",
    [163] = "Vanquisher %s",
    [164] = "Starcaller %s",
    [165] = "%s the Astral Walker",
    [166] = "%s, Herald of the Titans",
    [167] = "Furious Gladiator %s",
    [168] = "%s the Pilgrim",
    [169] = "Relentless Gladiator %s",
    [170] = "Grand Crusader %s",
    [171] = "%s the Argent Defender",
    [172] = "%s the Patient",
    [173] = "%s the Light of Dawn",
    [174] = "%s, Bane of the Fallen King",
    [175] = "%s the Kingslayer",
    [176] = "%s of the Ashen Verdict",
    [177] = "Wrathful Gladiator %s",
    -- Custom DarkChaos Prestige Titles
    [178] = "Prestige I %s",
    [179] = "Prestige II %s",
    [180] = "Prestige III %s",
    [181] = "Prestige IV %s",
    [182] = "Prestige V %s",
    [183] = "Prestige VI %s",
    [184] = "Prestige VII %s",
    [185] = "Prestige VIII %s",
    [186] = "Prestige IX %s",
    [187] = "Prestige X %s",
    -- Custom DarkChaos Dungeon/Achievement Titles
    [188] = "Dungeon Delver %s",
    [189] = "Stratholme Conqueror %s",
    [190] = "Molten Purifier %s",
    [191] = "Shadow Slayer %s",
    [192] = "Titan's Foe %s",
    [193] = "Crusader Supreme %s",
    [194] = "Lichborne Champion %s",
    [195] = "Crimson Protector %s",
    [196] = "Veteran Dungeon Master %s",
    [197] = "Master Dungeon Conqueror %s",
    [198] = "Elite Quest Master %s",
    [199] = "Legendary Explorer %s",
    [200] = "Speedrunner %s",
    [201] = "Speed Demon %s",
    [202] = "Loot Lord %s",
    [203] = "Collector's Pride %s",
    [204] = "Gold Rush %s",
    [205] = "Rich Adventurer %s",
    [206] = "Token Hoarder %s",
    [207] = "Token Master %s",
    [208] = "Blackrock Depths Conqueror %s",
    [209] = "Stratholme Liberator %s",
    [210] = "Molten Core Purifier %s",
    [211] = "Black Temple Destroyer %s",
    [212] = "Ulduar Titan Slayer %s",
    [213] = "Trial Champion %s",
    [214] = "Icecrown Liberator %s",
    [215] = "Ruby Sanctum Guardian %s",
    [216] = "Depths Explorer %s",
    [217] = "Strath Slayer %s",
    [218] = "Molten Expert %s",
}

-- Export for other modules
DCWelcome = DCWelcome or {}
DCWelcome.TitleFix = DCWelcome.TitleFix or {}
DCWelcome.TitleFix.DEFAULT_TITLES = DEFAULT_TITLES

local function InitializeTitleFix()
    -- LAYER 1: Initialize playerTitles global table (must exist for frame functions)
    if not _G.playerTitles then
        _G.playerTitles = {}
    end
    
    -- LAYER 2: Ensure GetNumTitles returns a safe number
    if not GetNumTitles or type(GetNumTitles) ~= "function" then
        _G.GetNumTitles = function()
            return 0
        end
    end
    
    -- LAYER 3: Create a safe wrapper for GetTitleName that NEVER returns nil
    -- This is the critical fix - strtrim() in PaperDollFrame crashes on nil
    local original_GetTitleName = _G.GetTitleName
    _G.GetTitleName = function(titleID)
        if not titleID then
            return DEFAULT_TITLES[0] or "No Title"
        end
        
        local result = nil
        
        -- Try original function if it exists
        if original_GetTitleName and type(original_GetTitleName) == "function" then
            local success, ret = pcall(original_GetTitleName, titleID)
            if success and ret then
                result = ret
            end
        end
        
        -- Return result if it's a valid string
        if result and type(result) == "string" and result ~= "" then
            return result
        end
        
        -- Fall back to default title database
        if DEFAULT_TITLES[titleID] then
            return DEFAULT_TITLES[titleID]
        end
        
        -- Last resort: generate a generic title name
        return "Title " .. tostring(titleID)
    end
    
    -- LAYER 4: Patch PlayerTitleFrame_UpdateTitles to handle nil title names
    if PlayerTitleFrame_UpdateTitles and type(PlayerTitleFrame_UpdateTitles) == "function" then
        local original_UpdateTitles = PlayerTitleFrame_UpdateTitles
        
        _G.PlayerTitleFrame_UpdateTitles = function()
            -- Ensure playerTitles exists before calling original
            if not playerTitles then
                playerTitles = {}
            end
            
            -- Wrap in pcall to catch any errors
            local success, err = pcall(function()
                original_UpdateTitles()
            end)
            
            if not success then
                -- Silent fail in integrated mode, but ensure frame is usable
                if PlayerTitlePickerScrollFrame then
                    FauxScrollFrame_SetOffset(PlayerTitlePickerScrollFrame, 0)
                end
            end
        end
    end
    
    -- LAYER 5: Patch PlayerTitlePickerScrollFrame_Update to handle nil playerTitles
    if PlayerTitlePickerScrollFrame_Update and type(PlayerTitlePickerScrollFrame_Update) == "function" then
        local original_ScrollUpdate = PlayerTitlePickerScrollFrame_Update
        
        _G.PlayerTitlePickerScrollFrame_Update = function()
            if not playerTitles then
                playerTitles = {}
            end
            
            local success, err = pcall(function()
                original_ScrollUpdate()
            end)
            
            if not success then
                -- Clear the scroll frame if error occurs
                if PlayerTitlePickerScrollFrame then
                    FauxScrollFrame_SetOffset(PlayerTitlePickerScrollFrame, 0)
                    for i = 1, 7 do
                        local button = _G["PlayerTitlePickerScrollFrameButton"..i]
                        if button then
                            button:Hide()
                        end
                    end
                end
            end
        end
    end
    
    -- LAYER 6: Patch PaperDollFrame_UpdatePortrait if it tries to use titles
    if PaperDollFrame_UpdatePortrait and type(PaperDollFrame_UpdatePortrait) == "function" then
        local original_UpdatePortrait = PaperDollFrame_UpdatePortrait
        
        _G.PaperDollFrame_UpdatePortrait = function(frame)
            if not frame then return end
            pcall(original_UpdatePortrait, frame)
        end
    end
    
    -- LAYER 7: Patch strtrim to handle nil input (catches any edge cases)
    local original_strtrim = _G.strtrim
    if original_strtrim then
        _G.strtrim = function(str, chars)
            if str == nil then
                return ""
            end
            return original_strtrim(str, chars)
        end
    end
end

-- Initialize immediately
InitializeTitleFix()

-- Also initialize on events
local titleFixFrame = CreateFrame("Frame")
titleFixFrame:RegisterEvent("ADDON_LOADED")
titleFixFrame:RegisterEvent("PLAYER_LOGIN")
titleFixFrame:RegisterEvent("CHARACTER_SHEET_OPEN")
titleFixFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "CHARACTER_SHEET_OPEN" then
        InitializeTitleFix()
    end
end)

-- Mark as loaded
DCWelcome.TitleFix.loaded = true
