/*
 * DarkChaos-255 Map Flight Licenses (maps 750 and 751)
 *
 * Flying on map 750 (The Sundered Wilds, 80-130) needs Scorched Weather Flying,
 * flying on map 751 (The Fallen Kingdom, 130-160) needs Plague Weather Flying,
 * the way Northrend needs Cold Weather Flying. Every riding trainer teaches
 * them (trainer_spell: level 120 / 150, Expert Riding). Code, config and SQL
 * still call them the flight licenses.
 *
 * - Gate: OnPlayerCanFlyInZone. Player::canFlyInZone runs it for every
 *   "flying areas only" spell (flying mounts, flight forms) at cast time and
 *   on every area change, so mounting somewhere else does not get around it.
 *   The zone-adaptive mounts (spell_gen_mount) and the playerbots ask the
 *   same function, so they follow the rule too.
 * - Speed: the license is a passive spell whose three auras add 50% to
 *   ground-mount, flying-mount and flight-form speed. The AuraScript area
 *   check keeps them applied only while the owner is on the license's map
 *   (re-evaluated on every aura target update, 500 ms).
 * - Account-wide: learning a license records it in the characters table
 *   `dc_account_flight_license` (pending_db_characters). Another character
 *   of the account learns it the first time it enters that map. Playerbots
 *   neither feed nor receive the pool (they learn it from riding trainers in
 *   the module's factory instead).
 * - Quests: at level 120 / 150 a breadcrumb quest is put into the quest log
 *   that sends the player to the Flying Instructor in the Jade Forest.
 *
 * Spell rows: Custom/CSV DBC/Spell.csv (client) and spell_dbc (server).
 * Trainer, quest and spell_script_names rows: pending world SQL.
 */

#include "Chat.h"
#include "Config.h"
#include "DataMap.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "StringFormat.h"
#include "Timer.h"
#include "WorldSession.h"
#include "DC/AddonExtension/dc_addon_namespace.h"

#include <array>
#include <atomic>

namespace
{
    constexpr char const* CONFIG_ENABLE = "DC.FlightLicense.Enable";
    constexpr char const* CONFIG_ACCOUNT_WIDE = "DC.FlightLicense.AccountWide";
    constexpr char const* CONFIG_AUTO_QUEST = "DC.FlightLicense.AutoQuest";

    constexpr char const* STATE_KEY = "dc_flight_license";
    constexpr char const* CHAT_PREFIX = "|cff00ccff[Flying]|r ";

    constexpr uint32 SPELL_SLOW_FALL = 130;
    constexpr uint32 HINT_COOLDOWN_MS = 5000;

    struct FlightLicense
    {
        uint32 MapId;
        uint32 SpellId;
        uint8 Level;
        uint32 QuestId;
        uint32 Bit;
        char const* Name;
        char const* Region;
    };

    constexpr std::array<FlightLicense, 2> LICENSES =
    {{
        { 750, 300610, 120, 81330, 0x1, "Scorched Weather Flying", "the Sundered Wilds" },
        { 751, 300611, 150, 81331, 0x2, "Plague Weather Flying", "the Fallen Kingdom" },
    }};

    // Written on the world thread at config (re)load, read from map threads.
    std::atomic<bool> sEnabled{true};
    std::atomic<bool> sAccountWide{true};
    std::atomic<bool> sAutoQuest{true};

    // Per character: what the account pool holds, and when the last hint went out.
    struct FlightLicenseState : public DataMap::Base
    {
        uint32 AccountMask = 0;
        bool AccountLoaded = false;
        uint32 LastHintMs = 0;
    };

    FlightLicense const* FindByMap(uint32 mapId)
    {
        for (FlightLicense const& license : LICENSES)
            if (license.MapId == mapId)
                return &license;

        return nullptr;
    }

    FlightLicense const* FindBySpell(uint32 spellId)
    {
        for (FlightLicense const& license : LICENSES)
            if (license.SpellId == spellId)
                return &license;

        return nullptr;
    }

    // Real players only; playerbots are ordinary Players on an IsBot() session.
    bool IsRealPlayer(Player const* player)
    {
        return player && player->GetSession() && !player->GetSession()->IsBot();
    }

    FlightLicenseState* GetState(Player* player)
    {
        return player->CustomData.GetDefault<FlightLicenseState>(STATE_KEY);
    }

    void Notify(Player* player, std::string const& text)
    {
        ChatHandler(player->GetSession()).SendSysMessage(CHAT_PREFIX + text);
    }

    bool TakeHintSlot(Player* player)
    {
        FlightLicenseState* state = GetState(player);
        uint32 const now = getMSTime();
        if (state->LastHintMs && getMSTimeDiff(state->LastHintMs, now) < HINT_COOLDOWN_MS)
            return false;

        state->LastHintMs = now;
        return true;
    }

