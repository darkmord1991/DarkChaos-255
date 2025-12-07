/*
 * Giant Isles - Cannon Quest Script
 * ============================================================================
 * Daily Quest: "Sink the Zandalari Scout"
 * 
 * Mechanics:
 *   - Player speaks to Captain Harlan to get the quest
 *   - Player enters a Coastal Cannon (vehicle)
 *   - When seated, a personal Zandalari Scout Ship spawns and follows waypoints
 *   - Player fires cannon at the ship (5 hits required to sink)
 *   - Ship sinks with visual effects, quest credit granted
 *   - Ship is personal (phased per player via summoner)
 * ============================================================================
 * Entry Range: 400320-400329 (Cannon Quest NPCs)
 * Quest ID: 80100
 * ============================================================================
 */

#include "ScriptMgr.h"
#include "Player.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "Vehicle.h"
#include "SpellScript.h"
#include "SpellAuras.h"
#include "TemporarySummon.h"
#include "ObjectAccessor.h"
#include "MotionMaster.h"
#include "MovementTypedefs.h"
#include "WaypointMgr.h"
#include "GameObject.h"
#include "Log.h"
#include "ScriptedCreature.h"

// ============================================================================
// CONSTANTS
// ============================================================================

enum CannonQuestData
{
    // NPC Entries (aligned with giant_isles_creatures.sql)
    NPC_CAPTAIN_HARLAN          = 400320,   // Quest giver
    NPC_COASTAL_CANNON          = 400321,   // Vehicle cannon
    GO_ZANDALARI_SCOUT_SHIP     = 400322,   // Ship GameObject (visual)
    NPC_SHIP_VISUAL_TRIGGER     = 400323,   // Visual trigger for ship explosion
    NPC_SHIP_HITBOX             = 400324,   // Invisible hitbox creature for damage

    // Quest
    QUEST_SINK_THE_SCOUT        = 80100,

    // Spells
    SPELL_CANNON_BLAST          = 69399,    // Main cannon attack (from ICC Gunship) - triggers missile
    SPELL_CANNON_BLAST_MISSILE  = 69400,    // The actual missile (triggered by 69399)
    SPELL_INCINERATING_BLAST    = 70174,    // Secondary cannon attack
    SPELL_INCINERATING_DAMAGE   = 69401,    // Damage from incinerating (triggered by 70174)
    SPELL_INCINERATING_MISSILE  = 69402,    // Missile from incinerating blast
    SPELL_SHIP_FIRE_VISUAL      = 70161,    // Fire visual on ship
    SPELL_SHIP_EXPLOSION        = 30934,    // Large explosion visual
    SPELL_SHIP_SMOKE            = 36469,    // Smoke visual
    SPELL_SHIP_SINKING          = 69263,    // Submerge visual (creature goes underwater)
    SPELL_BOAT_VISUAL           = 45693,    // Ship appearance visual (if available)

    // Mechanics
    HITS_REQUIRED               = 5,        // Hits needed to sink ship
    SHIP_DESPAWN_TIMER          = 5 * 60 * 1000, // 5 minutes timeout
    SHIP_SINK_TIMER             = 5000,     // 5 seconds to fully sink after destroyed

    // Gossip
    GOSSIP_MENU_CAPTAIN         = 400320,
    GOSSIP_TEXT_CAPTAIN         = 400320,

    // Waypoint Path ID
    PATH_SHIP_PATROL            = 4003220,  // Path for ship movement
};

enum ShipEvents
{
    EVENT_START_WAYPOINTS       = 1,
    EVENT_CHECK_ESCAPE          = 2,
};

// ============================================================================
// SHIP HIT TRACKING
// Using a map to track hits per player (since ships are personal)
// ============================================================================

static std::unordered_map<ObjectGuid, uint8> ShipHitCount;
static std::unordered_map<ObjectGuid, ObjectGuid> PlayerShipMap; // Player -> Ship mapping

// ============================================================================
// NPC SCRIPT - CAPTAIN HARLAN (Quest Giver)
// ============================================================================

