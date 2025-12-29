-- =============================================================================
-- Retail UI Port - Configuration
-- =============================================================================
-- This file controls the visual appearance and behavior of the custom GlueXML.
-- It is designed to be easily editable by server administrators.

RetailUI_Config = {
    -- -------------------------------------------------------------------------
    -- General Settings
    -- -------------------------------------------------------------------------
    General = {
        ServerName = "DarkChaos-255",
        Realmlist = "logon.darkchaos.com",
        DiscordURL = "discord.gg/darkchaos",
        WebsiteURL = "www.darkchaos.com",
        
        -- Font to use for main UI elements
        MainFont = "Interface\\Custom\\Fonts\\Retail_UI.ttf",
    },

    -- -------------------------------------------------------------------------
    -- Login Screen
    -- -------------------------------------------------------------------------
    Login = {
        -- Background image (must be BLP, 1920x1080 recommended)
        Background = "Interface\\Custom\\Login\\Background_Dragonflight",
        
        -- Server Logo (centered or top-left)
        Logo = "Interface\\Custom\\Login\\Logo_DarkChaos",
        LogoScale = 1.2,
        
        -- Music file (MP3)
        Music = "Sound\\Music\\GlueScreenMusic\\Dragonflight_Theme.mp3",
        
        -- Enable "News" panel on the left side
        ShowNews = true,
        NewsTitle = "Latest Updates",
        NewsContent = {
            "• New Level 255 Cap Unlocked!",
            "• Mythic+ Dungeons Available",
            "• Custom Transmog System Live",
        },
    },

    -- -------------------------------------------------------------------------
    -- Character Selection (Warband Style)
    -- -------------------------------------------------------------------------
    CharSelect = {
        -- Use the "Campfire" scene style
        Style = "Warband", -- Options: "Classic", "Warband", "Racial"
        
        -- Background model (m2) for the scene
        SceneModel = "Interface\\Custom\\Models\\WarbandScene.m2",
        
        -- Lighting settings (Ambient, Diffuse)
        Lighting = {
            Ambient = {0.3, 0.3, 0.3},
            Diffuse = {0.8, 0.8, 0.8},
            Direction = { -1, -1, -1 }
        }
    },

    -- -------------------------------------------------------------------------
    -- Character Creation
    -- -------------------------------------------------------------------------
    CharCreate = {
        -- Enable "Class Trial" button (even if fake/scripted)
        ShowClassTrial = false,
        
        -- Custom Race Descriptions
        RaceDescriptions = {
            [1] = "Humans are versatile and resilient...", -- Human
            [2] = "Orcs are savage and honorable...",      -- Orc
            -- ...
        },
        
        -- Custom Class Descriptions
        ClassDescriptions = {
            [1] = "Warriors combine strength...",          -- Warrior
            -- ...
        }
    },

    -- -------------------------------------------------------------------------
    -- Realm Selection
    -- -------------------------------------------------------------------------
    RealmList = {
        -- Show "Population" as a progress bar instead of text
        UseProgressBar = true,
        
        -- Custom Realm Type names (e.g., "Funserver" instead of "PVP")
        CustomTypes = {
            [0] = "Normal",
            [1] = "PvP",
            [6] = "Funserver",
            [8] = "Seasonal"
        }
    }
};
