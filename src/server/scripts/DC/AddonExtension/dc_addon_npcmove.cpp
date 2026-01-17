/*
 * Dark Chaos - NPCMove Addon Integration
 * ======================================
 *
 * Provides NPC mover controls via the DC Addon Protocol.
 */

#include "dc_addon_namespace.h"
#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "ObjectMgr.h"
#include "MapMgr.h"
#include "Chat.h"
#include "Log.h"
#include "Config.h"
#include "Language.h"
#include "WorldPacket.h"
#include "DatabaseEnv.h"
#include "Cell.h"
#include "CellImpl.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "../GOMove/GOMoveCommandIds.h"
#include <algorithm>
#include <cstring>

namespace DCAddon
{
    namespace NPCMove
    {
        static uint32 s_npcMoveMinSecurity = 1;
        static uint32 s_npcMoveMoveMinSecurity = SEC_GAMEMASTER;
        static bool s_npcMoveEnabled = true;

        struct AllCreaturesInRange
        {
            AllCreaturesInRange(WorldObject const* object, float range) : m_object(object), m_range(range) {}
            bool operator()(Creature* creature) const
            {
                return m_object && creature && m_object->IsWithinDist(creature, m_range, false);
            }

            WorldObject const* m_object;
            float m_range;
        };

        static void GetCreaturesInRange(Player* player, float range, std::list<Creature*>& out)
        {
            if (!player)
                return;
            AllCreaturesInRange check(player, range);
            Acore::CreatureListSearcher<AllCreaturesInRange> searcher(player, out, check);
            Cell::VisitObjects(player, searcher, range);
        }

        static void SendAddonMessage(Player* player, const char* msg)
        {
            if (!player || !msg)
                return;

            char buf[256];
            snprintf(buf, 256, "NPCMOVE\t%s", msg);

            WorldPacket data;
            uint32 messageLength = static_cast<uint32>(std::strlen(buf) + 1);
            data.Initialize(SMSG_MESSAGECHAT, 100);
            data << uint8(CHAT_MSG_SYSTEM);
            data << int32(LANG_ADDON);
            data << player->GetGUID().GetRawValue();
            data << uint32(0);
            data << player->GetGUID().GetRawValue();
            data << uint32(messageLength);
            data << buf;
            data << uint8(0);
            player->GetSession()->SendPacket(&data);
        }

        static void SendAdd(Player* player, ObjectGuid::LowType lowguid)
        {
            CreatureData const* data = sObjectMgr->GetCreatureData(lowguid);
            if (!data)
                return;

            CreatureTemplate const* temp = sObjectMgr->GetCreatureTemplate(data->id1);
            if (!temp)
                return;

            std::string name = temp->Name;
            if (name.empty())
                name = "Unknown Creature";
            std::replace(name.begin(), name.end(), '|', ' ');

            char msg[512];
            snprintf(msg, 512, "ADD|%u|%s|%u|%.4f|%.4f|%.4f", lowguid, name.c_str(), data->id1, data->posX, data->posY, data->posZ);
            SendAddonMessage(player, msg);
        }

        static void SendRemove(Player* player, ObjectGuid::LowType lowguid)
        {
            char msg[256];
            snprintf(msg, 256, "REMOVE|%u||0", lowguid);
            SendAddonMessage(player, msg);
        }

        static Creature* GetCreature(Player* player, ObjectGuid::LowType lowguid)
        {
            return ChatHandler(player->GetSession()).GetCreatureFromPlayerMapByDbGuid(lowguid);
        }

        static bool MoveCreatureTo(Player* player, Creature* creature, float x, float y, float z, float o)
        {
            if (!player || !creature)
                return false;

            if (!MapMgr::IsValidMapCoord(creature->GetMapId(), x, y, z))
                return false;

            if (CreatureData const* data = sObjectMgr->GetCreatureData(creature->GetSpawnId()))
            {
                const_cast<CreatureData*>(data)->posX = x;
                const_cast<CreatureData*>(data)->posY = y;
                const_cast<CreatureData*>(data)->posZ = z;
                const_cast<CreatureData*>(data)->orientation = o;
            }

            creature->SetPosition(x, y, z, o);
            creature->GetMotionMaster()->Initialize();

            if (creature->IsAlive())
            {
                creature->setDeathState(DeathState::JustDied);
                creature->Respawn();
            }

            WorldDatabasePreparedStatement* stmt = WorldDatabase.GetPreparedStatement(WORLD_UPD_CREATURE_POSITION);
            stmt->SetData(0, x);
            stmt->SetData(1, y);
            stmt->SetData(2, z);
            stmt->SetData(3, o);
            stmt->SetData(4, creature->GetSpawnId());
            WorldDatabase.Execute(stmt);

            return true;
        }

