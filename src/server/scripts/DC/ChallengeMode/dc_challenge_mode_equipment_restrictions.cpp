#include "dc_challenge_modes.h"

namespace
{
    bool IsSelfCraftedEquippableAllowed(Player* player, Item* item)
    {
        if (!player || !item)
            return true;

        // Only enforce if the mode is enabled and active for this player.
        if (!sChallengeModes->enabled())
            return true;

        bool selfCraftedActive = sChallengeModes->challengeEnabledForPlayer(SETTING_SELF_CRAFTED, player) ||
            sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player) ||
            sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player);

        if (!selfCraftedActive)
            return true;

        ObjectGuid creatorGuid = item->GetGuidValue(ITEM_FIELD_CREATOR);

        // Must have been crafted by THIS player.
        return !creatorGuid.IsEmpty() && creatorGuid == player->GetGUID();
    }
}

class ChallengeMode_EquipmentRestrictions_PlayerScript : public PlayerScript
{
public:
    ChallengeMode_EquipmentRestrictions_PlayerScript() : PlayerScript("ChallengeMode_EquipmentRestrictions_PlayerScript") { }

    [[nodiscard]] bool OnPlayerCanEquipItem(Player* player, uint8 /*slot*/, uint16& /*dest*/, Item* item, bool /*swap*/, bool not_loading) override
    {
        if (IsSelfCraftedEquippableAllowed(player, item))
            return true;

        // Avoid chat spam during login / inventory loading, but still block.
        if (not_loading && player && player->GetSession())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Self-Crafted Mode: you may only equip items you personally crafted.");
        }

        return false;
    }
};

void AddSC_dc_challenge_mode_equipment_restrictions()
{
    new ChallengeMode_EquipmentRestrictions_PlayerScript();
}
