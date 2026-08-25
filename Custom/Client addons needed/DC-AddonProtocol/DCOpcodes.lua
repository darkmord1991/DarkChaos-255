-- DCOpcodes.lua - the wire contract.
--
-- Module identifiers, opcode numbers and the per-module convenience wrappers
-- every DC addon calls (DC.AOE, DC.Hotspot, DC.MythicPlus, ...). These MUST
-- match the server side (DCAddonNamespace.h); they are the shared definition of
-- the protocol, not any one addon's private data, which is why they live with
-- the transport rather than being scattered across the addons that use them.
--
-- Split out of DCAddonProtocol.lua purely to stop that file being a 5,838-line
-- catch-all. Loaded immediately after it, so DCAddonProtocol is already
-- defined. Nothing here runs at load beyond building tables: no message can
-- arrive until the client finishes loading every file in the addon.

local DC = DCAddonProtocol
if not DC then
    return
end

-- Module identifiers (must match server-side DCAddonNamespace.h)
DC.Module = {
    CORE = "CORE",
    AOE_LOOT = "AOE",
    SPECTATOR = "SPEC",
    UPGRADE = "UPG",
    HOTSPOT = "SPOT",
    HINTERLAND = "HLBG",
    DUELS = "DUEL",
    MYTHIC_PLUS = "MPLUS",
    PRESTIGE = "PRES",
    SEASONAL = "SEAS",
    RESTORE_XP = "RXP",
    LEADERBOARD = "LBRD",
    WELCOME = "WELC",
    GROUP_FINDER = "GRPF",
    GOMOVE = "GOMV",
    TELEPORTS = "TELE",
    MAP_POI = "MPOI",
    QUEST_NAV = "QNAV",
    ENCOUNTERS = "DENC",
    EVENTS = "EVNT",
    WORLD = "WRLD",
    COLLECTION = "COLL",
    QOS = "QOS",
    QUEST_POPUPS = "QPOP",
}