        static Creature* SpawnCreature(Player* player, float x, float y, float z, float o, uint32 phase, uint32 entry)
        {
            if (!player || !entry)
                return nullptr;

            if (!MapMgr::IsValidMapCoord(player->GetMapId(), x, y, z))
                return nullptr;

            Map* map = player->GetMap();
            Creature* creature = new Creature();
            if (!creature->Create(map->GenerateLowGuid<HighGuid::Unit>(), map, phase, entry, 0, x, y, z, o))
            {
                delete creature;
                return nullptr;
            }

            creature->SaveToDB(map->GetId(), (1 << map->GetSpawnMode()), phase);

            ObjectGuid::LowType spawnId = creature->GetSpawnId();
            creature->CleanupsBeforeDelete();
            delete creature;

            creature = new Creature();
            if (!creature->LoadCreatureFromDB(spawnId, map, true, true))
            {
                delete creature;
                return nullptr;
            }

            sObjectMgr->AddCreatureToGrid(spawnId, sObjectMgr->GetCreatureData(spawnId));
            return creature;
        }

        static Creature* FindNearestCreature(Player* player, float range)
        {
            if (!player)
                return nullptr;

            std::list<Creature*> creatures;
            GetCreaturesInRange(player, range, creatures);

            Creature* nearest = nullptr;
            float bestDistSq = 0.0f;
            for (Creature* creature : creatures)
            {
                if (!creature || creature->IsPet() || creature->IsTotem())
                    continue;

                float distSq = player->GetExactDistSq(creature);
                if (!nearest || distSq < bestDistSq)
                {
                    nearest = creature;
                    bestDistSq = distSq;
                }
            }

            return nearest;
        }

