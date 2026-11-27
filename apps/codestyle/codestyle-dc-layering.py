#!/usr/bin/env python3
"""DC dependency-layering ratchet.

The DC script tree is layered:

    CrossSystem/CrossSystemCommon.h      <- leaf: stdlib + core only, NO DC includes
    CrossSystem/<everything else>        <- hub: may include core, may orchestrate
    <feature subsystems>                 <- may include the hub, not each other's headers

Two rules keep that from eroding. Both are ratchets, not sweeps: they enforce
"no worse than today", because converting the whole tree at once is not worth
doing as a project.

  DC-LAYER-1  CrossSystemCommon.h must include NO DC subsystem header, ever.
              It is the one header every subsystem can include without creating
              a cycle. The moment it reaches into a feature directory, that
              property is gone for all ~30 of its consumers at once.

  DC-LAYER-2  Header-to-header edges out of CrossSystem into a sibling
              subsystem must not increase. These are what turn a clean
              hub-and-spoke layout into a subsystem cycle. A .cpp in
              CrossSystem including a sibling header is fine and not counted --
              orchestration is allowed to call sideways; headers are not.

Run:  python apps/codestyle/codestyle-dc-layering.py
"""

import os
import re
import sys

DC_ROOT = os.path.join("src", "server", "scripts", "DC")
LEAF_HEADER = os.path.join(DC_ROOT, "CrossSystem", "CrossSystemCommon.h")
HUB = "CrossSystem"

# Header->header edges out of CrossSystem that exist today. This number must go
# DOWN, never up. Each remaining edge and why it is still here:
#
#   CrossSystemWorldBossMgr.h -> AddonExtension/dc_addon_namespace.h
#   CrossSystemUtilities.h    -> ItemUpgrades/ItemUpgradeManager.h   (currency layer)
#   CrossSystemRewards.h      -> Seasons/SeasonalRewardSystem.h
#   SeasonResolver.h          -> Seasons/SeasonalSystem.h
BASELINE_HUB_HEADER_EDGES = 4

INCLUDE_RE = re.compile(r'^[ \t]*#[ \t]*include[ \t]+"([^"]+)"', re.M)


def subsystem_dirs(dc_root):
    return sorted(d for d in os.listdir(dc_root)
                  if os.path.isdir(os.path.join(dc_root, d)))


def build_owner_map(dc_root, subs):
    """basename -> set of owning subsystems."""
    owner = {}
    for sub in subs:
        for root, _, files in os.walk(os.path.join(dc_root, sub)):
            for name in files:
                if name.endswith((".h", ".cpp")):
                    owner.setdefault(name, set()).add(sub)
    return owner


def includes_of(path):
    try:
        with open(path, encoding="utf-8", errors="ignore") as handle:
            return INCLUDE_RE.findall(handle.read())
    except OSError:
        return []


def check_leaf_purity(dc_root, owner, failures):
    if not os.path.exists(LEAF_HEADER):
        failures.append(("DC-LAYER-1", LEAF_HEADER,
                         "leaf header is missing -- the layering contract has no anchor"))
        return

    for inc in includes_of(LEAF_HEADER):
        base = os.path.basename(inc)
        owners = owner.get(base, set())
        # A DC subsystem header, or an explicit DC/ path, both violate the leaf rule.
        if owners - {HUB} or inc.replace("\\", "/").startswith("DC/"):
            failures.append((
                "DC-LAYER-1", LEAF_HEADER,
                'includes DC subsystem header "{}" -- the leaf layer must stay '
                "dependency-free".format(inc)))


def count_hub_header_edges(dc_root, owner):
    """Header->header edges from CrossSystem into any other subsystem."""
    edges = []
    hub_dir = os.path.join(dc_root, HUB)
    for root, _, files in os.walk(hub_dir):
        for name in files:
            if not name.endswith(".h"):
                continue
            path = os.path.join(root, name)
            for inc in includes_of(path):
                if not inc.endswith(".h"):
                    continue
                for target in owner.get(os.path.basename(inc), set()):
                    if target != HUB:
                        edges.append((path, inc, target))
    return edges


def main():
    if not os.path.isdir(DC_ROOT):
        print("DC layering check : Skipped (run from the repository root)")
        return 0

    subs = subsystem_dirs(DC_ROOT)
    owner = build_owner_map(DC_ROOT, subs)

    failures = []
    check_leaf_purity(DC_ROOT, owner, failures)

    edges = count_hub_header_edges(DC_ROOT, owner)
    if len(edges) > BASELINE_HUB_HEADER_EDGES:
        for path, inc, target in sorted(edges):
            print('  {} -> {} ("{}")'.format(path, target, inc))
        failures.append((
            "DC-LAYER-2", os.path.join(DC_ROOT, HUB),
            "CrossSystem now has {} header->sibling-header edges, baseline is {}. "
            "Put the shared piece in CrossSystemCommon.h, or move the dependency "
            "into a .cpp.".format(len(edges), BASELINE_HUB_HEADER_EDGES)))

    if failures:
        for rule, path, message in failures:
            print("{}: {}: {}".format(rule, path, message))
        print("")
        print("DC layering check : Failed ({} violation(s))".format(len(failures)))
        return 1

    if len(edges) < BASELINE_HUB_HEADER_EDGES:
        print("DC layering check : Passed -- CrossSystem header edges down to {} "
              "(baseline {}). Lower BASELINE_HUB_HEADER_EDGES in this script to "
              "lock the improvement in.".format(len(edges), BASELINE_HUB_HEADER_EDGES))
        return 0

    print("DC layering check : Passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
