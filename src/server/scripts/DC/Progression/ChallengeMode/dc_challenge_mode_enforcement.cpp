#include "dc_challenge_modes.h"

#include "SpellMgr.h"
#include "Group.h"
#include "Map.h"
#include "DBCStores.h"

#include <cmath>

namespace
{
    bool IsIronManOrPlusActive(Player* player)
    {
        return player && (sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player) ||
            sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player));
    }

    bool IsItemQualityAllowed(Player* player, Item* item)
    {
        if (!player || !item)
            return true;

        if (!sChallengeModes->enabled())
            return true;

        bool itemQualityActive = sChallengeModes->challengeEnabledForPlayer(SETTING_ITEM_QUALITY_LEVEL, player) ||
            IsIronManOrPlusActive(player);

        if (!itemQualityActive)
            return true;

        ItemTemplate const* proto = item->GetTemplate();
        if (!proto)
            return true;

        // White (Normal) and Gray (Poor) only.
        return proto->Quality <= ITEM_QUALITY_NORMAL;
    }

    void ApplySemiHardcoreDeathPenalty(Player* player)
    {
        if (!player)
            return;

        // Destroy all equipped items.
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
                player->DestroyItem(INVENTORY_SLOT_BAG_0, slot, true);
        }

        // Remove all carried gold.
        player->SetMoney(0);
    }

    float GetActiveXpMultiplier(Player* player)
    {
        if (!player)
            return 1.0f;

        if (!sChallengeModes->enabled())
            return 1.0f;

        float multiplier = 1.0f;

        // Stack multipliers for all enabled modes.
        // (Most modes are mutually exclusive via the UI, but stacking is safe.)
        constexpr ChallengeModeSettings kXpModes[] = {
            SETTING_HARDCORE,
            SETTING_SEMI_HARDCORE,
            SETTING_SELF_CRAFTED,
            SETTING_ITEM_QUALITY_LEVEL,
            SETTING_SLOW_XP_GAIN,
            SETTING_VERY_SLOW_XP_GAIN,
            SETTING_QUEST_XP_ONLY,
            SETTING_IRON_MAN,
            SETTING_IRON_MAN_PLUS
        };

        for (ChallengeModeSettings setting : kXpModes)
        {
            if (sChallengeModes->challengeEnabledForPlayer(setting, player))
                multiplier *= sChallengeModes->getXpBonusForChallenge(setting);
        }

        return multiplier;
    }

    bool IsProfessionBlockedForIronMan(Player* player, uint32 skillId)
    {
        if (!player)
            return false;

        if (!sChallengeModes->enabled())
            return false;

        bool ironManActive = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player);
        bool ironManPlusActive = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player);

        if (!ironManActive && !ironManPlusActive)
            return false;

        if (!IsProfessionSkill(skillId))
            return false;

        // Iron Man allows First Aid, Iron Man+ allows none.
        if (ironManActive && !ironManPlusActive && skillId == SKILL_FIRST_AID)
            return false;

        return true;
    }

    void ResetProfessionsForIronMan(Player* player)
    {
        if (!player)
            return;

        bool ironManActive = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN, player);
        bool ironManPlusActive = sChallengeModes->challengeEnabledForPlayer(SETTING_IRON_MAN_PLUS, player);

        if (!ironManActive && !ironManPlusActive)
            return;

        // Primary professions
        player->SetSkill(SKILL_ALCHEMY, 0, 0, 0);
        player->SetSkill(SKILL_BLACKSMITHING, 0, 0, 0);
        player->SetSkill(SKILL_ENCHANTING, 0, 0, 0);
        player->SetSkill(SKILL_ENGINEERING, 0, 0, 0);
        player->SetSkill(SKILL_HERBALISM, 0, 0, 0);
        player->SetSkill(SKILL_INSCRIPTION, 0, 0, 0);
        player->SetSkill(SKILL_JEWELCRAFTING, 0, 0, 0);
        player->SetSkill(SKILL_LEATHERWORKING, 0, 0, 0);
        player->SetSkill(SKILL_MINING, 0, 0, 0);
        player->SetSkill(SKILL_SKINNING, 0, 0, 0);
        player->SetSkill(SKILL_TAILORING, 0, 0, 0);

        // Secondary skills
        player->SetSkill(SKILL_COOKING, 0, 0, 0);
        player->SetSkill(SKILL_FISHING, 0, 0, 0);

        if (ironManPlusActive)
            player->SetSkill(SKILL_FIRST_AID, 0, 0, 0);
    }

    void ClearGlyphs(Player* player)
    {
        if (!player)
            return;

        for (uint8 slot = 0; slot < MAX_GLYPH_SLOT_INDEX; ++slot)
            player->SetGlyph(slot, 0, true);
    }
}

