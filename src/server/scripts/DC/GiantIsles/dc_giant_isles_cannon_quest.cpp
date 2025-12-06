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
#include "Log.h"

// ============================================================================
// CONSTANTS
// ============================================================================

enum CannonQuestData
{
    // NPC Entries (aligned with giant_isles_creatures.sql)
    NPC_CAPTAIN_HARLAN          = 400320,   // Quest giver
    NPC_COASTAL_CANNON          = 400321,   // Vehicle cannon
    NPC_ZANDALARI_SCOUT_SHIP    = 400322,   // Target ship (invisible creature + visual spell)
    NPC_SHIP_VISUAL_TRIGGER     = 400323,   // Visual trigger for ship explosion

    // Quest
    QUEST_SINK_THE_SCOUT        = 80100,

    // Spells
    SPELL_CANNON_BLAST          = 69399,    // Main cannon attack (from ICC Gunship)
    SPELL_CANNON_BLAST_DAMAGE   = 69401,    // Damage spell from cannon
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
        npc_coastal_cannonAI(Creature* creature) : VehicleAI(creature) { }

        void Reset() override
        {
            VehicleAI::Reset();
        }

        void PassengerBoarded(Unit* passenger, int8 /*seatId*/, bool apply) override
        {
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
            // Check if player has the quest
            if (player->GetQuestStatus(QUEST_SINK_THE_SCOUT) != QUEST_STATUS_INCOMPLETE)
            {
                // Player doesn't have the quest, inform them
                me->Whisper("You need the 'Sink the Zandalari Scout' quest to use this cannon.", 
                    LANG_UNIVERSAL, player);
                return;
            }

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
            // Spawn the ship at the starting position
            // TODO: Update these coordinates to actual spawn position
            float shipX = me->GetPositionX() + 100.0f;  // Placeholder - 100 units in front
            float shipY = me->GetPositionY();
            float shipZ = me->GetPositionZ() - 5.0f;    // Slightly lower (on water)
            float shipO = me->GetOrientation() + M_PI;  // Facing cannon

            Creature* ship = me->SummonCreature(NPC_ZANDALARI_SCOUT_SHIP, 
                shipX, shipY, shipZ, shipO, 
                TEMPSUMMON_TIMED_OR_DEAD_DESPAWN, SHIP_DESPAWN_TIMER);

            if (!ship)
            {
                LOG_ERROR("scripts.dc", "Giant Isles Cannon: Failed to spawn ship for player {}", 
                    player->GetName());
                return;
            }

            // Set the ship's creator to this player (for phasing/ownership)
            ship->SetCreatorGUID(player->GetGUID());

            // Store the mapping
            PlayerShipMap[player->GetGUID()] = ship->GetGUID();
            ShipHitCount[ship->GetGUID()] = 0;

            // Start the ship moving on its patrol path
            if (ship->AI())
            {
                // Cast visual aura for ship appearance
                ship->CastSpell(ship, SPELL_BOAT_VISUAL, true);
            }

            // Start movement along waypoints
            ship->GetMotionMaster()->MovePath(PATH_SHIP_PATROL, true);

            me->Whisper("Target acquired! A Zandalari scout ship is approaching. Open fire!", 
                LANG_UNIVERSAL, player);

            LOG_DEBUG("scripts.dc", "Giant Isles Cannon: Ship {} spawned for player {}", 
                ship->GetGUID().ToString(), player->GetName());
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
                            ship->DespawnOrUnsummon(1000);
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
// NPC SCRIPT - ZANDALARI SCOUT SHIP (Target)
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

        void InitializeAI() override
        {
            // Make the ship unattackable by normal means (only cannon can damage)
            me->SetUnitFlag(UNIT_FLAG_NOT_SELECTABLE);
            me->SetImmuneToPC(true);
            me->SetReactState(REACT_PASSIVE);

            // Apply visual spell for ship appearance
            me->CastSpell(me, SPELL_BOAT_VISUAL, true);
        }

        void SpellHit(Unit* caster, SpellInfo const* spellInfo) override
        {
            if (!caster || !spellInfo)
                return;

            // Check if this is a cannon blast
            if (spellInfo->Id != SPELL_CANNON_BLAST && spellInfo->Id != SPELL_CANNON_BLAST_DAMAGE)
                return;

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

            if (!player)
                return;

            // Verify this is the player's ship
            if (me->GetCreatorGUID() != player->GetGUID())
                return;

            // Increment hit count
            _hitCount++;
            ShipHitCount[me->GetGUID()] = _hitCount;

            LOG_DEBUG("scripts.dc", "Giant Isles Ship: Hit {} of {} for player {}", 
                _hitCount, HITS_REQUIRED, player->GetName());

            // Visual feedback
            me->CastSpell(me, SPELL_SHIP_FIRE_VISUAL, true);

            // Inform player of progress
            if (_hitCount < HITS_REQUIRED)
            {
                char msg[100];
                snprintf(msg, 100, "Direct hit! %u more hit%s to sink the ship!", 
                    HITS_REQUIRED - _hitCount, 
                    (HITS_REQUIRED - _hitCount) > 1 ? "s" : "");
                
                if (Creature* cannon = me->FindNearestCreature(NPC_COASTAL_CANNON, 200.0f))
                    cannon->Whisper(msg, LANG_UNIVERSAL, player);
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

            // Grant quest credit
            player->KilledMonsterCredit(NPC_ZANDALARI_SCOUT_SHIP);

            LOG_INFO("scripts.dc", "Giant Isles: Ship sunk by player {}", player->GetName());

            // Clean up player mapping
            PlayerShipMap.erase(player->GetGUID());
            ShipHitCount.erase(me->GetGUID());
        }

        void UpdateAI(uint32 diff) override
        {
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
// SPELL SCRIPT - CANNON BLAST (Target Validation)
// Ensures cannon only hits the player's personal ship
// ============================================================================

class spell_cannon_blast_giant_isles : public SpellScript
{
    PrepareSpellScript(spell_cannon_blast_giant_isles);

    void FilterTargets(std::list<WorldObject*>& targets)
    {
        Unit* caster = GetCaster();
        if (!caster)
            return;

        // Get the player controlling the cannon
        Player* player = nullptr;
        if (Vehicle* vehicle = caster->GetVehicleKit())
        {
            if (Unit* passenger = vehicle->GetPassenger(0))
                player = passenger->ToPlayer();
        }

        if (!player)
        {
            targets.clear();
            return;
        }

        // Only target the ship that belongs to this player
        targets.remove_if([player](WorldObject* target) -> bool
        {
            if (Creature* creature = target->ToCreature())
            {
                if (creature->GetEntry() == NPC_ZANDALARI_SCOUT_SHIP)
                {
                    // Only hit ships created by this player
                    return creature->GetCreatorGUID() != player->GetGUID();
                }
            }
            return false; // Don't remove other valid targets
        });
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(
            spell_cannon_blast_giant_isles::FilterTargets, EFFECT_0, TARGET_UNIT_DEST_AREA_ENEMY);
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
    RegisterSpellScript(spell_cannon_blast_giant_isles);
}
