/*
 * Dark Chaos - Teleport Addon Handler
 * ===================================
 * 
 * Handles teleport list requests from the client.
 * 
 * Copyright (C) 2024 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Config.h"
#include "Player.h"
#include "WorldSession.h"
#include "DatabaseEnv.h"
#include "Log.h"

namespace DCAddon
{
    // Forward declarations for internal helpers
    static std::string EscapeJsonString(const std::string& input);

    static void HandleRequestList(Player* player, const ParsedMessage& /*msg*/)
    {
            // Query game_tele table
            QueryResult result = WorldDatabase.Query("SELECT id, name, map, position_x, position_y, position_z, orientation FROM game_tele ORDER BY name");

            if (!result)
            {
                // Send empty list or error? Empty list is fine.
                JsonMessage response(Module::TELEPORTS, Opcode::Teleports::SMSG_SEND_LIST);
                response.Set("teleports", "[]"); // Empty JSON array
                response.Send(player);
                return;
            }

            // Build JSON array manually because we don't have a full JSON builder for arrays in the helper class yet (maybe?)
            // Let's check JsonValue capabilities in DCAddonNamespace.h or just build string.
            // The JsonValue seems to support basic types.
            // I'll build the JSON string manually for the array to be safe and efficient.

            std::stringstream ss;
            ss << "[";
            bool first = true;

            do
            {
                Field* fields = result->Fetch();
                uint32 id = fields[0].Get<uint32>();
                std::string name = fields[1].Get<std::string>();
                uint16 map = fields[2].Get<uint16>();
                float x = fields[3].Get<float>();
                float y = fields[4].Get<float>();
                float z = fields[5].Get<float>();
                float o = fields[6].Get<float>();

                if (!first) ss << ",";
                first = false;

                ss << "{";
                ss << "\"id\":" << id << ",";
                ss << "\"name\":\"" << EscapeJsonString(name) << "\",";
                ss << "\"map\":" << map << ",";
                ss << "\"x\":" << x << ",";
                ss << "\"y\":" << y << ",";
                ss << "\"z\":" << z << ",";
                ss << "\"o\":" << o;
                ss << "}";

            } while (result->NextRow());

            ss << "]";

            // Send response
            // We use a special way to send raw JSON string if the helper doesn't support setting raw JSON value
            // Looking at JsonMessage::Set, it takes string.
            // But wait, JsonMessage wraps it in an object.
            // So we send { "list": [...] }
            
            JsonMessage response(Module::TELEPORTS, Opcode::Teleports::SMSG_SEND_LIST);
            // We need to pass the array as a string value? No, that would be a string containing JSON.
            // If the client expects a JSON object with a key "list", that's fine.
            // But if we want to send just the array, we might need to bypass JsonMessage or modify it.
            
            // Let's assume we send { "list": [ ... ] }
            // But JsonValue::Set takes a JsonValue.
            // If JsonValue has a constructor for raw JSON string, we can use it.
            // If not, we might have to hack it or extend JsonValue.
            
            // Let's look at DCAddonNamespace.h again for JsonValue.
            // For now, I'll send it as a string and parse it on client.
            // "list": "[{...}, {...}]"
            // Client: list = JSON.parse(msg.list)
            
            response.Set("list", ss.str());
            response.Send(player);
        }

    static std::string EscapeJsonString(const std::string& input)
        {
            std::string output;
            output.reserve(input.length());
            for (char c : input)
            {
                switch (c) {
                    case '"': output += "\\\""; break;
                    case '\\': output += "\\\\"; break;
                    case '\b': output += "\\b"; break;
                    case '\f': output += "\\f"; break;
                    case '\n': output += "\\n"; break;
                    case '\r': output += "\\r"; break;
                    case '\t': output += "\\t"; break;
                    default: output += c; break;
                }
            }
            return output;
        }

    void RegisterHandlers()
    {
        // Load config-based enable flags/min security if desired in future
        // For now, ensure module enabled in router
        bool enabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.Teleports.Enable", true);
        if (!enabled)
            return;
        DC_REGISTER_HANDLER(Module::TELEPORTS, Opcode::Teleports::CMSG_REQUEST_LIST, HandleRequestList);
    }
}

// Register the handler(s) during script load
void AddSC_DCAddon_Teleports()
{
    DCAddon::RegisterHandlers();
}

    namespace DCAddon {
        void AddTeleportScripts()
        {
            RegisterHandlers();
        }
    }
