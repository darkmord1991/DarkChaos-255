/*
 * DarkChaos Item Upgrade - Enhanced NPC UI Helpers
 * 
 * This header provides utility functions for creating beautiful,
 * informative gossip menus with progress bars, transaction history,
 * and professional formatting.
 * 
 * Phase 3C.3 Enhancement
 * Author: DarkChaos Development Team
 * Date: November 4, 2025
 */

#ifndef DARKCHAOS_ITEMUPGRADE_UI_HELPERS_H
#define DARKCHAOS_ITEMUPGRADE_UI_HELPERS_H

#include "Common.h"
#include <sstream>
#include <iomanip>
#include <string>

namespace DarkChaos
{
    namespace ItemUpgrade
    {
        namespace UI
        {
            // =====================================================================
            // COLOR CODES FOR WoW CHAT
            // =====================================================================
            
            static constexpr const char* COLOR_TITLE     = "|cff99ccff";  // Cyan (titles)
            static constexpr const char* COLOR_POSITIVE  = "|cff00ff00";  // Green (positive)
            static constexpr const char* COLOR_NEGATIVE  = "|cffff0000";  // Red (negative)
            static constexpr const char* COLOR_NEUTRAL   = "|cffffffff";  // White (neutral)
            static constexpr const char* COLOR_GOLD      = "|cffd0ad00";  // Gold (currency)
            static constexpr const char* COLOR_WARNING   = "|cffff8000";  // Orange (warning)
            static constexpr const char* COLOR_RESET     = "|r";
            
            // =====================================================================
            // PROGRESS BAR VISUALIZATION
            // =====================================================================
            
            /**
             * Creates a visual progress bar for displaying token progress
             * @param current Current token amount
             * @param maximum Maximum token amount (weekly cap)
             * @param barLength Length of progress bar (default 20 characters)
             * @return Formatted progress bar string
             */
            inline std::string CreateProgressBar(uint32 current, uint32 maximum, uint32 barLength = 20)
            {
                if (maximum == 0) return "[ERROR: Zero maximum]";
                
                float percentage = (float)current / (float)maximum;
                uint32 filledBars = (uint32)(barLength * percentage);
                uint32 emptyBars = barLength - filledBars;
                
                std::ostringstream ss;
                ss << "[";
                
                // Filled portion
                for (uint32 i = 0; i < filledBars; ++i)
                    ss << COLOR_POSITIVE << "█" << COLOR_RESET;
                
                // Empty portion
                for (uint32 i = 0; i < emptyBars; ++i)
                    ss << COLOR_NEGATIVE << "░" << COLOR_RESET;
                
                ss << "] " << std::setw(3) << (int)(percentage * 100) << "%";
                
                return ss.str();
            }
            
            /**
             * Creates a weekly progress display
             * @param earned Tokens earned this week
             * @param cap Weekly cap (default 500)
             * @return Formatted weekly progress string
             */
            inline std::string CreateWeeklyProgressDisplay(uint32 earned, uint32 cap = 500)
            {
                std::ostringstream ss;
                ss << COLOR_TITLE << "Weekly Progress:" << COLOR_RESET << "\n";
                ss << COLOR_POSITIVE << earned << "/" << cap << COLOR_RESET << " tokens\n";
                ss << CreateProgressBar(earned, cap);
                return ss.str();
            }
            
            /**
             * Formats a currency amount with thousands separator
             * @param amount Currency amount
             * @return Formatted string with commas
             */
            inline std::string FormatCurrency(uint32 amount)
            {
                std::ostringstream ss;
                std::string numStr = std::to_string(amount);
                int numDigits = numStr.length();
                
                for (int i = 0; i < numDigits; ++i)
                {
                    if (i > 0 && (numDigits - i) % 3 == 0)
                        ss << ",";
                    ss << numStr[i];
                }
                
                return ss.str();
            }
            
            /**
             * Creates a fancy header for gossip menus
             * @param title Title text
             * @param width Width of header (default 35)
             * @return Formatted header string
             */
            inline std::string CreateHeader(const std::string& title, uint32 width = 35)
            {
                std::ostringstream ss;
                ss << COLOR_TITLE;
                ss << "╔";
                for (uint32 i = 0; i < width; ++i)
                    ss << "═";
                ss << "╗\n";
                
                int padding = (width - (int)title.length()) / 2;
                ss << "║";
                for (int i = 0; i < padding; ++i)
                    ss << " ";
                ss << title;
                for (int i = 0; i < width - padding - (int)title.length(); ++i)
                    ss << " ";
                ss << "║\n";
                
                ss << "╚";
                for (uint32 i = 0; i < width; ++i)
                    ss << "═";
                ss << "╝" << COLOR_RESET;
                
                return ss.str();
            }
            
