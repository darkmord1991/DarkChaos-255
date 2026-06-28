/*
 * DarkChaos - Minigob Manabonk ambiance for the guildhouse Legion Dalaran (map 1413).
 *
 * A port of TrinityCore's npc_minigob_manabonk (Northrend Dalaran prank) adapted for the
 * instanced guildhouse: the stock script keys off ZONE_DALARAN (4395), which the custom 1413
 * map is not, so it would never find players. This variant selects from the creature's MAP
 * instead (the whole 1413 instance IS the Dalaran), then polymorphs a random player, mails the
 * "Hot Soup" prank note, laughs and blinks away.
 *
 * Runs on a dedicated entry (800050) with ScriptName 'npc_dc_manabonk'; the stock 32838 is left
 * untouched so Northrend Dalaran behaves exactly as before.
 */

#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "Player.h"
#include "Mail.h"
#include "Containers.h"
#include "Random.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "MotionMaster.h"

enum ManabonkData
{
    SPELL_MANABONKED       = 61839,
    SPELL_TELEPORT_VISUAL  = 51347,
    SPELL_IMPROVED_BLINK   = 61995,

    EVENT_SELECT_TARGET    = 1,
    EVENT_LAUGH_1          = 2,
    EVENT_WANDER           = 3,
    EVENT_PAUSE            = 4,
    EVENT_CAST             = 5,
    EVENT_LAUGH_2          = 6,
    EVENT_BLINK            = 7,
    EVENT_DESPAWN          = 8,

    MAIL_MINIGOB_ENTRY     = 264,
    MAIL_DELIVER_DELAY_MIN = 5 * MINUTE,
    MAIL_DELIVER_DELAY_MAX = 15 * MINUTE
};

struct npc_dc_manabonk : public ScriptedAI
{
    npc_dc_manabonk(Creature* creature) : ScriptedAI(creature)
    {
        me->setActive(true);
    }

    void Reset() override
    {
        _playerGuid.Clear();
        me->SetVisible(false);
        _events.ScheduleEvent(EVENT_SELECT_TARGET, 1s);
    }

    void GetMapPlayers(std::vector<Player*>& playerList) const
    {
        Map::PlayerList const& players = me->GetMap()->GetPlayers();
        for (Map::PlayerList::const_iterator itr = players.begin(); itr != players.end(); ++itr)
            if (Player* player = itr->GetSource())
                if (player->IsInWorld() && !player->IsFlying() && !player->IsMounted() && !player->IsGameMaster())
                    playerList.push_back(player);
    }

    void SendMailToPlayer(Player* player) const
    {
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        int16 deliverDelay = irand(MAIL_DELIVER_DELAY_MIN, MAIL_DELIVER_DELAY_MAX);
        MailDraft(MAIL_MINIGOB_ENTRY, true).SendMailTo(trans, MailReceiver(player),
            MailSender(MAIL_CREATURE, uint64(me->GetEntry())), MAIL_CHECK_MASK_NONE, deliverDelay);
        CharacterDatabase.CommitTransaction(trans);
    }

    void UpdateAI(uint32 diff) override
    {
        _events.Update(diff);

        while (uint32 eventId = _events.ExecuteEvent())
        {
            switch (eventId)
            {
                case EVENT_SELECT_TARGET:
                {
                    std::vector<Player*> playerList;
                    GetMapPlayers(playerList);

                    // chance scales with population (>=100 players = guaranteed, else N%)
                    if (playerList.empty() || urand(1, 100) > playerList.size())
                    {
                        me->AddObjectToRemoveList();
                        break;
                    }

                    me->SetVisible(true);
                    DoCastSelf(SPELL_TELEPORT_VISUAL);
                    if (Player* player = Acore::Containers::SelectRandomContainerElement(playerList))
                    {
                        _playerGuid = player->GetGUID();
                        Position pos = player->GetPosition();
                        player->MovePositionToFirstCollision(pos, frand(10.0f, 30.0f), frand(0.0f, 6.28318f));
                        me->NearTeleportTo(pos.GetPositionX(), pos.GetPositionY(), pos.GetPositionZ(), pos.GetOrientation());
                    }
                    _events.ScheduleEvent(EVENT_LAUGH_1, 2s);
                    break;
                }
                case EVENT_LAUGH_1:
                    me->HandleEmoteCommand(EMOTE_ONESHOT_LAUGH_NO_SHEATHE);
                    _events.ScheduleEvent(EVENT_WANDER, 3s);
                    break;
                case EVENT_WANDER:
                    me->GetMotionMaster()->MoveRandom(8);
                    _events.ScheduleEvent(EVENT_PAUSE, 1min);
                    break;
                case EVENT_PAUSE:
                    me->GetMotionMaster()->MoveIdle();
                    _events.ScheduleEvent(EVENT_CAST, 2s);
                    break;
                case EVENT_CAST:
                    if (Player* player = ObjectAccessor::GetPlayer(*me, _playerGuid))
                    {
                        DoCast(player, SPELL_MANABONKED);
                        SendMailToPlayer(player);
                    }
                    else
                    {
                        me->AddObjectToRemoveList();
                        break;
                    }
                    _events.ScheduleEvent(EVENT_LAUGH_2, 8s);
                    break;
                case EVENT_LAUGH_2:
                    me->HandleEmoteCommand(EMOTE_ONESHOT_LAUGH_NO_SHEATHE);
                    _events.ScheduleEvent(EVENT_BLINK, 3s);
                    break;
                case EVENT_BLINK:
                    DoCastSelf(SPELL_IMPROVED_BLINK);
                    _events.ScheduleEvent(EVENT_DESPAWN, 4s);
                    break;
                case EVENT_DESPAWN:
                    me->AddObjectToRemoveList();
                    break;
                default:
                    break;
            }
        }
    }

private:
    ObjectGuid _playerGuid;
    EventMap _events;
};

void AddSC_dc_dalaran_manabonk()
{
    RegisterCreatureAI(npc_dc_manabonk);
}
