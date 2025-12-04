/*
 * DarkChaos Cross-System Reward Distributor Implementation
 *
 * Author: DarkChaos Development Team
 * Date: January 2026
 */

#include "RewardDistributor.h"
#include "CrossSystemManager.h"
#include "SessionContext.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Item.h"
#include "Log.h"
#include "Player.h"
#include "Timer.h"
#include <sstream>

namespace DarkChaos
{
namespace CrossSystem
{
    // =========================================================================
    // RewardCalculation
    // =========================================================================
    
    std::string RewardCalculation::GetBreakdown() const
    {
        std::ostringstream ss;
        ss << "Base: " << baseAmount;
        ss << " x Base(" << baseMultiplier << ")";
        
        if (prestigeMultiplier != 1.0f)
            ss << " x Prestige(" << prestigeMultiplier << ")";
        if (difficultyMultiplier != 1.0f)
            ss << " x Difficulty(" << difficultyMultiplier << ")";
        if (contentMultiplier != 1.0f)
            ss << " x Content(" << contentMultiplier << ")";
        if (keystoneMultiplier != 1.0f)
            ss << " x Keystone(" << keystoneMultiplier << ")";
        if (seasonalMultiplier != 1.0f)
            ss << " x Seasonal(" << seasonalMultiplier << ")";
        if (eventMultiplier != 1.0f)
            ss << " x Event(" << eventMultiplier << ")";
            
        ss << " = " << finalAmount;
        
        if (wasCapped)
            ss << " (capped from " << finalAmount << " to " << cappedAmount << ")";
            
        return ss.str();
    }
    
    // =========================================================================
    // RewardDistributor Implementation
    // =========================================================================
    
    RewardDistributor* RewardDistributor::instance()
    {
        static RewardDistributor instance;
        return &instance;
    }
    
    // =========================================================================
    // Configuration
    // =========================================================================
    
    void RewardDistributor::LoadConfiguration()
    {
        // Load from database
        QueryResult result = WorldDatabase.Query(
            "SELECT config_key, config_value FROM dc_seasonal_reward_config WHERE config_key LIKE 'reward_%'"
        );
        
        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                std::string key = fields[0].Get<std::string>();
                std::string value = fields[1].Get<std::string>();
                
                if (key == "reward_weekly_token_cap")
                    weeklyTokenCap_ = std::stoul(value);
                else if (key == "reward_weekly_essence_cap")
                    weeklyEssenceCap_ = std::stoul(value);
                else if (key == "reward_base_token_multiplier")
                    multiplierConfig_.baseTokenMultiplier = std::stof(value);
                else if (key == "reward_base_essence_multiplier")
                    multiplierConfig_.baseEssenceMultiplier = std::stof(value);
                else if (key == "reward_prestige_bonus_per_level")
                    multiplierConfig_.prestigeBonusPerLevel = std::stof(value);
                else if (key == "reward_mythic_plus_level_bonus")
                    multiplierConfig_.mythicPlusLevelBonus = std::stof(value);
            }
            while (result->NextRow());
        }
        
        // Set default content type multipliers
        multiplierConfig_.contentTypeMultipliers[ContentType::OpenWorld] = 1.0f;
        multiplierConfig_.contentTypeMultipliers[ContentType::Dungeon] = 1.2f;
        multiplierConfig_.contentTypeMultipliers[ContentType::Raid] = 1.5f;
        multiplierConfig_.contentTypeMultipliers[ContentType::Battleground] = 1.1f;
        multiplierConfig_.contentTypeMultipliers[ContentType::HLBG] = 1.3f;
        