class npc_captain_harlan : public CreatureScript
{
public:
    npc_captain_harlan() : CreatureScript("npc_captain_harlan") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return false;

        // Check if player has the quest
        if (player->GetQuestStatus(QUEST_SINK_THE_SCOUT) == QUEST_STATUS_INCOMPLETE)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, 
                "The cannon is ready, Captain. I'll sink that scout ship!", 
                GOSSIP_SENDER_MAIN, 1);
        }

        // Default quest giver behavior
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());

        SendGossipMenuFor(player, GOSSIP_TEXT_CAPTAIN, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return false;

        CloseGossipMenuFor(player);

        if (action == 1)
        {
            // Direct player to the cannon
            creature->Whisper("The coastal cannon is just down the hill, soldier. "
                "Get in there and show those Zandalari what we're made of!", 
                LANG_UNIVERSAL, player);
        }

        return true;
    }

    bool OnQuestAccept(Player* player, Creature* creature, Quest const* quest) override
    {
        if (!player || !creature || !quest)
            return false;

        if (quest->GetQuestId() == QUEST_SINK_THE_SCOUT)
        {
            creature->Whisper("A Zandalari scout ship has been spotted off the coast. "
                "Use our coastal cannon to sink it before they can report back!", 
                LANG_UNIVERSAL, player);
        }

        return false;
    }
};

// ============================================================================
// NPC SCRIPT - COASTAL CANNON (Vehicle)
// ============================================================================

class npc_coastal_cannon : public CreatureScript
{
public:
    npc_coastal_cannon() : CreatureScript("npc_coastal_cannon") { }

    struct npc_coastal_cannonAI : public VehicleAI
    {
        npc_coastal_cannonAI(Creature* creature) : VehicleAI(creature) 
        {
            LOG_INFO("scripts.dc", "Giant Isles Cannon: AI created for cannon {}", creature->GetGUID().ToString());
        }

        void Reset() override
        {
            VehicleAI::Reset();
            LOG_INFO("scripts.dc", "Giant Isles Cannon: AI Reset called");
        }

        void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
        {
            LOG_INFO("scripts.dc", "Giant Isles Cannon: PassengerBoarded called, apply={}", apply);
            
            if (!passenger || !passenger->IsPlayer())
                return;

            Player* player = passenger->ToPlayer();

            if (apply)
            {
                // Player entered the cannon
                OnPlayerEnterCannon(player);
            }
            else
            {
                // Player exited the cannon
                OnPlayerExitCannon(player);
            }
        }

        void OnPlayerEnterCannon(Player* player)
        {
            LOG_INFO("scripts.dc", "Giant Isles Cannon: Player {} entered cannon", player->GetName());

            // Check if player has the quest (or allow for testing without quest)
            QuestStatus questStatus = player->GetQuestStatus(QUEST_SINK_THE_SCOUT);
            LOG_INFO("scripts.dc", "Giant Isles Cannon: Quest {} status = {}", QUEST_SINK_THE_SCOUT, uint32(questStatus));

            // For now, allow usage even without quest for testing
            // TODO: Re-enable quest check after testing
            /*
            if (questStatus != QUEST_STATUS_INCOMPLETE)
            {
                me->Whisper("You need the 'Sink the Zandalari Scout' quest to use this cannon.", 
                    LANG_UNIVERSAL, player);
                return;
            }
            */

            // Check if player already has a ship spawned
            auto it = PlayerShipMap.find(player->GetGUID());
            if (it != PlayerShipMap.end())
            {
                // Ship already exists, check if it's still valid
                if (Creature* existingShip = ObjectAccessor::GetCreature(*me, it->second))
                {
                    if (existingShip->IsAlive())
                    {
                        me->Whisper("Your target ship is still out there! Take aim!", 
                            LANG_UNIVERSAL, player);
                        return;
                    }
                }
                // Ship is gone, clean up
                PlayerShipMap.erase(it);
            }

            // Spawn personal ship for this player
            SpawnShipForPlayer(player);
        }

