/*
 * Dark Chaos - Fake Players Module
 * ================================
 *
 * Generates synthetic players for testing. These are shown in the /who list
 * and counted as online, but they are not real characters.
 */

#include "Config.h"
#include "DBCEnums.h"
#include "DBCStores.h"
#include "Log.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "WhoListCacheMgr.h"
#include "WorldSessionMgr.h"

#include <algorithm>
#include <cctype>
#include <string>
#include <unordered_set>
#include <vector>

namespace DCFakePlayers
{
    namespace ConfigKeys
    {
        constexpr char const* ENABLE = "FakePlayers.Enable";
        constexpr char const* COUNT = "FakePlayers.Count";
        constexpr char const* MIN_LEVEL = "FakePlayers.MinLevel";
        constexpr char const* MAX_LEVEL_KEY = "FakePlayers.MaxLevel";
        constexpr char const* REFRESH_INTERVAL = "FakePlayers.RefreshIntervalSeconds";
        constexpr char const* RANDOMIZE_REFRESH = "FakePlayers.RandomizeEachRefresh";
        constexpr char const* ZONES = "FakePlayers.Zones";
        constexpr char const* ZONE_WEIGHT_DEFAULT = "FakePlayers.ZoneWeight.Default";
        constexpr char const* ZONE_WEIGHT_CAPITAL = "FakePlayers.ZoneWeight.Capital";
        constexpr char const* ZONE_WEIGHT_TOWN = "FakePlayers.ZoneWeight.Town";
        constexpr char const* ZONE_WEIGHT_DUNGEON = "FakePlayers.ZoneWeight.Dungeon";
        constexpr char const* ZONE_WEIGHT_RAID = "FakePlayers.ZoneWeight.Raid";
        constexpr char const* ZONE_WEIGHT_BATTLEGROUND = "FakePlayers.ZoneWeight.Battleground";
        constexpr char const* ZONE_WEIGHT_ARENA = "FakePlayers.ZoneWeight.Arena";
        constexpr char const* ZONE_WEIGHT_USE_MAX_PLAYERS = "FakePlayers.ZoneWeight.UseMaxPlayers";
        constexpr char const* AFK_CHANCE = "FakePlayers.AfkChancePercent";
        constexpr char const* AFK_SUFFIX = "FakePlayers.AfkSuffix";
        constexpr char const* GUILD_TAGS_ENABLE = "FakePlayers.GuildTags.Enable";
        constexpr char const* GUILD_TAGS_LIST = "FakePlayers.GuildTags.List";
        constexpr char const* GUILD_TAGS_PERCENT = "FakePlayers.GuildTags.Percent";
    }

    struct ZoneEntry
    {
        uint32 zoneId = 0;
        uint32 weight = 1;
    };

    struct RaceClassOption
    {
        uint8 race = 0;
        std::vector<uint8> classes;
    };

    struct FakePlayerInfo
    {
        ObjectGuid guid;
        TeamId team = TEAM_NEUTRAL;
        AccountTypes security = SEC_PLAYER;
        uint8 level = 1;
        uint8 classId = 1;
        uint8 race = 1;
        uint8 gender = 0;
        uint32 zoneId = 0;
        std::string baseName;
        std::string name;
        std::wstring wideName;
        std::string guildName;
        std::wstring wideGuildName;
        bool isAfk = false;
    };

