/*
 * DarkChaos QoL - Paged collection vendors
 *
 * SMSG_LIST_INVENTORY carries at most MAX_VENDOR_ITEMS (150) rows on 3.3.5, so
 * a vendor holding the whole downported roster (well over a thousand mounts or
 * pets) only ever shows its first 150 items. On top of that the stock handler
 * walks the list with a uint8 counter, so everything past that is unreachable.
 *
 * Instead of spreading the roster over a crowd of NPCs, each collection vendor
 * gets a gossip menu with one entry per page. The pages are built in memory
 * from the vendor's own npc_vendor rows (sorted by name, "Reins of" / "Cage of"
 * ignored), and a page is opened through SendListInventory's vendorEntry
 * override, which buying already honours via WorldSession::GetCurrentVendor().
 *
 * The base vendor's npc_vendor rows stay the single source of truth: new
 * downport batches keep appending to it and the pages follow automatically.
 * They are rebuilt on startup, and again from the world thread (maps idle)
 * whenever the base list changes size or `.reload npc_vendor` wiped the cache.
 */

#include "ScriptMgr.h"
#include "Creature.h"
#include "GossipDef.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"
#include "WorldSession.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <string>
#include <string_view>
#include <vector>

namespace
{

struct PagedVendorDef
{
    uint32 baseEntry;       // creature entry whose npc_vendor rows hold the full roster
    uint32 pageEntryBase;   // in-memory vendor entries used for the pages (never in the DB)
    char const* label;      // gossip label prefix
};

// Page entries live far above any creature_template / npc_vendor entry.
constexpr std::array<PagedVendorDef, 2> PagedVendors =
{{
    { 3461020, 2100000000, "Mounts" },  // Skeletal Stablemaster
    { 3461229, 2100000100, "Pets" },    // Skeletal Petkeeper
}};

constexpr uint32 PageSize = MAX_VENDOR_ITEMS;
constexpr uint32 MaxPages = GOSSIP_MAX_MENU_ITEMS;
constexpr uint32 StaleCheckIntervalMs = 5000;

struct PageItem
{
    std::string sortKey;
    std::string displayName;
    VendorItem row;
};

struct VendorPage
{
    uint32 entry = 0;
    std::string label;
    std::vector<uint32> items;  // for removing the page's rows on rebuild
};

struct PagedVendorState
{
    std::size_t builtFromCount = 0;
    std::vector<VendorPage> pages;
};

std::array<PagedVendorState, PagedVendors.size()> sStates;

std::string_view StripPrefix(std::string_view name)
{
    for (std::string_view prefix : { "Reins of ", "Cage of " })
    {
        if (name.starts_with(prefix))
        {
            name.remove_prefix(prefix.size());
            break;
        }
    }

    if (name.starts_with("the "))
        name.remove_prefix(4);

    return name;
}

std::string FirstWord(std::string const& name)
{
    std::string word = name.substr(0, name.find(' '));
    if (word.size() > 14)
        word.resize(14);
    return word;
}

PagedVendorDef const* FindDef(uint32 creatureEntry, std::size_t* index = nullptr)
{
    for (std::size_t i = 0; i < PagedVendors.size(); ++i)
    {
        if (PagedVendors[i].baseEntry == creatureEntry)
        {
            if (index)
                *index = i;
            return &PagedVendors[i];
        }
    }

    return nullptr;
}

void ClearPages(PagedVendorState& state)
{
    for (VendorPage const& page : state.pages)
        for (uint32 item : page.items)
            sObjectMgr->RemoveVendorItem(page.entry, item, false);

    state.pages.clear();
    state.builtFromCount = 0;
}

void BuildPages(PagedVendorDef const& def, PagedVendorState& state)
{
    ClearPages(state);

    VendorItemData const* base = sObjectMgr->GetNpcVendorItemList(def.baseEntry);
    if (!base || base->Empty())
        return;

    std::vector<PageItem> sorted;
    sorted.reserve(base->m_items.size());

    for (VendorItem const* row : base->m_items)
    {
        ItemTemplate const* proto = row ? sObjectMgr->GetItemTemplate(row->item) : nullptr;
        if (!proto)
            continue;

        std::string display(StripPrefix(proto->Name1));
        std::string key = display;
        std::transform(key.begin(), key.end(), key.begin(), [](unsigned char c) { return std::tolower(c); });

        sorted.push_back({ std::move(key), std::move(display), *row });
    }

    std::stable_sort(sorted.begin(), sorted.end(),
        [](PageItem const& a, PageItem const& b) { return a.sortKey < b.sortKey; });

    std::size_t const total = sorted.size();
    std::size_t pageCount = (total + PageSize - 1) / PageSize;
    if (pageCount > MaxPages)
    {
        LOG_ERROR("scripts.dc", "PagedCollectionVendor: vendor {} holds {} items, only the first {} pages ({} items) "
            "fit in the gossip menu", def.baseEntry, total, MaxPages, MaxPages * PageSize);
        pageCount = MaxPages;
    }

    // Spread evenly instead of 150/150/.../leftover so no page is a stub.
    std::size_t const perPage = pageCount ? (total + pageCount - 1) / pageCount : 0;

    for (std::size_t p = 0; p < pageCount; ++p)
    {
        std::size_t const first = p * perPage;
        std::size_t const last = std::min(first + perPage, total);
        if (first >= last)
            break;

        VendorPage page;
        page.entry = def.pageEntryBase + p;
        page.items.reserve(last - first);

        for (std::size_t i = first; i < last; ++i)
        {
            VendorItem const& row = sorted[i].row;
            sObjectMgr->AddVendorItem(page.entry, row.item, row.maxcount, row.incrtime, row.ExtendedCost, false);
            page.items.push_back(row.item);
        }

        page.label = Acore::StringFormat("{} {}/{}: {} - {}", def.label, p + 1, pageCount,
            FirstWord(sorted[first].displayName), FirstWord(sorted[last - 1].displayName));

        state.pages.push_back(std::move(page));
    }

    state.builtFromCount = base->m_items.size();

    LOG_INFO("scripts.dc", "PagedCollectionVendor: vendor {} split into {} pages ({} items)",
        def.baseEntry, state.pages.size(), total);
}

bool IsStale(PagedVendorDef const& def, PagedVendorState const& state)
{
    VendorItemData const* base = sObjectMgr->GetNpcVendorItemList(def.baseEntry);
    std::size_t const baseCount = base ? base->m_items.size() : 0;

    if (baseCount != state.builtFromCount)
        return true;

    // `.reload npc_vendor` clears the whole cache, including our in-memory pages.
    return !state.pages.empty() && !sObjectMgr->GetNpcVendorItemList(state.pages.front().entry);
}

void RebuildAll(bool onlyStale)
{
    for (std::size_t i = 0; i < PagedVendors.size(); ++i)
        if (!onlyStale || IsStale(PagedVendors[i], sStates[i]))
            BuildPages(PagedVendors[i], sStates[i]);
}

} // namespace