        void SpawnShipForPlayer(Player* player)
        {
            LOG_INFO("scripts.dc", "Giant Isles Cannon: SpawnShipForPlayer called for {}", player->GetName());

            // Spawn the ship at first waypoint position
            // Waypoint path 4003220 starts at (5835.31, 1738.56, -2.14912)
            float shipX = 5835.31f;  // First waypoint X
            float shipY = 1738.56f;  // First waypoint Y
            float shipZ = -2.14f;    // Water level
            float shipO = 4.05f;     // First waypoint orientation

            LOG_INFO("scripts.dc", "Giant Isles Cannon: Attempting to spawn ship at ({}, {}, {})", shipX, shipY, shipZ);

            // Just spawn a single creature - it will be the visual AND hitbox
            // Using NPC_SHIP_HITBOX which should have a visible ship model
            Creature* ship = me->SummonCreature(NPC_SHIP_HITBOX,
                shipX, shipY, shipZ, shipO,
                TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, SHIP_DESPAWN_TIMER);

            if (!ship)
            {
                LOG_ERROR("scripts.dc", "Giant Isles Cannon: Failed to spawn ship creature for player {}", player->GetName());
                // Try to send a message to player about failure
                ChatHandler(player->GetSession()).PSendSysMessage("DEBUG: Ship spawn failed!");
                return;
            }

            LOG_INFO("scripts.dc", "Giant Isles Cannon: Ship creature {} spawned successfully", ship->GetGUID().ToString());

            // Set the ship's creator to this player (for phasing/ownership)
            ship->SetCreatorGUID(player->GetGUID());

            // Store the mapping
            PlayerShipMap[player->GetGUID()] = ship->GetGUID();
            ShipHitCount[ship->GetGUID()] = 0;

            me->Whisper("Target acquired! A Zandalari scout ship is approaching. Open fire!",
                LANG_UNIVERSAL, player);
        }

        void OnPlayerExitCannon(Player* player)
        {
            // Check if player has a ship and clean up if quest not complete
            auto it = PlayerShipMap.find(player->GetGUID());
            if (it != PlayerShipMap.end())
            {
                if (Creature* ship = ObjectAccessor::GetCreature(*me, it->second))
                {
                    // Only despawn if quest is still incomplete (player abandoned)
                    if (player->GetQuestStatus(QUEST_SINK_THE_SCOUT) == QUEST_STATUS_INCOMPLETE)
                    {
                        // Check if ship is still alive (not already sunk)
                        if (ship->IsAlive())
                        {
                            ship->DespawnOrUnsummon(1s);
                            me->Whisper("The ship is escaping! You'll have to try again.", 
                                LANG_UNIVERSAL, player);
                        }
                    }
                }

                // Clean up tracking
                ShipHitCount.erase(it->second);
                PlayerShipMap.erase(it);
            }
        }

        // Called when cannon finishes casting a spell
        void OnSpellCastFinished(SpellInfo const* spell, SpellFinishReason reason) override
        {
            if (!spell)
                return;

            // Only process successful cannon spell casts
            if (reason != SPELL_FINISHED_SUCCESSFUL_CAST)
                return;

            // Check if this is a cannon spell
            if (spell->Id != SPELL_CANNON_BLAST && spell->Id != SPELL_INCINERATING_BLAST)
                return;

            LOG_INFO("scripts.dc", "Giant Isles Cannon: Cannon fired spell {} ({})", spell->Id, spell->SpellName[0]);

            // Get the player in the cannon
            Player* player = nullptr;
            if (Vehicle* vehicle = me->GetVehicleKit())
            {
                if (Unit* passenger = vehicle->GetPassenger(0))
                    player = passenger->ToPlayer();
            }

            if (!player)
            {
                LOG_INFO("scripts.dc", "Giant Isles Cannon: No player in cannon");
                return;
            }

            // Find the player's ship
            auto it = PlayerShipMap.find(player->GetGUID());
            if (it == PlayerShipMap.end())
            {
                LOG_INFO("scripts.dc", "Giant Isles Cannon: No ship found for player");
                return;
            }

            Creature* ship = ObjectAccessor::GetCreature(*me, it->second);
            if (!ship || !ship->IsAlive())
            {
                LOG_INFO("scripts.dc", "Giant Isles Cannon: Ship not found or dead");
                return;
            }

            // Directly notify the ship of a hit
            // We'll call a custom function or use SpellHit simulation
            if (ship->AI())
            {
                // Cast a dummy spell or use DamageTaken to register the hit
                // Using SetData to communicate with ship AI
                ship->AI()->SetData(1, spell->Id); // 1 = "cannon hit" event
                LOG_INFO("scripts.dc", "Giant Isles Cannon: Notified ship of cannon hit!");
            }
        }

