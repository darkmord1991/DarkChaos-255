#ifndef DC_GREAT_VAULT_UTILS_H
#define DC_GREAT_VAULT_UTILS_H

#include "Player.h"
#include <string>

namespace DC
{
    namespace VaultUtils
    {
        inline std::string GetPlayerSpec(Player* player)
        {
            if (!player)
                return "Unknown";

            uint8 classId = player->getClass();
            uint8 primaryTree = player->GetMostPointsTalentTree();

            switch (classId)
            {
                case CLASS_WARRIOR:
                    if (primaryTree == 0) return "Arms";
                    if (primaryTree == 1) return "Fury";
                    return "Protection";
                case CLASS_PALADIN:
                    if (primaryTree == 0) return "Holy";
                    if (primaryTree == 1) return "Protection";
                    return "Retribution";
                case CLASS_HUNTER:
                    if (primaryTree == 0) return "Beast Mastery";
                    if (primaryTree == 1) return "Marksmanship";
                    return "Survival";
                case CLASS_ROGUE:
                    if (primaryTree == 0) return "Assassination";
                    if (primaryTree == 1) return "Combat";
                    return "Subtlety";
                case CLASS_PRIEST:
                    if (primaryTree == 0) return "Discipline";
                    if (primaryTree == 1) return "Holy";
                    return "Shadow";
                case CLASS_DEATH_KNIGHT:
                    if (primaryTree == 0) return "Blood";
                    if (primaryTree == 1) return "Frost";
                    return "Unholy";
                case CLASS_SHAMAN:
                    if (primaryTree == 0) return "Elemental";
                    if (primaryTree == 1) return "Enhancement";
                    return "Restoration";
                case CLASS_MAGE:
                    if (primaryTree == 0) return "Arcane";
                    if (primaryTree == 1) return "Fire";
                    return "Frost";
                case CLASS_WARLOCK:
                    if (primaryTree == 0) return "Affliction";
                    if (primaryTree == 1) return "Demonology";
                    return "Destruction";
                case CLASS_DRUID:
                    if (primaryTree == 0) return "Balance";
                    if (primaryTree == 1) return "Feral Combat";
                    return "Restoration";
                default:
                    return "Unknown";
            }
        }

        inline std::string GetPlayerArmorType(Player* player)
        {
            if (!player)
                return "Misc";

            switch (player->getClass())
            {
                case CLASS_WARRIOR:
                case CLASS_PALADIN:
                case CLASS_DEATH_KNIGHT:
                    return "Plate";
                case CLASS_HUNTER:
                case CLASS_SHAMAN:
                    return "Mail";
                case CLASS_ROGUE:
                case CLASS_DRUID:
                    return "Leather";
                case CLASS_PRIEST:
                case CLASS_MAGE:
                case CLASS_WARLOCK:
                    return "Cloth";
                default:
                    return "Misc";
            }
        }

        inline uint8 GetPlayerRoleMask(Player* player)
        {
            if (!player)
                return 7; // Universal

            uint8 classId = player->getClass();
            uint8 primaryTree = player->GetMostPointsTalentTree();

            // 1=Tank, 2=Healer, 4=DPS
            switch (classId)
            {
                case CLASS_WARRIOR:
                    return (primaryTree == 2) ? 1 : 4; // Protection = Tank, others = DPS
                case CLASS_PALADIN:
                    if (primaryTree == 0) return 2; // Holy = Healer
                    if (primaryTree == 1) return 1; // Protection = Tank
                    return 4; // Retribution = DPS
                case CLASS_HUNTER:
                    return 4; // Always DPS
                case CLASS_ROGUE:
                    return 4; // Always DPS
                case CLASS_PRIEST:
                    return (primaryTree == 2) ? 4 : 2; // Shadow = DPS, others = Healer
                case CLASS_DEATH_KNIGHT:
                    return (primaryTree == 0) ? 1 : 4; // Blood = Tank, others = DPS
                case CLASS_SHAMAN:
                    return (primaryTree == 2) ? 2 : 4; // Restoration = Healer, others = DPS
                case CLASS_MAGE:
                    return 4; // Always DPS
                case CLASS_WARLOCK:
                    return 4; // Always DPS
                case CLASS_DRUID:
                    if (primaryTree == 0) return 4; // Balance = DPS
                    if (primaryTree == 2) return 2; // Restoration = Healer
                    return 5; // Feral = Tank + DPS (role_mask 5)
                default:
                    return 7; // Universal
            }
        }

        inline uint32 GetPlayerClassMask(Player* player)
        {
            if (!player)
                return 0;

            switch (player->getClass())
            {
                case CLASS_WARRIOR:      return 1;
                case CLASS_PALADIN:      return 2;
                case CLASS_HUNTER:       return 4;
                case CLASS_ROGUE:        return 8;
                case CLASS_PRIEST:       return 16;
                case CLASS_DEATH_KNIGHT: return 32;
                case CLASS_SHAMAN:       return 64;
                case CLASS_MAGE:         return 128;
                case CLASS_WARLOCK:      return 256;
                case CLASS_DRUID:        return 1024; // Note: Check standard masks, usually Druid is 1024 (1<<10)
                default:                 return 0;
            }
        }
    }
}

#endif // DC_GREAT_VAULT_UTILS_H
