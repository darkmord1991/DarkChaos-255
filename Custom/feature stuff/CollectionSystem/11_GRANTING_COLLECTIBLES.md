# Granting Collectibles as Rewards

**Added:** 2026-08-11
**Code:** `src/server/scripts/DC/CollectionSystem/CollectionGrant.{h,cpp}`, `CollectionRewards.cpp`, `src/server/scripts/DC/Commands/cs_dc_collection.cpp`
**SQL:** `Custom/Custom feature SQLs/worlddb/CollectionSystem/2026_08_11_00_dc_collection_rewards.sql`
**Requires:** worldserver rebuild + the SQL applied to the world DB.

## The problem this replaces

There used to be no dedicated way to hand a player a mount or a pet. The
working routes were all indirect:

1. an item that teaches the spell, given as a quest `RewardItem` or loot drop,
   which the collection importer later picks up into `dc_collection_items`;
2. `achievement_reward.ItemID` plus mail;
3. `RewardDistributor::DistributeItem()` from C++ — again, an item.

All three route through an item, so every reward needed an item to exist first.
Hand-written `INSERT`s into `dc_collection_items` were the other option, and
they consistently forgot at least one of: teaching the spell, refreshing the
mount-speed bonus, invalidating the appearance cache, notifying the addon. The
collection shop did exactly that — a bought mount showed up in the Collection UI
but was missing from the spellbook until the next login sync.

## The API

```cpp
#include "DC/CollectionSystem/CollectionGrant.h"

DCCollection::GrantOptions options;
options.sourceType = "QUEST";              // dc_collection_items.source_type
options.sourceId   = quest->GetQuestId();
options.sourceText = "Quest: Ashes to Ashes";   // shown on the client toast

DCCollection::GrantCollectible(player, DCCollection::CollectionType::MOUNT, 48025, options);
```

One call performs the whole sequence: normalise the entry, validate it, write
the account-wide unlock row, teach the spell / apply the title on the account's
online character, refresh mount-speed bonuses and transmog caches, and push
`SMSG_COLLECTIBLE_GRANTED` so the UI updates without a relog.

Other entry points:

| Call | Use |
| --- | --- |
| `GrantCollectible(Player*, type, entry, opts)` | normal case |
| `GrantCollectibleToAccount(accountId, type, entry, opts)` | offline player; online characters of the account are still updated |
| `GrantMount(Player*, entry, opts)` / `GrantPet(...)` | convenience wrappers |
| `RevokeCollectible(accountId, type, entry, unlearn)` | refunds, GM corrections |
| `NormalizeCollectibleEntry` / `ValidateCollectibleEntry` | validation tooling |

`GrantResult` distinguishes `Granted` from `AlreadyOwned` (both mean the account
owns it — use `OwnsAfterGrant()`), and reports `InvalidEntry`, `InvalidType`,
`SystemDisabled`, `SchemaMissing`, `NoAccount` for anything else.

### Entry id conventions

The API accepts whichever id you have and normalises it to the form
`dc_collection_items.entry_id` stores:

| Type | Stored as | Also accepted |
| --- | --- | --- |
| MOUNT | mount spell id | teaching item id |
| PET | teaching item id | summon spell id |
| TOY / HEIRLOOM | item id | — |
| TITLE | `CharTitles` id | bit index |
| TRANSMOG | display id | item id |

Appearances are the exception to the table name: since 2026-10-01 a TRANSMOG
grant is written to `dc_transmog_collection` (the wardrobe, with `obtained_by`,
`obtained_from` and `obtained_via` filled in), because the wardrobe never read
`dc_collection_items`. Ownership checks, revokes and collection counts for
appearances read the wardrobe table too; type-6 rows in `dc_collection_items`
are legacy.

### Options worth knowing

- `teach = false` — record the unlock only; the login sync applies it later.
  Used by the learn-spell hook, where the character already has the spell.
- `notify = false` — suppress the client push when the caller sends its own
  result message (the shop does this).
- `skipValidation = true` — for callers that already know what the entry is.
  Normalisation still runs.

## Data-driven quest / achievement rewards