            /**
             * Creates a stat row for display
             * @param label Label text
             * @param value Value (right-aligned)
             * @param width Width of line (default 35)
             * @return Formatted stat row
             */
            inline std::string CreateStatRow(const std::string& label, const std::string& value, uint32 width = 35)
            {
                std::ostringstream ss;
                int spacingNeeded = width - label.length() - value.length() - 2;
                
                ss << COLOR_NEUTRAL << label;
                for (int i = 0; i < spacingNeeded; ++i)
                    ss << " ";
                ss << value << COLOR_RESET;
                
                return ss.str();
            }
            
            /**
             * Creates reward tier indicator
             * @param amount Token amount
             * @param cap Weekly cap
             * @return Status indicator string
             */
            inline std::string CreateTierIndicator(uint32 amount, uint32 cap)
            {
                float percentage = (float)amount / (float)cap;
                
                if (percentage >= 1.0f)
                    return COLOR_GOLD + std::string("★ CAPPED") + COLOR_RESET;
                else if (percentage >= 0.8f)
                    return COLOR_WARNING + std::string("⚠ Nearly Capped") + COLOR_RESET;
                else if (percentage >= 0.5f)
                    return COLOR_POSITIVE + std::string("✓ Good Progress") + COLOR_RESET;
                else if (percentage > 0.0f)
                    return COLOR_POSITIVE + std::string("✓ Earning") + COLOR_RESET;
                else
                    return COLOR_NEUTRAL + std::string("○ Not Started") + COLOR_RESET;
            }
            
            // =====================================================================
            // TRANSACTION HISTORY FORMATTING
            // =====================================================================
            
            /**
             * Formats event type name for display
             * @param eventType Event type (quest, creature, pvp, achievement, battleground)
             * @return Human-readable event type
             */
            inline std::string FormatEventType(const std::string& eventType)
            {
                if (eventType == "quest")
                    return COLOR_POSITIVE + std::string("Quest") + COLOR_RESET;
                else if (eventType == "creature")
                    return COLOR_POSITIVE + std::string("Creature Kill") + COLOR_RESET;
                else if (eventType == "pvp")
                    return COLOR_WARNING + std::string("PvP Kill") + COLOR_RESET;
                else if (eventType == "achievement")
                    return COLOR_GOLD + std::string("Achievement") + COLOR_RESET;
                else if (eventType == "battleground")
                    return COLOR_POSITIVE + std::string("Battleground") + COLOR_RESET;
                else if (eventType == "admin")
                    return COLOR_WARNING + std::string("Admin") + COLOR_RESET;
                else
                    return COLOR_NEUTRAL + eventType + COLOR_RESET;
            }
            
            /**
             * Formats a time difference as readable string
             * @param secondsAgo Seconds since event
             * @return Human-readable time string
             */
            inline std::string FormatTimeDifference(time_t secondsAgo)
            {
                std::ostringstream ss;
                
                if (secondsAgo < 60)
                    ss << secondsAgo << "s ago";
                else if (secondsAgo < 3600)
                    ss << (secondsAgo / 60) << "m ago";
                else if (secondsAgo < 86400)
                    ss << (secondsAgo / 3600) << "h ago";
                else
                    ss << (secondsAgo / 86400) << "d ago";
                
                return ss.str();
            }
            
            /**
             * Creates a currency description
             * @param isUpgradeToken True for upgrade token, false for essence
             * @return Description string
             */
            inline std::string CreateCurrencyDescription(bool isUpgradeToken)
            {
                std::ostringstream ss;
                
                if (isUpgradeToken)
                {
                    ss << COLOR_POSITIVE << "Upgrade Tokens" << COLOR_RESET << "\n";
                    ss << "  Used to upgrade items from T1 to T4\n";
                    ss << "  Weekly Limit: " << COLOR_WARNING << "500" << COLOR_RESET << "\n";
                    ss << "  Earned from: Quests, Creatures, PvP\n";
                }
                else
                {
                    ss << COLOR_GOLD << "Artifact Essence" << COLOR_RESET << "\n";
                    ss << "  Used to upgrade artifacts and T5 items\n";
                    ss << "  Weekly Limit: " << COLOR_POSITIVE << "Unlimited" << COLOR_RESET << "\n";
                    ss << "  Earned from: Achievements, Raid Bosses\n";
                }
                
                return ss.str();
            }
            
            /**
             * Creates a price display for item costs
             * @param tokenCost Token cost
             * @param essenceCost Essence cost
             * @return Formatted price display
             */
            inline std::string CreatePriceDisplay(uint32 tokenCost, uint32 essenceCost)
            {
                std::ostringstream ss;
                ss << COLOR_TITLE << "Upgrade Cost:" << COLOR_RESET << "\n";
                if (tokenCost > 0)
                    ss << "  " << COLOR_POSITIVE << "Tokens: " << FormatCurrency(tokenCost) << COLOR_RESET << "\n";
                if (essenceCost > 0)
                    ss << "  " << COLOR_GOLD << "Essence: " << FormatCurrency(essenceCost) << COLOR_RESET;
                
                return ss.str();
            }
            
        } // namespace UI
    } // namespace ItemUpgrade
} // namespace DarkChaos

#endif // DARKCHAOS_ITEMUPGRADE_UI_HELPERS_H
