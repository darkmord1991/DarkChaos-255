"""Vendor the retail talent UI into DC-Talents (the single entry point for re-syncing with retail).

Steps:
  1. Copy every retail Lua file in LUA_MANIFEST into DC-Talents/Retail/..., unchanged except for a
     prelude on LINE 1 ("local _, ns = ...; setfenv(1, ns.env); <original line 1>") so line numbers in
     error messages still match Blizzard's source.
  2. Convert the retail XML files (xml2lua.MANIFEST) into Lua data for Core/Templates.lua.
  3. Generate DC-Talents/Data/RetailData.lua: the Enum / Constants tables, global strings, colours and
     SOUNDKIT ids that the vendored code (and our DC layer) references, taken from the retail API
     documentation, Helix/GlobalStrings.lua, Helix/GlobalColors.lua and SoundKitConstants.

DC changes never edit the vendored files; they live in DC-Talents/DC/ (mixin overrides, stand-ins for
retail systems we do not port, the C_Traits emulation). So a new retail build is: point RETAIL at the
new extract, rerun this script, run the headless tests, fix what the DC layer needs.

Usage: python sync_retail.py [--retail DIR] [--data-only | --toc-only]
"""
import argparse
import glob
import os
import re
import sys

import xml2lua

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Talents'))
DEFAULT_RETAIL = xml2lua.RETAIL

PRELUDE = 'local _, ns = ...; setfenv(1, ns.env); '