        void UpdateAI(uint32 /*diff*/) override
        {
            // Cannon doesn't need active AI behavior
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_coastal_cannonAI(creature);
    }
};

// ============================================================================
// NPC SCRIPT - SHIP HITBOX (Invisible target creature)
// ============================================================================

class npc_zandalari_scout_ship : public CreatureScript
{
public:
    npc_zandalari_scout_ship() : CreatureScript("npc_zandalari_scout_ship") { }

    struct npc_zandalari_scout_shipAI : public ScriptedAI
    {
        npc_zandalari_scout_shipAI(Creature* creature) : ScriptedAI(creature) 
        {
            _hitCount = 0;
            _isSinking = false;
            _sinkTimer = 0;
        }

        void Reset() override
        {
            _hitCount = 0;
            _isSinking = false;
            _sinkTimer = 0;
        }

        // Called by cannon AI when a cannon spell is fired
        void SetData(uint32 type, uint32 data) override
        {
            if (type == 1) // Cannon hit event
            {
                LOG_INFO("scripts.dc", "Giant Isles Ship: SetData received cannon hit, spell={}", data);
                
                if (_isSinking)
                    return;

                // Get the player who owns this ship
                Player* player = ObjectAccessor::GetPlayer(*me, me->GetCreatorGUID());
                if (!player)
                {
                    LOG_INFO("scripts.dc", "Giant Isles Ship: No owner player found");
                    return;
                }

                RegisterHit(player);
            }
        }

        void RegisterHit(Player* player)
        {
            if (_isSinking || !player)
                return;

            // Increment hit count
            _hitCount++;
            ShipHitCount[me->GetGUID()] = _hitCount;

            LOG_INFO("scripts.dc", "Giant Isles Ship: Hit {} of {} for player {}", 
                _hitCount, HITS_REQUIRED, player->GetName());

            // Visual feedback - explosion
            me->CastSpell(me, SPELL_SHIP_EXPLOSION, true);

            // Inform player of progress
            if (_hitCount < HITS_REQUIRED)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Direct hit!|r %u more hit%s to sink the ship!", 
                    HITS_REQUIRED - _hitCount, 
                    (HITS_REQUIRED - _hitCount) > 1 ? "s" : "");
            }
            else
            {
                // Ship is sinking!
                StartSinking(player);
            }
        }

        void InitializeAI() override
        {
            // Ship is selectable and passive - only cannon can hit it
            me->SetReactState(REACT_PASSIVE);
            // Don't disable movement - ship will patrol on waypoints
            LOG_INFO("scripts.dc", "Giant Isles Ship: AI initialized for ship {}", me->GetGUID().ToString());
            
            // Start waypoint movement after a short delay
            _events.ScheduleEvent(EVENT_START_WAYPOINTS, 2s);
        }