class DCPagedCollectionVendorWorldScript : public WorldScript
{
public:
    DCPagedCollectionVendorWorldScript()
        : WorldScript("DCPagedCollectionVendorWorldScript", { WORLDHOOK_ON_STARTUP, WORLDHOOK_ON_UPDATE }) { }

    void OnStartup() override
    {
        RebuildAll(false);
    }

    // Runs on the world thread after the map updaters have finished their tick,
    // so touching the vendor cache here cannot race a vendor window being built.
    void OnUpdate(uint32 diff) override
    {
        _sinceCheck += diff;
        if (_sinceCheck < StaleCheckIntervalMs)
            return;

        _sinceCheck = 0;
        RebuildAll(true);
    }

private:
    uint32 _sinceCheck = 0;
};

class npc_dc_paged_collection_vendor : public CreatureScript
{
public:
    npc_dc_paged_collection_vendor() : CreatureScript("npc_dc_paged_collection_vendor") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        std::size_t index = 0;
        if (!FindDef(creature->GetEntry(), &index) || sStates[index].pages.empty())
        {
            // Not paged (or not built yet): behave like a plain vendor.
            player->GetSession()->SendListInventory(creature->GetGUID());
            return true;
        }

        ClearGossipMenuFor(player);

        std::vector<VendorPage> const& pages = sStates[index].pages;
        for (std::size_t p = 0; p < pages.size(); ++p)
            AddGossipItemFor(player, GOSSIP_ICON_VENDOR, pages[p].label, GOSSIP_SENDER_MAIN,
                GOSSIP_ACTION_INFO_DEF + static_cast<uint32>(p));

        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);

        std::size_t index = 0;
        if (!FindDef(creature->GetEntry(), &index))
            return true;

        std::vector<VendorPage> const& pages = sStates[index].pages;
        uint32 const page = action - GOSSIP_ACTION_INFO_DEF;
        if (action < GOSSIP_ACTION_INFO_DEF || page >= pages.size())
            return true;

        player->GetSession()->SendListInventory(creature->GetGUID(), pages[page].entry);
        return true;
    }
};

void AddSC_dc_paged_collection_vendor_qol()
{
    new DCPagedCollectionVendorWorldScript();
    new npc_dc_paged_collection_vendor();
}
