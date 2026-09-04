/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Relative include, matching how BattlegroundMgr.cpp reaches the same tree -
// the DC scripts directory is not on any target's include path.
#include "../../../../server/scripts/DC/HinterlandBG/hlbg_constants.h"
#include "gtest/gtest.h"

#include <set>
#include <string>

/**
 * Covers the pure affix helpers in hlbg_constants.h.
 *
 * These are worth pinning because three separate things must agree: the
 * per-affix arrays in BattlegroundHLBG (indexed directly by affix code), the
 * announce text, and the DC-HinterlandBG addon's own copy of the name and
 * description tables in HLBG_Stubs.lua. Drift between them is silent - an affix
 * with no name renders as "Affix 7" in the client and nobody notices.
 */
using namespace HinterlandBGConstants;

namespace
{
    // Every affix that actually exists, in code order.
    std::vector<uint8> AllAffixCodes()
    {
        std::vector<uint8> codes;
        for (uint8 code = HLBG_AFFIX_SUNLIGHT; code <= HLBG_AFFIX_LAST; ++code)
            codes.push_back(code);

        return codes;
    }

    bool IsRuleAffix(uint8 code)
    {
        return code == HLBG_AFFIX_WARLORDS
            || code == HLBG_AFFIX_SKIRMISH
            || code == HLBG_AFFIX_BLOODLUST;
    }
}

TEST(HLBGAffixTest, StorageCoversEveryAffixCode)
{
    // The arrays in BattlegroundHLBG are indexed by affix code; a short array
    // would be an out-of-bounds write rather than a visible failure.
    EXPECT_GT(uint32(HLBG_AFFIX_STORAGE_SIZE), uint32(HLBG_AFFIX_LAST));
}

TEST(HLBGAffixTest, EveryAffixHasANameAndDescription)
{
    for (uint8 code : AllAffixCodes())
    {
        EXPECT_STRNE(GetAffixName(code), "None") << "affix " << uint32(code) << " has no name";
        EXPECT_STRNE(GetAffixName(code), "") << "affix " << uint32(code) << " has an empty name";
        EXPECT_STRNE(GetAffixDescription(code), "") << "affix " << uint32(code) << " has no description";
    }
}

TEST(HLBGAffixTest, AffixNamesAreUnique)
{
    std::set<std::string> seen;
    for (uint8 code : AllAffixCodes())
        EXPECT_TRUE(seen.insert(GetAffixName(code)).second) << "duplicate name for affix " << uint32(code);
}

TEST(HLBGAffixTest, UnknownAffixDegradesToNone)
{
    EXPECT_STREQ(GetAffixName(HLBG_AFFIX_NONE), "None");
    EXPECT_STREQ(GetAffixName(HLBG_AFFIX_LAST + 1), "None");
    EXPECT_STREQ(GetAffixDescription(HLBG_AFFIX_NONE), "");
}

TEST(HLBGAffixTest, AuraAffixesHaveASpellAndRuleAffixesDoNot)
{
    for (uint8 code : AllAffixCodes())
    {
        if (IsRuleAffix(code))
        {
            // Rule affixes retune the resource economy; casting a spell for
            // them would be a copy-paste slip.
            EXPECT_EQ(GetDefaultAffixPlayerSpell(code), 0u)
                << "rule affix " << uint32(code) << " should not carry a spell";
        }
        else
        {
            EXPECT_NE(GetDefaultAffixPlayerSpell(code), 0u)
                << "aura affix " << uint32(code) << " has no spell";
        }
    }
}

TEST(HLBGAffixTest, WeatherStatesAreReachableValues)
{
    // Values are WeatherState (Weather.h). Anything outside this set either
    // renders nothing or renders the wrong biome - snow in a temperate forest.
    std::set<uint32> const allowed = { 0u /*Clear*/, 1u /*Fog*/, 3u /*LightRain*/,
        4u /*Rain*/, 5u /*HeavyRain*/, 86u /*Thunderstorm*/, 90u /*BlackRain*/ };

    for (uint8 code : AllAffixCodes())
    {
        EXPECT_TRUE(allowed.count(GetDefaultAffixWeatherState(code)) > 0)
            << "affix " << uint32(code) << " maps to an unexpected weather state "
            << GetDefaultAffixWeatherState(code);
    }
}

TEST(HLBGAffixTest, ClearWeatherHasZeroIntensity)
{
    // A "clear" state with a non-zero density still draws precipitation.
    for (uint8 code : AllAffixCodes())
        if (GetDefaultAffixWeatherState(code) == 0u)
            EXPECT_FLOAT_EQ(GetDefaultAffixWeatherIntensity(code), 0.0f)
                << "affix " << uint32(code) << " is clear but has rain density";
}

TEST(HLBGAffixTest, ContradictoryAffixesNeverPairUp)
{
    // Opposite movement speed, duplicate clear sky, duplicate detection aura,
    // and contradictory NPC economy rules.
    EXPECT_FALSE(AreAffixesCompatible(HLBG_AFFIX_GENTLE_BREEZE, HLBG_AFFIX_HEAVY_RAIN));
    EXPECT_FALSE(AreAffixesCompatible(HLBG_AFFIX_SUNLIGHT, HLBG_AFFIX_CLEAR_SKIES));
    EXPECT_FALSE(AreAffixesCompatible(HLBG_AFFIX_FOG, HLBG_AFFIX_NIGHTFALL));
    EXPECT_FALSE(AreAffixesCompatible(HLBG_AFFIX_WARLORDS, HLBG_AFFIX_SKIRMISH));
}

TEST(HLBGAffixTest, CompatibilityIsSymmetric)
{
    for (uint8 left : AllAffixCodes())
        for (uint8 right : AllAffixCodes())
            EXPECT_EQ(AreAffixesCompatible(left, right), AreAffixesCompatible(right, left))
                << "asymmetric verdict for " << uint32(left) << " / " << uint32(right);
}

TEST(HLBGAffixTest, AnAffixNeverPairsWithItself)
{
    for (uint8 code : AllAffixCodes())
        EXPECT_FALSE(AreAffixesCompatible(code, code)) << "affix " << uint32(code) << " paired with itself";
}

TEST(HLBGAffixTest, UnrelatedAffixesPairUp)
{
    EXPECT_TRUE(AreAffixesCompatible(HLBG_AFFIX_SUNLIGHT, HLBG_AFFIX_STORM));
    EXPECT_TRUE(AreAffixesCompatible(HLBG_AFFIX_BLOODLUST, HLBG_AFFIX_FOG));
    EXPECT_TRUE(AreAffixesCompatible(HLBG_AFFIX_WARLORDS, HLBG_AFFIX_GENTLE_BREEZE));
}

TEST(HLBGAffixTest, WeatherNamesCoverTheStatesInUse)
{
    for (uint8 code : AllAffixCodes())
        EXPECT_STRNE(GetWeatherName(GetDefaultAffixWeatherState(code)), "Unknown")
            << "affix " << uint32(code) << " weather state has no display name";
}

TEST(HLBGAffixTest, TeamNamesMatchTeamIdOrdering)
{
    // dc_hlbg_winner_history.winner_tid and dc_hlbg_match_participants.team both
    // store TeamId, and the addon leaderboards join them.
    EXPECT_STREQ(GetTeamName(0), "Alliance");
    EXPECT_STREQ(GetTeamName(1), "Horde");
    EXPECT_STREQ(GetTeamName(2), "Draw");
}
