/*
 * DarkChaos: per-character XP rate.
 *
 *   .dc xp                 shows this character's rate and the allowed range
 *   .dc xp <rate>          sets it (a multiplier of the realm rate, e.g. 0.5)
 *   .dc xp reset           back to the realm rate
 *   .dc xp bonus [on|off]  DC bonus XP on or off (no argument toggles)
 *
 * The rate multiplies whatever OnPlayerGiveXP is handed, which already
 * includes the realm Rate.XP.* settings, so 1.0 is the realm rate and
 * DC.XPRate.Max = 1.0 (default) keeps anyone from exceeding it. The other XP
 * hooks add percentages or multiply too, so the result does not depend on
 * hook order.
 *
 * 0 (allowed while DC.XPRate.Min = 0) is "XP off". It only zeroes the amount
 * handed to GiveXP and never touches PLAYER_FLAGS_NO_XP_GAIN, which stays
 * owned by the Experience Eliminator, the max-level logic and the prestige
 * reset (which clears it); challenge-mode multipliers and the quest-XP-only
 * mode compose with it.
 *
 * Bonus XP off strips DC's own bonus sources: the prestige alt bonus, the
 * hotspot buff and prestige talent XP effects (each asks
 * DCXPRate::IsBonusXPOptedOut). Rested XP, Recruit-a-Friend and racial
 * traits are core or character mechanics and stay. Hotspot kill objectives
 * keep counting.
 *
 * Stored per character in character_settings (EnablePlayerSettings = 1 on
 * the live realm), source "dc-xp-rate", one value: bit 31 = custom rate set,
 * bit 30 = bonus XP off, bits 0-15 = rate in hundredths. With
 * EnablePlayerSettings = 0 the choice lasts until logout.
 *
 * Playerbots are never affected.
 */

#include "dc_xp_rate.h"

#include "Chat.h"
#include "ChatCommand.h"
#include "CommandScript.h"
#include "Config.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringConvert.h"
#include "StringFormat.h"
#include "Util.h"
#include "WorldSession.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <limits>
#include <string>

using namespace Acore::ChatCommands;

namespace
{
    constexpr char const* SETTING_SOURCE = "dc-xp-rate";
    constexpr uint32 SETTING_INDEX = 0;

    constexpr uint32 FLAG_CUSTOM_RATE = 0x80000000u;
    constexpr uint32 FLAG_NO_BONUS    = 0x40000000u;
    constexpr uint32 RATE_MASK        = 0x0000FFFFu;

    // Hundredths; the setting stores 16 bits of it.
    constexpr uint32 RATE_SCALE = 100;
    constexpr float RATE_CEILING = float(RATE_MASK) / RATE_SCALE;

    // Written on the world thread at config (re)load, read on map threads.
    std::atomic<bool> s_enabled{true};
    std::atomic<uint32> s_minHundredths{0};
    std::atomic<uint32> s_maxHundredths{RATE_SCALE};

    uint32 ToHundredths(float rate)
    {
        rate = std::clamp(rate, 0.0f, RATE_CEILING);
        return uint32(std::lround(rate * RATE_SCALE));
    }

    float FromHundredths(uint32 hundredths)
    {
        return float(hundredths) / RATE_SCALE;
    }

    bool IsRealPlayer(Player const* player)
    {
        return player && player->GetSession() && !player->GetSession()->IsBot();
    }

    uint32 ReadSetting(Player* player)
    {
        return player->GetPlayerSetting(SETTING_SOURCE, SETTING_INDEX).value;
    }

    void WriteSetting(Player* player, uint32 value)
    {
        player->UpdatePlayerSetting(SETTING_SOURCE, SETTING_INDEX, value);
    }

    // The stored rate clamped to the current range, so lowering DC.XPRate.Max
    // also reins in characters that picked more under the old setting.
    uint32 EffectiveHundredths(uint32 setting)
    {
        if (!(setting & FLAG_CUSTOM_RATE))
            return RATE_SCALE;

        uint32 const minH = s_minHundredths;
        uint32 const maxH = std::max(minH, s_maxHundredths.load());
        return std::clamp(setting & RATE_MASK, minH, maxH);
    }

    std::string FormatRate(uint32 hundredths)
    {
        return Acore::StringFormat("{:.2f}", FromHundredths(hundredths));
    }

    void ShowStatus(ChatHandler* handler, Player* player)
    {
        uint32 const setting = ReadSetting(player);
        uint32 const effective = EffectiveHundredths(setting);
        uint32 const minH = s_minHundredths;
        uint32 const maxH = std::max(minH, s_maxHundredths.load());

        if (effective == 0)
            handler->SendSysMessage("|cff00ccff[XP]|r Your XP rate: |cffff6060off|r (0.00x the realm rate).");
        else
            handler->PSendSysMessage("|cff00ccff[XP]|r Your XP rate: {}x the realm rate{}.", FormatRate(effective),
                (setting & FLAG_CUSTOM_RATE) ? "" : " (default)");

        handler->PSendSysMessage("|cff00ccff[XP]|r Allowed: {}x to {}x. Bonus XP (prestige alt bonus, hotspots, "
            "prestige talents): {}.", FormatRate(minH), FormatRate(maxH),
            (setting & FLAG_NO_BONUS) ? "|cffff6060off|r" : "on");
        handler->SendSysMessage("|cff00ccff[XP]|r Usage: .dc xp <rate> | .dc xp reset | .dc xp bonus [on|off]");
    }