-- Opcode definitions for each module (must match server-side DCAddonNamespace.h)
DC.Opcode = {
    Core = {
        CMSG_HANDSHAKE = 0x01,
        CMSG_VERSION_CHECK = 0x02,
        CMSG_FEATURE_QUERY = 0x03,
        SMSG_HANDSHAKE_ACK = 0x10,
        SMSG_VERSION_RESULT = 0x11,
        SMSG_FEATURE_LIST = 0x12,
        SMSG_RELOAD_UI = 0x13,
        SMSG_SERVER_CONTEXT = 0x14,
        SMSG_CROSS_EVENT = 0x15,
        SMSG_PERMISSION_DENIED = 0x1E,
        SMSG_ERROR = 0x1F,
    },
    AOE = {
        CMSG_TOGGLE_ENABLED = 0x01,
        CMSG_SET_QUALITY = 0x02,
        CMSG_GET_STATS = 0x03,
        CMSG_SET_AUTO_SKIN = 0x04,
        CMSG_SET_RANGE = 0x05,
        CMSG_GET_SETTINGS = 0x06,
        CMSG_IGNORE_ITEM = 0x07,
        CMSG_GET_QUALITY_STATS = 0x08,
        SMSG_STATS = 0x10,
        SMSG_SETTINGS_SYNC = 0x11,
        SMSG_LOOT_RESULT = 0x12,
        SMSG_GOLD_COLLECTED = 0x13,
        SMSG_QUALITY_STATS = 0x14,
    },
    GOMove = {
        CMSG_REQUEST_MOVE = 0x01,
        CMSG_REQUEST_SEARCH = 0x02,
        CMSG_REQUEST_TELE_SYNC = 0x03,
        SMSG_MOVE_RESULT = 0x10,
        SMSG_SEARCH_RESULT = 0x11,
        SMSG_TELE_LIST = 0x12,
    },
    Hotspot = {
        CMSG_GET_LIST = 0x01,
        CMSG_GET_INFO = 0x02,
        CMSG_TELEPORT = 0x03,
        CMSG_TOGGLE_PINS = 0x04,
        SMSG_HOTSPOT_LIST = 0x10,
        SMSG_HOTSPOT_INFO = 0x11,
        SMSG_HOTSPOT_SPAWN = 0x12,
        SMSG_HOTSPOT_EXPIRE = 0x13,
        SMSG_TELEPORT_RESULT = 0x14,
    },
    Upgrade = {
        CMSG_GET_ITEM_INFO = 0x01,
        CMSG_DO_UPGRADE = 0x02,
        CMSG_LIST_UPGRADEABLE = 0x03,
        CMSG_GET_COSTS = 0x04,
        CMSG_PACKAGE_SELECT = 0x05,
        SMSG_ITEM_INFO = 0x10,
        SMSG_UPGRADE_RESULT = 0x11,
        SMSG_UPGRADEABLE_LIST = 0x12,
        SMSG_COST_INFO = 0x13,
        SMSG_CURRENCY_UPDATE = 0x14,
        SMSG_PACKAGE_SELECTED = 0x15,
        -- Transmutation
        CMSG_GET_TRANSMUTE_INFO = 0x20,
        CMSG_DO_TRANSMUTE = 0x21,
        SMSG_TRANSMUTE_INFO = 0x30,
        SMSG_TRANSMUTE_RESULT = 0x31,
        SMSG_OPEN_TRANSMUTE_UI = 0x32,
    },
    Spec = {
        CMSG_REQUEST_SPECTATE = 0x01,
        CMSG_STOP_SPECTATE = 0x02,
        CMSG_LIST_RUNS = 0x03,
        CMSG_SET_HUD_OPTION = 0x04,
        CMSG_SWITCH_TARGET = 0x05,
        SMSG_SPECTATE_START = 0x10,
        SMSG_SPECTATE_STOP = 0x11,
        SMSG_RUN_LIST = 0x12,
        SMSG_HUD_UPDATE = 0x13,
        SMSG_PLAYER_STATS = 0x14,
        SMSG_BOSS_UPDATE = 0x15,
        SMSG_TIMER_SYNC = 0x16,
        SMSG_DEATH_COUNT = 0x17,
    },
    Duel = {
        CMSG_GET_STATS = 0x01,
        CMSG_GET_LEADERBOARD = 0x02,
        CMSG_SPECTATE_DUEL = 0x03,
        SMSG_STATS = 0x10,
        SMSG_LEADERBOARD = 0x11,
        SMSG_DUEL_START = 0x12,
        SMSG_DUEL_END = 0x13,
        SMSG_DUEL_UPDATE = 0x14,
    },
    MPlus = {
        CMSG_GET_KEY_INFO = 0x01,
        CMSG_GET_AFFIXES = 0x02,
        CMSG_GET_BEST_RUNS = 0x03,
        CMSG_GET_KEYSTONE_LIST = 0x04,
        CMSG_REQUEST_HUD = 0x05,
        CMSG_GET_VAULT_INFO = 0x06,
        CMSG_CLAIM_VAULT_REWARD = 0x07,
        SMSG_KEY_INFO = 0x10,
        SMSG_AFFIXES = 0x11,
        SMSG_BEST_RUNS = 0x12,
        SMSG_RUN_START = 0x13,
        SMSG_RUN_END = 0x14,
        SMSG_TIMER_UPDATE = 0x15,
        SMSG_OBJECTIVE_UPDATE = 0x16,
        SMSG_KEYSTONE_LIST = 0x17,
        SMSG_VAULT_INFO = 0x18,
        SMSG_CLAIM_VAULT_RESULT = 0x19,
        -- Token Vendor UI
        SMSG_TOKEN_VENDOR_OPEN = 0x80,
        CMSG_TOKEN_VENDOR_CHOICES = 0x81,
        SMSG_TOKEN_VENDOR_CHOICES = 0x82,
        CMSG_TOKEN_VENDOR_BUY = 0x83,
        SMSG_TOKEN_VENDOR_RESULT = 0x84,
        CMSG_TOKEN_VENDOR_EXCHANGE = 0x85,
        SMSG_TOKEN_VENDOR_STATE = 0x86,
        -- Seasonal Dungeon Teleporter UI
        SMSG_SEASONAL_PORTAL_OPEN = 0x90,
        CMSG_SEASONAL_PORTAL_TELEPORT = 0x91,
        SMSG_SEASONAL_PORTAL_RESULT = 0x92,
    },
    Prestige = {
        CMSG_GET_INFO = 0x01,
        CMSG_GET_BONUSES = 0x02,
        SMSG_INFO = 0x10,
        SMSG_BONUSES = 0x11,
        SMSG_LEVEL_UP = 0x12,
    },
    Season = {
        CMSG_GET_CURRENT = 0x01,
        CMSG_GET_REWARDS = 0x02,
        CMSG_GET_PROGRESS = 0x03,
        SMSG_CURRENT_SEASON = 0x10,
        SMSG_REWARDS = 0x11,
        SMSG_PROGRESS = 0x12,
        SMSG_SEASON_END = 0x13,
    },
    HLBG = {
        CMSG_REQUEST_STATUS = 0x01,
        CMSG_REQUEST_RESOURCES = 0x02,
        CMSG_REQUEST_OBJECTIVE = 0x03,
        CMSG_QUICK_QUEUE = 0x04,
        CMSG_LEAVE_QUEUE = 0x05,
        CMSG_REQUEST_STATS = 0x06,
        SMSG_STATUS = 0x10,
        SMSG_RESOURCES = 0x11,
        SMSG_OBJECTIVE = 0x12,
        SMSG_QUEUE_UPDATE = 0x13,
        SMSG_TIMER_SYNC = 0x14,
        SMSG_TEAM_SCORE = 0x15,
        SMSG_STATS = 0x16,
        SMSG_AFFIX_INFO = 0x17,
        SMSG_MATCH_END = 0x18,
    },
    Leaderboard = {
        CMSG_GET_LEADERBOARD = 0x01,
        CMSG_GET_CATEGORIES = 0x02,
        CMSG_GET_MY_RANK = 0x03,
        CMSG_REFRESH = 0x04,
        CMSG_TEST_TABLES = 0x05,
        CMSG_GET_SEASONS = 0x06,
        CMSG_GET_MPLUS_DUNGEONS = 0x07,
        SMSG_LEADERBOARD_DATA = 0x10,
        SMSG_CATEGORIES = 0x11,
        SMSG_MY_RANK = 0x12,
        SMSG_TEST_RESULTS = 0x15,
        SMSG_SEASONS_LIST = 0x16,
        SMSG_MPLUS_DUNGEONS = 0x17,
        SMSG_ERROR = 0x1F,
    },
    Welcome = {
        CMSG_GET_SERVER_INFO = 0x01,
        CMSG_GET_FAQ = 0x02,
        CMSG_DISMISS = 0x03,
        CMSG_MARK_FEATURE_SEEN = 0x04,
        CMSG_GET_WHATS_NEW = 0x05,
        CMSG_GET_PROGRESS = 0x06,
        CMSG_GET_NPC_INFO = 0x07,
        SMSG_SHOW_WELCOME = 0x10,
        SMSG_SERVER_INFO = 0x11,
        SMSG_FAQ_DATA = 0x12,
        SMSG_FEATURE_UNLOCK = 0x13,
        SMSG_WHATS_NEW = 0x14,
        SMSG_LEVEL_MILESTONE = 0x15,
        SMSG_PROGRESS_DATA = 0x16,
        SMSG_NPC_INFO = 0x17,
    },
    Events = {
        CMSG_SUBSCRIBE = 0x01,
        CMSG_UNSUBSCRIBE = 0x02,
        SMSG_EVENT_UPDATE = 0x10,
        SMSG_EVENT_SPAWN = 0x11,
        SMSG_EVENT_REMOVE = 0x12,
    },
    Teleports = {
        CMSG_REQUEST_LIST = 0x01,
        SMSG_SEND_LIST = 0x10,
    },
    MapPOI = {
        CMSG_REQUEST_LIST = 0x01,
        CMSG_REQUEST_KNOWN_TAXI = 0x02,
        SMSG_SEND_LIST = 0x10,
        SMSG_KNOWN_TAXI = 0x11,
    },
    QuestPopups = {
        CMSG_ACCEPT_QUEST = 0x01,
        CMSG_COMPLETE_QUEST = 0x02,
        SMSG_OFFER = 0x10,
        SMSG_COMPLETE_READY = 0x11,
    },
    World = {
        CMSG_GET_CONTENT = 0x01,
        SMSG_CONTENT = 0x10,
        SMSG_UPDATE = 0x11,
    },
    Collection = {
        -- Sync/Request
        CMSG_HANDSHAKE = 0x01,
        CMSG_GET_FULL_COLLECTION = 0x02,
        CMSG_SYNC_COLLECTION = 0x03,
        CMSG_GET_STATS = 0x04,
        CMSG_GET_BONUSES = 0x05,
        CMSG_GET_DEFINITIONS = 0x06,
        CMSG_GET_COLLECTION = 0x07,
        -- Shop
        CMSG_GET_SHOP = 0x10,
        CMSG_BUY_ITEM = 0x11,
        CMSG_GET_CURRENCIES = 0x12,
        -- Wishlist
        CMSG_GET_WISHLIST = 0x20,
        CMSG_ADD_WISHLIST = 0x21,
        CMSG_REMOVE_WISHLIST = 0x22,
        -- Actions
        CMSG_USE_ITEM = 0x30,
        CMSG_SET_FAVORITE = 0x31,
        CMSG_TOGGLE_UNLOCK = 0x32,
        CMSG_SET_TRANSMOG = 0x33,
        CMSG_GET_TRANSMOG_SLOT_ITEMS = 0x34,
        CMSG_SEARCH_TRANSMOG_ITEMS = 0x35,
        CMSG_GET_COLLECTED_APPEARANCES = 0x36,
        CMSG_GET_TRANSMOG_STATE = 0x37,
        CMSG_APPLY_TRANSMOG_PREVIEW = 0x38,
        -- Server responses
        SMSG_HANDSHAKE_ACK = 0x40,
        SMSG_FULL_COLLECTION = 0x41,
        SMSG_DELTA_SYNC = 0x42,
        SMSG_STATS = 0x43,
        SMSG_BONUSES = 0x44,
        SMSG_ITEM_LEARNED = 0x45,
        SMSG_DEFINITIONS = 0x46,
        SMSG_COLLECTION = 0x47,
        SMSG_TRANSMOG_STATE = 0x48,
        SMSG_TRANSMOG_SLOT_ITEMS = 0x49,
        SMSG_COLLECTED_APPEARANCES = 0x4A,
        SMSG_ITEM_SETS = 0x4B,
        SMSG_SAVED_OUTFITS = 0x4C,
        SMSG_SHOP_DATA = 0x50,
        SMSG_PURCHASE_RESULT = 0x51,
        SMSG_CURRENCIES = 0x52,
        SMSG_WISHLIST_DATA = 0x60,
        SMSG_WISHLIST_AVAILABLE = 0x61,
        SMSG_WISHLIST_UPDATED = 0x62,
        SMSG_OPEN_UI = 0x70,
        SMSG_ERROR = 0x7F,
    },
    QOS = {
        CMSG_SYNC_SETTINGS = 0x01,
        CMSG_UPDATE_SETTING = 0x02,
        CMSG_GET_ITEM_INFO = 0x03,
        CMSG_GET_NPC_INFO = 0x04,
        CMSG_GET_SPELL_INFO = 0x05,
        CMSG_REQUEST_FEATURE = 0x06,
        CMSG_COLLECT_ALL_MAIL = 0x07,
        SMSG_SETTINGS_SYNC = 0x10,
        SMSG_SETTING_UPDATED = 0x11,
        SMSG_ITEM_INFO = 0x12,
        SMSG_NPC_INFO = 0x13,
        SMSG_SPELL_INFO = 0x14,
        SMSG_FEATURE_DATA = 0x15,
        SMSG_NOTIFICATION = 0x16,
    },
}

