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
    
    Undead = {
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

-- ============================================================================
-- CAMERA HELPER FUNCTIONS
-- ============================================================================

-- Get camera settings for player's current race/gender and specific slot
function Wardrobe:GetCameraPosition(slotLabel)
    -- Validate input
    if not slotLabel or slotLabel == "" then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end
    
    local _, raceFileName = UnitRace("player")
    local gender = UnitSex("player") -- 2 = Male, 3 = Female
    
    if not raceFileName or not gender then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end
    
    -- Navigate database hierarchy with fallbacks
    local raceData = self.CameraDB[raceFileName] or self.CameraDB.Human
    if not raceData then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end
    
    local genderData = raceData[gender] or raceData[2]
    if not genderData then
        return { x = 1.0, y = 0, z = 0, facing = 0 }
    end
    
    -- Return slot-specific position or default full-body view
    return genderData[slotLabel] or { x = 1.2, y = 0, z = 0, facing = 0 }
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