    class dc_xp_rate_world : public WorldScript
    {
    public:
        dc_xp_rate_world() : WorldScript("dc_xp_rate_world", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

        void OnAfterConfigLoad(bool /*reload*/) override
        {
            s_enabled = sConfigMgr->GetOption<bool>("DC.XPRate.Enable", true);
            s_minHundredths = ToHundredths(sConfigMgr->GetOption<float>("DC.XPRate.Min", 0.0f));
            s_maxHundredths = ToHundredths(sConfigMgr->GetOption<float>("DC.XPRate.Max", 1.0f));
        }
    };

    class dc_xp_rate_player : public PlayerScript
    {
    public:
        dc_xp_rate_player() : PlayerScript("dc_xp_rate_player", { PLAYERHOOK_ON_GIVE_EXP }) { }

        // Map thread. Reads only the character's in-memory settings.
        void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
        {
            if (!amount || !s_enabled || !IsRealPlayer(player))
                return;

            uint32 const hundredths = EffectiveHundredths(ReadSetting(player));
            if (hundredths == RATE_SCALE)
                return;

            uint64 const scaled = uint64(amount) * hundredths / RATE_SCALE;
            amount = uint32(std::min<uint64>(scaled, std::numeric_limits<uint32>::max()));
        }
    };

    class dc_xp_rate_commandscript : public CommandScript
    {
    public:
        dc_xp_rate_commandscript() : CommandScript("dc_xp_rate_commandscript") { }

        ChatCommandTable GetCommands() const override
        {
            // `.dc` is the shared player namespace (mod-dungeon-clear, .dc difficulty):
            // only add a subcommand to it, never a root handler. The blank entry
            // below belongs to `xp`, which nothing else uses.
            static ChatCommandTable xpTable =
            {
                { "bonus", HandleXPBonus, SEC_PLAYER, Console::No },
                { "",      HandleXP,      SEC_PLAYER, Console::No }
            };
            static ChatCommandTable dcTable =
            {
                { "xp", xpTable }
            };
            static ChatCommandTable commandTable =
            {
                { "dc", dcTable }
            };
            return commandTable;
        }

        static bool HandleXP(ChatHandler* handler, Optional<std::string_view> arg)
        {
            Player* player = handler->GetPlayer();
            if (!player)
                return false;

            if (!s_enabled)
            {
                handler->SendSysMessage("Personal XP rates are disabled on this realm.");
                return true;
            }

            if (!arg || arg->empty())
            {
                ShowStatus(handler, player);
                return true;
            }

            uint32 setting = ReadSetting(player);

            if (StringEqualI(*arg, "reset") || StringEqualI(*arg, "default"))
            {
                WriteSetting(player, setting & FLAG_NO_BONUS);
                handler->SendSysMessage("|cff00ccff[XP]|r Your XP rate is back to the realm rate.");
                return true;
            }

            std::string_view text = *arg;
            if (!text.empty() && (text.back() == 'x' || text.back() == 'X'))
                text.remove_suffix(1);

            Optional<float> rate = Acore::StringTo<float>(text);
            if (!rate || !std::isfinite(*rate) || *rate < 0.0f)
            {
                handler->SendSysMessage(
                    "Usage: .dc xp <rate> (for example 0.5) | .dc xp reset | .dc xp bonus [on|off]");
                return true;
            }

            uint32 const minH = s_minHundredths;
            uint32 const maxH = std::max(minH, s_maxHundredths.load());
            uint32 const wanted = ToHundredths(*rate);

            if (wanted < minH || wanted > maxH)
            {
                handler->PSendSysMessage("|cff00ccff[XP]|r The rate must be between {}x and {}x.",
                    FormatRate(minH), FormatRate(maxH));
                return true;
            }

            setting &= FLAG_NO_BONUS;
            if (wanted != RATE_SCALE)
                setting |= FLAG_CUSTOM_RATE | wanted;

            WriteSetting(player, setting);

            if (wanted == 0)
                handler->SendSysMessage("|cff00ccff[XP]|r Experience gain is now |cffff6060off|r for this character. "
                    "Type .dc xp reset to turn it back on.");
            else
                handler->PSendSysMessage("|cff00ccff[XP]|r Your XP rate is now {}x the realm rate.",
                    FormatRate(wanted));

            return true;
        }

        static bool HandleXPBonus(ChatHandler* handler, Optional<std::string_view> state)
        {
            Player* player = handler->GetPlayer();
            if (!player)
                return false;

            if (!s_enabled)
            {
                handler->SendSysMessage("Personal XP rates are disabled on this realm.");
                return true;
            }

            uint32 setting = ReadSetting(player);
            bool bonusOn = (setting & FLAG_NO_BONUS) == 0;

            if (!state || state->empty())
                bonusOn = !bonusOn;
            else if (StringEqualI(*state, "on") || *state == "1")
                bonusOn = true;
            else if (StringEqualI(*state, "off") || *state == "0")
                bonusOn = false;
            else
            {
                handler->SendSysMessage("Usage: .dc xp bonus [on|off]");
                return true;
            }

            if (bonusOn)
                setting &= ~FLAG_NO_BONUS;
            else
                setting |= FLAG_NO_BONUS;

            WriteSetting(player, setting);

            handler->PSendSysMessage("|cff00ccff[XP]|r Bonus XP (prestige alt bonus, hotspots, prestige talents) "
                "is now {}. Rested XP is not affected.", bonusOn ? "on" : "|cffff6060off|r");
            return true;
        }
    };
}

namespace DCXPRate
{
    bool IsBonusXPOptedOut(Player* player)
    {
        if (!s_enabled || !IsRealPlayer(player))
            return false;

        return (ReadSetting(player) & FLAG_NO_BONUS) != 0;
    }
}

void AddSC_dc_xp_rate()
{
    new dc_xp_rate_world();
    new dc_xp_rate_player();
    new dc_xp_rate_commandscript();
}