        static void HandleRequestMove(Player* player, const ParsedMessage& msg)
        {
            if (!DCAddon::CheckAddonPermission(player, Module::NPCMOVE, s_npcMoveMoveMinSecurity))
            {
                DCAddon::SendPermissionDenied(player, Module::NPCMOVE, "Insufficient GM level to use addon commands");
                return;
            }

            if (msg.GetDataCount() < 3)
                return;

            uint32 ID = msg.GetUInt32(0);
            uint32 lowguid = msg.GetUInt32(1);
            uint32 ARG = msg.GetUInt32(2);

            using namespace DarkChaos::GOMove;

            if (ID < SPAWN)
            {
                if (ID >= DELET && ID <= GOTO)
                {
                    Creature* target = GetCreature(player, lowguid);
                    if (!target)
                    {
                        DCAddon::SendError(player, Module::NPCMOVE, "Creature GUID not found");
                        return;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);
                    uint32 p = target->GetPhaseMask();

                    switch (ID)
                    {
                        case DELET:
                        {
                            if (!target->IsPet() && !target->IsTotem())
                            {
                                target->CombatStop();
                                target->DeleteFromDB();
                                target->AddObjectToRemoveList();
                                SendRemove(player, lowguid);
                            }
                        } break;
                        case X: MoveCreatureTo(player, target, player->GetPositionX(), y, z, o); break;
                        case Y: MoveCreatureTo(player, target, x, player->GetPositionY(), z, o); break;
                        case Z: MoveCreatureTo(player, target, x, y, player->GetPositionZ(), o); break;
                        case O: MoveCreatureTo(player, target, x, y, z, player->GetOrientation()); break;
                        case RESPAWN:
                        {
                            if (Creature* spawned = SpawnCreature(player, x, y, z, o, p, target->GetEntry()))
                                SendAdd(player, spawned->GetSpawnId());
                        } break;
                        case GOTO:
                        {
                            if (player->IsInFlight())
                                player->CleanupAfterTaxiFlight();
                            else
                                player->SaveRecallPosition();
                            player->TeleportTo(target->GetMapId(), x, y, z, o);
                        } break;
                        case GROUND:
                        {
                            float ground = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, MAX_HEIGHT);
                            if (ground != INVALID_HEIGHT)
                                MoveCreatureTo(player, target, x, y, ground, o);
                        } break;
                        case FLOOR:
                        {
                            float floor = target->GetMap()->GetHeight(target->GetPhaseMask(), x, y, z);
                            if (floor != INVALID_HEIGHT)
                                MoveCreatureTo(player, target, x, y, floor, o);
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
                            float const new_ori = (multi - multi_int > 0.5f) ? (multi_int + 1) * piper2 : multi_int * piper2;
                            player->SetFacingTo(new_ori);
                        } break;
                        case SELECTNEAR:
                        {
                            ChatHandler handler(player->GetSession());
                            Creature* creature = handler.getSelectedCreature();
                            if (!creature)
                                creature = FindNearestCreature(player, 30.0f);
                            if (!creature)
                                DCAddon::SendError(player, Module::NPCMOVE, "No creatures found");
                            else
                                SendAdd(player, creature->GetSpawnId());
                        } break;
                    }
                }
            }
            else if (ARG && ID >= SPAWN)
            {
                if (ID >= NORTH && ID <= PHASE)
                {
                    Creature* target = GetCreature(player, lowguid);
                    if (!target)
                    {
                        DCAddon::SendError(player, Module::NPCMOVE, "Creature GUID not found");
                        return;
                    }

                    float x, y, z, o;
                    target->GetPosition(x, y, z, o);

                    switch (ID)
                    {
                        case NORTH: MoveCreatureTo(player, target, x + ((float)ARG / 100), y, z, o); break;
                        case EAST: MoveCreatureTo(player, target, x, y - ((float)ARG / 100), z, o); break;
                        case SOUTH: MoveCreatureTo(player, target, x - ((float)ARG / 100), y, z, o); break;
                        case WEST: MoveCreatureTo(player, target, x, y + ((float)ARG / 100), z, o); break;
                        case NORTHEAST: MoveCreatureTo(player, target, x + ((float)ARG / 100), y - ((float)ARG / 100), z, o); break;
                        case SOUTHEAST: MoveCreatureTo(player, target, x - ((float)ARG / 100), y - ((float)ARG / 100), z, o); break;
                        case SOUTHWEST: MoveCreatureTo(player, target, x - ((float)ARG / 100), y + ((float)ARG / 100), z, o); break;
                        case NORTHWEST: MoveCreatureTo(player, target, x + ((float)ARG / 100), y + ((float)ARG / 100), z, o); break;
                        case UP: MoveCreatureTo(player, target, x, y, z + ((float)ARG / 100), o); break;
                        case DOWN: MoveCreatureTo(player, target, x, y, z - ((float)ARG / 100), o); break;
                        case RIGHT: MoveCreatureTo(player, target, x, y, z, o - ((float)ARG / 100)); break;
                        case LEFT: MoveCreatureTo(player, target, x, y, z, o + ((float)ARG / 100)); break;
                        case PHASE:
                        {
                            target->SetPhaseMask(ARG, true);
                            if (!target->IsPet())
                                target->SaveToDB();
                            if (CreatureData const* data = sObjectMgr->GetCreatureData(target->GetSpawnId()))
                                const_cast<CreatureData*>(data)->phaseMask = ARG;
                        } break;
                    }
                }
                else
                {
                    switch (ID)
                    {
                        case SPAWN:
                        case SPAWNSPELL:
                        {
                            if (Creature* spawned = SpawnCreature(player,
                                player->GetPositionX(),
                                player->GetPositionY(),
                                player->GetPositionZ(),
                                player->GetOrientation(),
                                player->GetPhaseMaskForSpawn(),
                                ARG))
                            {
                                SendAdd(player, spawned->GetSpawnId());
                            }
                        } break;
                        case SELECTALLNEAR:
                        {
                            float range = static_cast<float>(ARG);
                            std::list<Creature*> creatures;
                            GetCreaturesInRange(player, range, creatures);
                            for (Creature* creature : creatures)
                            {
                                if (!creature || creature->IsPet() || creature->IsTotem())
                                    continue;
                                SendAdd(player, creature->GetSpawnId());
                            }
                        } break;
                    }
                }
            }
        }

        void RegisterHandlers()
        {
            s_npcMoveMinSecurity = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.NPCMove.MinSecurity", 1);
            s_npcMoveMoveMinSecurity = sConfigMgr->GetOption<uint32>("DC.AddonProtocol.NPCMove.MinSecurityMove", SEC_GAMEMASTER);
            s_npcMoveEnabled = sConfigMgr->GetOption<bool>("DC.AddonProtocol.NPCMove.Enable", true);

            if (!s_npcMoveEnabled)
                return;

            DC_REGISTER_HANDLER(Module::NPCMOVE, Opcode::NPCMove::CMSG_REQUEST_MOVE, HandleRequestMove);
        }
    }
}

void AddSC_DCAddon_NPCMove()
{
    DCAddon::NPCMove::RegisterHandlers();
}