class ChallengeMode_ItemQuality_PlayerScript : public PlayerScript
{
public:
    ChallengeMode_ItemQuality_PlayerScript() : PlayerScript("ChallengeMode_ItemQuality_PlayerScript") { }

    [[nodiscard]] bool OnPlayerCanEquipItem(Player* player, uint8 /*slot*/, uint16& /*dest*/, Item* item, bool /*swap*/, bool not_loading) override
    {
        if (IsItemQualityAllowed(player, item))
            return true;

        if (not_loading && player && player->GetSession())
        {
            ChatHandler(player->GetSession()).PSendSysMessage(
                "Item Quality Restriction: you may only equip gray/white items.");
        }

        return false;
    }
};

class ChallengeMode_SemiHardcore_PlayerScript : public PlayerScript
{
public:
    ChallengeMode_SemiHardcore_PlayerScript() : PlayerScript("ChallengeMode_SemiHardcore_PlayerScript") { }

    void OnPlayerJustDied(Player* player) override
    {
        if (!player)
            return;

        if (!sChallengeModes->enabled())
            return;

        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_SEMI_HARDCORE, player))
            return;

        ApplySemiHardcoreDeathPenalty(player);

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Semi-Hardcore: death penalty applied (equipped items + gold lost).");
    }
};

class ChallengeMode_XP_PlayerScript : public PlayerScript
{
public:
    ChallengeMode_XP_PlayerScript() : PlayerScript("ChallengeMode_XP_PlayerScript") { }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 xpSource) override
    {
        if (!player || amount == 0)
            return;

        if (!sChallengeModes->enabled())
            return;

        // Quest XP only blocks all non-quest XP sources.
        if (sChallengeModes->challengeEnabledForPlayer(SETTING_QUEST_XP_ONLY, player))
        {
            if (xpSource != XPSOURCE_QUEST && xpSource != XPSOURCE_QUEST_DF)
            {
                amount = 0;
                return;
            }
        }

        float mult = GetActiveXpMultiplier(player);
        if (mult == 1.0f)
            return;

        amount = static_cast<uint32>(std::floor(static_cast<float>(amount) * mult));
    }
};

class ChallengeMode_IronManPlus_PlayerScript : public PlayerScript
{
public:
    ChallengeMode_IronManPlus_PlayerScript() : PlayerScript("ChallengeMode_IronManPlus_PlayerScript") { }

    void OnPlayerLogin(Player* player) override
    {
        if (!player || !sChallengeModes->enabled())
            return;

        if (!IsIronManOrPlusActive(player))
            return;

        // Enforce immediately on login to prevent keeping restricted state.
        player->resetTalents(true);
        player->SetFreeTalentPoints(0);
        ClearGlyphs(player);
        ResetProfessionsForIronMan(player);

        // Ensure solo play
        if (Group* group = player->GetGroup())
            group->RemoveMember(player->GetGUID(), GROUP_REMOVEMETHOD_LEAVE, player->GetGUID());

        // If logged out inside an instance, eject to entrance.
        if (MapEntry const* mapEntry = sMapStore.LookupEntry(player->GetMapId()))
        {
            if (mapEntry->IsDungeon())
            {
                int32 entranceMapId;
                float x;
                float y;
                if (mapEntry->GetEntrancePos(entranceMapId, x, y))
                    player->TeleportTo(static_cast<uint32>(entranceMapId), x, y, player->GetPositionZ(), player->GetOrientation());
            }
        }
    }