    static std::vector<RaceClassOption> const kRaceClassOptions = {
        { RACE_HUMAN,      { CLASS_WARRIOR, CLASS_PALADIN, CLASS_ROGUE, CLASS_PRIEST, CLASS_MAGE, CLASS_WARLOCK, CLASS_DEATH_KNIGHT } },
        { RACE_ORC,        { CLASS_WARRIOR, CLASS_HUNTER, CLASS_ROGUE, CLASS_SHAMAN, CLASS_WARLOCK, CLASS_DEATH_KNIGHT } },
        { RACE_DWARF,      { CLASS_WARRIOR, CLASS_PALADIN, CLASS_HUNTER, CLASS_ROGUE, CLASS_PRIEST, CLASS_DEATH_KNIGHT } },
        { RACE_NIGHTELF,   { CLASS_WARRIOR, CLASS_HUNTER, CLASS_ROGUE, CLASS_PRIEST, CLASS_DRUID, CLASS_DEATH_KNIGHT } },
        { RACE_UNDEAD_PLAYER, { CLASS_WARRIOR, CLASS_ROGUE, CLASS_PRIEST, CLASS_MAGE, CLASS_WARLOCK, CLASS_DEATH_KNIGHT } },
        { RACE_TAUREN,     { CLASS_WARRIOR, CLASS_HUNTER, CLASS_SHAMAN, CLASS_DRUID, CLASS_DEATH_KNIGHT } },
        { RACE_GNOME,      { CLASS_WARRIOR, CLASS_ROGUE, CLASS_MAGE, CLASS_WARLOCK, CLASS_DEATH_KNIGHT } },
        { RACE_TROLL,      { CLASS_WARRIOR, CLASS_HUNTER, CLASS_ROGUE, CLASS_PRIEST, CLASS_SHAMAN, CLASS_MAGE, CLASS_DEATH_KNIGHT } },
        { RACE_BLOODELF,   { CLASS_PALADIN, CLASS_HUNTER, CLASS_ROGUE, CLASS_PRIEST, CLASS_MAGE, CLASS_WARLOCK, CLASS_DEATH_KNIGHT } },
        { RACE_DRAENEI,    { CLASS_WARRIOR, CLASS_PALADIN, CLASS_HUNTER, CLASS_PRIEST, CLASS_SHAMAN, CLASS_MAGE, CLASS_DEATH_KNIGHT } }
    };

    static std::vector<ZoneEntry> BuildZonesFromDBC()
    {
        std::vector<ZoneEntry> out;
        std::unordered_set<uint32> seen;

        for (uint32 i = 0; i < sAreaTableStore.GetNumRows(); ++i)
        {
            AreaTableEntry const* area = sAreaTableStore.LookupEntry(i);
            if (!area)
                continue;

            if (area->zone != 0)
                continue; // Only include zone entries (not sub-areas)

            uint32 zoneId = area->ID;
            if (!zoneId || seen.count(zoneId))
                continue;

            seen.insert(zoneId);
            out.push_back({ zoneId, 1u });
        }

        return out;
    }

    static std::string Trim(std::string const& in)
    {
        size_t start = in.find_first_not_of(" \t\n\r");
        if (start == std::string::npos)
            return "";

        size_t end = in.find_last_not_of(" \t\n\r");
        return in.substr(start, end - start + 1);
    }

    static std::vector<uint32> ParseCsvU32(std::string const& csv)
    {
        std::vector<uint32> out;
        size_t start = 0;
        while (start < csv.size())
        {
            size_t comma = csv.find(',', start);
            std::string token = csv.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            token = Trim(token);
            if (!token.empty())
            {
                uint32 value = static_cast<uint32>(std::strtoul(token.c_str(), nullptr, 10));
                if (value > 0)
                    out.push_back(value);
            }

            if (comma == std::string::npos)
                break;

            start = comma + 1;
        }
        return out;
    }

    static std::vector<std::string> ParseCsvStrings(std::string const& csv)
    {
        std::vector<std::string> out;
        size_t start = 0;
        while (start < csv.size())
        {
            size_t comma = csv.find(',', start);
            std::string token = csv.substr(start, comma == std::string::npos ? std::string::npos : comma - start);
            token = Trim(token);
            if (!token.empty())
                out.push_back(token);

            if (comma == std::string::npos)
                break;

            start = comma + 1;
        }
        return out;
    }

