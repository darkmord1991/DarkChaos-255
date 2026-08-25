# DC-JournalData

LoadOnDemand companion addon for **DC-Journal**. Contains `ItemsCache.lua` only.

## Why it is separate

`ItemsCache.lua` is 13.2 MB of source declaring 96,169 item rows. It used to be
listed in `dc-journal.toc`, so it was tokenised, parsed and materialised into
Lua tables at **every login**, whether or not the player ever opened the
Adventure Guide.

Measured cost of keeping it resident (Lua 5.1, 32-bit client):

| Component | Resident |
| --- | --- |
| 96,169 row tables @ 160 B | 14.7 MB |
| English names | 4.0 MB |
| Russian names | 6.0 MB |
| Icon paths (12,396 distinct, interned) | 0.55 MB |
| Outer table hash part | 3.0 MB |
| **Total** | **~28 MB** |

The table is strictly read-only and has exactly one consumer:
`C_ItemMixin:GetItemInfoFromCache` in
`DC-Journal/Interface/FrameXML/Utils/C_Item.lua`.

That consumer is only ever reached as a **fallback**: `C_Item:GetItemInfo` asks
the client's own `GetItemInfo` first and only consults this table for items the
3.3.5 client does not know about (custom and backported items). So for most
sessions the 28 MB was never read at all.

## How it loads

`C_Item.lua` calls `LoadAddOn("DC-JournalData")` the first time
`GetItemInfoFromCache` needs the table, then caches the result of that attempt.
This is the same pattern DC-GM uses for `AzerothAdmin_Models`.

If the addon is missing or disabled, the accessor returns `nil` exactly as it
did before when an item was absent from the table — the Adventure Guide falls
back to the client's own item data and nothing errors.

## Deployment

This is a **top-level addon folder**. It must be installed as a sibling of
`DC-Journal`, not nested inside it:

```text
Interface/AddOns/
├── DC-Journal/
└── DC-JournalData/
```

A nested folder is not scanned by the client and `LoadAddOn` would fail with
reason 2 (addon missing).

## What deliberately stayed behind

`CreaturesCache.lua` (30,009 rows, ~4 MB) is **not** here. Unlike `ItemsCache`
it is written to at content-registration time — `DCJournal.AddBossModel` in
`DarkChaos_Content.lua` registers custom creature entries into it. Deferring it
would make those writes land on a nil table behind an `if CreaturesCache and`
guard, silently breaking custom boss model previews. It stays eagerly loaded.