        // Handle any damage taken (more reliable than SpellHit for vehicle spells)
        void DamageTaken(Unit* attacker, uint32& damage, DamageEffectType /*damagetype*/, SpellSchoolMask /*damageSchoolMask*/) override
        {
            LOG_INFO("scripts.dc", "Giant Isles Ship: DamageTaken called, damage={}, attacker={}", 
                damage, attacker ? attacker->GetName() : "null");

            if (!attacker || _isSinking)
            {
                damage = 0;
                return;
            }

            // Get the player who fired (might be in vehicle)
            Player* player = nullptr;
            if (attacker->IsPlayer())
            {
                player = attacker->ToPlayer();
            }
            else if (attacker->IsCreature())
            {
                // Attacker is cannon, get the passenger
                if (Vehicle* vehicle = attacker->GetVehicleKit())
                {
                    if (Unit* passenger = vehicle->GetPassenger(0))
                        player = passenger->ToPlayer();
                }
                // Also try getting controlled player
                if (!player)
                {
                    if (Unit* charmer = attacker->GetCharmerOrOwner())
                        player = charmer->ToPlayer();
                }
            }

            if (!player)
            {
                LOG_INFO("scripts.dc", "Giant Isles Ship: No player found from attacker");
                damage = 0;
                return;
            }

            // Verify this is the player's ship
            if (me->GetCreatorGUID() != player->GetGUID())
            {
                LOG_INFO("scripts.dc", "Giant Isles Ship: Ship creator mismatch");
                damage = 0;
                return;
            }

            // Prevent actual damage (we track hits instead)
            damage = 0;

            // Increment hit count
            _hitCount++;
            ShipHitCount[me->GetGUID()] = _hitCount;

            LOG_INFO("scripts.dc", "Giant Isles Ship: Hit {} of {} for player {}", 
                _hitCount, HITS_REQUIRED, player->GetName());

            // Visual feedback - use a simple visual that definitely exists
            me->CastSpell(me, 30934, true); // Explosion visual

            // Inform player of progress
            if (_hitCount < HITS_REQUIRED)
            {
                ChatHandler(player->GetSession()).PSendSysMessage("|cFF00FF00Direct hit!|r %u more hit%s to sink the ship!", 
                    HITS_REQUIRED - _hitCount, 
                    (HITS_REQUIRED - _hitCount) > 1 ? "s" : "");
            }
            else
            {
                // Ship is sinking!
                StartSinking(player);
            }
        }

        void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
        {
            LOG_INFO("scripts.dc", "Giant Isles Ship: SpellHit called, spell={}", spellInfo ? spellInfo->Id : 0);
            
            if (!caster || !spellInfo)
                return;

            // Check if this is any cannon-related spell
            switch (spellInfo->Id)
            {
                case SPELL_CANNON_BLAST:        // 69399 - Main cannon cast
                case SPELL_CANNON_BLAST_MISSILE:// 69400 - Missile impact
                case SPELL_INCINERATING_BLAST:  // 70174 - Incinerating cast
                case SPELL_INCINERATING_DAMAGE: // 69401 - Incinerating damage
                case SPELL_INCINERATING_MISSILE:// 69402 - Incinerating missile
                    break; // These are valid cannon spells
                default:
                    return; // Not a cannon spell
            }

            // Already sinking, ignore hits
            if (_isSinking)
                return;

            // Get the player who fired (might be in vehicle)
            Player* player = nullptr;
            if (caster->IsPlayer())
                player = caster->ToPlayer();
            else if (caster->IsCreature())
            {
                // Caster is cannon, get the passenger
                if (Vehicle* vehicle = caster->GetVehicleKit())
                {
                    if (Unit* passenger = vehicle->GetPassenger(0))
                        player = passenger->ToPlayer();
                }
            }

            // If still no player, check summon owner
            if (!player && caster->GetOwnerGUID())
            {
                if (Player* owner = ObjectAccessor::GetPlayer(*me, caster->GetOwnerGUID()))
                    player = owner;
            }

            if (!player)
            {
                LOG_INFO("scripts.dc", "Giant Isles Ship: SpellHit - no player found from caster");
                return;
            }

            // Verify this is the player's ship
            if (me->GetCreatorGUID() != player->GetGUID())
            {
                LOG_INFO("scripts.dc", "Giant Isles Ship: SpellHit - wrong player (creator={}, attacker={})", 
                    me->GetCreatorGUID().ToString(), player->GetGUID().ToString());
                return;
            }

            // Increment hit count
            _hitCount++;
            ShipHitCount[me->GetGUID()] = _hitCount;

            LOG_INFO("scripts.dc", "Giant Isles Ship: SpellHit registered! Hit {} of {} for player {}", 
                _hitCount, HITS_REQUIRED, player->GetName());

            // Visual feedback
            me->CastSpell(me, SPELL_SHIP_EXPLOSION, true);

            // Inform player of progress
            if (_hitCount < HITS_REQUIRED)
            {
                // Build message without printf-style percent placeholders to avoid
                // client/server formatting issues leaving literal % sequences.
                std::string msg = "Direct hit! ";
                msg += std::to_string(HITS_REQUIRED - _hitCount);
                msg += " more hit";
                if ((HITS_REQUIRED - _hitCount) > 1)
                    msg += "s";
                msg += " to sink the ship!";

                if (Creature* cannon = me->FindNearestCreature(NPC_COASTAL_CANNON, 200.0f))
                    cannon->Whisper(msg.c_str(), LANG_UNIVERSAL, player);
            }
            else
            {
                // Ship is sinking!
                StartSinking(player);
            }
        }

