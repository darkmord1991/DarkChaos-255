/*
 * Dark Chaos - Unified Addon Communication Namespace
 * =====================================================
 * 
 * This header defines the unified DCAddon namespace for all client-server
 * addon communication in Dark Chaos.
 * 
 * Architecture:
 * - All DC addon messages use the unified "DC" prefix
 * - Subsystems are identified by MODULE byte in the message
 * - Coexists with AIO (SAIO/CAIO) without conflict
 * 
 * Message Format:
 * Simple: DC|MODULE|OPCODE|DATA1|DATA2|...
 * JSON:   DC|MODULE|OPCODE|J|{"key":"value",...}
 * 
 * Where MODULE is one of:
 * - AOE  (AOE Loot system)
 * - SPEC (Mythic+ Spectator)
 * - UPG  (Item Upgrade)
 * - HLBG (Hinterland BG)
 * - DUEL (Phased Duels)
 * - MPLUS (Mythic+ general)
 * - PRES (Prestige system)
 * - SEAS (Seasonal system)
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#ifndef DC_ADDON_NAMESPACE_H
#define DC_ADDON_NAMESPACE_H

#include "Player.h"
#include "Chat.h"
#include "WorldPacket.h"
#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <sstream>
#include <map>

namespace DCAddon
{
    // ========================================================================
    // CONSTANTS
    // ========================================================================
    
    // The unified DC addon prefix - ALL DC messages use this
    constexpr const char* DC_PREFIX = "DC";
    
    // Message delimiter
    constexpr char DELIMITER = '|';
    
    // WoW 3.3.5a message limits
    constexpr uint32 MAX_CLIENT_MSG_SIZE = 255;
    constexpr uint32 MAX_SERVER_MSG_SIZE = 2560;
    
    // Module identifiers (first field after prefix)
    namespace Module
    {
        constexpr const char* AOE_LOOT      = "AOE";
        constexpr const char* SPECTATOR     = "SPEC";
        constexpr const char* UPGRADE       = "UPG";
        constexpr const char* HINTERLAND    = "HLBG";
        constexpr const char* HINTERLAND_BG = "HLBG";  // Alias
        constexpr const char* PHASED_DUELS  = "DUEL";
        constexpr const char* MYTHIC_PLUS   = "MPLUS";
        constexpr const char* PRESTIGE      = "PRES";
        constexpr const char* SEASONAL      = "SEAS";
        constexpr const char* CORE          = "CORE";   // Handshake, version check
        constexpr const char* HOTSPOT       = "SPOT";   // Hotspot/XP zones
        constexpr const char* LEADERBOARD   = "LBRD";   // Unified leaderboards
        constexpr const char* WELCOME       = "WELC";   // First-start/welcome system
        constexpr const char* GROUP_FINDER  = "GRPF";   // Group Finder (M+, Raid Finder)
    }
    
    // ========================================================================
    // OPCODES BY MODULE
    // ========================================================================
    
    namespace Opcode
    {
        // Core/Handshake opcodes
        namespace Core
        {
            constexpr uint8 CMSG_HANDSHAKE         = 0x01;  // Client says hello
            constexpr uint8 CMSG_VERSION_CHECK     = 0x02;  // Client sends version
            constexpr uint8 CMSG_FEATURE_QUERY     = 0x03;  // Client asks what's enabled
            
            constexpr uint8 SMSG_HANDSHAKE_ACK     = 0x10;  // Server acknowledges
            constexpr uint8 SMSG_VERSION_RESULT    = 0x11;  // Server version check result
            constexpr uint8 SMSG_FEATURE_LIST      = 0x12;  // Server sends enabled features
            constexpr uint8 SMSG_RELOAD_UI         = 0x13;  // Server tells client to reload
        }
        
        // AOE Loot opcodes
        namespace AOE
        {
            constexpr uint8 CMSG_TOGGLE_ENABLED    = 0x01;
            constexpr uint8 CMSG_SET_QUALITY       = 0x02;
            constexpr uint8 CMSG_GET_STATS         = 0x03;
            constexpr uint8 CMSG_SET_AUTO_SKIN     = 0x04;
            constexpr uint8 CMSG_SET_RANGE         = 0x05;
            constexpr uint8 CMSG_GET_SETTINGS      = 0x06;
            constexpr uint8 CMSG_IGNORE_ITEM       = 0x07;
            constexpr uint8 CMSG_GET_QUALITY_STATS = 0x08;  // Request quality breakdown
            
            constexpr uint8 SMSG_STATS             = 0x10;
            constexpr uint8 SMSG_SETTINGS_SYNC     = 0x11;
            constexpr uint8 SMSG_LOOT_RESULT       = 0x12;
            constexpr uint8 SMSG_GOLD_COLLECTED    = 0x13;
            constexpr uint8 SMSG_QUALITY_STATS     = 0x14;  // Quality breakdown response
        }
        
        // Spectator opcodes
        namespace Spec
        {
            constexpr uint8 CMSG_REQUEST_SPECTATE  = 0x01;
            constexpr uint8 CMSG_STOP_SPECTATE     = 0x02;
            constexpr uint8 CMSG_LIST_RUNS         = 0x03;
            constexpr uint8 CMSG_SET_HUD_OPTION    = 0x04;
            constexpr uint8 CMSG_SWITCH_TARGET     = 0x05;
            
            constexpr uint8 SMSG_SPECTATE_START    = 0x10;
            constexpr uint8 SMSG_SPECTATE_STOP     = 0x11;
            constexpr uint8 SMSG_RUN_LIST          = 0x12;
            constexpr uint8 SMSG_HUD_UPDATE        = 0x13;
            constexpr uint8 SMSG_PLAYER_STATS      = 0x14;
            constexpr uint8 SMSG_BOSS_UPDATE       = 0x15;
            constexpr uint8 SMSG_TIMER_SYNC        = 0x16;
            constexpr uint8 SMSG_DEATH_COUNT       = 0x17;
        }
        
        // Item Upgrade opcodes
        namespace Upgrade
        {
            constexpr uint8 CMSG_GET_ITEM_INFO     = 0x01;
            constexpr uint8 CMSG_DO_UPGRADE        = 0x02;
            constexpr uint8 CMSG_LIST_UPGRADEABLE  = 0x03;
            constexpr uint8 CMSG_GET_COSTS         = 0x04;
            
            constexpr uint8 SMSG_ITEM_INFO         = 0x10;
            constexpr uint8 SMSG_UPGRADE_RESULT    = 0x11;
            constexpr uint8 SMSG_UPGRADEABLE_LIST  = 0x12;
            constexpr uint8 SMSG_COST_INFO         = 0x13;
            constexpr uint8 SMSG_CURRENCY_UPDATE   = 0x14;
        }
        
        // Phased Duels opcodes
        namespace Duel
        {
            constexpr uint8 CMSG_GET_STATS         = 0x01;
            constexpr uint8 CMSG_GET_LEADERBOARD   = 0x02;
            constexpr uint8 CMSG_SPECTATE_DUEL     = 0x03;
            
            constexpr uint8 SMSG_STATS             = 0x10;
            constexpr uint8 SMSG_LEADERBOARD       = 0x11;
            constexpr uint8 SMSG_DUEL_START        = 0x12;
            constexpr uint8 SMSG_DUEL_END          = 0x13;
            constexpr uint8 SMSG_DUEL_UPDATE       = 0x14;
        }
        
        // Mythic+ opcodes
        namespace MPlus
        {
            constexpr uint8 CMSG_GET_KEY_INFO      = 0x01;
            constexpr uint8 CMSG_GET_AFFIXES       = 0x02;
            constexpr uint8 CMSG_GET_BEST_RUNS     = 0x03;
            
            constexpr uint8 SMSG_KEY_INFO          = 0x10;
            constexpr uint8 SMSG_AFFIXES           = 0x11;
            constexpr uint8 SMSG_BEST_RUNS         = 0x12;
            constexpr uint8 SMSG_RUN_START         = 0x13;
            constexpr uint8 SMSG_RUN_END           = 0x14;
            constexpr uint8 SMSG_TIMER_UPDATE      = 0x15;
            constexpr uint8 SMSG_OBJECTIVE_UPDATE  = 0x16;
        }
        
        // Prestige opcodes
        namespace Prestige
        {
            constexpr uint8 CMSG_GET_INFO          = 0x01;
            constexpr uint8 CMSG_GET_BONUSES       = 0x02;
            
            constexpr uint8 SMSG_INFO              = 0x10;
            constexpr uint8 SMSG_BONUSES           = 0x11;
            constexpr uint8 SMSG_LEVEL_UP          = 0x12;
        }
        
        // Seasonal opcodes
        namespace Season
        {
            constexpr uint8 CMSG_GET_CURRENT       = 0x01;
            constexpr uint8 CMSG_GET_REWARDS       = 0x02;
            constexpr uint8 CMSG_GET_PROGRESS      = 0x03;
            
            constexpr uint8 SMSG_CURRENT_SEASON    = 0x10;
            constexpr uint8 SMSG_REWARDS           = 0x11;
            constexpr uint8 SMSG_PROGRESS          = 0x12;
            constexpr uint8 SMSG_SEASON_END        = 0x13;
        }
        
        // Hotspot opcodes (XP bonus zones)
        namespace Hotspot
        {
            constexpr uint8 CMSG_REQUEST_LIST      = 0x01;
            constexpr uint8 CMSG_TELEPORT          = 0x02;
            constexpr uint8 CMSG_TOGGLE_PINS       = 0x03;
            
            constexpr uint8 SMSG_LIST              = 0x10;
            constexpr uint8 SMSG_NEW_HOTSPOT       = 0x11;
            constexpr uint8 SMSG_HOTSPOT_EXPIRED   = 0x12;
            constexpr uint8 SMSG_TELEPORT_RESULT   = 0x13;
            constexpr uint8 SMSG_ENTERED_HOTSPOT   = 0x14;
            constexpr uint8 SMSG_LEFT_HOTSPOT      = 0x15;
        }
        
        // Hinterland BG opcodes
        namespace HLBG
        {
            constexpr uint8 CMSG_REQUEST_STATUS    = 0x01;
            constexpr uint8 CMSG_REQUEST_RESOURCES = 0x02;
            constexpr uint8 CMSG_REQUEST_OBJECTIVE = 0x03;
            constexpr uint8 CMSG_QUICK_QUEUE       = 0x04;
            constexpr uint8 CMSG_LEAVE_QUEUE       = 0x05;
            constexpr uint8 CMSG_REQUEST_STATS     = 0x06;
            
            constexpr uint8 SMSG_STATUS            = 0x10;
            constexpr uint8 SMSG_RESOURCES         = 0x11;
            constexpr uint8 SMSG_OBJECTIVE         = 0x12;
            constexpr uint8 SMSG_QUEUE_UPDATE      = 0x13;
            constexpr uint8 SMSG_TIMER_SYNC        = 0x14;
            constexpr uint8 SMSG_TEAM_SCORE        = 0x15;
            constexpr uint8 SMSG_STATS             = 0x16;
            constexpr uint8 SMSG_AFFIX_INFO        = 0x17;
            constexpr uint8 SMSG_MATCH_END         = 0x18;
        }
        
        // Unified Leaderboard opcodes
        namespace Leaderboard
        {
            constexpr uint8 CMSG_GET_LEADERBOARD   = 0x01;  // Request leaderboard data
            constexpr uint8 CMSG_GET_CATEGORIES    = 0x02;  // Request available categories
            constexpr uint8 CMSG_GET_MY_RANK       = 0x03;  // Request player's rank
            constexpr uint8 CMSG_REFRESH           = 0x04;  // Force refresh
            constexpr uint8 CMSG_TEST_TABLES       = 0x05;  // Test database tables (debug)
            constexpr uint8 CMSG_GET_SEASONS       = 0x06;  // Get available seasons
            
            constexpr uint8 SMSG_LEADERBOARD_DATA  = 0x10;  // Leaderboard response
            constexpr uint8 SMSG_CATEGORIES        = 0x11;  // Available categories
            constexpr uint8 SMSG_MY_RANK           = 0x12;  // Player's rank info
            constexpr uint8 SMSG_TEST_RESULTS      = 0x15;  // Database test results
            constexpr uint8 SMSG_SEASONS_LIST      = 0x16;  // Available seasons list
            constexpr uint8 SMSG_ERROR             = 0x1F;  // Error response
        }
        
        // Welcome/First-Start opcodes
        namespace Welcome
        {
            constexpr uint8 CMSG_GET_SERVER_INFO   = 0x01;  // Request server configuration
            constexpr uint8 CMSG_GET_FAQ           = 0x02;  // Request FAQ data
            constexpr uint8 CMSG_DISMISS_WELCOME   = 0x03;  // User dismissed welcome
            constexpr uint8 CMSG_MARK_FEATURE_SEEN = 0x04;  // User saw feature intro
            constexpr uint8 CMSG_GET_WHATS_NEW     = 0x05;  // Request what's new content
            
            constexpr uint8 SMSG_SHOW_WELCOME      = 0x10;  // Trigger welcome popup
            constexpr uint8 SMSG_SERVER_INFO       = 0x11;  // Server configuration
            constexpr uint8 SMSG_FAQ_DATA          = 0x12;  // FAQ content
            constexpr uint8 SMSG_FEATURE_UNLOCK    = 0x13;  // Feature unlocked notification
            constexpr uint8 SMSG_WHATS_NEW         = 0x14;  // What's new content
            constexpr uint8 SMSG_LEVEL_MILESTONE   = 0x15;  // Level milestone reached
        }
        
        // Group Finder opcodes (M+, Raid Finder, Scheduled Events)
        namespace GroupFinder
        {
            // Client -> Server: Listings
            constexpr uint8 CMSG_CREATE_LISTING      = 0x10;  // Create a new group listing
            constexpr uint8 CMSG_SEARCH_LISTINGS     = 0x11;  // Search for groups
            constexpr uint8 CMSG_APPLY_TO_GROUP      = 0x12;  // Apply to join a group
            constexpr uint8 CMSG_CANCEL_APPLICATION  = 0x13;  // Cancel pending application
            constexpr uint8 CMSG_ACCEPT_APPLICATION  = 0x14;  // Leader accepts an applicant
            constexpr uint8 CMSG_DECLINE_APPLICATION = 0x15;  // Leader declines an applicant
            constexpr uint8 CMSG_DELIST_GROUP        = 0x16;  // Remove group listing
            constexpr uint8 CMSG_UPDATE_LISTING      = 0x17;  // Update group listing
            
            // Client -> Server: Keystone & Difficulty
            constexpr uint8 CMSG_GET_MY_KEYSTONE     = 0x20;  // Request player's keystone info
            constexpr uint8 CMSG_SET_DIFFICULTY      = 0x21;  // Request difficulty change
            constexpr uint8 CMSG_GET_DUNGEON_LIST    = 0x22;  // Get M+ dungeon list from DB
            constexpr uint8 CMSG_GET_RAID_LIST       = 0x23;  // Get raid list from DB
            
            // Client -> Server: Spectating
            constexpr uint8 CMSG_START_SPECTATE      = 0x25;  // Request to spectate a run
            constexpr uint8 CMSG_STOP_SPECTATE       = 0x26;  // Stop spectating
            constexpr uint8 CMSG_GET_SPECTATE_LIST   = 0x27;  // Get available runs to spectate
            
            // Client -> Server: Scheduled Events
            constexpr uint8 CMSG_CREATE_EVENT        = 0x60;  // Create scheduled event
            constexpr uint8 CMSG_SIGNUP_EVENT        = 0x61;  // Sign up for event
            constexpr uint8 CMSG_CANCEL_SIGNUP       = 0x62;  // Cancel event signup
            constexpr uint8 CMSG_GET_SCHEDULED_EVENTS= 0x63;  // Get upcoming events
            constexpr uint8 CMSG_GET_MY_SIGNUPS      = 0x64;  // Get my event signups
            constexpr uint8 CMSG_CANCEL_EVENT        = 0x65;  // Cancel event (leader only)
            
            // Server -> Client: Listings
            constexpr uint8 SMSG_LISTING_CREATED     = 0x30;  // Confirm listing created
            constexpr uint8 SMSG_SEARCH_RESULTS      = 0x31;  // Search results
            constexpr uint8 SMSG_APPLICATION_STATUS  = 0x32;  // Application accepted/declined
            constexpr uint8 SMSG_NEW_APPLICATION     = 0x33;  // Leader: new applicant
            constexpr uint8 SMSG_GROUP_UPDATED       = 0x34;  // Group composition changed
            
            // Server -> Client: Keystone & Difficulty
            constexpr uint8 SMSG_KEYSTONE_INFO       = 0x40;  // Player's keystone data
            constexpr uint8 SMSG_DIFFICULTY_CHANGED  = 0x41;  // Confirm difficulty changed
            constexpr uint8 SMSG_DUNGEON_LIST        = 0x42;  // M+ dungeon list from DB
            constexpr uint8 SMSG_RAID_LIST           = 0x43;  // Raid list from DB
            
            // Server -> Client: Spectating
            constexpr uint8 SMSG_SPECTATE_DATA       = 0x45;  // Spectator live data
            constexpr uint8 SMSG_SPECTATE_LIST       = 0x47;  // Available runs to spectate
            constexpr uint8 SMSG_SPECTATE_STARTED    = 0x48;  // Spectating started
            constexpr uint8 SMSG_SPECTATE_ENDED      = 0x49;  // Spectating ended
            
            // Server -> Client: Scheduled Events
            constexpr uint8 SMSG_EVENT_CREATED       = 0x70;  // Event created confirmation
            constexpr uint8 SMSG_EVENT_SIGNUP_RESULT = 0x71;  // Signup result
            constexpr uint8 SMSG_SCHEDULED_EVENTS    = 0x72;  // List of events
            constexpr uint8 SMSG_MY_SIGNUPS          = 0x73;  // My event signups
            
            // Server -> Client: Errors
            constexpr uint8 SMSG_ERROR               = 0x5F;  // Error response
        }
    }
    
    // ========================================================================
    // MESSAGE UTILITIES
    // ========================================================================
    
    class Message
    {
    public:
        Message() = default;
        Message(const std::string& module, uint8 opcode)
            : _module(module), _opcode(opcode) {}
        
        // Build message for sending
        Message& Add(const std::string& value)
        {
            _data.push_back(value);
            return *this;
        }
        
        Message& Add(int32 value)
        {
            _data.push_back(std::to_string(value));
            return *this;
        }
        
        Message& Add(uint32 value)
        {
            _data.push_back(std::to_string(value));
            return *this;
        }
        
        Message& Add(float value)
        {
            _data.push_back(std::to_string(value));
            return *this;
        }
        
        Message& Add(bool value)
        {
            _data.push_back(value ? "1" : "0");
            return *this;
        }
        
        Message& Add(ObjectGuid guid)
        {
            _data.push_back(std::to_string(guid.GetRawValue()));
            return *this;
        }
        
        // Build final message string
        std::string Build() const
        {
            std::string result = _module;
            result += DELIMITER;
            result += std::to_string(_opcode);
            
            for (const auto& d : _data)
            {
                result += DELIMITER;
                result += d;
            }
            
            return result;
        }
        
        // Send to player
        void Send(Player* player) const;
        
        // Alias for Send (convenience method)
        void SendTo(Player* player) const { Send(player); }
        
        // Send to multiple players
        void SendToList(const std::vector<Player*>& players) const
        {
            for (Player* p : players)
            {
                if (p)
                    Send(p);
            }
        }
        
    private:
        std::string _module;
        uint8 _opcode;
        std::vector<std::string> _data;
    };
    
    // Parse incoming message
    class ParsedMessage
    {
    public:
        ParsedMessage(const std::string& raw)
        {
            Parse(raw);
        }
        
        bool IsValid() const { return _valid; }
        const std::string& GetModule() const { return _module; }
        uint8 GetOpcode() const { return _opcode; }
        size_t GetDataCount() const { return _data.size(); }
        bool HasMore() const { return _currentIndex < _data.size(); }
        
        // Get data at index with type conversion
        std::string GetString(size_t index) const
        {
            return (index < _data.size()) ? _data[index] : "";
        }
        
        // Sequential read methods for parser-style access
        std::string NextString()
        {
            return HasMore() ? _data[_currentIndex++] : "";
        }
        
        int32 GetInt32(size_t index) const
        {
            try {
                return (index < _data.size()) ? std::stoi(_data[index]) : 0;
            } catch (...) {
                return 0;
            }
        }
        
        uint32 GetUInt32(size_t index) const
        {
            try {
                return (index < _data.size()) ? static_cast<uint32>(std::stoul(_data[index])) : 0;
            } catch (...) {
                return 0;
            }
        }
        
        float GetFloat(size_t index) const
        {
            try {
                return (index < _data.size()) ? std::stof(_data[index]) : 0.0f;
            } catch (...) {
                return 0.0f;
            }
        }
        
        bool GetBool(size_t index) const
        {
            return GetString(index) == "1";
        }
        
        uint64 GetUInt64(size_t index) const
        {
            try {
                return (index < _data.size()) ? std::stoull(_data[index]) : 0;
            } catch (...) {
                return 0;
            }
        }
        
    private:
        void Parse(const std::string& raw)
        {
            std::stringstream ss(raw);
            std::string token;
            std::vector<std::string> tokens;
            
            while (std::getline(ss, token, DELIMITER))
            {
                tokens.push_back(token);
            }
            
            if (tokens.size() < 2)
            {
                _valid = false;
                return;
            }
            
            _module = tokens[0];
            try {
                _opcode = static_cast<uint8>(std::stoi(tokens[1]));
            } catch (...) {
                _valid = false;
                return;
            }
            
            // Remaining tokens are data
            for (size_t i = 2; i < tokens.size(); ++i)
            {
                _data.push_back(tokens[i]);
            }
            
            _valid = true;
        }
        
        bool _valid = false;
        std::string _module;
        uint8 _opcode = 0;
        std::vector<std::string> _data;
        mutable size_t _currentIndex = 0;
    };
    
    // Parser - alias for ParsedMessage with sequential read support
    // Used by module handlers for convenient data extraction
    class Parser
    {
    public:
        Parser(const ParsedMessage& msg) : _msg(msg), _index(0) {}
        
        uint8 GetOpcode() const { return _msg.GetOpcode(); }
        bool HasMore() const { return _index < _msg.GetDataCount(); }
        
        std::string GetString() { return _msg.GetString(_index++); }
        int32 GetInt32() { return _msg.GetInt32(_index++); }
        uint32 GetUInt32() { return _msg.GetUInt32(_index++); }
        float GetFloat() { return _msg.GetFloat(_index++); }
        bool GetBool() { return _msg.GetBool(_index++); }
        uint64 GetUInt64() { return _msg.GetUInt64(_index++); }
        
        // Peek at next without consuming
        std::string PeekString() const { return HasMore() ? _msg.GetString(_index) : ""; }
        
        // Skip N fields
        void Skip(size_t count = 1) { _index += count; }
        
        // Reset to beginning of data
        void Reset() { _index = 0; }
        
    private:
        const ParsedMessage& _msg;
        size_t _index;
    };
    
    // ========================================================================
    // MESSAGE HANDLER REGISTRATION
    // ========================================================================
    
    using MessageHandler = std::function<void(Player*, const ParsedMessage&)>;
    
    class MessageRouter
    {
    public:
        static MessageRouter& Instance()
        {
            static MessageRouter instance;
            return instance;
        }
        
        // Register a handler for a module + opcode combination
        void RegisterHandler(const std::string& module, uint8 opcode, MessageHandler handler)
        {
            std::string key = module + "_" + std::to_string(opcode);
            _handlers[key] = handler;
        }
        
        // Route an incoming message to the appropriate handler
        bool Route(Player* player, const std::string& rawMessage)
        {
            ParsedMessage msg(rawMessage);
            if (!msg.IsValid())
                return false;
            
            std::string key = msg.GetModule() + "_" + std::to_string(msg.GetOpcode());
            auto it = _handlers.find(key);
            
            if (it != _handlers.end())
            {
                it->second(player, msg);
                return true;
            }
            
            return false;  // No handler registered
        }
        
        // Check if a module is enabled
        bool IsModuleEnabled(const std::string& module) const
        {
            auto it = _enabledModules.find(module);
            return (it != _enabledModules.end()) ? it->second : false;
        }
        
        void SetModuleEnabled(const std::string& module, bool enabled)
        {
            _enabledModules[module] = enabled;
        }
        
    private:
        MessageRouter() = default;
        std::unordered_map<std::string, MessageHandler> _handlers;
        std::unordered_map<std::string, bool> _enabledModules;
    };
    
    // ========================================================================
    // HELPER MACROS FOR HANDLER REGISTRATION
    // ========================================================================
    
    #define DC_REGISTER_HANDLER(module, opcode, handler) \
        DCAddon::MessageRouter::Instance().RegisterHandler(module, opcode, handler)
    
    #define DC_SEND_MESSAGE(player, module, opcode) \
        DCAddon::Message(module, opcode)
    
    // ========================================================================
    // CHUNKING SUPPORT (for messages > 255 bytes)
    // ========================================================================
    
    class ChunkedMessage
    {
    public:
        // Split a large message into chunks
        static std::vector<std::string> Chunk(const std::string& message, uint32 maxSize = MAX_CLIENT_MSG_SIZE - 10)
        {
            std::vector<std::string> chunks;
            
            if (message.size() <= maxSize)
            {
                // No chunking needed, but mark as single chunk
                chunks.push_back("0|1|" + message);
                return chunks;
            }
            
            uint32 totalChunks = (message.size() + maxSize - 1) / maxSize;
            
            for (uint32 i = 0; i < totalChunks; ++i)
            {
                std::string chunk = std::to_string(i) + "|" + std::to_string(totalChunks) + "|";
                chunk += message.substr(i * maxSize, maxSize);
                chunks.push_back(chunk);
            }
            
            return chunks;
        }
        
        // Reassemble chunks (call per incoming chunk, returns complete message when done)
        bool AddChunk(const std::string& chunk)
        {
            // Parse chunk header: INDEX|TOTAL|DATA
            std::stringstream ss(chunk);
            std::string indexStr, totalStr;
            
            if (!std::getline(ss, indexStr, '|') || !std::getline(ss, totalStr, '|'))
                return false;
            
            uint32 index = std::stoul(indexStr);
            uint32 total = std::stoul(totalStr);
            
            if (_totalChunks == 0)
            {
                _totalChunks = total;
                _chunks.resize(total);
                _received.resize(total, false);
            }
            
            if (index >= _totalChunks || total != _totalChunks)
                return false;
            
            // Get remaining data after second |
            std::string data;
            std::getline(ss, data);
            
            _chunks[index] = data;
            _received[index] = true;
            _receivedCount++;
            
            return _receivedCount == _totalChunks;
        }
        
        std::string GetCompleteMessage() const
        {
            std::string result;
            for (const auto& chunk : _chunks)
                result += chunk;
            return result;
        }
        
        bool IsComplete() const { return _receivedCount == _totalChunks; }
        void Reset()
        {
            _chunks.clear();
            _received.clear();
            _totalChunks = 0;
            _receivedCount = 0;
        }
        
    private:
        std::vector<std::string> _chunks;
        std::vector<bool> _received;
        uint32 _totalChunks = 0;
        uint32 _receivedCount = 0;
    };
    
    // ========================================================================
    // JSON SUPPORT
    // ========================================================================
    
    // JSON marker for detecting JSON payloads
    constexpr const char* JSON_MARKER = "J";
    
    // Simple JSON value class for addon communication
    class JsonValue
    {
    public:
        enum Type { Null, Bool, Number, String, Array, Object };
        
        JsonValue() : _type(Null) {}
        JsonValue(bool v) : _type(Bool), _bool(v) {}
        JsonValue(int32 v) : _type(Number), _number(static_cast<double>(v)) {}
        JsonValue(uint32 v) : _type(Number), _number(static_cast<double>(v)) {}
        JsonValue(double v) : _type(Number), _number(v) {}
        JsonValue(const std::string& v) : _type(String), _string(v) {}
        JsonValue(const char* v) : _type(String), _string(v) {}
        
        Type GetType() const { return _type; }
        bool IsNull() const { return _type == Null; }
        bool IsBool() const { return _type == Bool; }
        bool IsNumber() const { return _type == Number; }
        bool IsString() const { return _type == String; }
        bool IsArray() const { return _type == Array; }
        bool IsObject() const { return _type == Object; }
        
        bool AsBool() const { return _bool; }
        double AsNumber() const { return _number; }
        int32 AsInt32() const { return static_cast<int32>(_number); }
        uint32 AsUInt32() const { return static_cast<uint32>(_number); }
        const std::string& AsString() const { return _string; }
        const std::vector<JsonValue>& AsArray() const { return _array; }
        const std::map<std::string, JsonValue>& AsObject() const { return _object; }
        
        // Object access
        bool HasKey(const std::string& key) const 
        { 
            return _type == Object && _object.find(key) != _object.end(); 
        }
        
        const JsonValue& operator[](const std::string& key) const
        {
            static JsonValue null;
            if (_type != Object) return null;
            auto it = _object.find(key);
            return (it != _object.end()) ? it->second : null;
        }
        
        // Array access
        const JsonValue& operator[](size_t index) const
        {
            static JsonValue null;
            return (_type == Array && index < _array.size()) ? _array[index] : null;
        }
        
        size_t Size() const
        {
            if (_type == Array) return _array.size();
            if (_type == Object) return _object.size();
            return 0;
        }
        
        // Building JSON
        void SetNull() { _type = Null; }
        void Set(bool v) { _type = Bool; _bool = v; }
        void Set(double v) { _type = Number; _number = v; }
        void Set(const std::string& v) { _type = String; _string = v; }
        
        void SetArray() { _type = Array; _array.clear(); }
        void Push(const JsonValue& v) { if (_type == Array) _array.push_back(v); }
        
        void SetObject() { _type = Object; _object.clear(); }
        void Set(const std::string& key, const JsonValue& v) 
        { 
            if (_type == Object) _object[key] = v; 
        }
        
        // Encode to JSON string
        std::string Encode() const
        {
            switch (_type)
            {
                case Null: return "null";
                case Bool: return _bool ? "true" : "false";
                case Number: {
                    std::ostringstream ss;
                    ss << _number;
                    return ss.str();
                }
                case String: {
                    std::string result = "\"";
                    for (char c : _string) {
                        if (c == '"') result += "\\\"";
                        else if (c == '\\') result += "\\\\";
                        else if (c == '\n') result += "\\n";
                        else if (c == '\r') result += "\\r";
                        else if (c == '\t') result += "\\t";
                        else result += c;
                    }
                    result += "\"";
                    return result;
                }
                case Array: {
                    std::string result = "[";
                    for (size_t i = 0; i < _array.size(); ++i) {
                        if (i > 0) result += ",";
                        result += _array[i].Encode();
                    }
                    result += "]";
                    return result;
                }
                case Object: {
                    std::string result = "{";
                    bool first = true;
                    for (const auto& [k, v] : _object) {
                        if (!first) result += ",";
                        first = false;
                        result += "\"" + k + "\":" + v.Encode();
                    }
                    result += "}";
                    return result;
                }
            }
            return "null";
        }
        
    private:
        Type _type = Null;
        bool _bool = false;
        double _number = 0.0;
        std::string _string;
        std::vector<JsonValue> _array;
        std::map<std::string, JsonValue> _object;
    };
    
    // Simple JSON parser
    class JsonParser
    {
    public:
        static JsonValue Parse(const std::string& json)
        {
            size_t pos = 0;
            return ParseValue(json, pos);
        }
        
    private:
        static void SkipWhitespace(const std::string& s, size_t& pos)
        {
            while (pos < s.size() && (s[pos] == ' ' || s[pos] == '\t' || s[pos] == '\n' || s[pos] == '\r'))
                ++pos;
        }
        
        static JsonValue ParseValue(const std::string& s, size_t& pos)
        {
            SkipWhitespace(s, pos);
            if (pos >= s.size()) return JsonValue();
            
            char c = s[pos];
            if (c == '"') return ParseString(s, pos);
            if (c == '{') return ParseObject(s, pos);
            if (c == '[') return ParseArray(s, pos);
            if (c == 't' && s.substr(pos, 4) == "true") { pos += 4; return JsonValue(true); }
            if (c == 'f' && s.substr(pos, 5) == "false") { pos += 5; return JsonValue(false); }
            if (c == 'n' && s.substr(pos, 4) == "null") { pos += 4; return JsonValue(); }
            if (c == '-' || (c >= '0' && c <= '9')) return ParseNumber(s, pos);
            
            return JsonValue();
        }
        
        static JsonValue ParseString(const std::string& s, size_t& pos)
        {
            if (s[pos] != '"') return JsonValue();
            ++pos;
            std::string result;
            while (pos < s.size() && s[pos] != '"') {
                if (s[pos] == '\\' && pos + 1 < s.size()) {
                    ++pos;
                    char esc = s[pos];
                    if (esc == '"') result += '"';
                    else if (esc == '\\') result += '\\';
                    else if (esc == 'n') result += '\n';
                    else if (esc == 'r') result += '\r';
                    else if (esc == 't') result += '\t';
                    else if (esc == 'u') { pos += 4; result += '?'; }  // Skip unicode
                    ++pos;
                } else {
                    result += s[pos++];
                }
            }
            if (pos < s.size()) ++pos;  // Skip closing "
            return JsonValue(result);
        }
        
        static JsonValue ParseNumber(const std::string& s, size_t& pos)
        {
            size_t start = pos;
            if (s[pos] == '-') ++pos;
            while (pos < s.size() && s[pos] >= '0' && s[pos] <= '9') ++pos;
            if (pos < s.size() && s[pos] == '.') {
                ++pos;
                while (pos < s.size() && s[pos] >= '0' && s[pos] <= '9') ++pos;
            }
            if (pos < s.size() && (s[pos] == 'e' || s[pos] == 'E')) {
                ++pos;
                if (pos < s.size() && (s[pos] == '+' || s[pos] == '-')) ++pos;
                while (pos < s.size() && s[pos] >= '0' && s[pos] <= '9') ++pos;
            }
            return JsonValue(std::stod(s.substr(start, pos - start)));
        }
        
        static JsonValue ParseArray(const std::string& s, size_t& pos)
        {
            if (s[pos] != '[') return JsonValue();
            ++pos;
            JsonValue arr;
            arr.SetArray();
            SkipWhitespace(s, pos);
            if (pos < s.size() && s[pos] == ']') { ++pos; return arr; }
            while (pos < s.size()) {
                arr.Push(ParseValue(s, pos));
                SkipWhitespace(s, pos);
                if (pos >= s.size()) break;
                if (s[pos] == ']') { ++pos; break; }
                if (s[pos] == ',') ++pos;
            }
            return arr;
        }
        
        static JsonValue ParseObject(const std::string& s, size_t& pos)
        {
            if (s[pos] != '{') return JsonValue();
            ++pos;
            JsonValue obj;
            obj.SetObject();
            SkipWhitespace(s, pos);
            if (pos < s.size() && s[pos] == '}') { ++pos; return obj; }
            while (pos < s.size()) {
                SkipWhitespace(s, pos);
                JsonValue keyVal = ParseString(s, pos);
                if (!keyVal.IsString()) break;
                SkipWhitespace(s, pos);
                if (pos >= s.size() || s[pos] != ':') break;
                ++pos;
                obj.Set(keyVal.AsString(), ParseValue(s, pos));
                SkipWhitespace(s, pos);
                if (pos >= s.size()) break;
                if (s[pos] == '}') { ++pos; break; }
                if (s[pos] == ',') ++pos;
            }
            return obj;
        }
    };
    
    // JSON Message builder
    class JsonMessage
    {
    public:
        JsonMessage(const std::string& module, uint8 opcode)
            : _module(module), _opcode(opcode) 
        {
            _json.SetObject();
        }
        
        JsonMessage& Set(const std::string& key, bool v) { _json.Set(key, JsonValue(v)); return *this; }
        JsonMessage& Set(const std::string& key, int32 v) { _json.Set(key, JsonValue(v)); return *this; }
        JsonMessage& Set(const std::string& key, uint32 v) { _json.Set(key, JsonValue(v)); return *this; }
        JsonMessage& Set(const std::string& key, double v) { _json.Set(key, JsonValue(v)); return *this; }
        JsonMessage& Set(const std::string& key, const std::string& v) { _json.Set(key, JsonValue(v)); return *this; }
        JsonMessage& Set(const std::string& key, const char* v) { _json.Set(key, JsonValue(v)); return *this; }
        
        std::string Build() const
        {
            std::string result = _module;
            result += DELIMITER;
            result += std::to_string(_opcode);
            result += DELIMITER;
            result += JSON_MARKER;
            result += DELIMITER;
            result += _json.Encode();
            return result;
        }
        
        void Send(Player* player) const
        {
            if (!player || !player->GetSession())
                return;
            
            // Build the full message with DC prefix and tab separator
            std::string fullMsg = std::string(DC_PREFIX) + "\t" + Build();
            
            // Use proper ChatHandler to build addon message packet
            WorldPacket data;
            ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, fullMsg);
            player->SendDirectMessage(&data);
        }
        
    private:
        std::string _module;
        uint8 _opcode;
        JsonValue _json;
    };
    
    // Check if a parsed message contains JSON
    inline bool IsJsonMessage(const ParsedMessage& msg)
    {
        return msg.GetDataCount() > 0 && msg.GetString(0) == JSON_MARKER;
    }
    
    // Get JSON data from a message (returns empty JsonValue if not JSON)
    inline JsonValue GetJsonData(const ParsedMessage& msg)
    {
        if (!IsJsonMessage(msg) || msg.GetDataCount() < 2)
            return JsonValue();
        
        return JsonParser::Parse(msg.GetString(1));
    }

}  // namespace DCAddon

#endif // DC_ADDON_NAMESPACE_H
