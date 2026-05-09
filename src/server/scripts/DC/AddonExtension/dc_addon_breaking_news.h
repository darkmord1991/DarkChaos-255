#ifndef DC_ADDON_BREAKING_NEWS_H
#define DC_ADDON_BREAKING_NEWS_H

#include <cstdint>
#include <string>

class WorldSession;

namespace DCBreakingNews
{
    struct Snapshot
    {
        bool enabled = false;
        std::string title;
        std::string body;
        std::string format = "simplehtml";
        uint32 revision = 0;
        uint32 updatedAt = 0;
    };

    Snapshot GetSnapshot();
    bool Reload(bool force, std::string* errorMessage = nullptr);
    bool SendToSession(WorldSession* session);
}

void AddSC_dc_addon_breaking_news();

#endif // DC_ADDON_BREAKING_NEWS_H