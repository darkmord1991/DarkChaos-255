/*
 * DCBalanceReference.cpp
 *
 * Loads `dc_balance_reference` once and serves its rows. See the header for
 * what the table is and why it sits in the game library.
 */

#include "DCBalanceReference.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "QueryResult.h"
#include "Timer.h"
#include <algorithm>
#include <array>
#include <atomic>

namespace DarkChaos
{
    namespace BalanceReference
    {
        namespace
        {
            struct Slot
            {
                Growth growth;
                bool present = false;
            };

            // Indexed by level; a uint8 can never run past the end.
            std::array<Slot, 256> s_rows;

            // Written on the world thread at config (re)load, read on map threads.
            std::atomic<float> s_creatureSpellScale{1.5f};
            std::atomic<bool> s_guardianSpells{true};
            std::atomic<bool> s_guardianMelee{true};
            std::atomic<bool> s_powerAbilities{true};

            // Share of a level-80 white hit that is weapon damage; the rest
            // is attack power. tools/balance/gen_reference.py builds
            // melee_growth from the same number (WEAPON_SHARE_OF_HIT_80), so
            // the attack power curve can be taken back out of the row.
            constexpr float WEAPON_SHARE_OF_HIT_80 = 0.45f;

            // Damage spells that are a share of attack power alone (a base
            // of 0 to 12 points). Sorted: IsPowerAbility searches it.
            constexpr std::array<uint32, 12> POWER_ABILITIES =
            {
                12809,  // Concussion Blow, 38%
                20187,  // Judgement of Righteousness
                20253,  // Intercept, 12%
                23881,  // Bloodthirst, 50%
                31804,  // Judgement of Vengeance
                34428,  // Victory Rush, 45%
                46968,  // Shockwave, 75%
                53733,  // Judgement of Corruption
                54158,  // Judgement (Light, Wisdom, Justice)
                55078,  // Blood Plague
                55095,  // Frost Fever
                57755   // Heroic Throw, 50%
            };
        }

        void Load()
        {
            uint32 oldMSTime = getMSTime();

            for (Slot& slot : s_rows)
                slot = Slot();

            // Look before reading: querying a table that does not exist yet
            // would put an SQL error in the log on every start until the
            // pending file is applied.
            if (!WorldDatabase.Query("SHOW TABLES LIKE 'dc_balance_reference'"))
            {
                LOG_INFO("server.loading",
                    ">> No `dc_balance_reference` table. Scaling above level 80 keeps the stock formulas.");
                LOG_INFO("server.loading", " ");
                return;
            }

            //         0      1            2              3              4
            QueryResult result = WorldDatabase.Query(
                "SELECT level, gear_growth, weapon_growth, health_growth, melee_growth FROM dc_balance_reference");
            if (!result)
            {
                LOG_WARN("server.loading",
                    ">> Loaded 0 balance reference rows. DB table `dc_balance_reference` is empty.");
                LOG_INFO("server.loading", " ");
                return;
            }

            uint32 count = 0;
            do
            {
                Field* fields = result->Fetch();

                uint8 level = fields[0].Get<uint8>();
                Growth growth;
                growth.gear = fields[1].Get<float>();
                growth.weapon = fields[2].Get<float>();
                growth.health = fields[3].Get<float>();
                growth.melee = fields[4].Get<float>();

                // Every reader multiplies or divides by these.
                if (growth.gear <= 0.0f || growth.weapon <= 0.0f || growth.health <= 0.0f || growth.melee <= 0.0f)
                {
                    LOG_ERROR("sql.sql",
                        "Table `dc_balance_reference` has a growth factor of zero or less at level {}, "
                        "ignoring the row.", level);
                    continue;
                }

                s_rows[level].growth = growth;
                s_rows[level].present = true;
                ++count;
            } while (result->NextRow());

            LOG_INFO("server.loading", ">> Loaded {} balance reference rows in {} ms", count,
                GetMSTimeDiffToNow(oldMSTime));
            LOG_INFO("server.loading", " ");
        }

        Growth const* Find(uint8 level)
        {
            Slot const& slot = s_rows[level];
            return slot.present ? &slot.growth : nullptr;
        }

        void LoadConfig()
        {
            s_creatureSpellScale = sConfigMgr->GetOption<float>("DC.Balance.CreatureSpellScale", 1.5f);
            s_guardianSpells = sConfigMgr->GetOption<bool>("DC.Balance.GuardianSpells", true);
            s_guardianMelee = sConfigMgr->GetOption<bool>("DC.Balance.GuardianMelee", true);
            s_powerAbilities = sConfigMgr->GetOption<bool>("DC.Balance.PowerAbilities", true);
        }

        float GuardianSpellGrowth(uint8 level, bool heal)
        {
            if (level <= 80 || !s_guardianSpells)
                return 0.0f;

            Growth const* growth = Find(level);
            if (!growth)
                return 0.0f;

            return heal ? growth->health : growth->melee;
        }

        GuardianMelee GuardianMeleeGrowth(uint8 level)
        {
            if (level <= 80 || !s_guardianMelee)
                return { level, 1.0f };

            Growth const* growth = Find(level);
            if (!growth)
                return { level, 1.0f };

            return { 80, growth->melee };
        }

        bool IsPowerAbility(uint32 spellId)
        {
            return std::binary_search(POWER_ABILITIES.begin(), POWER_ABILITIES.end(), spellId);
        }

        float PowerAbilityGrowth(uint8 level)
        {
            if (level <= 80 || !s_powerAbilities)
                return 1.0f;

            Growth const* growth = Find(level);
            if (!growth)
                return 1.0f;

            float attackPower =
                (growth->melee - WEAPON_SHARE_OF_HIT_80 * growth->weapon) / (1.0f - WEAPON_SHARE_OF_HIT_80);
            if (attackPower <= 0.0f)
                return 1.0f;

            return std::max(1.0f, growth->melee / attackPower);
        }

        float CapCreatureSpellPower(float power, float powerAtLevel80, uint8 level)
        {
            if (level <= 80)
                return power;

            float scale = s_creatureSpellScale;
            Growth const* growth = Find(level);
            if (scale <= 0.0f || !growth)
                return power;

            return std::min(power, powerAtLevel80 * growth->health * scale);
        }
    }
}