        void StartSinking(Player* player)
        {
            if (_isSinking)
                return;

            _isSinking = true;
            _sinkTimer = SHIP_SINK_TIMER;

            // Stop movement
            me->StopMoving();
            me->GetMotionMaster()->Clear();

            // Big explosion
            me->CastSpell(me, SPELL_SHIP_EXPLOSION, true);
            me->CastSpell(me, SPELL_SHIP_SMOKE, true);

            // Zone-wide message for the player
            if (Creature* cannon = me->FindNearestCreature(NPC_COASTAL_CANNON, 200.0f))
            {
                cannon->Whisper("|cFF00FF00The Zandalari scout ship is sinking! Great work, soldier!|r", 
                    LANG_UNIVERSAL, player);
            }

            // Grant quest credit (use hitbox entry)
            player->KilledMonsterCredit(NPC_SHIP_HITBOX);

            LOG_INFO("scripts.dc", "Giant Isles: Ship sunk by player {}", player->GetName());

            // Clean up player mapping
            PlayerShipMap.erase(player->GetGUID());
            ShipHitCount.erase(me->GetGUID());
        }

        void UpdateAI(uint32 diff) override
        {
            _events.Update(diff);

            if (_isSinking)
            {
                if (_sinkTimer <= diff)
                {
                    // Despawn the ship
                    me->DespawnOrUnsummon();
                }
                else
                {
                    _sinkTimer -= diff;
                }
                return;
            }

            // Handle scheduled events
            while (uint32 eventId = _events.ExecuteEvent())
            {
                switch (eventId)
                {
                    case EVENT_START_WAYPOINTS:
                    {
                        LOG_INFO("scripts.dc", "Giant Isles Ship: Starting waypoint patrol");
                        // Use smooth path movement along a patrol route
                        // Create waypoints dynamically for the ship to follow
                        me->GetMotionMaster()->Clear();
                        // Use MoveWaypoint which accepts a repeatable flag (true = repeating patrol)
                        me->GetMotionMaster()->MoveWaypoint(PATH_SHIP_PATROL, true);
                        break;
                    }
                    default:
                        break;
                }
            }
        }

        void MovementInform(uint32 type, uint32 pointId) override
        {
            // Handle waypoint completion if needed
            if (type == WAYPOINT_MOTION_TYPE)
            {
                // Ship completed a waypoint
                LOG_DEBUG("scripts.dc", "Giant Isles Ship: Reached waypoint {}", pointId);
            }
        }

    private:
        EventMap _events;
        uint8 _hitCount;
        bool _isSinking;
        uint32 _sinkTimer;
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_zandalari_scout_shipAI(creature);
    }
};

// ============================================================================
// REGISTER SCRIPTS
// ============================================================================

void AddSC_giant_isles_cannon_quest()
{
    new npc_captain_harlan();
    new npc_coastal_cannon();
    new npc_zandalari_scout_ship();
    // Note: Cannon spell targeting is handled via conditions table
    // See giant_isles_creatures.sql - conditions for spells 69400, 69402
    // The ship's SpellHit handler will count hits and sink the ship
}
