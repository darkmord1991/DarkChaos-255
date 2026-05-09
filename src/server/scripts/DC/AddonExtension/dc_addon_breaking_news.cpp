#include "dc_addon_breaking_news.h"

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"

#include <algorithm>
#include <cctype>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>

namespace DCBreakingNews
{
    namespace
    {
        constexpr uint16 SMSG_BREAKING_NEWS = 1315;
        constexpr std::time_t BREAKING_NEWS_CACHE_TTL_SECS = 30;

        constexpr char const* CONFIG_ENABLE = "DC.BreakingNews.Enable";
        constexpr char const* CONFIG_TITLE = "DC.BreakingNews.Title";
        constexpr char const* CONFIG_PATH = "DC.BreakingNews.ContentPath";
        constexpr char const* CONFIG_FORMAT = "DC.BreakingNews.Format";
        constexpr char const* CONFIG_CACHE = "DC.BreakingNews.Cache";
        constexpr char const* CONFIG_VERBOSE = "DC.BreakingNews.Verbose";

        struct CachedState
        {
            Snapshot snapshot;
            uint32 revisionCounter = 0;
            bool cacheEnabled = true;
            bool loadedOnce = false;
            std::time_t expiresAt = 0;
        };

        std::mutex sBreakingNewsLock;
        CachedState sBreakingNewsState;

        std::string Trim(std::string value)
        {
            auto notSpace = [](unsigned char ch)
            {
                return !std::isspace(ch);
            };

            value.erase(value.begin(),
                std::find_if(value.begin(), value.end(), notSpace));
            value.erase(
                std::find_if(value.rbegin(), value.rend(), notSpace).base(),
                value.end());
            return value;
        }

        std::string ToLowerCopy(std::string value)
        {
            std::transform(value.begin(), value.end(), value.begin(),
                [](unsigned char ch)
                {
                    return static_cast<char>(std::tolower(ch));
                });
            return value;
        }

        void StripWrapperTag(std::string& text, std::string const& tagName)
        {
            std::string lower = ToLowerCopy(text);
            std::string openPrefix = "<" + tagName;
            std::string closeTag = "</" + tagName + ">";

            std::size_t openPos = lower.find(openPrefix);
            if (openPos == std::string::npos)
                return;

            std::size_t openEnd = lower.find('>', openPos);
            if (openEnd == std::string::npos)
                return;

            std::size_t closePos = lower.rfind(closeTag);
            if (closePos == std::string::npos || closePos <= openEnd)
                return;

            text = text.substr(openEnd + 1, closePos - openEnd - 1);
        }

        std::string NormalizeFormat(std::string format)
        {
            format = Trim(ToLowerCopy(format));

            if (format.empty() || format == "html")
                return "simplehtml";

            if (format == "simplehtml" || format == "plain")
                return format;

            return "simplehtml";
        }

        std::string NormalizeBody(std::string body, std::string const& format)
        {
            body.erase(std::remove(body.begin(), body.end(), '\r'), body.end());

            if (format == "simplehtml")
            {
                StripWrapperTag(body, "html");
                StripWrapperTag(body, "body");
            }

            return Trim(body);
        }

        bool ReadContentFile(std::string const& path, std::string& content,
            std::string* errorMessage)
        {
            std::error_code errorCode;
            std::filesystem::path contentPath(path);

            if (std::filesystem::exists(contentPath, errorCode) &&
                std::filesystem::is_directory(contentPath, errorCode))
            {
                if (errorMessage)
                {
                    *errorMessage =
                        "Configured content path points to a directory; expected a file: " +
                        path;
                }
                return false;
            }

            std::ifstream input(path, std::ios::in | std::ios::binary);
            if (!input.is_open())
            {
                if (errorMessage)
                    *errorMessage = "Failed to open content file: " + path;
                return false;
            }

            std::ostringstream buffer;
            buffer << input.rdbuf();
            content = buffer.str();
            return true;
        }

        bool BuildSnapshotFromConfig(Snapshot& snapshot, bool& cacheEnabled,
            std::string* errorMessage)
        {
            snapshot = Snapshot();
            snapshot.enabled = sConfigMgr->GetOption<bool>(CONFIG_ENABLE, false);
            cacheEnabled = sConfigMgr->GetOption<bool>(CONFIG_CACHE, true);

            if (!snapshot.enabled)
                return true;

            std::string path = sConfigMgr->GetOption<std::string>(
                CONFIG_PATH, "./breakingnews.html");
            if (Trim(path).empty())
            {
                if (errorMessage)
                    *errorMessage = "Configured content path is empty.";
                return false;
            }

            snapshot.title = Trim(sConfigMgr->GetOption<std::string>(
                CONFIG_TITLE, "Breaking News"));
            if (snapshot.title.empty())
                snapshot.title = "Breaking News";

            snapshot.format = NormalizeFormat(sConfigMgr->GetOption<std::string>(
                CONFIG_FORMAT, "simplehtml"));

            std::string content;
            if (!ReadContentFile(path, content, errorMessage))
                return false;

            snapshot.body = NormalizeBody(std::move(content), snapshot.format);
            if (snapshot.body.empty())
            {
                if (errorMessage)
                    *errorMessage = "Configured content file is empty.";
                return false;
            }

            snapshot.updatedAt = static_cast<uint32>(std::time(nullptr));
            return true;
        }