        // Set default difficulty multipliers
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::Normal] = 1.0f;
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::Heroic] = 1.3f;
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::Mythic] = 1.6f;
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::MythicPlus] = 2.0f;
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::Raid10H] = 1.5f;
        multiplierConfig_.difficultyMultipliers[ContentDifficulty::Raid25H] = 1.8f;
        
        LOG_INFO("dc.crosssystem.rewards", "Reward configuration loaded. Token cap: {}, Essence cap: {}",
                 weeklyTokenCap_, weeklyEssenceCap_);
    }
    
    void RewardDistributor::ReloadConfiguration()
    {
        LoadConfiguration();
    }
    
    void RewardDistributor::SetEventMultiplier(float multiplier, uint32 durationSeconds)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        eventMultiplier_ = multiplier;
        
        if (durationSeconds > 0)
            eventMultiplierExpires_ = GameTime::GetGameTime().count() + durationSeconds;
        else
            eventMultiplierExpires_ = 0;
            
        LOG_INFO("dc.crosssystem.rewards", "Event multiplier set to {} for {} seconds",
                 multiplier, durationSeconds);
    }
    
    float RewardDistributor::GetEventMultiplier() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        if (eventMultiplierExpires_ > 0 && GameTime::GetGameTime().count() > eventMultiplierExpires_)
            return 1.0f;
            
        return eventMultiplier_;
    }
    
    // =========================================================================
    // Multiplier Calculation
    // =========================================================================
    
    RewardCalculation RewardDistributor::CalculateReward(const RewardContext& context, 
                                                         RewardType type, uint32 baseAmount)
    {
        RewardCalculation calc;
        calc.type = type;
        calc.baseAmount = baseAmount;
        
        // Get base multiplier
        calc.baseMultiplier = (type == RewardType::Tokens) 
            ? multiplierConfig_.baseTokenMultiplier 
            : multiplierConfig_.baseEssenceMultiplier;
        
        // Prestige multiplier
        calc.prestigeMultiplier = GetPrestigeMultiplier(context.prestigeLevel);
        
        // Difficulty multiplier
        calc.difficultyMultiplier = GetDifficultyMultiplier(context.difficulty);
        
        // Content type multiplier
        calc.contentMultiplier = GetContentTypeMultiplier(context.contentType);
        
        // Keystone level multiplier
        calc.keystoneMultiplier = GetKeystoneMultiplier(context.keystoneLevel);
        
        // Seasonal multiplier
        calc.seasonalMultiplier = GetSeasonalMultiplier(context.seasonId);
        
        // Event multiplier
        calc.eventMultiplier = GetEventMultiplier();
        
        // Calculate final multiplier
        calc.finalMultiplier = calc.baseMultiplier 
                             * calc.prestigeMultiplier 
                             * calc.difficultyMultiplier 
                             * calc.contentMultiplier 
                             * calc.keystoneMultiplier 
                             * calc.seasonalMultiplier 
                             * calc.eventMultiplier;
        
        // Calculate final amount
        calc.finalAmount = static_cast<uint32>(baseAmount * calc.finalMultiplier);
        
        // Apply weekly cap if needed
        // (Would need player info for actual cap checking)
        calc.cappedAmount = calc.finalAmount;
        calc.wasCapped = false;
        
        return calc;
    }
    
    float RewardDistributor::GetPrestigeMultiplier(uint8 prestigeLevel) const
    {
        return 1.0f + (prestigeLevel * multiplierConfig_.prestigeBonusPerLevel);
    }
    
    float RewardDistributor::GetDifficultyMultiplier(ContentDifficulty difficulty) const
    {
        auto it = multiplierConfig_.difficultyMultipliers.find(difficulty);
        if (it != multiplierConfig_.difficultyMultipliers.end())
            return it->second;
        return 1.0f;
    }
    
    float RewardDistributor::GetContentTypeMultiplier(ContentType type) const
    {
        auto it = multiplierConfig_.contentTypeMultipliers.find(type);
        if (it != multiplierConfig_.contentTypeMultipliers.end())
            return it->second;
        return 1.0f;
    }
    
    float RewardDistributor::GetKeystoneMultiplier(uint8 keystoneLevel) const
    {
        if (keystoneLevel == 0)
            return 1.0f;
            
        // +5% per keystone level
        return 1.0f + (keystoneLevel * multiplierConfig_.mythicPlusLevelBonus);
    }
    
    float RewardDistributor::GetSeasonalMultiplier(uint32 seasonId) const
    {
        // Could load from dc_seasonal_reward_multipliers
        return 1.0f;
    }
    
    // =========================================================================
    // Reward Distribution
    // =========================================================================
    
    DistributionResult RewardDistributor::Distribute(Player* player, const RewardContext& context,
                                                     const std::vector<RewardDefinition>& rewards)
    {
        DistributionResult result;
        
        if (!player)
        {
            result.success = false;
            result.error = "Invalid player";
            return result;
        }
        
        std::lock_guard<std::mutex> lock(mutex_);
        
        for (const auto& reward : rewards)
        {
            switch (reward.type)
            {
                case RewardType::Tokens:
                {
                    auto calc = CalculateReward(context, RewardType::Tokens, reward.amount);
                    
                    // Apply cap
                    if (weeklyTokenCap_ > 0)
                    {
                        auto capStatus = GetWeeklyCapStatus(player);
                        if (calc.finalAmount > capStatus.tokensRemaining)
                        {
                            calc.cappedAmount = capStatus.tokensRemaining;
                            calc.wasCapped = true;
                        }
                    }
                    
                    if (calc.cappedAmount > 0 && DoDistributeTokens(player, calc.cappedAmount))
                    {
                        result.tokensAwarded += calc.cappedAmount;
                        result.tokenCalc = calc;
                        stats_.tokensDistributed += calc.cappedAmount;
                        
                        // Update session
                        if (auto* session = GetPlayerSession(player))
                            session->AddSessionTokens(calc.cappedAmount);
                    }
                    break;
                }
                
                case RewardType::Essence:
                {
                    auto calc = CalculateReward(context, RewardType::Essence, reward.amount);
                    
                    // Apply cap
                    if (weeklyEssenceCap_ > 0)
                    {
                        auto capStatus = GetWeeklyCapStatus(player);
                        if (calc.finalAmount > capStatus.essenceRemaining)
                        {
                            calc.cappedAmount = capStatus.essenceRemaining;
                            calc.wasCapped = true;
                        }
                    }
                    
                    if (calc.cappedAmount > 0 && DoDistributeEssence(player, calc.cappedAmount))
                    {
                        result.essenceAwarded += calc.cappedAmount;
                        result.essenceCalc = calc;
                        stats_.essenceDistributed += calc.cappedAmount;
                        
                        // Update session
                        if (auto* session = GetPlayerSession(player))
                            session->AddSessionEssence(calc.cappedAmount);
                    }
                    break;
                }
                
                case RewardType::Item:
                {
                    if (DistributeItem(player, reward.itemId, reward.amount, 
                                      context.sourceSystem, context.sourceName))
                    {
                        result.itemsAwarded.push_back({reward.itemId, reward.amount});
                        stats_.itemsDistributed += reward.amount;
                    }
                    break;
                }
                
                default:
                    break;
            }
        }
        
        // Log transaction
        if (logTransactions_ && (result.tokensAwarded > 0 || result.essenceAwarded > 0))
        {
            RewardTransaction tx;
            tx.id = nextTransactionId_++;
            tx.playerGuid = player->GetGUID();
            tx.timestamp = GameTime::GetGameTime().count();
            tx.sourceSystem = context.sourceSystem;
            tx.triggerEvent = context.triggerEvent;
            tx.source = context.sourceName;
            tx.sourceId = context.sourceId;
            tx.tokensBase = result.tokenCalc.baseAmount;
            tx.tokensFinal = result.tokensAwarded;
            tx.essenceBase = result.essenceCalc.baseAmount;
            tx.essenceFinal = result.essenceAwarded;
            tx.multiplierApplied = result.tokenCalc.finalMultiplier;
            tx.wasCapped = result.tokenCalc.wasCapped || result.essenceCalc.wasCapped;
            
            LogTransaction(tx);
            result.transactionId = tx.id;
        }
        
        result.success = true;
        stats_.totalTransactions++;
        stats_.distributionsBySystem[context.sourceSystem]++;
        
        if (result.tokenCalc.wasCapped || result.essenceCalc.wasCapped)
            stats_.transactionsCapped++;
        
        return result;
    }
    
    DistributionResult RewardDistributor::DistributeTokens(Player* player, const RewardContext& context, 
                                                           uint32 baseAmount)
    {
        return Distribute(player, context, {RewardDefinition::Tokens(baseAmount)});
    }
    
    DistributionResult RewardDistributor::DistributeEssence(Player* player, const RewardContext& context,
                                                            uint32 baseAmount)
    {
        return Distribute(player, context, {RewardDefinition::Essence(baseAmount)});
    }
    
    DistributionResult RewardDistributor::DistributeBoth(Player* player, const RewardContext& context,
                                                         uint32 baseTokens, uint32 baseEssence)
    {
        return Distribute(player, context, {
            RewardDefinition::Tokens(baseTokens),
            RewardDefinition::Essence(baseEssence)
        });
    }
    
    bool RewardDistributor::DistributeItem(Player* player, uint32 itemId, uint32 count,
                                           SystemId source, const std::string& reason)
    {
        if (!player || itemId == 0 || count == 0)
            return false;
            
        ItemPosCountVec dest;
        InventoryResult msg = player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, itemId, count);
        
        if (msg != EQUIP_ERR_OK)
        {
            // Try to mail it
            // (Would need MailDraft implementation)
            LOG_WARN("dc.crosssystem.rewards", "Could not give item {} x{} to player {}: inventory full",
                     itemId, count, player->GetName());
            return false;
        }
        
        Item* item = player->StoreNewItem(dest, itemId, true);
        if (!item)
            return false;
            
        player->SendNewItem(item, count, true, false);
        
        LOG_DEBUG("dc.crosssystem.rewards", "Distributed item {} x{} to player {} from {} ({})",
                  itemId, count, player->GetName(), SystemIdToString(source), reason);
        
        return true;
    }
    
    // =========================================================================
    // Preview
    // =========================================================================
    
    std::vector<RewardCalculation> RewardDistributor::PreviewRewards(Player* player, 
                                                                      const RewardContext& context,
                                                                      const std::vector<RewardDefinition>& rewards)
    {
        std::vector<RewardCalculation> results;
        
        for (const auto& reward : rewards)
        {
            if (reward.type == RewardType::Tokens || reward.type == RewardType::Essence)
            {
                results.push_back(CalculateReward(context, reward.type, reward.amount));
            }
        }
        
        return results;
    }
    
    std::string RewardDistributor::GetRewardPreviewText(Player* player, const RewardContext& context,
                                                        const std::vector<RewardDefinition>& rewards)
    {
        auto calcs = PreviewRewards(player, context, rewards);
        
        std::ostringstream ss;
        ss << "Reward Preview:\n";
        
        for (const auto& calc : calcs)
        {
            ss << (calc.type == RewardType::Tokens ? "Tokens: " : "Essence: ");
            ss << calc.GetBreakdown() << "\n";
        }
        
        return ss.str();
    }
    
    // =========================================================================
    // Weekly Caps
    // =========================================================================
    
    WeeklyCapStatus RewardDistributor::GetWeeklyCapStatus(Player* player) const
    {
        WeeklyCapStatus status;
        
        if (!player)
            return status;
            
        // Load from dc_player_seasonal_stats or similar
        // For now, return unlimited
        status.tokensCap = weeklyTokenCap_;
        status.essenceCap = weeklyEssenceCap_;
        status.tokensRemaining = weeklyTokenCap_;
        status.essenceRemaining = weeklyEssenceCap_;
        
        return status;
    }
    
    bool RewardDistributor::IsAtTokenCap(Player* player) const
    {
        if (weeklyTokenCap_ == 0)
            return false;
        return GetWeeklyCapStatus(player).tokensAtCap;
    }
    
    bool RewardDistributor::IsAtEssenceCap(Player* player) const
    {
        if (weeklyEssenceCap_ == 0)
            return false;
        return GetWeeklyCapStatus(player).essenceAtCap;
    }
    
    // =========================================================================
    // Internal Distribution
    // =========================================================================
    
    bool RewardDistributor::DoDistributeTokens(Player* player, uint32 amount)
    {
        if (!player || amount == 0)
            return false;
            
        // Use the seasonal reward system's token handling
        // This would call into SeasonalRewardManager or update dc_player_upgrade_tokens
        
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
            "VALUES ({}, 'upgrade_token', {}, 1) "
            "ON DUPLICATE KEY UPDATE amount = amount + {}",
            player->GetGUID().GetCounter(), amount, amount
        );
        
        LOG_DEBUG("dc.crosssystem.rewards", "Distributed {} tokens to player {}",
                  amount, player->GetName());
        
        return true;
    }
    
    bool RewardDistributor::DoDistributeEssence(Player* player, uint32 amount)
    {
        if (!player || amount == 0)
            return false;
            
        CharacterDatabase.Execute(
            "INSERT INTO dc_player_upgrade_tokens (player_guid, currency_type, amount, season) "
            "VALUES ({}, 'artifact_essence', {}, 1) "
            "ON DUPLICATE KEY UPDATE amount = amount + {}",
            player->GetGUID().GetCounter(), amount, amount
        );
        
        LOG_DEBUG("dc.crosssystem.rewards", "Distributed {} essence to player {}",
                  amount, player->GetName());
        
        return true;
    }
    
    // =========================================================================
    // Transaction Logging
    // =========================================================================
    
    void RewardDistributor::LogTransaction(const RewardTransaction& tx)
    {
        recentTransactions_.push_back(tx);
        
        // Trim if too large
        while (recentTransactions_.size() > maxTransactionHistory_)
        {
            recentTransactions_.erase(recentTransactions_.begin());
        }
        
        // Optionally log to database
        // CharacterDatabase.Execute(...);
    }
    
    std::vector<RewardTransaction> RewardDistributor::GetTransactionsForPlayer(ObjectGuid guid) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        
        std::vector<RewardTransaction> result;
        for (const auto& tx : recentTransactions_)
        {
            if (tx.playerGuid == guid)
                result.push_back(tx);
        }
        return result;
    }
    
    void RewardDistributor::ClearTransactionHistory()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        recentTransactions_.clear();
    }
    
    void RewardDistributor::ResetStatistics()
    {
        std::lock_guard<std::mutex> lock(mutex_);
        stats_ = Statistics();
    }

} // namespace CrossSystem
} // namespace DarkChaos
