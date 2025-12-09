/*
 * Dark Chaos - GOMove Addon Integration
 * =====================================
 * 
 * Integrates the GOMove system with the unified DC Addon Protocol.
 * Handles object moving, spawning, and searching via DC_ADDON messages.
 * 
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "DCAddonNamespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "MapManager.h"
#include "Chat.h"
#include "Log.h"
#include "../GOMove/GOMove.h" // Include original GOMove header

namespace DCAddon
{
    namespace GOMove
    {
        // Helper to send GOMove specific messages wrapped in DC Protocol
        static void SendGOMoveMessage(Player* player, const std::string& msg)
        {
            Message response(Module::GOMOVE, Opcode::GOMove::SMSG_MOVE_RESULT);
            response.AddData(msg);
            response.Send(player);
        }

        static void HandleRequestMove(Player* player, const ParsedMessage& msg)
        {
            // Format: DC|GOMV|0x01|ID|LOWGUID|ARG
            // This maps to the original .gomove command args
            
            if (msg.GetDataCount() < 3)
                return;

            uint32 ID = msg.GetUInt32(0);
            uint32 lowguid = msg.GetUInt32(1);
            uint32 ARG = msg.GetUInt32(2);

            // Enum from GOMoveScripts.cpp (we need to duplicate it or move it to header)
            enum commandIDs
            {
                TEST, SELECTNEAR, DELET, X, Y, Z, O, GROUND, FLOOR, RESPAWN, GOTO, FACE,
                SPAWN, NORTH, EAST, SOUTH, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST,
                UP, DOWN, LEFT, RIGHT, PHASE, SELECTALLNEAR, SPAWNSPELL,
            };

            if (ID < SPAWN) // no args
            {
                if (ID >= DELET && ID <= GOTO) // has target
                {
                    GameObject* target = ::GOMove::GetGameObject(player, lowguid);
                    if (!target)
                    {
                        SendGOMoveMessage(player, "Object GUID not found");
                        return;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);
                    uint32 p = target->GetPhaseMask();

                    switch (ID)
                    {
                        case DELET: ::GOMove::DeleteGameObject(target); ::GOMove::SendRemove(player, lowguid); break;
                        case X: ::GOMove::MoveGameObject(player, player->GetPositionX(), y, z, o, p, lowguid); break;
                        case Y: ::GOMove::MoveGameObject(player, x, player->GetPositionY(), z, o, p, lowguid); break;
                        case Z: ::GOMove::MoveGameObject(player, x, y, player->GetPositionZ(), o, p, lowguid); break;
                        case O: ::GOMove::MoveGameObject(player, x, y, z, player->GetOrientation(), p, lowguid); break;
                        case RESPAWN: ::GOMove::SpawnGameObject(player, x, y, z, o, p, target->GetEntry()); break;
                        case GOTO:
                        {
                            if (player->IsInFlight()) player->FinishTaxiFlight();
                            else player->SaveRecallPosition();
                            player->TeleportTo(target->GetMapId(), x, y, z, o);
                        } break;
                        case GROUND:
                        {
                            float ground = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, MAX_HEIGHT);
                            if (ground != INVALID_HEIGHT) ::GOMove::MoveGameObject(player, x, y, ground, o, p, lowguid);
                        } break;
                        case FLOOR:
                        {
                            float floor = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, z);
                            if (floor != INVALID_HEIGHT) ::GOMove::MoveGameObject(player, x, y, floor, o, p, lowguid);
                        } break;
                    }
                }
                else
                {
                    switch (ID)
                    {
                        case FACE:
                        {
                            float const piper2 = float(M_PI) / 2.0f;
                            float const multi = player->GetOrientation() / piper2;
                            float const multi_int = floor(multi);
                            float const new_ori = (multi - multi_int > 0.5f) ? (multi_int + 1)*piper2 : multi_int*piper2;
                            player->SetFacingTo(new_ori);
                        } break;
                        case SELECTNEAR:
                        {
                            GameObject* object = ChatHandler(player->GetSession()).GetNearbyGameObject();
                            if (!object)
                                SendGOMoveMessage(player, "No objects found");
                            else
                            {
                                ::GOMove::SendAdd(player, object->GetSpawnId());
                            }
                        } break;
                    }
                }
            }
            else if (ARG && ID >= SPAWN)
            {
                if (ID >= NORTH && ID <= PHASE)
                {
                    GameObject* target = ::GOMove::GetGameObject(player, lowguid);
                    if (!target)
                    {
                        SendGOMoveMessage(player, "Object GUID not found");
                        return;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);
                    uint32 p = target->GetPhaseMask();

                    switch (ID)
                    {
                        case NORTH: ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y, z, o, p, lowguid); break;
                        case EAST: ::GOMove::MoveGameObject(player, x, y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTH: ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y, z, o, p, lowguid); break;
                        case WEST: ::GOMove::MoveGameObject(player, x, y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case NORTHEAST: ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTHEAST: ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTHWEST: ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case NORTHWEST: ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case UP: ::GOMove::MoveGameObject(player, x, y, z + ((float)ARG / 100), o, p, lowguid); break;
                        case DOWN: ::GOMove::MoveGameObject(player, x, y, z - ((float)ARG / 100), o, p, lowguid); break;
                        case RIGHT: ::GOMove::MoveGameObject(player, x, y, z, o - ((float)ARG / 100), p, lowguid); break;
                        case LEFT: ::GOMove::MoveGameObject(player, x, y, z, o + ((float)ARG / 100), p, lowguid); break;
                        case PHASE: ::GOMove::MoveGameObject(player, x, y, z, o, ARG, lowguid); break;
                    }
                }
                else
                {
                    switch (ID)
                    {
                        case SPAWN:
                        {
                            if (::GOMove::SpawnGameObject(player, player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), player->GetOrientation(), player->GetPhaseMaskForSpawn(), ARG))
                                ::GOMove::Store.SpawnQueAdd(player->GetGUID(), ARG);
                        } break;
                        case SPAWNSPELL:
                        {
                            ::GOMove::Store.SpawnQueAdd(player->GetGUID(), ARG);
                        } break;
                        case SELECTALLNEAR:
                        {
                            for (GameObject const * go : ::GOMove::GetNearbyGameObjects(player, static_cast<float>(ARG)))
                                ::GOMove::SendAdd(player, go->GetSpawnId());
                        } break;
                    }
                }
            }
        }

        static void HandleRequestSearch(Player* player, const ParsedMessage& msg)
        {
            // Format: DC|GOMV|0x02|SEARCH_TERM
            if (msg.GetDataCount() < 1) return;
            
            std::string searchTerm = msg.GetString(0);
            if (searchTerm.empty()) return;
            
            // Convert to lowercase for case-insensitive search
            std::transform(searchTerm.begin(), searchTerm.end(), searchTerm.begin(), ::tolower);
            
            JsonValue response;
            JsonValue results = JsonValue::CreateArray();
            
            uint32 count = 0;
            
            std::string query = "SELECT entry, name, displayId FROM gameobject_template WHERE name LIKE '%" + searchTerm + "%' LIMIT 50";
            if (QueryResult result = WorldDatabase.Query(query.c_str()))
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 entry = fields[0].GetUInt32();
                    std::string name = fields[1].GetString();
                    uint32 displayId = fields[2].GetUInt32();
                    
                    JsonValue obj = JsonValue::CreateObject();
                    obj.Add("id", entry);
                    obj.Add("name", name);
                    obj.Add("display", displayId);
                    results.Add(obj);
                    
                    count++;
                } while (result->NextRow());
            }
            
            response.Add("results", results);
            response.Add("count", count);
            
            JsonMessage(Module::GOMOVE, Opcode::GOMove::SMSG_SEARCH_RESULT, response).Send(player);
        }

        static void HandleRequestTeleSync(Player* player, const ParsedMessage& msg)
        {
            // Format: DC|GOMV|0x03
            
            JsonValue response;
            JsonValue locations = JsonValue::CreateArray();
            
            // Query game_tele table
            if (QueryResult result = WorldDatabase.Query("SELECT id, name, map, position_x, position_y, position_z, orientation FROM game_tele ORDER BY name"))
            {
                do
                {
                    Field* fields = result->Fetch();
                    JsonValue loc = JsonValue::CreateObject();
                    loc.Add("id", fields[0].GetUInt32());
                    loc.Add("name", fields[1].GetString());
                    loc.Add("map", fields[2].GetUInt16());
                    loc.Add("x", fields[3].GetFloat());
                    loc.Add("y", fields[4].GetFloat());
                    loc.Add("z", fields[5].GetFloat());
                    loc.Add("o", fields[6].GetFloat());
                    locations.Add(loc);
                } while (result->NextRow());
            }
            
            response.Add("locations", locations);
            
            // This might be large, so the chunking in DC Protocol will handle it
            JsonMessage(Module::GOMOVE, Opcode::GOMove::SMSG_TELE_LIST, response).Send(player);
        }

        void RegisterHandlers()
        {
            DC_REGISTER_HANDLER(Module::GOMOVE, Opcode::GOMove::CMSG_REQUEST_MOVE, HandleRequestMove);
            DC_REGISTER_HANDLER(Module::GOMOVE, Opcode::GOMove::CMSG_REQUEST_SEARCH, HandleRequestSearch);
            DC_REGISTER_HANDLER(Module::GOMOVE, Opcode::GOMove::CMSG_REQUEST_TELE_SYNC, HandleRequestTeleSync);
        }
    }
}

// Register the handler
void AddSC_DCAddon_GOMove()
{
    DCAddon::GOMove::RegisterHandlers();
}