        bool RefreshLocked(bool force, std::string* errorMessage)
        {
            std::time_t now = std::time(nullptr);
            if (!force && sBreakingNewsState.loadedOnce
                && sBreakingNewsState.cacheEnabled
                && sBreakingNewsState.expiresAt > now)
            {
                return true;
            }

            Snapshot nextSnapshot;
            bool cacheEnabled = true;
            if (!BuildSnapshotFromConfig(nextSnapshot, cacheEnabled, errorMessage))
                return false;

            if (!nextSnapshot.enabled)
            {
                sBreakingNewsState = CachedState();
                return true;
            }

            sBreakingNewsState.snapshot = std::move(nextSnapshot);
            sBreakingNewsState.cacheEnabled = cacheEnabled;
            sBreakingNewsState.loadedOnce = true;
            sBreakingNewsState.expiresAt = cacheEnabled
                ? now + BREAKING_NEWS_CACHE_TTL_SECS
                : 0;
            sBreakingNewsState.snapshot.revision = ++sBreakingNewsState.revisionCounter;

            if (sConfigMgr->GetOption<bool>(CONFIG_VERBOSE, false))
            {
                LOG_INFO("module.dc",
                    "Breaking news refreshed (revision={}, format={}, bodyBytes={})",
                    sBreakingNewsState.snapshot.revision,
                    sBreakingNewsState.snapshot.format,
                    sBreakingNewsState.snapshot.body.size());
            }

            return true;
        }
    }

    Snapshot GetSnapshot()
    {
        std::lock_guard<std::mutex> lock(sBreakingNewsLock);
        RefreshLocked(false, nullptr);
        return sBreakingNewsState.snapshot;
    }

    bool Reload(bool force, std::string* errorMessage)
    {
        std::lock_guard<std::mutex> lock(sBreakingNewsLock);
        return RefreshLocked(force, errorMessage);
    }

    bool SendToSession(WorldSession* session)
    {
        if (!session)
            return false;

        Snapshot snapshot;
        {
            std::lock_guard<std::mutex> lock(sBreakingNewsLock);
            if (!RefreshLocked(false, nullptr))
                return false;

            snapshot = sBreakingNewsState.snapshot;
        }

        if (!snapshot.enabled || snapshot.body.empty())
            return false;

        WorldPacket data(SMSG_BREAKING_NEWS,
            snapshot.title.size() + snapshot.body.size() +
            snapshot.format.size() + 32);
        data << int32(snapshot.revision);
        data << int32(snapshot.updatedAt);
        data << snapshot.format;
        data << snapshot.title;
        data << snapshot.body;
        session->SendPacket(&data);

        if (sConfigMgr->GetOption<bool>(CONFIG_VERBOSE, false))
        {
            LOG_INFO("module.dc",
                "Breaking news sent to account={} (revision={}, format={}, bodyBytes={})",
                session->GetAccountId(), snapshot.revision,
                snapshot.format, snapshot.body.size());
        }

        return true;
    }
}

namespace
{
    class DCBreakingNewsServerScript : public ServerScript
    {
    public:
        DCBreakingNewsServerScript()
            : ServerScript("DCBreakingNewsServerScript",
                { SERVERHOOK_CAN_PACKET_SEND })
        {
        }

    private:
        bool CanPacketSend(WorldSession* session,
            WorldPacket const& packet) override
        {
            if (packet.GetOpcode() == SMSG_CHAR_ENUM)
                DCBreakingNews::SendToSession(session);

            return true;
        }
    };

    class DCBreakingNewsWorldScript : public WorldScript
    {
    public:
        DCBreakingNewsWorldScript()
            : WorldScript("DCBreakingNewsWorldScript",
                { WORLDHOOK_ON_AFTER_CONFIG_LOAD })
        {
        }

    private:
        void OnAfterConfigLoad(bool /*reload*/) override
        {
            std::string errorMessage;
            if (!DCBreakingNews::Reload(true, &errorMessage))
                LOG_ERROR("module.dc", "Breaking news reload failed: {}",
                    errorMessage);
        }
    };
}

void AddSC_dc_addon_breaking_news()
{
    new DCBreakingNewsServerScript();
    new DCBreakingNewsWorldScript();
}