LUA_MANIFEST = [
    # Blizzard_SharedXMLBase
    ('Blizzard_SharedXMLBase/Mixin.lua', 'Retail/SharedXMLBase/Mixin.lua'),
    ('Blizzard_SharedXMLBase/TableUtil.lua', 'Retail/SharedXMLBase/TableUtil.lua'),
    ('Blizzard_SharedXMLBase/EnumUtil.lua', 'Retail/SharedXMLBase/EnumUtil.lua'),
    ('Blizzard_SharedXMLBase/FunctionUtil.lua', 'Retail/SharedXMLBase/FunctionUtil.lua'),
    ('Blizzard_SharedXMLBase/MathUtil.lua', 'Retail/SharedXMLBase/MathUtil.lua'),
    ('Blizzard_SharedXMLBase/ExportUtil.lua', 'Retail/SharedXMLBase/ExportUtil.lua'),
    ('Blizzard_SharedXMLBase/TextureUtil.lua', 'Retail/SharedXMLBase/TextureUtil.lua'),
    ('Blizzard_SharedXMLBase/Flags.lua', 'Retail/SharedXMLBase/Flags.lua'),
    ('Blizzard_SharedXMLBase/CallbackRegistry.lua', 'Retail/SharedXMLBase/CallbackRegistry.lua'),
    ('Blizzard_SharedXMLBase/CallbackRegistrant.lua', 'Retail/SharedXMLBase/CallbackRegistrant.lua'),
    ('Blizzard_SharedXMLBase/GlobalCallbackRegistry.lua', 'Retail/SharedXMLBase/GlobalCallbackRegistry.lua'),
    ('Blizzard_SharedXMLBase/CvarUtil.lua', 'Retail/SharedXMLBase/CvarUtil.lua'),
    ('Blizzard_SharedXMLBase/FrameUtil.lua', 'Retail/SharedXMLBase/FrameUtil.lua'),
    ('Blizzard_SharedXMLBase/Color.lua', 'Retail/SharedXMLBase/Color.lua'),
    # Blizzard_SharedXML (toc order)
    ('Blizzard_SharedXML/LinkUtil.lua', 'Retail/SharedXML/LinkUtil.lua'),
    ('Blizzard_SharedXML/StringUtil.lua', 'Retail/SharedXML/StringUtil.lua'),
    ('Blizzard_SharedXML/UnitUtil.lua', 'Retail/SharedXML/UnitUtil.lua'),
    ('Blizzard_SharedXML/EventUtil.lua', 'Retail/SharedXML/EventUtil.lua'),
    ('Blizzard_SharedXML/RegionUtil.lua', 'Retail/SharedXML/RegionUtil.lua'),
    ('Blizzard_SharedXML/AnchorUtil.lua', 'Retail/SharedXML/AnchorUtil.lua'),
    ('Blizzard_SharedXML/GridLayoutUtil.lua', 'Retail/SharedXML/GridLayoutUtil.lua'),
    ('Blizzard_SharedXML/LayoutFrame.lua', 'Retail/SharedXML/LayoutFrame.lua'),
    ('Blizzard_SharedXML/SelectableButton.lua', 'Retail/SharedXML/SelectableButton.lua'),
    ('Blizzard_SharedXML/ButtonGroup.lua', 'Retail/SharedXML/ButtonGroup.lua'),
    ('Blizzard_SharedXML/Button/UIButtonTemplate.lua', 'Retail/SharedXML/UIButtonTemplate.lua'),
    ('Blizzard_SharedXML/Button/IconButtonTemplate.lua', 'Retail/SharedXML/IconButtonTemplate.lua'),
    ('Blizzard_SharedXML/MixinUtil.lua', 'Retail/SharedXML/MixinUtil.lua'),
    ('Blizzard_SharedXML/AnimationTemplates.lua', 'Retail/SharedXML/AnimationTemplates.lua'),
    ('Blizzard_SharedXML/Spinner.lua', 'Retail/SharedXML/Spinner.lua'),
    ('Blizzard_SharedXML/NineSlice.lua', 'Retail/SharedXML/NineSlice.lua'),
    ('Blizzard_SharedXML/NineSliceLayouts.lua', 'Retail/SharedXML/NineSliceLayouts.lua'),
    ('Blizzard_SharedXML/PortraitFrame.lua', 'Retail/SharedXML/PortraitFrame.lua'),
    ('Blizzard_SharedXML/TabSystem/TabSystemOwner.lua', 'Retail/SharedXML/TabSystemOwner.lua'),
    ('Blizzard_SharedXML/TabSystem/TabSystemTemplates.lua', 'Retail/SharedXML/TabSystemTemplates.lua'),
    ('Blizzard_SharedXML/LoadSystem/LoadSystemTemplates.lua', 'Retail/SharedXML/LoadSystemTemplates.lua'),
    ('Blizzard_SharedXML/InputBox/InputBoxTemplates.lua', 'Retail/SharedXML/InputBoxTemplates.lua'),
    # Blizzard_SpellSearch (toc order)
    ('Blizzard_SpellSearch/Blizzard_SpellSearchUtil.lua', 'Retail/SpellSearch/Blizzard_SpellSearchUtil.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchSource.lua', 'Retail/SpellSearch/Blizzard_SpellSearchSource.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchFilter.lua', 'Retail/SpellSearch/Blizzard_SpellSearchFilter.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchTextFilter.lua', 'Retail/SpellSearch/Blizzard_SpellSearchTextFilter.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchNameFilter.lua', 'Retail/SpellSearch/Blizzard_SpellSearchNameFilter.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchActionBarFilter.lua', 'Retail/SpellSearch/Blizzard_SpellSearchActionBarFilter.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchAssistedCombatFilter.lua', 'Retail/SpellSearch/Blizzard_SpellSearchAssistedCombatFilter.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchController.lua', 'Retail/SpellSearch/Blizzard_SpellSearchController.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchTemplates.lua', 'Retail/SpellSearch/Blizzard_SpellSearchTemplates.lua'),
    # Blizzard_SharedTalentUI (toc order, minus armor sets / red buttons / cards / list+grid frames)
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentUtil.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentUtil.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentEdgeTemplates.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentEdgeTemplates.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentButtonTemplates.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentButtonTemplates.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonAnimUtil.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonAnimUtil.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonAnim.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonAnim.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentDisplay.lua', 'Retail/SharedTalentUI/Blizzard_TalentDisplay.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonArt.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonArt.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonBase.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonBase.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonSpend.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonSpend.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonSelect.lua', 'Retail/SharedTalentUI/Blizzard_TalentButtonSelect.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentFrameTemplates.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentFrameTemplates.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.lua', 'Retail/SharedTalentUI/Blizzard_SharedTalentFrame.lua'),
    # Blizzard_PlayerSpells (talents, loadouts, specialization tab, host frame)
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentUtil.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentUtil.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutDialogTemplates.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutDialogTemplates.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentImportExport.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentImportExport.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutImportDialog.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutImportDialog.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutEditDialog.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutEditDialog.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutCreateDialog.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutCreateDialog.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentButtonTemplates.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentButtonTemplates.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentEdgeTemplates.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentEdgeTemplates.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentSearch.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentSearch.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentsFrame.lua', 'Retail/PlayerSpells/Blizzard_ClassTalentsFrame.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassSpecializationsFrame.lua', 'Retail/PlayerSpells/Blizzard_ClassSpecializationsFrame.lua'),
    ('Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua', 'Retail/PlayerSpells/Blizzard_PlayerSpellsFrame.lua'),
]