-- Convenience API functions for each module (JSON format by default)
DC.AOE = {
    Toggle = function(e) DC:Request("AOE", 0x01, { enabled = e }) end,
    SetQuality = function(q) DC:Request("AOE", 0x02, { quality = q }) end,
    SetAutoSkin = function(e) DC:Request("AOE", 0x04, { enabled = e }) end,
    SetRange = function(r) DC:Request("AOE", 0x05, { range = r }) end,
    GetStats = function() DC:Request("AOE", 0x03, {}) end,
    GetSettings = function() DC:Request("AOE", 0x06, {}) end,
    IgnoreItem = function(id) DC:Request("AOE", 0x07, { itemId = id }) end,
}

DC.Hotspot = {
    -- Optional v: echo the held list version; the server answers a matching
    -- version with a tiny { unchanged = true } reply instead of the full list.
    GetList = function(v) DC:Request("SPOT", 0x01, { v = v or 0 }) end,
    GetInfo = function(id) DC:Request("SPOT", 0x02, { id = id }) end,
    Teleport = function(id) DC:Request("SPOT", 0x03, { id = id }) end,
    TogglePins = function(e) DC:Request("SPOT", 0x04, { enabled = e }) end,
}

DC.Upgrade = {
    GetItemInfo = function(bag, slot) DC:Request("UPG", 0x01, { bag = bag, slot = slot }) end,
    DoUpgrade = function(bag, slot, level) DC:Request("UPG", 0x02, { bag = bag, slot = slot, targetLevel = level }) end,
    BatchRequest = function(items) DC:Request("UPG", 0x03, { items = items }) end,
    GetCurrency = function() DC:Request("UPG", 0x04, {}) end,
    SelectPackage = function(packageId) DC:Request("UPG", 0x05, { packageId = packageId }) end,
}

