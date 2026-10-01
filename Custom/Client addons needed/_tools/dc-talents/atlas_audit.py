"""List atlases DC-Talents references that Data/AtlasInfo.lua does not ship, grouped by retail sheet.

Static references only: atlas="..." in converted XML, SetAtlas("...") / *Atlas = "..." in Lua, and
"talents-..." style literals. Dynamic names built with format strings are listed separately.
Usage: python atlas_audit.py [--all]   (--all also lists the covered sheets)
"""
import argparse
import glob
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Talents'))
ATLAS_SOURCE = r'K:/Dark-Chaos/WoW 11.2.7 FrameXML/Helix/AtlasInfo.lua'


def load_retail_atlases():
    atlas_to_sheet = {}
    sheet = None
    for line in open(ATLAS_SOURCE, encoding='utf-8', errors='replace'):
        m = re.match(r'\s*\["(Interface/[^"]+)"\]=\{', line)
        if m:
            sheet = m.group(1)
            continue
        m = re.match(r'\s*\["([^"]+)"\]=\{', line)
        if m and sheet:
            atlas_to_sheet[m.group(1).lower()] = (sheet, m.group(1))
    return atlas_to_sheet


def load_shipped():
    path = os.path.join(ADDON, 'Data', 'AtlasInfo.lua')
    shipped = set()
    if os.path.exists(path):
        for m in re.finditer(r'^\s*\["([^"]+)"\] = \{ "Interface', open(path, encoding='utf-8').read(), re.M):
            shipped.add(m.group(1).lower())
    return shipped


def collect_references(retail):
    names, dynamic = set(), set()
    for path in glob.glob(os.path.join(ADDON, '**', '*.lua'), recursive=True):
        if os.path.basename(path) == 'AtlasInfo.lua':
            continue
        text = open(path, encoding='utf-8', errors='replace').read()
        for pattern in (r'atlas = "([^"]+)"', r'Atlas\(\s*"([^"]+)"', r'[Aa]tlas\w*\s*=\s*"([^"]+)"',
                        r'value = "([a-z_!][A-Za-z0-9_\-!]+)", type = "string"'):
            for m in re.finditer(pattern, text):
                names.add(m.group(1))
        for m in re.finditer(r'"([A-Za-z0-9_!\-]*%[sd][A-Za-z0-9_!\-%]*)"', text):
            dynamic.add(m.group(1))
    return {n for n in names if n.lower() in retail}, dynamic


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true')
    args = ap.parse_args()

    retail = load_retail_atlases()
    shipped = load_shipped()
    names, dynamic = collect_references(retail)

    missing_by_sheet, covered_by_sheet = {}, {}
    for name in sorted(names, key=str.lower):
        sheet, canonical = retail[name.lower()]
        bucket = covered_by_sheet if name.lower() in shipped else missing_by_sheet
        bucket.setdefault(sheet, []).append(canonical)

    print('referenced atlases: %d, shipped: %d, missing: %d' % (
        len(names), sum(len(v) for v in covered_by_sheet.values()), sum(len(v) for v in missing_by_sheet.values())))
    for sheet, atlases in sorted(missing_by_sheet.items(), key=lambda kv: -len(kv[1])):
        print('  MISSING %-62s %3d  %s' % (sheet, len(atlases), ', '.join(atlases[:6]) + (' ...' if len(atlases) > 6 else '')))
    if args.all:
        for sheet, atlases in sorted(covered_by_sheet.items()):
            print('  ok      %-62s %3d' % (sheet, len(atlases)))
    if dynamic:
        print('dynamic atlas patterns (check by hand):', ' | '.join(sorted(dynamic)))


if __name__ == '__main__':
    main()
