--[[
    DC-Collection UI/Wardrobe/CameraDB.lua
    =======================================
    
    Per-race, per-gender, per-slot camera positioning database for optimal
    transmog preview. Inspired by DressMe addon.
    
    Camera data structure:
    {
        x = distance,
        y = horizontal offset,
        z = vertical offset,
        facing = rotation angle (radians),
        sequence = animation sequence (optional, for grid preview)
    }
    
    Animation sequences:
    - Default: 0 (stand)
    - 3: Ready/Combat stance
    - 8: Special animation 1
    - Others: See WoW model viewer docs
]]

local DC = DCCollection
if not DC then return end

DC.Wardrobe = DC.Wardrobe or {}
local Wardrobe = DC.Wardrobe

-- ============================================================================
-- CAMERA DATABASE
-- ============================================================================

Wardrobe.CameraDB = {
    -- Format: [raceFileName][gender][slotType]
    -- gender: 2 = Male, 3 = Female
    -- slotType: Head, Shoulder, Back, Chest, etc.
    
    Human = {
        [2] = { -- Male
            Head = { x = 0.8, y = 0, z = 0.15, facing = 0, sequence = 3 , sequence = 3 },
            Shoulder = { x = 1.0, y = 0.1, z = 0.05, facing = 0.4, sequence = 3 , sequence = 3 },
            Back = { x = 1.2, y = 0, z = 0, facing = 3.14, sequence = 3 , sequence = 3 },
            Chest = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 , sequence = 3 },
            Shirt = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 , sequence = 3 },
            Tabard = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 , sequence = 3 },
            Wrist = { x = 0.9, y = 0.15, z = -0.1, facing = -0.8, sequence = 3 , sequence = 3 },
            Hands = { x = 0.9, y = 0.15, z = -0.15, facing = -1.0, sequence = 3 , sequence = 3 },
            Waist = { x = 1.0, y = 0, z = -0.15, facing = 0, sequence = 3 , sequence = 3 },
            Legs = { x = 1.2, y = 0, z = -0.3, facing = 0, sequence = 3 , sequence = 3 },
            Feet = { x = 1.0, y = 0, z = -0.65, facing = 0, sequence = 3 , sequence = 3 },
            MainHand = { x = 1.1, y = 0.2, z = -0.2, facing = -0.7, sequence = 3 , sequence = 3 },
            OffHand = { x = 1.1, y = -0.2, z = -0.2, facing = 0.7, sequence = 3 , sequence = 3 },
            Ranged = { x = 1.2, y = 0.2, z = 0, facing = 0.5, sequence = 3 , sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.75, y = 0, z = 0.12, facing = 0, sequence = 3 },
            Shoulder = { x = 0.95, y = 0.08, z = 0.03, facing = 0.35, sequence = 3 },
            Back = { x = 1.1, y = 0, z = 0, facing = 3.14, sequence = 3 },
            Chest = { x = 0.95, y = 0, z = 0, facing = 0, sequence = 3 },
            Shirt = { x = 0.95, y = 0, z = 0, facing = 0, sequence = 3 },
            Tabard = { x = 0.95, y = 0, z = 0, facing = 0, sequence = 3 },
            Wrist = { x = 0.85, y = 0.12, z = -0.08, facing = -0.75, sequence = 3 },
            Hands = { x = 0.85, y = 0.12, z = -0.12, facing = -0.9, sequence = 3 },
            Waist = { x = 0.95, y = 0, z = -0.12, facing = 0, sequence = 3 },
            Legs = { x = 1.1, y = 0, z = -0.28, facing = 0, sequence = 3 },
            Feet = { x = 0.95, y = 0, z = -0.6, facing = 0, sequence = 3 },
            MainHand = { x = 1.0, y = 0.18, z = -0.18, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.0, y = -0.18, z = -0.18, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.1, y = 0.18, z = 0, facing = 0.45, sequence = 3 },
        },
    },
    
    Dwarf = {
        [2] = { -- Male
            Head = { x = 0.75, y = 0, z = 0.08, facing = 0, sequence = 3 },
            Shoulder = { x = 0.9, y = 0.08, z = 0, facing = 0.35, sequence = 3 },
            Back = { x = 1.1, y = 0, z = -0.05, facing = 3.14, sequence = 3 },
            Chest = { x = 0.9, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Shirt = { x = 0.9, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Tabard = { x = 0.9, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Wrist = { x = 0.8, y = 0.12, z = -0.15, facing = -0.8, sequence = 3 },
            Hands = { x = 0.8, y = 0.12, z = -0.2, facing = -1.0, sequence = 3 },
            Waist = { x = 0.9, y = 0, z = -0.2, facing = 0, sequence = 3 },
            Legs = { x = 1.1, y = 0, z = -0.35, facing = 0, sequence = 3 },
            Feet = { x = 0.9, y = 0, z = -0.65, facing = 0, sequence = 3 },
            MainHand = { x = 1.0, y = 0.18, z = -0.25, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.0, y = -0.18, z = -0.25, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.1, y = 0.18, z = -0.05, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.7, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Shoulder = { x = 0.85, y = 0.07, z = -0.02, facing = 0.3, sequence = 3 },
            Back = { x = 1.0, y = 0, z = -0.07, facing = 3.14, sequence = 3 },
            Chest = { x = 0.85, y = 0, z = -0.07, facing = 0, sequence = 3 },
            Shirt = { x = 0.85, y = 0, z = -0.07, facing = 0, sequence = 3 },
            Tabard = { x = 0.85, y = 0, z = -0.07, facing = 0, sequence = 3 },
            Wrist = { x = 0.75, y = 0.1, z = -0.17, facing = -0.75, sequence = 3 },
            Hands = { x = 0.75, y = 0.1, z = -0.22, facing = -0.9, sequence = 3 },
            Waist = { x = 0.85, y = 0, z = -0.22, facing = 0, sequence = 3 },
            Legs = { x = 1.0, y = 0, z = -0.37, facing = 0, sequence = 3 },
            Feet = { x = 0.85, y = 0, z = -0.62, facing = 0, sequence = 3 },
            MainHand = { x = 0.95, y = 0.15, z = -0.27, facing = -0.65, sequence = 3 },
            OffHand = { x = 0.95, y = -0.15, z = -0.27, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.05, y = 0.15, z = -0.07, facing = 0.45, sequence = 3 },
        },
    },
    
    NightElf = {
        [2] = { -- Male
            Head = { x = 0.9, y = 0, z = 0.25, facing = 0, sequence = 3 },
            Shoulder = { x = 1.1, y = 0.12, z = 0.15, facing = 0.4, sequence = 3 },
            Back = { x = 1.3, y = 0, z = 0.05, facing = 3.14, sequence = 3 },
            Chest = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Shirt = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Tabard = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Wrist = { x = 1.0, y = 0.18, z = -0.05, facing = -0.8, sequence = 3 },
            Hands = { x = 1.0, y = 0.18, z = -0.1, facing = -1.0, sequence = 3 },
            Waist = { x = 1.1, y = 0, z = -0.1, facing = 0, sequence = 3 },
            Legs = { x = 1.3, y = 0, z = -0.25, facing = 0, sequence = 3 },
            Feet = { x = 1.1, y = 0, z = -0.6, facing = 0, sequence = 3 },
            MainHand = { x = 1.2, y = 0.22, z = -0.15, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.2, y = -0.22, z = -0.15, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.3, y = 0.22, z = 0.05, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.85, y = 0, z = 0.2, facing = 0, sequence = 3 },
            Shoulder = { x = 1.05, y = 0.1, z = 0.1, facing = 0.35, sequence = 3 },
            Back = { x = 1.2, y = 0, z = 0.02, facing = 3.14, sequence = 3 },
            Chest = { x = 1.05, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Shirt = { x = 1.05, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Tabard = { x = 1.05, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Wrist = { x = 0.95, y = 0.15, z = -0.08, facing = -0.75, sequence = 3 },
            Hands = { x = 0.95, y = 0.15, z = -0.13, facing = -0.9, sequence = 3 },
            Waist = { x = 1.05, y = 0, z = -0.13, facing = 0, sequence = 3 },
            Legs = { x = 1.2, y = 0, z = -0.28, facing = 0, sequence = 3 },
            Feet = { x = 1.05, y = 0, z = -0.58, facing = 0, sequence = 3 },
            MainHand = { x = 1.15, y = 0.2, z = -0.18, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.15, y = -0.2, z = -0.18, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.25, y = 0.2, z = 0.02, facing = 0.45, sequence = 3 },
        },
    },
    
    Gnome = {
        [2] = { -- Male
            Head = { x = 0.55, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Shoulder = { x = 0.65, y = 0.05, z = -0.1, facing = 0.3, sequence = 3 },
            Back = { x = 0.8, y = 0, z = -0.15, facing = 3.14, sequence = 3 },
            Chest = { x = 0.65, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Shirt = { x = 0.65, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Tabard = { x = 0.65, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Wrist = { x = 0.6, y = 0.08, z = -0.25, facing = -0.8, sequence = 3 },
            Hands = { x = 0.6, y = 0.08, z = -0.3, facing = -1.0, sequence = 3 },
            Waist = { x = 0.65, y = 0, z = -0.3, facing = 0, sequence = 3 },
            Legs = { x = 0.8, y = 0, z = -0.45, facing = 0, sequence = 3 },
            Feet = { x = 0.65, y = 0, z = -0.7, facing = 0, sequence = 3 },
            MainHand = { x = 0.75, y = 0.12, z = -0.35, facing = -0.7, sequence = 3 },
            OffHand = { x = 0.75, y = -0.12, z = -0.35, facing = 0.7, sequence = 3 },
            Ranged = { x = 0.8, y = 0.12, z = -0.15, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.5, y = 0, z = -0.07, facing = 0, sequence = 3 },
            Shoulder = { x = 0.6, y = 0.04, z = -0.12, facing = 0.25, sequence = 3 },
            Back = { x = 0.75, y = 0, z = -0.17, facing = 3.14, sequence = 3 },
            Chest = { x = 0.6, y = 0, z = -0.17, facing = 0, sequence = 3 },
            Shirt = { x = 0.6, y = 0, z = -0.17, facing = 0, sequence = 3 },
            Tabard = { x = 0.6, y = 0, z = -0.17, facing = 0, sequence = 3 },
            Wrist = { x = 0.55, y = 0.07, z = -0.27, facing = -0.75, sequence = 3 },
            Hands = { x = 0.55, y = 0.07, z = -0.32, facing = -0.9, sequence = 3 },
            Waist = { x = 0.6, y = 0, z = -0.32, facing = 0, sequence = 3 },
            Legs = { x = 0.75, y = 0, z = -0.47, facing = 0, sequence = 3 },
            Feet = { x = 0.6, y = 0, z = -0.68, facing = 0, sequence = 3 },
            MainHand = { x = 0.7, y = 0.1, z = -0.37, facing = -0.65, sequence = 3 },
            OffHand = { x = 0.7, y = -0.1, z = -0.37, facing = 0.65, sequence = 3 },
            Ranged = { x = 0.75, y = 0.1, z = -0.17, facing = 0.45, sequence = 3 },
        },
    },
    
    Draenei = {
        [2] = { -- Male
            Head = { x = 0.95, y = 0, z = 0.3, facing = 0, sequence = 3 },
            Shoulder = { x = 1.15, y = 0.13, z = 0.2, facing = 0.4, sequence = 3 },
            Back = { x = 1.35, y = 0, z = 0.1, facing = 3.14, sequence = 3 },
            Chest = { x = 1.15, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Shirt = { x = 1.15, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Tabard = { x = 1.15, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Wrist = { x = 1.05, y = 0.2, z = 0, facing = -0.8, sequence = 3 },
            Hands = { x = 1.05, y = 0.2, z = -0.05, facing = -1.0, sequence = 3 },
            Waist = { x = 1.15, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Legs = { x = 1.35, y = 0, z = -0.2, facing = 0, sequence = 3 },
            Feet = { x = 1.15, y = 0, z = -0.55, facing = 0, sequence = 3 },
            MainHand = { x = 1.25, y = 0.23, z = -0.1, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.25, y = -0.23, z = -0.1, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.35, y = 0.23, z = 0.1, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.9, y = 0, z = 0.25, facing = 0, sequence = 3 },
            Shoulder = { x = 1.1, y = 0.11, z = 0.15, facing = 0.35, sequence = 3 },
            Back = { x = 1.25, y = 0, z = 0.07, facing = 3.14, sequence = 3 },
            Chest = { x = 1.1, y = 0, z = 0.07, facing = 0, sequence = 3 },
            Shirt = { x = 1.1, y = 0, z = 0.07, facing = 0, sequence = 3 },
            Tabard = { x = 1.1, y = 0, z = 0.07, facing = 0, sequence = 3 },
            Wrist = { x = 1.0, y = 0.17, z = -0.03, facing = -0.75, sequence = 3 },
            Hands = { x = 1.0, y = 0.17, z = -0.08, facing = -0.9, sequence = 3 },
            Waist = { x = 1.1, y = 0, z = -0.08, facing = 0, sequence = 3 },
            Legs = { x = 1.25, y = 0, z = -0.23, facing = 0, sequence = 3 },
            Feet = { x = 1.1, y = 0, z = -0.53, facing = 0, sequence = 3 },
            MainHand = { x = 1.2, y = 0.21, z = -0.13, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.2, y = -0.21, z = -0.13, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.3, y = 0.21, z = 0.07, facing = 0.45, sequence = 3 },
        },
    },
    
    Orc = {
        [2] = { -- Male
            Head = { x = 0.85, y = 0, z = 0.2, facing = 0, sequence = 3 },
            Shoulder = { x = 1.05, y = 0.13, z = 0.1, facing = 0.4, sequence = 3 },
            Back = { x = 1.25, y = 0, z = 0, facing = 3.14, sequence = 3 },
            Chest = { x = 1.05, y = 0, z = 0, facing = 0, sequence = 3 },
            Shirt = { x = 1.05, y = 0, z = 0, facing = 0, sequence = 3 },
            Tabard = { x = 1.05, y = 0, z = 0, facing = 0, sequence = 3 },
            Wrist = { x = 0.95, y = 0.17, z = -0.1, facing = -0.8, sequence = 3 },
            Hands = { x = 0.95, y = 0.17, z = -0.15, facing = -1.0, sequence = 3 },
            Waist = { x = 1.05, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Legs = { x = 1.25, y = 0, z = -0.3, facing = 0, sequence = 3 },
            Feet = { x = 1.05, y = 0, z = -0.63, facing = 0, sequence = 3 },
            MainHand = { x = 1.15, y = 0.21, z = -0.2, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.15, y = -0.21, z = -0.2, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.25, y = 0.21, z = 0, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.8, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Shoulder = { x = 0.95, y = 0.1, z = 0.05, facing = 0.35, sequence = 3 },
            Back = { x = 1.15, y = 0, z = -0.02, facing = 3.14, sequence = 3 },
            Chest = { x = 0.95, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Shirt = { x = 0.95, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Tabard = { x = 0.95, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Wrist = { x = 0.85, y = 0.14, z = -0.12, facing = -0.75, sequence = 3 },
            Hands = { x = 0.85, y = 0.14, z = -0.17, facing = -0.9, sequence = 3 },
            Waist = { x = 0.95, y = 0, z = -0.17, facing = 0, sequence = 3 },
            Legs = { x = 1.15, y = 0, z = -0.32, facing = 0, sequence = 3 },
            Feet = { x = 0.95, y = 0, z = -0.61, facing = 0, sequence = 3 },
            MainHand = { x = 1.05, y = 0.18, z = -0.22, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.05, y = -0.18, z = -0.22, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.15, y = 0.18, z = -0.02, facing = 0.45, sequence = 3 },
        },
    },
    
    -- NOTE: the WoW client race file name for the Forsaken is "Scourge",
    -- not "Undead". Keying this as "Undead" meant every undead player silently
    -- fell back to the Human camera. Keyed correctly as "Scourge" below; an
    -- "Undead" alias is added after the table for any external callers.
    Scourge = {
        [2] = { -- Male
            Head = { x = 0.8, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Shoulder = { x = 1.0, y = 0.1, z = 0.05, facing = 0.4, sequence = 3 },
            Back = { x = 1.2, y = 0, z = 0, facing = 3.14, sequence = 3 },
            Chest = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Shirt = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Tabard = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Wrist = { x = 0.9, y = 0.15, z = -0.1, facing = -0.8, sequence = 3 },
            Hands = { x = 0.9, y = 0.15, z = -0.15, facing = -1.0, sequence = 3 },
            Waist = { x = 1.0, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Legs = { x = 1.2, y = 0, z = -0.3, facing = 0, sequence = 3 },
            Feet = { x = 1.0, y = 0, z = -0.65, facing = 0, sequence = 3 },
            MainHand = { x = 1.1, y = 0.2, z = -0.2, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.1, y = -0.2, z = -0.2, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.2, y = 0.2, z = 0, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.75, y = 0, z = 0.12, facing = 0, sequence = 3 },
            Shoulder = { x = 0.9, y = 0.08, z = 0.02, facing = 0.35, sequence = 3 },
            Back = { x = 1.1, y = 0, z = -0.02, facing = 3.14, sequence = 3 },
            Chest = { x = 0.9, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Shirt = { x = 0.9, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Tabard = { x = 0.9, y = 0, z = -0.02, facing = 0, sequence = 3 },
            Wrist = { x = 0.8, y = 0.12, z = -0.12, facing = -0.75, sequence = 3 },
            Hands = { x = 0.8, y = 0.12, z = -0.17, facing = -0.9, sequence = 3 },
            Waist = { x = 0.9, y = 0, z = -0.17, facing = 0, sequence = 3 },
            Legs = { x = 1.1, y = 0, z = -0.32, facing = 0, sequence = 3 },
            Feet = { x = 0.9, y = 0, z = -0.63, facing = 0, sequence = 3 },
            MainHand = { x = 1.0, y = 0.15, z = -0.22, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.0, y = -0.15, z = -0.22, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.1, y = 0.15, z = -0.02, facing = 0.45, sequence = 3 },
        },
    },
    
    Tauren = {
        [2] = { -- Male
            Head = { x = 1.0, y = 0, z = 0.4, facing = 0, sequence = 3 },
            Shoulder = { x = 1.2, y = 0.15, z = 0.3, facing = 0.4, sequence = 3 },
            Back = { x = 1.4, y = 0, z = 0.15, facing = 3.14, sequence = 3 },
            Chest = { x = 1.2, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Shirt = { x = 1.2, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Tabard = { x = 1.2, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Wrist = { x = 1.1, y = 0.22, z = 0.05, facing = -0.8, sequence = 3 },
            Hands = { x = 1.1, y = 0.22, z = 0, facing = -1.0, sequence = 3 },
            Waist = { x = 1.2, y = 0, z = 0, facing = 0, sequence = 3 },
            Legs = { x = 1.4, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Feet = { x = 1.2, y = 0, z = -0.5, facing = 0, sequence = 3 },
            MainHand = { x = 1.3, y = 0.25, z = -0.05, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.3, y = -0.25, z = -0.05, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.4, y = 0.25, z = 0.15, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.9, y = 0, z = 0.3, facing = 0, sequence = 3 },
            Shoulder = { x = 1.1, y = 0.12, z = 0.2, facing = 0.35, sequence = 3 },
            Back = { x = 1.3, y = 0, z = 0.1, facing = 3.14, sequence = 3 },
            Chest = { x = 1.1, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Shirt = { x = 1.1, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Tabard = { x = 1.1, y = 0, z = 0.1, facing = 0, sequence = 3 },
            Wrist = { x = 1.0, y = 0.18, z = 0, facing = -0.75, sequence = 3 },
            Hands = { x = 1.0, y = 0.18, z = -0.05, facing = -0.9, sequence = 3 },
            Waist = { x = 1.1, y = 0, z = -0.05, facing = 0, sequence = 3 },
            Legs = { x = 1.3, y = 0, z = -0.2, facing = 0, sequence = 3 },
            Feet = { x = 1.1, y = 0, z = -0.48, facing = 0, sequence = 3 },
            MainHand = { x = 1.2, y = 0.2, z = -0.1, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.2, y = -0.2, z = -0.1, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.3, y = 0.2, z = 0.1, facing = 0.45, sequence = 3 },
        },
    },
    
    Troll = {
        [2] = { -- Male
            Head = { x = 0.9, y = 0, z = 0.3, facing = 0, sequence = 3 },
            Shoulder = { x = 1.1, y = 0.13, z = 0.2, facing = 0.4, sequence = 3 },
            Back = { x = 1.3, y = 0, z = 0.05, facing = 3.14, sequence = 3 },
            Chest = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Shirt = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Tabard = { x = 1.1, y = 0, z = 0.05, facing = 0, sequence = 3 },
            Wrist = { x = 1.0, y = 0.2, z = -0.05, facing = -0.8, sequence = 3 },
            Hands = { x = 1.0, y = 0.2, z = -0.1, facing = -1.0, sequence = 3 },
            Waist = { x = 1.1, y = 0, z = -0.1, facing = 0, sequence = 3 },
            Legs = { x = 1.3, y = 0, z = -0.25, facing = 0, sequence = 3 },
            Feet = { x = 1.1, y = 0, z = -0.6, facing = 0, sequence = 3 },
            MainHand = { x = 1.2, y = 0.23, z = -0.15, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.2, y = -0.23, z = -0.15, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.3, y = 0.23, z = 0.05, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.85, y = 0, z = 0.25, facing = 0, sequence = 3 },
            Shoulder = { x = 1.0, y = 0.1, z = 0.15, facing = 0.35, sequence = 3 },
            Back = { x = 1.2, y = 0, z = 0.02, facing = 3.14, sequence = 3 },
            Chest = { x = 1.0, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Shirt = { x = 1.0, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Tabard = { x = 1.0, y = 0, z = 0.02, facing = 0, sequence = 3 },
            Wrist = { x = 0.9, y = 0.16, z = -0.08, facing = -0.75, sequence = 3 },
            Hands = { x = 0.9, y = 0.16, z = -0.13, facing = -0.9, sequence = 3 },
            Waist = { x = 1.0, y = 0, z = -0.13, facing = 0, sequence = 3 },
            Legs = { x = 1.2, y = 0, z = -0.28, facing = 0, sequence = 3 },
            Feet = { x = 1.0, y = 0, z = -0.58, facing = 0, sequence = 3 },
            MainHand = { x = 1.1, y = 0.19, z = -0.18, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.1, y = -0.19, z = -0.18, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.2, y = 0.19, z = 0.02, facing = 0.45, sequence = 3 },
        },
    },
    
    BloodElf = {
        [2] = { -- Male
            Head = { x = 0.8, y = 0, z = 0.18, facing = 0, sequence = 3 },
            Shoulder = { x = 1.0, y = 0.1, z = 0.08, facing = 0.4, sequence = 3 },
            Back = { x = 1.2, y = 0, z = 0, facing = 3.14, sequence = 3 },
            Chest = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Shirt = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Tabard = { x = 1.0, y = 0, z = 0, facing = 0, sequence = 3 },
            Wrist = { x = 0.9, y = 0.15, z = -0.1, facing = -0.8, sequence = 3 },
            Hands = { x = 0.9, y = 0.15, z = -0.15, facing = -1.0, sequence = 3 },
            Waist = { x = 1.0, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Legs = { x = 1.2, y = 0, z = -0.3, facing = 0, sequence = 3 },
            Feet = { x = 1.0, y = 0, z = -0.62, facing = 0, sequence = 3 },
            MainHand = { x = 1.1, y = 0.2, z = -0.2, facing = -0.7, sequence = 3 },
            OffHand = { x = 1.1, y = -0.2, z = -0.2, facing = 0.7, sequence = 3 },
            Ranged = { x = 1.2, y = 0.2, z = 0, facing = 0.5, sequence = 3 },
        },
        [3] = { -- Female
            Head = { x = 0.75, y = 0, z = 0.15, facing = 0, sequence = 3 },
            Shoulder = { x = 0.9, y = 0.08, z = 0.05, facing = 0.35, sequence = 3 },
            Back = { x = 1.1, y = 0, z = 0, facing = 3.14, sequence = 3 },
            Chest = { x = 0.9, y = 0, z = 0, facing = 0, sequence = 3 },
            Shirt = { x = 0.9, y = 0, z = 0, facing = 0, sequence = 3 },
            Tabard = { x = 0.9, y = 0, z = 0, facing = 0, sequence = 3 },
            Wrist = { x = 0.8, y = 0.12, z = -0.1, facing = -0.75, sequence = 3 },
            Hands = { x = 0.8, y = 0.12, z = -0.15, facing = -0.9, sequence = 3 },
            Waist = { x = 0.9, y = 0, z = -0.15, facing = 0, sequence = 3 },
            Legs = { x = 1.1, y = 0, z = -0.3, facing = 0, sequence = 3 },
            Feet = { x = 0.9, y = 0, z = -0.6, facing = 0, sequence = 3 },
            MainHand = { x = 1.0, y = 0.15, z = -0.2, facing = -0.65, sequence = 3 },
            OffHand = { x = 1.0, y = -0.15, z = -0.2, facing = 0.65, sequence = 3 },
            Ranged = { x = 1.1, y = 0.15, z = 0, facing = 0.45, sequence = 3 },
        },
    },
}

-- Backwards-compat alias: some older code/data referenced "Undead".
-- The live lookup uses the client race file name ("Scourge"), but keep this
-- pointing at the same table so nothing breaks if "Undead" is referenced.
Wardrobe.CameraDB.Undead = Wardrobe.CameraDB.Scourge

-- ============================================================================
-- CAMERA HELPER FUNCTIONS
-- ============================================================================

-- EQUIPMENT_SLOTS labels ("Main Hand"/"Off Hand") differ from the CameraDB keys
-- ("MainHand"/"OffHand"). Without this mapping those weapon slots never matched
-- and silently fell back to the full-body camera.
local SLOT_LABEL_TO_CAMKEY = {
    ["Main Hand"] = "MainHand",
    ["Off Hand"]  = "OffHand",
    ["Off-Hand"]  = "OffHand",
    ["Offhand"]   = "OffHand",
}

-- Per-weapon-subclass framing tweaks layered ON TOP of the base weapon camera,
-- expressed as offsets so we don't duplicate the whole DB. "x" is distance
-- (larger = further/zoomed out). Long weapons pull back; short ones move in.
Wardrobe.WeaponSubclassCamera = Wardrobe.WeaponSubclassCamera or {
    ["2H"]       = { x = 0.40, z = -0.05 },
    ["Polearm"]  = { x = 0.45, z = -0.05 },
    ["Staff"]    = { x = 0.45, z = -0.05 },
    ["Bow"]      = { x = 0.35 },
    ["Gun"]      = { x = 0.35 },
    ["Crossbow"] = { x = 0.40 },
    ["Dagger"]   = { x = -0.10 },
    ["Wand"]     = { x = -0.10 },
    ["Fist"]     = { x = -0.05 },
    ["Shield"]   = { x = 0.10 },
}

-- Get camera settings for player's current race/gender and specific slot.
-- Optional `subclass` (a key into WeaponSubclassCamera) layers weapon-length
-- framing offsets for the 3D grid/preview.
function Wardrobe:GetCameraPosition(slotLabel, subclass)
    -- Validate input
    if not slotLabel or slotLabel == "" then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end

    local camKey = SLOT_LABEL_TO_CAMKEY[slotLabel] or slotLabel

    local _, raceFileName = UnitRace("player")
    local gender = UnitSex("player") -- 2 = Male, 3 = Female

    if not raceFileName or not gender then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end

    -- Navigate database hierarchy with fallbacks
    local raceData = self.CameraDB[raceFileName] or self.CameraDB.Human
    local genderData = raceData and (raceData[gender] or raceData[2])
    local base = (genderData and genderData[camKey]) or { x = 1.2, y = 0, z = 0, facing = 0 }

    -- Copy so callers never mutate the shared DB entry.
    local pos = {
        x = base.x or 1.2,
        y = base.y or 0,
        z = base.z or 0,
        facing = base.facing or 0,
        sequence = base.sequence,
    }

    -- Layer weapon-subclass framing offsets when previewing a specific weapon.
    if subclass and (camKey == "MainHand" or camKey == "OffHand" or camKey == "Ranged") then
        local off = self.WeaponSubclassCamera[subclass]
        if off then
            pos.x = pos.x + (off.x or 0)
            pos.y = pos.y + (off.y or 0)
            pos.z = pos.z + (off.z or 0)
        end
    end

    return pos
end

-- Apply camera position to model
function Wardrobe:ApplyCameraPosition(model, position)
    if not model or not position then return end
    
    -- Store original position for reset
    if not model.originalPosition then
        model.originalPosition = {
            x = 0,
            y = 0,
            z = 0,
            facing = 0
        }
    end
    
    -- Apply position
    if model.SetPosition then
        model:SetPosition(position.x, position.y, position.z)
    end
    
    if model.SetFacing then
        model:SetFacing(position.facing)
    end
end

-- Reset camera to default full-body view
function Wardrobe:ResetCameraPosition(model)
    if not model then return end

    model:SetUnit("player")

    if model.SetPosition then
        model:SetPosition(1.0, 0, 0)
    end

    if model.SetFacing then
        model:SetFacing(0)
    end
end

-- ============================================================================
-- MODEL CAMERA CONTROLLER
-- Rotate (with release momentum), additive wheel zoom, and right-drag pan.
-- "x" is camera DISTANCE: smaller = closer (zoomed in), larger = further out.
-- ============================================================================

Wardrobe.MODEL_X_MIN = 0.3            -- closest the camera can get
Wardrobe.MODEL_X_MAX = 3.0            -- farthest (full zoom out)
Wardrobe.MODEL_Z_MIN = -2.0
Wardrobe.MODEL_Z_MAX = 2.0
Wardrobe.MODEL_FULLBODY = { x = 1.8, y = 0, z = -0.2, facing = 0 }
Wardrobe.MODEL_ZOOM_STEP = 0.12       -- distance change per wheel notch
-- Pull the big left-panel model back from the (tight) per-slot framing so a Head
-- selection shows head+shoulders rather than just the face. Tunable.
Wardrobe.MAIN_MODEL_ZOOMOUT = 0.4
Wardrobe.MODEL_PAN_STEP = 0.004       -- z change per pixel of vertical drag
Wardrobe.MODEL_ROT_FRICTION = 6.0     -- spin coast decay (higher = stops sooner)
Wardrobe.MODEL_SPIN_STOP = 0.05       -- rad/s below which coasting stops

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Push the model's stored camera (cameraX/Y/Z + rotation) onto the model.
function Wardrobe:_ApplyModelCamera(model)
    if not model then return end
    local x = clamp(model.cameraX or self.MODEL_FULLBODY.x, self.MODEL_X_MIN, self.MODEL_X_MAX)
    local y = model.cameraY or 0
    local z = clamp(model.cameraZ or 0, self.MODEL_Z_MIN, self.MODEL_Z_MAX)
    model.cameraX, model.cameraZ = x, z
    if model.SetPosition then model:SetPosition(x, y, z) end
    if model.SetFacing then model:SetFacing(model.rotation or 0) end
    if model._dcUpdateCamDebug then model:_dcUpdateCamDebug() end
end

-- Set the absolute base framing for a slot (resets any prior zoom/pan).
function Wardrobe:SetModelCameraFromSlot(model, slotLabel, subclass)
    if not model then return end
    local pos = self:GetCameraPosition(slotLabel, subclass)
    model.cameraX = (pos.x or self.MODEL_FULLBODY.x) + (self.MAIN_MODEL_ZOOMOUT or 0)
    model.cameraY = pos.y or 0
    model.cameraZ = pos.z or 0
    model.rotation = pos.facing or 0
    model._zoomTarget = nil  -- cancel any in-flight smooth zoom
    if pos.sequence then
        model._dcPreviewSequence = pos.sequence
    end
    self:_ApplyModelCamera(model)
    if type(self.StabilizePreviewModel) == "function" then
        self:StabilizePreviewModel(model, model._dcPreviewSequence)
    end
end

-- Wire rotate/zoom/pan handlers onto a DressUpModel. Idempotent.
function Wardrobe:_SetupModelController(model)
    if not model or model._dcControllerReady then return end
    model._dcControllerReady = true

    -- Start at a defined full-body framing so wheel-zoom/pan work immediately,
    -- before any slot is selected (cameraX previously defaulted to 0, which made
    -- the multiplicative zoom a no-op).
    model.cameraX = self.MODEL_FULLBODY.x
    model.cameraY = self.MODEL_FULLBODY.y
    model.cameraZ = self.MODEL_FULLBODY.z
    model.rotation = self.MODEL_FULLBODY.facing
    model.cameraDistance = 1.0  -- retained for any legacy reads

    model:EnableMouse(true)
    model:EnableMouseWheel(true)

    local dragging = nil       -- "rotate" | "pan" | nil
    local lastX, lastY = 0, 0
    local spinVel = 0          -- rad/s, drives coast-to-stop after a rotate drag

    model:SetScript("OnMouseDown", function(m, button)
        lastX, lastY = GetCursorPosition()
        spinVel = 0
        if button == "LeftButton" then
            dragging = "rotate"
        elseif button == "RightButton" then
            dragging = "pan"
        end
    end)

    model:SetScript("OnMouseUp", function()
        dragging = nil
    end)

    model:SetScript("OnMouseWheel", function(m, delta)
        -- Scroll up (delta > 0) = zoom in = decrease distance. Eased toward a
        -- target in OnUpdate so repeated notches feel smooth, not jumpy.
        local base = m._zoomTarget or m.cameraX or Wardrobe.MODEL_FULLBODY.x
        m._zoomTarget = clamp(base - delta * Wardrobe.MODEL_ZOOM_STEP,
            Wardrobe.MODEL_X_MIN, Wardrobe.MODEL_X_MAX)
    end)

    model:SetScript("OnUpdate", function(m, elapsed)
        elapsed = elapsed or 0.016
        local rotSpeed = Wardrobe.CAMERA_ROTATION_SPEED or 0.01
        local changed = false

        if dragging then
            local cx, cy = GetCursorPosition()
            local dx, dy = cx - lastX, cy - lastY
            lastX, lastY = cx, cy
            if dragging == "rotate" then
                local dRot = dx * rotSpeed
                m.rotation = (m.rotation or 0) + dRot
                local dt = math.max(elapsed, 0.001)
                -- Smoothed angular velocity so stutter frames don't spike release speed.
                spinVel = spinVel * 0.4 + (dRot / dt) * 0.6
                changed = true
            elseif dragging == "pan" then
                m.cameraZ = clamp((m.cameraZ or 0) + dy * Wardrobe.MODEL_PAN_STEP,
                    Wardrobe.MODEL_Z_MIN, Wardrobe.MODEL_Z_MAX)
                changed = true
            end
        else
            -- Coast to a stop with framerate-independent exponential decay.
            if math.abs(spinVel) > Wardrobe.MODEL_SPIN_STOP then
                m.rotation = (m.rotation or 0) + spinVel * elapsed
                spinVel = spinVel * math.exp(-Wardrobe.MODEL_ROT_FRICTION * elapsed)
                changed = true
            elseif spinVel ~= 0 then
                spinVel = 0
            end
        end

        -- Eased zoom toward target (works alongside rotate/pan/coast).
        local zt = m._zoomTarget
        if zt then
            local cur = m.cameraX or zt
            local diff = zt - cur
            if math.abs(diff) < 0.004 then
                m.cameraX = zt
                m._zoomTarget = nil
            else
                m.cameraX = cur + diff * (1 - math.exp(-12 * elapsed))
            end
            changed = true
        end

        if changed then
            Wardrobe:_ApplyModelCamera(m)
        end
    end)
end

-- ============================================================================
-- CAMERA DEBUG / CAPTURE OVERLAY
-- /wardrobe camdebug toggles a live x/y/z/facing readout on the model;
-- /wardrobe camdump prints a ready-to-paste CameraDB line for the current slot.
-- ============================================================================

function Wardrobe:ToggleCameraDebug()
    local model = self.frame and self.frame.model
    if not model then
        if DC and DC.Print then DC:Print("Open the wardrobe first (/wardrobe).") end
        return
    end

    if model._dcCamDebugText then
        model._dcCamDebugText:Hide()
        model._dcCamDebugText = nil
        model._dcUpdateCamDebug = nil
        if DC and DC.Print then DC:Print("Wardrobe camera debug: off") end
        return
    end

    local host = model:GetParent() or model
    local fs = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", model, "TOPLEFT", 4, -4)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.2, 1, 0.2)
    model._dcCamDebugText = fs
    model._dcUpdateCamDebug = function(m)
        local x, y, z = 0, 0, 0
        if m.GetPosition then x, y, z = m:GetPosition() end
        fs:SetFormattedText("slot: %s\nx=%.3f  y=%.3f  z=%.3f\nfacing=%.3f",
            (self.selectedSlot and self.selectedSlot.label) or "(none)",
            x or 0, y or 0, z or 0, m.rotation or 0)
    end
    model._dcUpdateCamDebug(model)

    if DC and DC.Print then
        DC:Print("Wardrobe camera debug: on. Pick a slot, frame it with drag/zoom/pan, then /wardrobe camdump.")
    end
end

function Wardrobe:DumpCameraForSelectedSlot()
    local model = self.frame and self.frame.model
    if not model then
        if DC and DC.Print then DC:Print("Open the wardrobe first (/wardrobe).") end
        return
    end
    local label = (self.selectedSlot and self.selectedSlot.label) or "(none)"
    local x, y, z = model.cameraX or 0, model.cameraY or 0, model.cameraZ or 0
    if model.GetPosition then x, y, z = model:GetPosition() end
    local _, race = UnitRace("player")
    local sexId = UnitSex("player")
    local line = string.format(
        "%s [%s][%d] = { x = %.3f, y = %.3f, z = %.3f, facing = %.3f, sequence = %d },",
        label, tostring(race), sexId or 0, x or 0, y or 0, z or 0,
        model.rotation or 0, model._dcPreviewSequence or 0)
    if DC and DC.Print then DC:Print(line) end
end