DC.Spectator = {
    RequestSpectate = function(runId) DC:Request("SPEC", 0x01, { runId = runId }) end,
    StopSpectate = function() DC:Request("SPEC", 0x02, {}) end,
    ListRuns = function() DC:Request("SPEC", 0x03, {}) end,
    SetHudOption = function(opt, val) DC:Request("SPEC", 0x04, { option = opt, value = val }) end,
}

DC.MythicPlus = {
    GetKeyInfo = function() DC:Request("MPLUS", 0x01, {}) end,
    GetAffixes = function() DC:Request("MPLUS", 0x02, {}) end,
    GetBestRuns = function() DC:Request("MPLUS", 0x03, {}) end,
    GetKeystoneList = function() DC:Request("MPLUS", 0x04, {}) end,
    RequestHUD = function(reason) DC:Request("MPLUS", 0x05, { reason = reason or "client" }) end,
}

DC.Season = {
    GetCurrent = function() DC:Request("SEAS", 0x01, {}) end,
    GetRewards = function() DC:Request("SEAS", 0x02, {}) end,
    GetProgress = function() DC:Request("SEAS", 0x03, {}) end,
    ClaimReward = function(id) DC:Request("SEAS", 0x04, { rewardId = id }) end,
    GetLeaderboard = function() DC:Request("SEAS", 0x05, {}) end,
    GetChallenges = function() DC:Request("SEAS", 0x06, {}) end,
}

