/* HLBG Battleground Integration Helper
 * Integrates HLBG systems into AzerothCore sources.
 */

#include "HLBG_AIO_Handlers.cpp"
#include "WorldSessionMgr.h"
#include "Chat/Chat.h"

class HinterlandBattlegroundIntegration
{
public:
	static void OnBattlegroundStart(uint32 instanceId, uint32 affixId)
	{
				WorldDatabase.Execute("INSERT INTO hlbg_battle_history (battle_start, affix_id, instance_id, map_id) VALUES (NOW(), {}, {}, 47)", affixId, instanceId);
		BroadcastBattleStart(affixId);
		LOG_INFO("hlbg", "Hinterland BG started - Instance: {}, Affix: {}", instanceId, affixId);
	}

	static void OnBattlegroundEnd(uint32 instanceId, const std::string& winner, uint32 allianceResources, uint32 hordeResources, uint32 duration, uint32 affixId)
	{
		WorldDatabase.Execute("UPDATE hlbg_battle_history SET battle_end = NOW(), winner_faction = '{}', duration_seconds = {}, alliance_resources = {}, horde_resources = {} WHERE instance_id = {} AND battle_end IS NULL",
			winner, duration, allianceResources, hordeResources, instanceId);

		uint32 alliancePlayers = GetPlayerCountInBG(instanceId, ALLIANCE);
		uint32 hordePlayers = GetPlayerCountInBG(instanceId, HORDE);

		WorldDatabase.Execute("UPDATE hlbg_battle_history SET alliance_players = {}, horde_players = {} WHERE instance_id = {} AND battle_end IS NOT NULL ORDER BY id DESC LIMIT 1",
			alliancePlayers, hordePlayers, instanceId);

		HLBGAIOHandlers::UpdateBattleResults(winner, duration, affixId, allianceResources, hordeResources, alliancePlayers, hordePlayers);
		UpdatePlayerStatistics(instanceId, winner);
	}

	static void BroadcastLiveStatus(uint32 allianceResources, uint32 hordeResources, uint32 affixId, uint32 timeRemaining)
	{
		#ifdef HAS_AIO
		WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
		for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
		{
			if (WorldSession* sess = itr->second)
			{
				Player* player = sess->GetPlayer();
				if (!player || !player->IsInWorld())
					continue;

				AioPacket data;
				data.WriteU32(allianceResources);
				data.WriteU32(hordeResources);
				data.WriteU32(affixId);
				data.WriteU32(timeRemaining);

				AIO().Handle(player, "HLBG", "Status", data);
			}
		}
		#else
		// AIO not available: nothing to broadcast
		(void)allianceResources; (void)hordeResources; (void)affixId; (void)timeRemaining;
		#endif
	}

	static void OnPlayerEnterBG(Player* player, uint32 instanceId)
	{
		if (!player)
			return;

		uint32 playerGuid = player->GetGUID().GetCounter();
	std::string playerName = player->GetName();
	std::string faction = player->GetTeamId() == TEAM_ALLIANCE ? "Alliance" : "Horde";

		WorldDatabase.Execute("INSERT INTO hlbg_player_stats (player_guid, player_name, faction, battles_participated, last_participation) VALUES ({}, '{}', '{}', 1, NOW()) ON DUPLICATE KEY UPDATE battles_participated = battles_participated + 1, last_participation = NOW()",
			playerGuid, playerName, faction);

		SendBattleStatusToPlayer(player, instanceId);
	}

	static void OnPlayerKill(Player* killer, Player* victim, uint32 instanceId)
	{
		if (!killer || !victim)
			return;

		uint32 killerGuid = killer->GetGUID().GetCounter();
		uint32 victimGuid = victim->GetGUID().GetCounter();

	WorldDatabase.Execute("UPDATE hlbg_player_stats SET total_kills = total_kills + 1 WHERE player_guid = {}", killerGuid);
	WorldDatabase.Execute("UPDATE hlbg_player_stats SET total_deaths = total_deaths + 1 WHERE player_guid = {}", victimGuid);
		WorldDatabase.Execute("UPDATE hlbg_statistics SET total_kills = total_kills + 1, total_deaths = total_deaths + 1");
	}

	static void OnResourceCapture(Player* player, uint32 resourceAmount, uint32 instanceId)
	{
		if (!player)
			return;

		uint32 playerGuid = player->GetGUID().GetCounter();
	WorldDatabase.Execute("UPDATE hlbg_player_stats SET resources_captured = resources_captured + {} WHERE player_guid = {}", resourceAmount, playerGuid);
	}

private:
	static void BroadcastBattleStart(uint32 affixId)
	{
		WorldSessionMgr::SessionMap const& sessions = sWorldSessionMgr->GetAllSessions();
		for (WorldSessionMgr::SessionMap::const_iterator itr = sessions.begin(); itr != sessions.end(); ++itr)
		{
			if (WorldSession* sess = itr->second)
			{
				Player* player = sess->GetPlayer();
				if (!player || !player->IsInWorld())
					continue;

				ChatHandler(player->GetSession()).PSendSysMessage("Hinterland Battleground has started with affix {}!", affixId);
			}
		}
	}

	static void UpdatePlayerStatistics(uint32 instanceId, const std::string& winner)
	{
		if (winner == "Alliance")
			WorldDatabase.Execute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Alliance')", instanceId);
		else if (winner == "Horde")
			WorldDatabase.Execute("UPDATE hlbg_player_stats SET battles_won = battles_won + 1 WHERE player_guid IN (SELECT player_guid FROM your_bg_participants_table WHERE instance_id = {} AND faction = 'Horde')", instanceId);

	QueryResult result = WorldDatabase.Query("SELECT COUNT(DISTINCT player_guid) FROM your_bg_participants_table WHERE instance_id = {}", instanceId);
		if (result)
		{
			uint32 participantCount = result->Fetch()[0].Get<uint32>();
			WorldDatabase.Execute("UPDATE hlbg_statistics SET total_players_participated = total_players_participated + {}", participantCount);
		}
	}

	static void SendBattleStatusToPlayer(Player* player, uint32 instanceId)
	{
		#ifdef HAS_AIO
		uint32 allianceResources = GetCurrentAllianceResources(instanceId);
		uint32 hordeResources = GetCurrentHordeResources(instanceId);
		uint32 affixId = GetCurrentAffix(instanceId);
		uint32 timeRemaining = GetBattleTimeRemaining(instanceId);

		AioPacket data;
		data.WriteU32(allianceResources);
		data.WriteU32(hordeResources);
		data.WriteU32(affixId);
		data.WriteU32(timeRemaining);

		AIO().Handle(player, "HLBG", "Status", data);
		#else
		// AIO not available: nothing to send
		(void)player; (void)instanceId;
		#endif
	}

	static uint32 GetPlayerCountInBG(uint32 instanceId, uint32 team) { return 0; }
	static uint32 GetCurrentAllianceResources(uint32 instanceId) { return 0; }
	static uint32 GetCurrentHordeResources(uint32 instanceId) { return 0; }
	static uint32 GetCurrentAffix(uint32 instanceId) { return 0; }
	static uint32 GetBattleTimeRemaining(uint32 instanceId) { return 0; }
};

