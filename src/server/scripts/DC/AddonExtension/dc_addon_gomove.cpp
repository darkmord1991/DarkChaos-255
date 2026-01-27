/*
 * Dark Chaos - GOMove Addon Integration
 * =====================================
 *
 * Integrates the GOMove system with the unified DC Addon Protocol.
 * Handles object moving, spawning, and searching via DC_ADDON messages.
 *
 * Copyright (C) 2025 Dark Chaos Development Team
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "GameObject.h"
#include "ObjectMgr.h"
#include "MapMgr.h"
#include "Chat.h"
#include "Log.h"
#include "Config.h"
#include "Language.h"
#include "../GOMove/GOMove.h" // Include original GOMove header
#include "../GOMove/GOMoveCommandIds.h"

namespace DCAddon
{
    namespace GOMove
    {
    static uint32 s_gomoveMinSecurity = 1;
    static uint32 s_gomoveMoveMinSecurity = SEC_GAMEMASTER;
    static bool s_gomoveEnabled = true; // fallback if router not configured
        // Helper to send GOMove specific messages wrapped in DC Protocol
        static void SendGOMoveMessage(Player* player, const std::string& msg)
        {
            Message response(Module::GOMOVE, Opcode::GOMove::SMSG_MOVE_RESULT);
            response.Add(msg);
            response.Send(player);
        }

        static void SendGOMoveSuccessMessage(Player* player, GameObject* object)
        {
            if (!player || !object) return;

            GameObjectTemplate const* objectInfo = object->GetGOInfo();
            if (!objectInfo) return;

            ChatHandler(player->GetSession()).PSendSysMessage(LANG_GAMEOBJECT_ADD,
                objectInfo->entry,
                objectInfo->name,
                object->GetSpawnId(),
                object->GetPositionX(),
                object->GetPositionY(),
                object->GetPositionZ()
            );
        }

        static void HandleRequestMove(Player* player, const ParsedMessage& msg)
        {
            // Quick guard: check module enabled + GM level
            if (!DCAddon::CheckAddonPermission(player, Module::GOMOVE, s_gomoveMoveMinSecurity))
            {
                DCAddon::SendPermissionDenied(player, Module::GOMOVE, "Insufficient GM level to use addon commands");
                return;
            }
            // Format: DC|GOMV|0x01|ID|LOWGUID|ARG
            // This maps to the original .gomove command args

            if (msg.GetDataCount() < 1)
            {
                DCAddon::SendError(player, Module::GOMOVE, "Missing command id", DCAddon::ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
                return;
            }

            uint32 ID = msg.GetUInt32(0);
            uint32 lowguid = msg.GetUInt32(1);
            uint32 ARG = msg.GetUInt32(2);

            using namespace DarkChaos::GOMove;

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

                    GameObject* newObject = nullptr;
                    switch (ID)
                    {
                        case DELET: ::GOMove::DeleteGameObject(target); ::GOMove::SendRemove(player, lowguid); break;
                        case X: newObject = ::GOMove::MoveGameObject(player, player->GetPositionX(), y, z, o, p, lowguid); break;
                        case Y: newObject = ::GOMove::MoveGameObject(player, x, player->GetPositionY(), z, o, p, lowguid); break;
                        case Z: newObject = ::GOMove::MoveGameObject(player, x, y, player->GetPositionZ(), o, p, lowguid); break;
                        case O: newObject = ::GOMove::MoveGameObject(player, x, y, z, player->GetOrientation(), p, lowguid); break;
                        case RESPAWN: newObject = ::GOMove::SpawnGameObject(player, x, y, z, o, p, target->GetEntry()); break;
                        case GOTO:
                        {
                            if (player->IsInFlight()) player->CleanupAfterTaxiFlight();
                            else player->SaveRecallPosition();
                            player->TeleportTo(target->GetMapId(), x, y, z, o);
                        } break;
                        case GROUND:
                        {
                            float ground = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, MAX_HEIGHT);
                            if (ground != INVALID_HEIGHT) newObject = ::GOMove::MoveGameObject(player, x, y, ground, o, p, lowguid);
                        } break;
                        case FLOOR:
                        {
                            float floor = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, z);
                            if (floor != INVALID_HEIGHT) newObject = ::GOMove::MoveGameObject(player, x, y, floor, o, p, lowguid);
                        } break;
                    }
                    if (newObject) SendGOMoveSuccessMessage(player, newObject);
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

                    GameObject* newObject = nullptr;
                    switch (ID)
                    {
                        case NORTH: newObject = ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y, z, o, p, lowguid); break;
                        case EAST: newObject = ::GOMove::MoveGameObject(player, x, y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTH: newObject = ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y, z, o, p, lowguid); break;
                        case WEST: newObject = ::GOMove::MoveGameObject(player, x, y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case NORTHEAST: newObject = ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTHEAST: newObject = ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y - ((float)ARG / 100), z, o, p, lowguid); break;
                        case SOUTHWEST: newObject = ::GOMove::MoveGameObject(player, x - ((float)ARG / 100), y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case NORTHWEST: newObject = ::GOMove::MoveGameObject(player, x + ((float)ARG / 100), y + ((float)ARG / 100), z, o, p, lowguid); break;
                        case UP: newObject = ::GOMove::MoveGameObject(player, x, y, z + ((float)ARG / 100), o, p, lowguid); break;
                        case DOWN: newObject = ::GOMove::MoveGameObject(player, x, y, z - ((float)ARG / 100), o, p, lowguid); break;
                        case RIGHT: newObject = ::GOMove::MoveGameObject(player, x, y, z, o - ((float)ARG / 100), p, lowguid); break;
                        case LEFT: newObject = ::GOMove::MoveGameObject(player, x, y, z, o + ((float)ARG / 100), p, lowguid); break;
                        case PHASE: newObject = ::GOMove::MoveGameObject(player, x, y, z, o, ARG, lowguid); break;
                    }
                    if (newObject) SendGOMoveSuccessMessage(player, newObject);
                }
                else
                {
                    switch (ID)
                    {
                        case SPAWN:
                        {
                            GameObject* newObject = ::GOMove::SpawnGameObject(player, player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), player->GetOrientation(), player->GetPhaseMaskForSpawn(), ARG);
                            if (newObject)
                            {
                                ::GOMove::Store.SpawnQueAdd(player->GetGUID(), ARG);
                                SendGOMoveSuccessMessage(player, newObject);
                            }
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
            if (!DCAddon::CheckAddonPermission(player, Module::GOMOVE, s_gomoveMinSecurity))
            {
                DCAddon::SendPermissionDenied(player, Module::GOMOVE, "Insufficient GM level to use addon commands");
                return;
            }
            // Format: DC|GOMV|0x02|SEARCH_TERM
            if (msg.GetDataCount() < 1)
            {
                DCAddon::SendError(player, Module::GOMOVE, "Missing search term", DCAddon::ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
                return;
            }

            std::string searchTerm = msg.GetString(0);
            if (searchTerm.empty())
            {
                DCAddon::SendError(player, Module::GOMOVE, "Empty search term", DCAddon::ErrorCode::BAD_FORMAT, Opcode::Core::SMSG_ERROR);
                return;
            }

            // Convert to lowercase for case-insensitive search
            std::transform(searchTerm.begin(), searchTerm.end(), searchTerm.begin(), ::tolower);

            // Escape user-provided search term for SQL safety
            std::string escaped = searchTerm;
            WorldDatabase.EscapeString(escaped);

            JsonValue response;
            JsonValue results; results.SetArray();

            uint32 count = 0;

            std::string query = "SELECT entry, name, displayId FROM gameobject_template WHERE name LIKE '%" + escaped + "%' LIMIT 50";
            if (QueryResult result = WorldDatabase.Query(query.c_str()))
            {
                do
                {
                    Field* fields = result->Fetch();
                    uint32 entry = fields[0].Get<uint32>();
                    std::string name = fields[1].Get<std::string>();
                    uint32 displayId = fields[2].Get<uint32>();

                    JsonValue obj; obj.SetObject();
                    obj.Set("id", JsonValue(entry));
                    obj.Set("name", JsonValue(name));
                    obj.Set("display", JsonValue(displayId));
                    results.Push(obj);

                    count++;
                } while (result->NextRow());
            }

            response.Set("results", results);
            response.Set("count", JsonValue(count));

            JsonMessage(Module::GOMOVE, Opcode::GOMove::SMSG_SEARCH_RESULT, response).Send(player);
        }

        static void HandleRequestTeleSync(Player* player, const ParsedMessage& msg)
        {
            (void)msg; // msg is intentionally unused in this handler
            if (!DCAddon::CheckAddonPermission(player, Module::GOMOVE, s_gomoveMinSecurity))
            {
                DCAddon::SendPermissionDenied(player, Module::GOMOVE, "Insufficient GM level to use addon commands");
                return;
            }
            // Format: DC|GOMV|0x03

            JsonValue response;
            JsonValue locations; locations.SetArray();

            // Query game_tele table
            if (QueryResult result = WorldDatabase.Query("SELECT id, name, map, position_x, position_y, position_z, orientation FROM game_tele ORDER BY name"))
            {
                do
                {
                    Field* fields = result->Fetch();
                    JsonValue loc; loc.SetObject();
                    loc.Set("id", JsonValue(fields[0].Get<uint32>()));
                    loc.Set("name", JsonValue(fields[1].Get<std::string>()));
                    loc.Set("map", JsonValue(fields[2].Get<uint16>()));
                    loc.Set("x", JsonValue(fields[3].Get<float>()));
                    loc.Set("y", JsonValue(fields[4].Get<float>()));
                    loc.Set("z", JsonValue(fields[5].Get<float>()));
                    loc.Set("o", JsonValue(fields[6].Get<float>()));
                    locations.Push(loc);
                } while (result->NextRow());
            }

            response.Set("locations", locations);

            // This might be large, so the chunking in DC Protocol will handle it
            JsonMessage(Module::GOMOVE, Opcode::GOMove::SMSG_TELE_LIST, response).Send(player);
        }

        void RegisterHandlers()
        {
            // Load module-specific options
            s_gomoveMinSecurity = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.GOMove.MinSecurity", 1);
            s_gomoveMoveMinSecurity = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.GOMove.MinSecurityMove", SEC_GAMEMASTER);
            s_gomoveEnabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.GOMove.Enable", true);

            if (!s_gomoveEnabled)
                return;
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