    void InsertPoolRow(uint32 accountId, uint32 spellId, Player const* player)
    {
        CharacterDatabase.Execute(
            "INSERT IGNORE INTO `dc_account_flight_license` (`account_id`, `spell_id`, `learned_by`) "
            "VALUES ({}, {}, {})", accountId, spellId, player->GetGUID().GetCounter());
    }

    // Runs inside the fly gate. Must not touch auras: the area re-check comes from
    // Player::UpdateAreaDependentAuras, which is iterating them right now.
    void HandleFlightDenied(Player* player, FlightLicense const& license, SpellInfo const* bySpell)
    {
        if (player->HasAura(bySpell->Id))
        {
            // The flight aura is already up (logged out in the air, or the rule went live mid-flight)
            // and the core strips it as soon as this returns: slow fall instead of a deadly drop.
            player->m_Events.AddEventAtOffset([player]()
            {
                if (player->IsInWorld() && player->IsAlive())
                    player->AddAura(SPELL_SLOW_FALL, player);
            }, 0ms);
        }

        if (!IsRealPlayer(player) || !TakeHintSlot(player))
            return;

        Notify(player, Acore::StringFormat("Flying in {} needs {}. Every riding trainer teaches it from level {}.",
            license.Region, license.Name, uint32(license.Level)));
    }

    // A license another character of the account learned, granted on entering its map.
    void GrantFromAccount(Player* player)
    {
        if (!sEnabled || !sAccountWide || !player->IsInWorld())
            return;

        FlightLicense const* license = FindByMap(player->GetMapId());
        if (!license || player->HasSpell(license->SpellId))
            return;

        FlightLicenseState* state = GetState(player);
        if (!state->AccountLoaded || !(state->AccountMask & license->Bit))
            return;

        player->learnSpell(license->SpellId);
        if (!player->HasSpell(license->SpellId))
            return;

        Notify(player, Acore::StringFormat("Another character of your account knows {}: you can fly in {} as well.",
            license->Name, license->Region));

        LOG_INFO("module.dc", "[FlightLicense] {} received {} ({}) from the account pool",
            player->GetName(), license->Name, license->SpellId);
    }

    void SyncAccountPool(Player* player, QueryResult const& result)
    {
        uint32 pooled = 0;
        if (result)
        {
            do
            {
                if (FlightLicense const* license = FindBySpell(result->Fetch()[0].Get<uint32>()))
                    pooled |= license->Bit;
            } while (result->NextRow());
        }

        // Learned before the pool existed, or while account-wide was off: seed it now.
        uint32 const accountId = player->GetSession()->GetAccountId();
        for (FlightLicense const& license : LICENSES)
        {
            if ((pooled & license.Bit) || !player->HasSpell(license.SpellId))
                continue;

            InsertPoolRow(accountId, license.SpellId, player);
            pooled |= license.Bit;
        }

        FlightLicenseState* state = GetState(player);
        state->AccountMask = pooled;
        state->AccountLoaded = true;

        // Logging in on a license map counts as entering it.
        GrantFromAccount(player);
    }

    void OfferQuest(Player* player, FlightLicense const& license)
    {
        if (player->GetLevel() < license.Level || player->HasSpell(license.SpellId))
            return;

        // The account already holds it: this character receives it on entering the map, no trainer needed.
        FlightLicenseState const* state = GetState(player);
        if (sAccountWide && state->AccountLoaded && (state->AccountMask & license.Bit))
            return;

        Quest const* quest = sObjectMgr->GetQuestTemplate(license.QuestId);
        if (!quest || player->GetQuestStatus(license.QuestId) != QUEST_STATUS_NONE ||
            player->GetQuestRewardStatus(license.QuestId) || !player->CanTakeQuest(quest, false))
            return;

        if (!player->CanAddQuest(quest, false))
        {
            Notify(player, Acore::StringFormat("You can now learn {}. Free a quest log slot and log in again to "
                "receive \"{}\".", license.Name, quest->GetTitle()));
            return;
        }

        player->AddQuestAndCheckCompletion(quest, nullptr);
        Notify(player, Acore::StringFormat("You can now learn {}. New quest: \"{}\".", license.Name,
            quest->GetTitle()));
    }

    // Offers every license quest whose level lies above oldLevel (0 = all reached levels).
    void OfferQuests(Player* player, uint8 oldLevel)
    {
        if (!sAutoQuest || !IsRealPlayer(player))
            return;

        for (FlightLicense const& license : LICENSES)
            if (oldLevel < license.Level)
                OfferQuest(player, license);
    }

    class DCFlightLicenseWorldScript : public WorldScript
    {
    public:
        DCFlightLicenseWorldScript() : WorldScript("DCFlightLicenseWorldScript", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            sEnabled = sConfigMgr->GetOption<bool>(CONFIG_ENABLE, true);
            sAccountWide = sConfigMgr->GetOption<bool>(CONFIG_ACCOUNT_WIDE, true);
            sAutoQuest = sConfigMgr->GetOption<bool>(CONFIG_AUTO_QUEST, true);
        }
    };