    class FakePlayersManager
    {
    public:
        void LoadConfig()
        {
            _enabled = sConfigMgr->GetOption<bool>(ConfigKeys::ENABLE, true);
            _count = sConfigMgr->GetOption<uint32>(ConfigKeys::COUNT, 500);
            _minLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>(ConfigKeys::MIN_LEVEL, 1));
            _maxLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>(ConfigKeys::MAX_LEVEL_KEY, 255));
            _refreshIntervalMs = sConfigMgr->GetOption<uint32>(ConfigKeys::REFRESH_INTERVAL, 300) * IN_MILLISECONDS;
            _randomizeEachRefresh = sConfigMgr->GetOption<bool>(ConfigKeys::RANDOMIZE_REFRESH, false);
            _zoneWeightDefault = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_DEFAULT, 1);
            _zoneWeightCapital = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_CAPITAL, 8);
            _zoneWeightTown = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_TOWN, 3);
            _zoneWeightDungeon = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_DUNGEON, 5);
            _zoneWeightRaid = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_RAID, 10);
            _zoneWeightBattleground = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_BATTLEGROUND, 8);
            _zoneWeightArena = sConfigMgr->GetOption<uint32>(ConfigKeys::ZONE_WEIGHT_ARENA, 4);
            _zoneWeightUseMaxPlayers = sConfigMgr->GetOption<bool>(ConfigKeys::ZONE_WEIGHT_USE_MAX_PLAYERS, true);
            _afkChancePercent = sConfigMgr->GetOption<uint32>(ConfigKeys::AFK_CHANCE, 0);
            _afkSuffix = sConfigMgr->GetOption<std::string>(ConfigKeys::AFK_SUFFIX, " AFK");
            _guildTagsEnabled = sConfigMgr->GetOption<bool>(ConfigKeys::GUILD_TAGS_ENABLE, true);
            _guildTagsList = ParseCsvStrings(sConfigMgr->GetOption<std::string>(ConfigKeys::GUILD_TAGS_LIST, ""));
            _guildTagsPercent = std::min<uint32>(100u, sConfigMgr->GetOption<uint32>(ConfigKeys::GUILD_TAGS_PERCENT, 35));

            if (_minLevel == 0)
                _minLevel = 1;
            if (_maxLevel < _minLevel)
                std::swap(_minLevel, _maxLevel);

            _zones.clear();
            std::string zoneCsv = sConfigMgr->GetOption<std::string>(ConfigKeys::ZONES, "");
            if (!zoneCsv.empty())
            {
                auto values = ParseCsvU32(zoneCsv);
                for (uint32 zoneId : values)
                    _zones.push_back({ zoneId, 1u });
            }
            if (_zones.empty())
                _zones = BuildZonesFromDBC();

            if (_zones.empty())
                _zones.push_back({ 1519, 1u });

            ApplyZoneWeights();

            LOG_INFO("scripts.dc", "[FakePlayers] Config loaded (Enabled={}, Count={}, Zones={}, Refresh={}s)",
                _enabled ? "Yes" : "No", _count, _zones.size(), _refreshIntervalMs / IN_MILLISECONDS);
        }

        void Initialize()
        {
            _refreshTimerMs = 0;
            _usedNames.clear();
            _players.clear();
            _shuffleOrder.clear();

            if (!_enabled || _count == 0)
                return;

            _players.reserve(_count);
            for (uint32 i = 0; i < _count; ++i)
            {
                FakePlayerInfo info;
                info.guid = MakeFakeGuid(i);
                info.baseName = GenerateName();
                info.name = info.baseName;
                info.wideName.clear();
                if (!Utf8toWStr(info.name, info.wideName))
                    info.wideName = L"fake";
                wstrToLower(info.wideName);
                ApplyGuildTag(info, true);
                RandomizePlayer(info, true);
                ApplyAfkStatus(info, true);
                _players.push_back(info);
            }

            BuildShuffleOrder();
            ShuffleOrder();

            LOG_INFO("scripts.dc", "[FakePlayers] Spawned {} fake players for /who list", _players.size());
        }

        void Update(uint32 diff)
        {
            if (!_enabled || _players.empty() || _refreshIntervalMs == 0)
                return;

            if (_refreshTimerMs > diff)
            {
                _refreshTimerMs -= diff;
                return;
            }

            _refreshTimerMs = _refreshIntervalMs;

            ShuffleOrder();

            for (auto& player : _players)
            {
                RandomizePlayer(player, _randomizeEachRefresh);
                ApplyGuildTag(player, true);
                ApplyAfkStatus(player, true);
            }
        }

        uint32 GetCount() const
        {
            return (_enabled ? static_cast<uint32>(_players.size()) : 0u);
        }

        void AppendWhoList(WhoListInfoVector& out) const
        {
            if (!_enabled)
                return;

            for (uint32 index : _shuffleOrder)
            {
                if (index >= _players.size())
                    continue;

                auto const& player = _players[index];
                WhoListPlayerInfo entry(player.guid, player.team, player.security, player.level,
                    player.classId, player.race, player.zoneId, player.gender, true,
                    player.wideName, player.wideGuildName, player.name, player.guildName);

                uint32 insertPos = out.empty() ? 0u : urand(0u, static_cast<uint32>(out.size()));
                out.insert(out.begin() + insertPos, std::move(entry));
            }
        }

    private:
        ObjectGuid MakeFakeGuid(uint32 index) const
        {
            static constexpr ObjectGuid::LowType kFakeGuidBase = 0xFFF00000;
            return ObjectGuid::Create<HighGuid::Player>(kFakeGuidBase + index);
        }

        uint8 RandomLevel() const
        {
            return static_cast<uint8>(urand(_minLevel, _maxLevel));
        }

        ZoneEntry RandomZone() const
        {
            if (_zones.empty())
                return { 1519, 1u };

            if (_totalZoneWeight == 0)
                return _zones[urand(0u, static_cast<uint32>(_zones.size() - 1))];

            uint32 roll = urand(1u, _totalZoneWeight);
            for (auto const& zone : _zones)
            {
                if (roll <= zone.weight)
                    return zone;
                roll -= zone.weight;
            }

            return _zones.back();
        }

        std::pair<uint8, uint8> RandomRaceClass() const
        {
            auto const& option = kRaceClassOptions[urand(0u, static_cast<uint32>(kRaceClassOptions.size() - 1))];
            uint8 clss = option.classes[urand(0u, static_cast<uint32>(option.classes.size() - 1))];
            return { option.race, clss };
        }

        void RandomizePlayer(FakePlayerInfo& info, bool fullRandomize)
        {
            if (fullRandomize)
            {
                auto [race, clss] = RandomRaceClass();
                info.race = race;
                info.classId = clss;
                info.gender = static_cast<uint8>(urand(0, 1));
                info.level = RandomLevel();
            }

            auto zone = RandomZone();
            info.zoneId = zone.zoneId;
            info.team = Player::TeamIdForRace(info.race);
        }

        std::string GenerateName()
        {
            static std::vector<std::string> const syllables = {
                "al", "an", "ar", "bel", "bor", "cor", "dan", "dor", "el", "fa", "gar", "han",
                "ir", "jor", "kal", "kor", "lan", "lor", "mar", "mor", "nar", "nor", "or", "por",
                "ran", "rin", "sar", "ser", "tor", "tur", "ul", "ur", "val", "ven", "vor", "war",
                "wil", "yor", "zen"
            };

            for (uint32 attempt = 0; attempt < 50; ++attempt)
            {
                uint32 parts = urand(2u, 3u);
                std::string name;
                for (uint32 i = 0; i < parts; ++i)
                {
                    name += syllables[urand(0u, static_cast<uint32>(syllables.size() - 1))];
                }

                if (name.size() < 3 || name.size() > 12)
                    continue;

                name[0] = static_cast<char>(std::toupper(name[0]));
                for (size_t i = 1; i < name.size(); ++i)
                    name[i] = static_cast<char>(std::tolower(name[i]));

                if (_usedNames.insert(name).second)
                    return name;
            }

            return "Tester" + std::to_string(urand(1000u, 9999u));
        }

        std::string GenerateGuildName()
        {
            if (!_guildTagsList.empty())
                return _guildTagsList[urand(0u, static_cast<uint32>(_guildTagsList.size() - 1))];

            static std::vector<std::string> const prefixes = {
                "Crimson", "Silver", "Golden", "Shadow", "Storm", "Iron", "Emerald", "Obsidian", "Azure", "Radiant"
            };
            static std::vector<std::string> const suffixes = {
                "Legion", "Order", "Guard", "Vanguard", "Circle", "Syndicate", "Crusade", "Brotherhood", "Company", "Clan"
            };

            return prefixes[urand(0u, static_cast<uint32>(prefixes.size() - 1))] + " " +
                suffixes[urand(0u, static_cast<uint32>(suffixes.size() - 1))];
        }

        void ApplyAfkStatus(FakePlayerInfo& info, bool forceRoll)
        {
            if (_afkChancePercent == 0)
            {
                info.isAfk = false;
                if (info.name != info.baseName)
                {
                    info.name = info.baseName;
                    UpdateWideName(info);
                }
                return;
            }

            if (forceRoll || info.isAfk == false)
            {
                info.isAfk = (urand(1u, 100u) <= _afkChancePercent);
            }

            std::string displayName = info.baseName;
            if (info.isAfk)
            {
                if (displayName.size() + _afkSuffix.size() <= 12)
                    displayName += _afkSuffix;
            }

            if (info.name != displayName)
            {
                info.name = displayName;
                UpdateWideName(info);
            }
        }

        void UpdateWideName(FakePlayerInfo& info)
        {
            info.wideName.clear();
            if (!Utf8toWStr(info.name, info.wideName))
                info.wideName = L"fake";
            wstrToLower(info.wideName);
        }

        void ApplyGuildTag(FakePlayerInfo& info, bool forceRoll)
        {
            if (!_guildTagsEnabled || _guildTagsPercent == 0)
            {
                info.guildName.clear();
                info.wideGuildName.clear();
                return;
            }

            if (forceRoll)
            {
                bool hasGuild = (urand(1u, 100u) <= _guildTagsPercent);
                if (hasGuild)
                    info.guildName = GenerateGuildName();
                else
                    info.guildName.clear();

                info.wideGuildName.clear();
                if (!info.guildName.empty())
                {
                    if (!Utf8toWStr(info.guildName, info.wideGuildName))
                        info.wideGuildName = L"";
                    wstrToLower(info.wideGuildName);
                }
            }
        }

        uint32 GetInstanceWeight(MapEntry const* mapEntry) const
        {
            if (!mapEntry)
                return 1u;

            if (!_zoneWeightUseMaxPlayers)
                return 1u;

            return std::max(1u, mapEntry->maxPlayers);
        }

        uint32 ComputeZoneWeight(AreaTableEntry const* area) const
        {
            if (!area)
                return std::max(1u, _zoneWeightDefault);

            uint64 weight = std::max<uint32>(1u, _zoneWeightDefault);
            if (area->flags & (AREA_FLAG_CAPITAL | AREA_FLAG_SLAVE_CAPITAL | AREA_FLAG_SLAVE_CAPITAL2))
                weight *= std::max(1u, _zoneWeightCapital);
            else if (area->flags & AREA_FLAG_TOWN)
                weight *= std::max(1u, _zoneWeightTown);

            MapEntry const* mapEntry = sMapStore.LookupEntry(area->mapid);
            if (mapEntry)
            {
                uint32 instanceWeight = GetInstanceWeight(mapEntry);
                if (mapEntry->IsRaid())
                    weight *= std::max(1u, _zoneWeightRaid) * instanceWeight;
                else if (mapEntry->IsNonRaidDungeon())
                    weight *= std::max(1u, _zoneWeightDungeon) * instanceWeight;
                else if (mapEntry->IsBattleground())
                    weight *= std::max(1u, _zoneWeightBattleground) * instanceWeight;
                else if (mapEntry->IsBattleArena())
                    weight *= std::max(1u, _zoneWeightArena) * instanceWeight;
            }

            if (weight == 0)
                weight = 1;

            return static_cast<uint32>(weight);
        }

        void ApplyZoneWeights()
        {
            _totalZoneWeight = 0;
            for (auto& zone : _zones)
            {
                AreaTableEntry const* area = sAreaTableStore.LookupEntry(zone.zoneId);
                zone.weight = ComputeZoneWeight(area);
                _totalZoneWeight += zone.weight;
            }

            if (_totalZoneWeight == 0)
                _totalZoneWeight = static_cast<uint32>(_zones.size());
        }

        void BuildShuffleOrder()
        {
            _shuffleOrder.clear();
            _shuffleOrder.reserve(_players.size());
            for (uint32 i = 0; i < _players.size(); ++i)
                _shuffleOrder.push_back(i);
        }

        void ShuffleOrder()
        {
            if (_shuffleOrder.size() <= 1)
                return;

            for (size_t i = _shuffleOrder.size() - 1; i > 0; --i)
            {
                size_t j = static_cast<size_t>(urand(0u, static_cast<uint32>(i)));
                std::swap(_shuffleOrder[i], _shuffleOrder[j]);
            }
        }

        bool _enabled = false;
        uint32 _count = 0;
        uint8 _minLevel = 1;
        uint8 _maxLevel = 255;
        uint32 _refreshIntervalMs = 0;
        uint32 _refreshTimerMs = 0;
        bool _randomizeEachRefresh = false;
        std::vector<ZoneEntry> _zones;
        uint32 _zoneWeightDefault = 1;
        uint32 _zoneWeightCapital = 8;
        uint32 _zoneWeightTown = 3;
        uint32 _zoneWeightDungeon = 5;
        uint32 _zoneWeightRaid = 10;
        uint32 _zoneWeightBattleground = 8;
        uint32 _zoneWeightArena = 4;
        bool _zoneWeightUseMaxPlayers = true;
        uint32 _totalZoneWeight = 0;
        uint32 _afkChancePercent = 0;
        std::string _afkSuffix;
        bool _guildTagsEnabled = true;
        std::vector<std::string> _guildTagsList;
        uint32 _guildTagsPercent = 35;
        std::vector<FakePlayerInfo> _players;
        std::vector<uint32> _shuffleOrder;
        std::unordered_set<std::string> _usedNames;
    };

    static FakePlayersManager sFakePlayersMgr;

    class DCFakePlayersWorldScript : public WorldScript
    {
    public:
        DCFakePlayersWorldScript() : WorldScript("DCFakePlayersWorldScript") { }

        void OnStartup() override
        {
            sFakePlayersMgr.LoadConfig();
            sFakePlayersMgr.Initialize();
        }

        void OnUpdate(uint32 diff) override
        {
            sFakePlayersMgr.Update(diff);
        }
    };
}

void AddSC_dc_fake_players()
{
    using namespace DCFakePlayers;

    sFakePlayersMgr.LoadConfig();
    sFakePlayersMgr.Initialize();

    sWhoListCacheMgr->RegisterExternalWhoListProvider(
        [](WhoListInfoVector& out) { sFakePlayersMgr.AppendWhoList(out); },
        []() { return sFakePlayersMgr.GetCount(); });

    sWorldSessionMgr->RegisterExtraPlayerCountProvider(
        []() { return sFakePlayersMgr.GetCount(); });

    new DCFakePlayersWorldScript();
}