# XML files additionally converted by this script (on top of xml2lua.MANIFEST).
EXTRA_XML = [
    ('Blizzard_SharedXML/Spinner.xml', 'Retail/SharedXML/Spinner.xml.lua'),
    ('Blizzard_SharedXML/LoadSystem/LoadSystemTemplates.xml', 'Retail/SharedXML/LoadSystemTemplates.xml.lua'),
    # Only the two search-box templates: InputBoxTemplate itself stays the stock 3.3.5 one.
    ('Blizzard_SharedXML/InputBox/InputBoxTemplates.xml', 'Retail/SharedXML/InputBoxTemplates.xml.lua',
        ['InputBoxInstructionsTemplate', 'SearchBoxTemplate']),
]


# ----------------------------------------------------------------------------
# DC-Talents.toc (generated: the vendored file list and its order come from the manifests above)
# ----------------------------------------------------------------------------

TOC_HEADER = [
    '## Interface: 30300',
    '## Title: |cffFFCC00DC|r Talents',
    '## Notes: The retail talent window (11.2.7) for Dark Chaos: three trees side by side, loadouts,|nfree respecs through the DC server module.',
    '## Author: DarkChaos Development Team',
    '## Version: 1.0.0',
    '## Dependencies: DC-AddonProtocol',
    '## OptionalDeps: DC-QOS, DC-Welcome',
    '## SavedVariables: DCTalentsDB',
    '## SavedVariablesPerCharacter: DCTalentsCharDB',
    '',
    '# Generated by _tools/dc-talents/sync_retail.py; edit TOC_LAYOUT there, not this file.',
]

# 'retail:<Folder>' expands to that folder's vendored Lua files in LUA_MANIFEST order, each followed
# by its converted XML. '#' lines become comments.
TOC_LAYOUT = [
    '# Runtime: private environment, retail data, the retail widget API on 3.3.5',
    'Core/Env.lua', 'Data/RetailData.lua', 'Core/RetailAPI.lua', 'Core/Engine.lua', 'Core/Line.lua',
    'Core/Animations.lua', 'Core/Templates.lua',
    'Data/AtlasInfo.lua', 'Data/AtlasExtra.lua', 'Data/TalentData.lua', 'Core/Atlas.lua',
    '# Retail shared code',
    'retail:SharedXMLBase',
    'Core/Pools.lua',
    'retail:SharedXML',
    '# DC stand-ins for retail systems that are not ported (SpellSearch reads them while loading)',
    'DC/Locale.lua', 'DC/Early.lua', 'DC/Standins.lua',
    'retail:SpellSearch',
    '# The C_Traits layer (it must exist before SharedTalentUtil wraps C_Traits at load)',
    'DC/Layout.lua', 'DC/Traits.lua', 'DC/Loadouts.lua', 'DC/Server.lua',
    '# Retail talent UI',
    'retail:SharedTalentUI',
    'retail:PlayerSpells',
    '# DC overrides, the pet tab and the window',
    'DC/Overrides.lua', 'DC/PetTalents.lua', 'DC/Frame.lua',
]

# Converted XML without a Lua file of its own -> the vendored file it loads after.
XML_ONLY_AFTER = {
    'Retail/SharedXML/SharedUIPanelTemplates.xml.lua': 'Retail/SharedXML/PortraitFrame.lua',
}


