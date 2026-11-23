#include "Chat.h"
#include "DBCStores.h"
#include "GameObjectAI.h"
#include "Group.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "World.h"
#include "naxx40_config.h"
#include "naxx40_defs.h"

bool IsAttuned(Player const* player)
{
    if ((player->GetQuestStatus(NAXX40_ATTUNEMENT_1) == QUEST_STATUS_REWARDED) ||
        (player->GetQuestStatus(NAXX40_ATTUNEMENT_2) == QUEST_STATUS_REWARDED) ||
        (player->GetQuestStatus(NAXX40_ATTUNEMENT_3) == QUEST_STATUS_REWARDED))
    {
        return true;
    }
    return false;
}

bool Naxx40MeetsAttunement(Player const* player)
{
    return !sVanillaNaxxramas->requireAttunement || IsAttuned(player);
}

// Group::SetRaidDifficulty skips every guard of the difficulty opcode (MiscHandler.cpp): mirror the ones that matter.
bool Naxx40CanChangeGroupRaidDifficulty(Player* player, Group* group, bool notify)
{
    ChatHandler handler(player->GetSession());
    if (!group->IsLeader(player->GetGUID()))
    {
        if (notify)
            handler.SendSysMessage("Only the raid leader can take the raid into Naxxramas. Ask them to go first.");
        return false;
    }

    if (uint32 preventionTime = group->GetDifficultyChangePreventionTime())
    {
        if (notify)
            handler.PSendSysMessage("Raid difficulty may not change again for {} sec.", preventionTime);
        return false;
    }

    for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        if (!member)
            continue;

        // A member in a raid instance (or zoning) would be left on the old difficulty.
        MapEntry const* memberMap = sMapStore.LookupEntry(member->GetMapId());
        if (!member->IsInWorld() || (memberMap && memberMap->IsRaid()))
        {
            if (notify)
                handler.SendSysMessage("The raid difficulty cannot change while a raid member is in a raid or zoning.");
            return false;
        }
    }

    return true;
}

// The 40-man is map 2921 on RAID_DIFFICULTY_10MAN_HEROIC; check entry before the group setting is touched.
bool Naxx40PrepareRaidDifficulty(Player* player, bool notify)
{
    Group* group = player->GetGroup();
    if (!group)
    {
        // Only the player's own setting; the core still refuses a raid map without a raid group.
        player->SetRaidDifficulty(RAID_DIFFICULTY_10MAN_HEROIC);
        return true;
    }

    if (group->GetRaidDifficulty() == RAID_DIFFICULTY_10MAN_HEROIC)
        return true;

    if (!Naxx40CanChangeGroupRaidDifficulty(player, group, notify))
        return false;

    if (!group->isRaidGroup() && !sWorld->getBoolConfig(CONFIG_INSTANCE_IGNORE_RAID))
    {
        if (notify)
            ChatHandler(player->GetSession()).SendSysMessage("You must be in a raid group to enter Naxxramas.");
        return false;
    }

    if (!player->Satisfy(sObjectMgr->GetAccessRequirement(MAP_NAXX, RAID_DIFFICULTY_10MAN_HEROIC), MAP_NAXX, notify))
        return false;

    group->SetRaidDifficulty(RAID_DIFFICULTY_10MAN_HEROIC);
    return true;
}

class gobject_naxx40_tele : public GameObjectScript
{
public:
    gobject_naxx40_tele() : GameObjectScript("gobject_naxx40_tele") { }

    struct gobject_naxx40_teleAI: GameObjectAI
    {
        explicit gobject_naxx40_teleAI(GameObject* object) : GameObjectAI(object) { };
    };

    GameObjectAI* GetAI(GameObject* object) const override
    {
        return new gobject_naxx40_teleAI(object);
    }

    bool OnGossipHello(Player* player, GameObject* /*go*/) override
    {
        bool meetLevelRequirement = player->GetLevel() >= 51;
        if (!meetLevelRequirement)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You must be level 51+, in a Raid group, and be attuned to Naxxramas to enter.");
            return true;
        }

        bool meetTeleportSkipRequirement = (player->GetQuestStatus(NAXX40_ENTRANCE_FLAG) == QUEST_STATUS_REWARDED) || !sVanillaNaxxramas->requireNaxxStrath;
        if (!meetTeleportSkipRequirement)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not meet the requirements to use the skip.");
            return true;
        }

        if (!Naxx40MeetsAttunement(player))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You must be level 51+, in a Raid group, and be attuned to Naxxramas to enter.");
            return true;
        }

        if (!Naxx40PrepareRaidDifficulty(player, true))
            return true;

        player->TeleportTo(MAP_NAXX, 3005.51f, -3434.64f, 304.195f, 6.2831f);

        return true;
    }
};

void AddSC_custom_gameobjects_40()
{
    new gobject_naxx40_tele();
}