DC.Hinterland = {
    GetStatus = function() DC:Request("HLBG", 0x01, {}) end,
    GetResources = function() DC:Request("HLBG", 0x02, {}) end,
    GetObjective = function() DC:Request("HLBG", 0x03, {}) end,
    QuickQueue = function() DC:Request("HLBG", 0x04, {}) end,
    LeaveQueue = function() DC:Request("HLBG", 0x05, {}) end,
    GetStats = function() DC:Request("HLBG", 0x06, {}) end,
}

DC.Duel = {
    GetStats = function() DC:Request("DUEL", 0x01, {}) end,
    GetLeaderboard = function() DC:Request("DUEL", 0x02, {}) end,
    SpectateMatch = function(id) DC:Request("DUEL", 0x03, { matchId = id }) end,
}

DC.Prestige = {
    GetInfo = function() DC:Request("PRES", 0x01, {}) end,
    GetBonuses = function() DC:Request("PRES", 0x02, {}) end,
}

-- Unified Leaderboard API
DC.Leaderboard = {
    -- Request leaderboard data
    Get = function(category, subcategory, page, limit)
        DC:Request("LBRD", 0x01, {
            category = category or "mplus",
            subcategory = subcategory or "mplus_key",
            page = page or 1,
            limit = limit or 25,
            seasonId = 0,
        })
    end,
    -- Request available categories
    GetCategories = function() DC:Request("LBRD", 0x02, {}) end,
    -- Get player's rank in a category
    GetMyRank = function(category, subcategory)
        DC:Request("LBRD", 0x03, {
            category = category or "mplus",
            subcategory = subcategory or "mplus_key",
        })
    end,
    -- Force refresh
    Refresh = function() DC:Request("LBRD", 0x04, {}) end,
}