def toc_lines():
    xml_outputs = [entry[1] for entry in xml2lua.MANIFEST] + [entry[1] for entry in EXTRA_XML]
    lua_outputs = [dst for _, dst in LUA_MANIFEST]
    lua_set = set(lua_outputs)
    xml_for_lua = {}
    after = {}
    for xml in xml_outputs:
        lua = xml[:-len('.xml.lua')] + '.lua'
        if lua in lua_set:
            xml_for_lua[lua] = xml
        elif xml in XML_ONLY_AFTER:
            after.setdefault(XML_ONLY_AFTER[xml], []).append(xml)
        else:
            raise SystemExit('%s has no Lua file and no XML_ONLY_AFTER entry' % xml)

    lines = list(TOC_HEADER)
    for item in TOC_LAYOUT:
        if item.startswith('#'):
            lines.extend(['', item])
        elif item.startswith('retail:'):
            folder = 'Retail/%s/' % item.split(':', 1)[1]
            for lua in lua_outputs:
                if lua.startswith(folder):
                    lines.append(lua)
                    if lua in xml_for_lua:
                        lines.append(xml_for_lua[lua])
                    lines.extend(after.get(lua, []))
        else:
            lines.append(item)

    missing = [line for line in lines if line and not line.startswith('#')
               and not os.path.exists(os.path.join(ADDON, line))]
    if missing:
        raise SystemExit('TOC entries without a file: ' + ', '.join(missing))
    listed = {line for line in lines if line.endswith('.lua')}
    unlisted = []
    for path in glob.glob(os.path.join(ADDON, '**', '*.lua'), recursive=True):
        rel = os.path.relpath(path, ADDON).replace(os.sep, '/')
        if rel not in listed:
            unlisted.append(rel)
    if unlisted:
        print('  not in the TOC (intended?):', ' '.join(sorted(unlisted)))
    return [line if line.startswith('#') else line.replace('/', '\\') for line in lines]