For most content no C++ is needed. Add a row to `dc_collection_rewards` in the
world DB:

```sql
DELETE FROM `dc_collection_rewards` WHERE `source_type` = 'QUEST' AND `source_id` = 820056;
INSERT INTO `dc_collection_rewards`
  (`source_type`, `source_id`, `collection_type`, `entry_id`, `team`, `enabled`, `comment`)
VALUES
  ('QUEST', 820056, 1, 48025, 0, 1, 'Reins of the Crimson Drake');
```

`source_type` is `QUEST` or `ACHIEVEMENT`; `collection_type` is 1-6;
`team` is 0 both / 1 alliance / 2 horde. Rows load at startup and on
`.collection reload`.

Every row is normalised and validated **at load time**, not at reward time — a
bad entry is reported in the worldserver log under `sql.sql` and skipped, so it
never fails silently in front of a player.

## Cross-system rewards

`RewardDistributor` gained a `RewardType::Collectible`:

```cpp
GetRewardDistributor()->Distribute(player, context, {
    RewardDefinition::Tokens(50),
    RewardDefinition::Mount(48025)
});
```

No multipliers apply to collectibles; the definition carries `collectionType`
and `collectionEntry`, and results land in `DistributionResult::collectiblesAwarded`.

## Commands

```
.collection grant  <type> <entry> [player]   SEC_ADMINISTRATOR
.collection revoke <type> <entry> [player]   SEC_ADMINISTRATOR
.collection check  <type> <entry> [player]   SEC_GAMEMASTER
.collection reload                           SEC_ADMINISTRATOR
```

`check` is the debugging tool: it reports how an entry normalises, whether it
validates, and whether the account owns it. The target may be offline.

### Shift-clicked links

`<entry>` also takes a link, which is what a GM actually has in front of them
when a player links a mount in chat:

```
.collection grant [Witherhide Cliffstomper]         a DC-Collection mount/pet link
.collection grant mount [Witherhide Cliffstomper]   same, type spelled out
.collection grant pet [Mini Diablo]                 a plain item link
.collection check [Witherhide Cliffstomper]         works on all three commands
```

A DC-Collection link (`|Hdc:mount:...|h`, built by the addon's
`Modules/CollectionLinks.lua`) carries its own type, so the `<type>` token in
front of one is optional; when both are given and disagree, the link wins. The
id inside the link is the addon's definition key — a mount spell id, a pet
teaching item id — which is exactly what the normaliser expects.

Before this, pasting a link produced
`Value '|Hdc:mount:1:300948:...' is not valid for type unsigned int` — the
`uint32` parameter got the raw hyperlink text, truncated at the first space in
the mount's name.

Staff also see the id and a ready-made grant line in the tooltip when hovering
one of those links in chat: the collection `SMSG_STATS` payload carries a `gm`
flag for `security >= SEC_GAMEMASTER`, which the addon stores as `DC.isGM`.

## Protocol

`SMSG_COLLECTIBLE_GRANTED = 0x6B` (Collection module) supersedes
`SMSG_ITEM_LEARNED = 0x45`. Two payload shapes:

```json
{ "count": 1, "items": [ {"type": 1, "entryId": 48025} ],
  "sourceType": "QUEST", "source": "Quest: Ashes to Ashes" }

{ "syncComplete": true, "spellsTaught": 214, "titlesApplied": 3 }
```

The server still emits the legacy `0x45` per item behind the new push so older
addon builds keep working; a current client suppresses the duplicate for 10
seconds (`DC:WasRecentlyGranted`).

The batched form matters for the account-wide login sync: a burst is one packet
and one UI refresh instead of N pushes each triggering its own
`RequestStats`/`RequestBonuses` round trip. The `syncComplete` form replaced the
old "please relog or /reload to see mounts/companions" chat advice — the client
now just refreshes.

## Deployment

1. Rebuild the worldserver (new source files).
2. Apply `2026_08_11_00_dc_collection_rewards.sql` to the world DB.
3. Redeploy the DC-Collection addon (`Protocol.lua` changed).

The server change works without the addon update — the client simply keeps
handling the legacy `0x45` push.