    void OnPlayerCalculateTalentsPoints(Player const* player, uint32& talentPointsForLevel) override
    {
        if (!player || !sChallengeModes->enabled())
            return;

        if (IsIronManOrPlusActive(const_cast<Player*>(player)))
            talentPointsForLevel = 0;
    }

    void OnPlayerFreeTalentPointsChanged(Player* player, uint32 newPoints) override
    {
        if (!player || !sChallengeModes->enabled())
            return;

        if (!IsIronManOrPlusActive(player))
            return;

        if (newPoints != 0)
            player->SetFreeTalentPoints(0);
    }

    void OnPlayerLearnTalents(Player* player, uint32 /*talentId*/, uint32 /*talentRank*/, uint32 /*spellid*/) override
    {
        if (!player || !sChallengeModes->enabled())
            return;

        if (!IsIronManOrPlusActive(player))
            return;

        // If something slips through, revert.
        player->resetTalents(true);
        player->SetFreeTalentPoints(0);

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: talents are disabled.");
    }

    void OnPlayerLearnSpell(Player* player, uint32 spellID) override
    {
        if (!player || !sChallengeModes->enabled())
            return;

        if (!IsIronManOrPlusActive(player))
            return;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellID);
        if (!spellInfo)
            return;

        for (uint8 eff = 0; eff < MAX_SPELL_EFFECTS; ++eff)
        {
            if (spellInfo->Effects[eff].Effect != SPELL_EFFECT_SKILL)
                continue;

            uint32 skillId = spellInfo->Effects[eff].MiscValue;
            if (!IsProfessionBlockedForIronMan(player, skillId))
                continue;

            // Best-effort rollback: remove skill + remove learned spell.
            player->SetSkill(skillId, 0, 0, 0);
            player->removeSpell(spellID, SPEC_MASK_ALL, false);

            if (player->GetSession())
                ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: professions are disabled.");
            break;
        }
    }

    bool OnPlayerCanUpdateSkill(Player* player, uint32 skillId) override
    {
        if (!player || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        return !IsProfessionBlockedForIronMan(player, skillId);
    }

    bool OnPlayerCanCastItemUseSpell(Player* player, Item* /*item*/, SpellCastTargets const& /*targets*/, uint8 /*cast_count*/, uint32 glyphIndex) override
    {
        if (!player || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        if (glyphIndex == 0)
            return true;

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: glyphs are disabled.");

        return false;
    }

    bool OnPlayerCanGroupInvite(Player* player, std::string& /*membername*/) override
    {
        if (!player || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: grouping is disabled.");

        return false;
    }

    bool OnPlayerCanGroupAccept(Player* player, Group* /*group*/) override
    {
        if (!player || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: grouping is disabled.");

        return false;
    }

    bool OnPlayerCanJoinLfg(Player* player, uint8 /*roles*/, lfg::LfgDungeonSet& /*dungeons*/, const std::string& /*comment*/) override
    {
        if (!player || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: dungeons are disabled.");

        return false;
    }

    bool OnPlayerCanEnterMap(Player* player, MapEntry const* entry, InstanceTemplate const* /*instance*/, MapDifficulty const* /*mapDiff*/, bool loginCheck) override
    {
        if (!player || !entry || !sChallengeModes->enabled())
            return true;

        if (!IsIronManOrPlusActive(player))
            return true;

        if (!entry->IsDungeon())
            return true;

        // Allow login checks so we can safely eject on login.
        if (loginCheck)
            return true;

        if (player->GetSession())
            ChatHandler(player->GetSession()).PSendSysMessage("Iron Man: you cannot enter dungeons or raids.");

        return false;
    }
};

void AddSC_dc_challenge_mode_enforcement()
{
    new ChallengeMode_ItemQuality_PlayerScript();
    new ChallengeMode_SemiHardcore_PlayerScript();
    new ChallengeMode_XP_PlayerScript();
    new ChallengeMode_IronManPlus_PlayerScript();
}