def write_toc():
    lines = toc_lines()
    with open(os.path.join(ADDON, 'DC-Talents.toc'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')
    return sum(1 for line in lines if line and not line.startswith('#'))


def vendor_lua(retail):
    count = 0
    for src, dst in LUA_MANIFEST:
        src_path = os.path.join(retail, src)
        dst_path = os.path.join(ADDON, dst)
        text = open(src_path, encoding='utf-8-sig').read().replace('\r\n', '\n')
        lines = text.split('\n')
        lines[0] = PRELUDE + lines[0]
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        with open(dst_path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write('\n'.join(lines))
        count += 1
    return count


def convert_xml(retail):
    manifest = list(xml2lua.MANIFEST)
    for extra in EXTRA_XML:
        if extra not in manifest:
            manifest.append(extra)
    for entry in manifest:
        only = entry[2] if len(entry) > 2 else None
        xml2lua.convert(os.path.join(retail, entry[0]), os.path.join(ADDON, entry[1]), xml2lua.RETAIL_LABEL, only)
    return len(manifest)


# ---------------------------------------------------------------------------------------------
# Retail data (Enum / Constants / strings / colours / sound kits)
# ---------------------------------------------------------------------------------------------

def lua_string(value):
    return xml2lua.lua_string(value)


def collect_references():
    """Identifiers referenced by every Lua file of the addon (vendored + generated + DC layer)."""
    enums, consts, soundkits, caps = set(), set(), set(), set()
    for path in glob.glob(os.path.join(ADDON, '**', '*.lua'), recursive=True):
        if os.path.basename(path) == 'RetailData.lua':
            continue
        text = open(path, encoding='utf-8', errors='replace').read()
        text = re.sub(r'--\[(=*)\[.*?\]\1\]', '', text, flags=re.S)
        for m in re.finditer(r'\bEnum\.([A-Za-z0-9_]+)', text):
            enums.add(m.group(1))
        for m in re.finditer(r'\bConstants\.([A-Za-z0-9_]+)', text):
            consts.add(m.group(1))
        for m in re.finditer(r'\bSOUNDKIT\.([A-Za-z0-9_]+)', text):
            soundkits.add(m.group(1))
        for m in re.finditer(r'\b([A-Z][A-Z0-9_]{3,})\b', text):
            caps.add(m.group(1))
        # Global strings referenced from converted XML (text= / KeyValue global values).
        for m in re.finditer(r'(?:text|value) = "([A-Z][A-Z0-9_]{3,})"', text):
            caps.add(m.group(1))
    return enums, consts, soundkits, caps


def parse_api_docs(retail):
    """All Enumeration and Constants tables from Blizzard_APIDocumentationGenerated."""
    enums, constants = {}, {}
    for path in glob.glob(os.path.join(retail, 'Blizzard_APIDocumentationGenerated', '*.lua')):
        src = open(path, encoding='utf-8', errors='replace').read()
        for m in re.finditer(r'Name = "(\w+)",\s*Type = "Enumeration",(.*?)\n\t\t\},', src, re.S):
            name, body = m.groups()
            values = re.findall(r'\{ Name = "(\w+)", Type = "\w+", EnumValue = (-?\d+)', body)
            if values:
                enums[name] = values
        for m in re.finditer(r'Name = "(\w+)",\s*Type = "Constants",(.*?)\n\t\t\},', src, re.S):
            name, body = m.groups()
            values = re.findall(r'\{ Name = "(\w+)", Type = "\w+", Value = ([^ ]+) \}', body)
            if values:
                constants[name] = values
    return enums, constants


def parse_global_strings(retail):
    strings = {}
    path = os.path.join(retail, 'Helix', 'GlobalStrings.lua')
    for line in open(path, encoding='utf-8', errors='replace'):
        m = re.match(r'^([A-Z][A-Z0-9_]*) = "(.*)";?\s*$', line.rstrip('\n'))
        if m:
            strings[m.group(1)] = m.group(2)
    return strings


# The real 3.3.5a GlobalStrings.lua (the archive extract_widget_api.py also reads).
STOCK_GLOBALSTRINGS = r'K:/Dark-Chaos/Custom/Client addons needed/Archive/3.3.5-interface-files-main/GlobalStrings.lua'


def parse_stock_global_strings():
    strings = {}
    if not os.path.exists(STOCK_GLOBALSTRINGS):
        print('  warning: stock GlobalStrings.lua not found; every retail string is emitted')
        return strings
    for line in open(STOCK_GLOBALSTRINGS, encoding='utf-8', errors='replace'):
        m = re.match(r'^([A-Z][A-Z0-9_]*)\s*=\s*"(.*)";?\s*$', line.rstrip('\n'))
        if m:
            strings[m.group(1)] = m.group(2)
    return strings


def parse_global_colors(retail):
    colors = {}
    path = os.path.join(retail, 'Helix', 'GlobalColors.lua')
    if not os.path.exists(path):
        return colors
    text = open(path, encoding='utf-8', errors='replace').read()
    # NAME_CODE, NAME = "|cffrrggbb", CreateColor(r, g, b, a)
    pattern = r'^([A-Z0-9_]+)_CODE, ([A-Z0-9_]+) = "(\|c[0-9A-Fa-f]{8})", CreateColor\(([^)]*)\)'
    for m in re.finditer(pattern, text, re.M):
        colors[m.group(2)] = {'code': m.group(3), 'rgba': [p.strip() for p in m.group(4).split(',')]}
    return colors


def parse_soundkits(retail):
    kits = {}
    for path in glob.glob(os.path.join(retail, '**', 'SoundKitConstants.lua'), recursive=True):
        for m in re.finditer(r'^\s*([A-Z0-9_]+)\s*=\s*(\d+),?', open(path, encoding='utf-8', errors='replace').read(), re.M):
            kits[m.group(1)] = m.group(2)
    return kits


def generate_data(retail):
    enum_refs, const_refs, soundkit_refs, caps = collect_references()
    enums, constants = parse_api_docs(retail)
    strings = parse_global_strings(retail)
    colors = parse_global_colors(retail)
    soundkits = parse_soundkits(retail)

    out = [
        '-- Generated by _tools/dc-talents/sync_retail.py from %s: API documentation Enum/Constants,' % xml2lua.RETAIL_LABEL,
        '-- Helix/GlobalStrings.lua, Helix/GlobalColors.lua and SoundKitConstants, limited to what the addon references.',
        '-- Do not edit by hand; rerun the script. Everything lands in the private environment, never in _G.',
        'local _, ns = ...',
        'setfenv(1, ns.env)',
        '',
        'Enum = Enum or {}',
    ]
    missing_enums = []
    for name in sorted(enum_refs):
        if name in enums:
            values = ', '.join('%s = %s' % (xml2lua.lua_key(k), v) for k, v in enums[name])
            out.append('Enum.%s = Enum.%s or { %s }' % (name, name, values))
        else:
            missing_enums.append(name)

    # Retail generates Enum.<Name>Meta = { MinValue, MaxValue, NumValues } for every enum; constants
    # and code reference them, so derive the ones in use from the base enum.
    meta_refs = {name[:-4] for name in enum_refs if name.endswith('Meta')}
    for name in const_refs:
        for _, value in constants.get(name, []):
            for m in re.finditer(r'Enum\.(\w+)Meta\.', value):
                meta_refs.add(m.group(1))
    for base in sorted(meta_refs):
        if base in enums:
            if base not in enum_refs:
                values = ', '.join('%s = %s' % (xml2lua.lua_key(k), v) for k, v in enums[base])
                out.append('Enum.%s = Enum.%s or { %s }' % (base, base, values))
            numbers = [int(v) for _, v in enums[base]]
            out.append('Enum.%sMeta = Enum.%sMeta or { MinValue = %d, MaxValue = %d, NumValues = %d }' % (
                base, base, min(numbers), max(numbers), len(numbers)))
            missing_enums = [e for e in missing_enums if e != base + 'Meta']

    out.append('')
    out.append('Constants = Constants or {}')
    missing_consts = []
    for name in sorted(const_refs):
        if name in constants:
            values = ', '.join('%s = %s' % (xml2lua.lua_key(k), v) for k, v in constants[name])
            out.append('Constants.%s = Constants.%s or { %s }' % (name, name, values))
        else:
            missing_consts.append(name)

    out.append('')
    out.append('SOUNDKIT = SOUNDKIT or {}')
    for name in sorted(soundkit_refs):
        if name in soundkits:
            out.append('SOUNDKIT.%s = %s' % (name, soundkits[name]))

    out.append('')
    out.append('-- Retail global strings used by the port that the 3.3.5 client lacks (or words differently),')
    out.append('-- visible inside our environment only. Strings stock 3.3.5 has with the same enUS text are left')
    out.append("-- out, so lookups fall through to the client's own, localized, copy.")
    stock = parse_stock_global_strings()
    string_count = 0
    skipped_stock = 0
    for name in sorted(caps):
        if name in strings:
            if stock.get(name) == strings[name]:
                skipped_stock += 1
                continue
            value = strings[name].encode('utf-8').decode('unicode_escape', errors='ignore') if '\\' in strings[name] else strings[name]
            out.append('%s = %s' % (name, lua_string(value)))
            string_count += 1

    out.append('')
    out.append('-- Retail named colours (Helix/GlobalColors.lua) used by the port. The vendored Color.lua turns')
    out.append('-- them into ColorMixins through C_UIColor.GetColors (Core/RetailAPI.lua) when it loads.')
    out.append('ns.RetailColorDefinitions = {')
    color_count = 0
    wanted = set(caps)
    wanted |= {name[:-5] for name in caps if name.endswith('_CODE')}
    for name in sorted(wanted):
        if name in colors:
            rgba = colors[name]['rgba']
            out.append('    { %s, %s, %s },' % (lua_string(name), lua_string(colors[name]['code']), ', '.join(rgba)))
            color_count += 1
    out.append('}')
    out.append('')

    path = os.path.join(ADDON, 'Data', 'RetailData.lua')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(out))

    print('RetailData.lua: %d enums, %d constants, %d soundkits, %d strings (%d left to the stock client), %d colours' % (
        len(enum_refs) - len(missing_enums), len(const_refs) - len(missing_consts), len(soundkit_refs), string_count,
        skipped_stock, color_count))
    if missing_enums:
        print('  enums referenced but not in the API docs (DC must define them):', ' '.join(missing_enums))
    if missing_consts:
        print('  constants referenced but not in the API docs:', ' '.join(missing_consts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--retail', default=DEFAULT_RETAIL)
    ap.add_argument('--data-only', action='store_true')
    ap.add_argument('--toc-only', action='store_true')
    args = ap.parse_args()

    if args.toc_only:
        print('wrote DC-Talents.toc (%d files)' % write_toc())
        return 0
    if not args.data_only:
        print('vendored %d Lua files' % vendor_lua(args.retail))
        print('converted %d XML files' % convert_xml(args.retail))
    generate_data(args.retail)
    print('wrote DC-Talents.toc (%d files)' % write_toc())
    return 0


if __name__ == '__main__':
    sys.exit(main())