-- Welcome/First-Start API
DC.Welcome = {
    -- Request server configuration
    GetServerInfo = function() DC:Request("WELC", 0x01, {}) end,
    -- Request FAQ data (future: dynamic FAQ from server)
    GetFAQ = function() DC:Request("WELC", 0x02, {}) end,
    -- Notify server that user dismissed welcome
    Dismiss = function() DC:Request("WELC", 0x03, {}) end,
    -- Mark a feature introduction as seen
    MarkFeatureSeen = function(feature) DC:Request("WELC", 0x04, { feature = feature }) end,
    -- Request What's New content
    GetWhatsNew = function() DC:Request("WELC", 0x05, {}) end,
}

-- Group Finder API (Raid Finder + Mythic Dungeon Finder)
DC.GroupFinder = {
    -- Create a new group listing
    CreateListing = function(data)
        -- data: { dungeonId, keyLevel, note, roles = { tank, healer, dps1, dps2, dps3 } }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CREATE_LISTING, data)
    end,
    
    -- Search for groups
    Search = function(filters)
        -- filters: { dungeonId, minLevel, maxLevel, role, hasSlot }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SEARCH_LISTINGS, filters or {})
    end,
    
    -- Apply to join a group
    Apply = function(listingId, role, message)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_APPLY_TO_GROUP, {
            listingId = listingId,
            role = role,
            message = message or ""
        })
    end,
    
    -- Cancel pending application
    CancelApplication = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_APPLICATION, { listingId = listingId })
    end,
    
    -- Leader: Accept an applicant
    AcceptApplicant = function(listingId, applicantGuid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_ACCEPT_APPLICATION, {
            listingId = listingId,
            applicantGuid = applicantGuid
        })
    end,
    
    -- Leader: Decline an applicant
    DeclineApplicant = function(listingId, applicantGuid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DECLINE_APPLICATION, {
            listingId = listingId,
            applicantGuid = applicantGuid
        })
    end,
    
    -- Remove group listing (delist)
    Delist = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DELIST_GROUP, { listingId = listingId })
    end,
    
    -- Alias for Delist (backward compatibility)
    CancelListing = function(listingId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_DELIST_GROUP, { listingId = listingId })
    end,

    -- Get system info (rewards, etc)
    GetSystemInfo = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SYSTEM_INFO, {})
    end,
    
    -- Update group listing
    UpdateListing = function(listingId, data)
        data.listingId = listingId
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_UPDATE_LISTING, data)
    end,
    
    -- Get my active applications
    GetMyApplications = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_APPLICATIONS, {})
    end,
    
    -- Get player's keystone info
    GetKeystoneInfo = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_KEYSTONE, {})
    end,
    
    -- Get M+ dungeon list from database (current season)
    GetDungeonList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_DUNGEON_LIST, {})
    end,
    
    -- Get raid list from database (all eras)
    GetRaidList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_RAID_LIST, {})
    end,
    
    -- Spectator functions
    StartSpectate = function(runId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_START_SPECTATE, { runId = runId })
    end,
    
    StopSpectate = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_STOP_SPECTATE, {})
    end,
    
    GetSpectateList = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SPECTATE_LIST, {})
    end,

    -- ============================================================
    -- Auto-matchmaking queue (LFG-style)
    -- ============================================================
    -- category: 1 = dungeon (Mythic 0), 2 = raid
    -- roles: bitmask (tank=1, healer=2, dps=4)
    -- dungeonId: specific map id, or 0 for "any" (dungeons only)
    -- difficulty: dungeon/raid difficulty enum value
    -- raidSize: 10 or 25 for raids
    JoinQueue = function(category, roles, dungeonId, difficulty, raidSize)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_QUEUE_JOIN, {
            category = category or 1,
            roles = roles or 4,
            dungeonId = dungeonId or 0,
            difficulty = difficulty or 0,
            raidSize = raidSize or 0,
        })
    end,

    LeaveQueue = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_QUEUE_LEAVE, {})
    end,

    GetQueueStatus = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_QUEUE_STATUS_REQUEST, {})
    end,

    RespondToProposal = function(proposalId, accept)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_QUEUE_PROPOSAL_RESPONSE, {
            proposalId = proposalId,
            accept = accept and true or false,
        })
    end,

    -- Request the full mythic dungeon + raid catalog (dynamic from MapDifficulty).
    GetQueueCatalog = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_QUEUE_CATALOG, {})
    end,

    -- Difficulty control
    SetDifficulty = function(difficultyType, difficulty)
        -- difficultyType: "dungeon" or "raid"
        -- difficulty: "normal", "heroic", "mythic" (dungeon) or "10n", "25n", "10h", "25h" (raid)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SET_DIFFICULTY, {
            type = difficultyType,
            difficulty = difficulty
        })
    end,
    
    -- ========================================================================
    -- SCHEDULED EVENTS API
    -- ========================================================================
    
    -- Create a scheduled event
    CreateEvent = function(data)
        -- data: { eventType, dungeonId, dungeonName, keyLevel, scheduledTime (unix timestamp), maxSignups, note }
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CREATE_EVENT, data)
    end,
    
    -- Sign up for an event
    SignupEvent = function(eventId, role, note)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_SIGNUP_EVENT, {
            eventId = eventId,
            role = role or 0,
            note = note or ""
        })
    end,
    
    -- Cancel signup for an event
    CancelSignup = function(eventId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_SIGNUP, { eventId = eventId })
    end,
    
    -- Get upcoming scheduled events
    GetScheduledEvents = function(eventType)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_SCHEDULED_EVENTS, {
            eventType = eventType or 0  -- 0 = all types
        })
    end,
    
    -- Get my event signups
    GetMySignups = function()
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_GET_MY_SIGNUPS, {})
    end,
    
    -- Cancel an event (leader only)
    CancelEvent = function(eventId)
        DC:Request("GRPF", DC.GroupFinderOpcodes.CMSG_CANCEL_EVENT, { eventId = eventId })
    end,
}