    class DCFlightLicensePlayerScript : public PlayerScript
    {
    public:
        DCFlightLicensePlayerScript() : PlayerScript("DCFlightLicensePlayerScript",
        {
            PLAYERHOOK_ON_CAN_PLAYER_FLY_IN_ZONE, PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_LOGIN,
            PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_LEVEL_CHANGED
        }) { }

        [[nodiscard]] bool OnPlayerCanFlyInZone(Player* player, uint32 mapId, uint32 /*zoneId*/,
            SpellInfo const* bySpell) override
        {
            if (!sEnabled)
                return true;

            FlightLicense const* license = FindByMap(mapId);
            if (!license || player->HasSpell(license->SpellId))
                return true;

            // Loaner mounts skip Cold Weather Flying; they skip the licenses as well.
            if (bySpell && bySpell->HasAttribute(SPELL_ATTR7_IGNORES_COLD_WEATHER_FLYING_REQUIREMENT))
                return true;

            // bySpell is null for "may this player fly here" questions (smart mount, playerbots).
            if (bySpell)
                HandleFlightDenied(player, *license, bySpell);

            return false;
        }

        // Map thread: updates this character's cached pool and issues an async insert.
        void OnPlayerLearnSpell(Player* player, uint32 spellId) override
        {
            FlightLicense const* license = FindBySpell(spellId);
            if (!license || !sEnabled || !sAccountWide || !IsRealPlayer(player))
                return;

            FlightLicenseState* state = GetState(player);
            if (state->AccountMask & license->Bit)
                return;

            state->AccountMask |= license->Bit;
            InsertPoolRow(player->GetSession()->GetAccountId(), spellId, player);
        }

        void OnPlayerLogin(Player* player) override
        {
            if (!sEnabled || !IsRealPlayer(player))
                return;

            if (!sAccountWide)
            {
                OfferQuests(player, 0);
                return;
            }

            // The continuation runs on the world thread, outside map updates.
            ObjectGuid const guid = player->GetGUID();
            DCAddon::EnqueueQueryCallback(CharacterDatabase.AsyncQuery(Acore::StringFormat(
                "SELECT `spell_id` FROM `dc_account_flight_license` WHERE `account_id` = {}",
                player->GetSession()->GetAccountId()))
                .WithCallback([guid](QueryResult result)
            {
                Player* target = ObjectAccessor::FindPlayer(guid);
                if (!target || !target->IsInWorld() || !target->GetSession())
                    return;

                SyncAccountPool(target, result);
                OfferQuests(target, 0);
            }));
        }

        // Also runs for the login map, before the login query above has answered;
        // SyncAccountPool covers that case.
        void OnPlayerMapChanged(Player* player) override
        {
            if (!sEnabled || !sAccountWide || !IsRealPlayer(player) || !FindByMap(player->GetMapId()))
                return;

            // Learning in the middle of Map::AddPlayerToMap works, but the chat line would land under the
            // loading screen; give the client a moment. GrantFromAccount checks the map again.
            player->m_Events.AddEventAtOffset([player]() { GrantFromAccount(player); }, 1s);
        }

        void OnPlayerLevelChanged(Player* player, uint8 oldLevel) override
        {
            if (sEnabled && player->GetLevel() > oldLevel)
                OfferQuests(player, oldLevel);
        }
    };

    class DCFlightLicenseAccountScript : public AccountScript
    {
    public:
        DCFlightLicenseAccountScript() : AccountScript("DCFlightLicenseAccountScript",
            { ACCOUNTHOOK_ON_BEFORE_ACCOUNT_DELETE }) { }

        void OnBeforeAccountDelete(uint32 accountId) override
        {
            CharacterDatabase.Execute("DELETE FROM `dc_account_flight_license` WHERE `account_id` = {}", accountId);
        }
    };
}

// Keeps the license's speed auras applied only while the owner is on the license's map.
class spell_dc_flight_license : public AuraScript
{
    PrepareAuraScript(spell_dc_flight_license);

    bool CheckAreaTarget(Unit* target)
    {
        FlightLicense const* license = FindBySpell(GetId());
        return license && sEnabled && target->GetMapId() == license->MapId;
    }

    void Register() override
    {
        DoCheckAreaTarget += AuraCheckAreaTargetFn(spell_dc_flight_license::CheckAreaTarget);
    }
};

void AddSC_dc_flight_license()
{
    new DCFlightLicenseWorldScript();
    new DCFlightLicensePlayerScript();
    new DCFlightLicenseAccountScript();
    RegisterSpellScript(spell_dc_flight_license);
}
