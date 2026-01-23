/*
 * Dark Chaos - Fake Players Module
 * ================================
 *
 * Generates synthetic players for testing. These are shown in the /who list
 * and counted as online, but they are not real characters.
 */

#include "Config.h"
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
        constexpr char const* MAX_LEVEL = "FakePlayers.MaxLevel";
        constexpr char const* REFRESH_INTERVAL = "FakePlayers.RefreshIntervalSeconds";
        constexpr char const* RANDOMIZE_REFRESH = "FakePlayers.RandomizeEachRefresh";
        constexpr char const* ZONES = "FakePlayers.Zones";
    }

    struct ZoneEntry
    {
        uint32 zoneId = 0;
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
        std::string name;
        std::wstring wideName;
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
            out.push_back({ zoneId });
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

    class FakePlayersManager
    {
    public:
        void LoadConfig()
        {
            _enabled = sConfigMgr->GetOption<bool>(ConfigKeys::ENABLE, true);
            _count = sConfigMgr->GetOption<uint32>(ConfigKeys::COUNT, 500);
            _minLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>(ConfigKeys::MIN_LEVEL, 1));
            _maxLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>(ConfigKeys::MAX_LEVEL, 255));
            _refreshIntervalMs = sConfigMgr->GetOption<uint32>(ConfigKeys::REFRESH_INTERVAL, 300) * IN_MILLISECONDS;
            _randomizeEachRefresh = sConfigMgr->GetOption<bool>(ConfigKeys::RANDOMIZE_REFRESH, false);

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
                    _zones.push_back({ zoneId });
            }
            if (_zones.empty())
                _zones = BuildZonesFromDBC();

            if (_zones.empty())
                _zones.push_back({ 1519 });

            LOG_INFO("scripts.dc", "[FakePlayers] Config loaded (Enabled={}, Count={}, Zones={}, Refresh={}s)",
                _enabled ? "Yes" : "No", _count, _zones.size(), _refreshIntervalMs / IN_MILLISECONDS);
        }

        void Initialize()
        {
            _refreshTimerMs = 0;
            _usedNames.clear();
            _players.clear();

            if (!_enabled || _count == 0)
                return;

            _players.reserve(_count);
            for (uint32 i = 0; i < _count; ++i)
            {
                FakePlayerInfo info;
                info.guid = MakeFakeGuid(i);
                info.name = GenerateName();
                info.wideName.clear();
                if (!Utf8toWStr(info.name, info.wideName))
                    info.wideName = L"fake";
                wstrToLower(info.wideName);
                RandomizePlayer(info, true);
                _players.push_back(info);
            }

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

            for (auto& player : _players)
            {
                RandomizePlayer(player, _randomizeEachRefresh);
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

            for (auto const& player : _players)
            {
                out.emplace_back(player.guid, player.team, player.security, player.level,
                    player.classId, player.race, player.zoneId, player.gender, true,
                    player.wideName, L"", player.name, "");
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
                return { 1519 };

            return _zones[urand(0u, static_cast<uint32>(_zones.size() - 1))];
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

        bool _enabled = false;
        uint32 _count = 0;
        uint8 _minLevel = 1;
        uint8 _maxLevel = 255;
        uint32 _refreshIntervalMs = 0;
        uint32 _refreshTimerMs = 0;
        bool _randomizeEachRefresh = false;
        std::vector<ZoneEntry> _zones;
        std::vector<FakePlayerInfo> _players;
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
