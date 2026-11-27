"""Convert retail FrameXML (.xml) into Lua data files the DC-Talents template runtime can load.

WoW 3.3.5a cannot parse modern FrameXML: it has no mixin=, parentArray=, relativeKey=, atlas=,
method=, KeyValues, textureSubLevel, inherit="prepend", MaskTexture, Line, ... Instead of hand
translating every template, this script turns each XML file into a Lua table that mirrors the XML
tree one to one (tag, attributes, children), compiles inline script bodies into Lua functions, and
leaves every retail semantic to one interpreter: DC-Talents/Core/Templates.lua.

Re-syncing with a newer retail build is therefore: copy the new XML, rerun this script.

Usage:
    python xml2lua.py <input.xml> <output.lua> [--source-label LABEL]
    python xml2lua.py --batch            (converts every file listed in MANIFEST below)
"""
import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Talents'))
RETAIL = r'K:/Dark-Chaos/WoW 11.2.7 FrameXML'
RETAIL_LABEL = 'retail 11.2.7 (64632)'

# (retail source relative to RETAIL, output relative to the addon folder)
MANIFEST = [
    ('Blizzard_SharedXMLBase/CallbackRegistrant.xml', 'Retail/SharedXMLBase/CallbackRegistrant.xml.lua'),
    ('Blizzard_SharedXML/LayoutFrame.xml', 'Retail/SharedXML/LayoutFrame.xml.lua'),
    ('Blizzard_SharedXML/AnimationTemplates.xml', 'Retail/SharedXML/AnimationTemplates.xml.lua'),
    ('Blizzard_SharedXML/Button/UIButtonTemplate.xml', 'Retail/SharedXML/UIButtonTemplate.xml.lua'),
    ('Blizzard_SharedXML/Button/IconButtonTemplate.xml', 'Retail/SharedXML/IconButtonTemplate.xml.lua'),
    ('Blizzard_SharedXML/SelectableButton.xml', 'Retail/SharedXML/SelectableButton.xml.lua'),
    ('Blizzard_SharedXML/Spinner.xml', 'Retail/SharedXML/Spinner.xml.lua'),
    ('Blizzard_SharedXML/SharedUIPanelTemplates.xml', 'Retail/SharedXML/SharedUIPanelTemplates.xml.lua', [
        '_UI-Frame-TopTileStreaks', 'UIPanelCloseButtonDefaultAnchors', 'NineSliceCodeTemplate', 'NineSlicePanelTemplate',
        'PortraitFrameBaseTemplate', 'PortraitFrameTexturedBaseTemplate', 'PortraitFrameTemplateNoCloseButton',
        'PortraitFrameTemplate',
    ]),
    ('Blizzard_SharedXML/TabSystem/TabSystemOwner.xml', 'Retail/SharedXML/TabSystemOwner.xml.lua'),
    ('Blizzard_SharedXML/TabSystem/TabSystemTemplates.xml', 'Retail/SharedXML/TabSystemTemplates.xml.lua'),
    ('Blizzard_SpellSearch/Blizzard_SpellSearchTemplates.xml', 'Retail/SpellSearch/Blizzard_SpellSearchTemplates.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentEdgeTemplates.xml', 'Retail/SharedTalentUI/Blizzard_SharedTalentEdgeTemplates.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentButtonTemplates.xml', 'Retail/SharedTalentUI/Blizzard_SharedTalentButtonTemplates.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonAnim.xml', 'Retail/SharedTalentUI/Blizzard_TalentButtonAnim.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentDisplay.xml', 'Retail/SharedTalentUI/Blizzard_TalentDisplay.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonArt.xml', 'Retail/SharedTalentUI/Blizzard_TalentButtonArt.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_TalentButtonSelect.xml', 'Retail/SharedTalentUI/Blizzard_TalentButtonSelect.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.xml', 'Retail/SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentFrameTemplates.xml', 'Retail/SharedTalentUI/Blizzard_SharedTalentFrameTemplates.xml.lua'),
    ('Blizzard_SharedTalentUI/Blizzard_SharedTalentFrame.xml', 'Retail/SharedTalentUI/Blizzard_SharedTalentFrame.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutDialogTemplates.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutDialogTemplates.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutImportDialog.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutImportDialog.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutEditDialog.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutEditDialog.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentLoadoutCreateDialog.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentLoadoutCreateDialog.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentButtonTemplates.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentButtonTemplates.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentEdgeTemplates.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentEdgeTemplates.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassTalentsFrame.xml', 'Retail/PlayerSpells/Blizzard_ClassTalentsFrame.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_ClassSpecializationsFrame.xml', 'Retail/PlayerSpells/Blizzard_ClassSpecializationsFrame.xml.lua'),
    ('Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.xml', 'Retail/PlayerSpells/Blizzard_PlayerSpellsFrame.xml.lua'),
]

# Parameter lists for inline script bodies, matching the retail script handler signatures.
SCRIPT_ARGS = {
    'OnLoad': 'self', 'OnShow': 'self', 'OnHide': 'self', 'OnEvent': 'self, event, ...',
    'OnUpdate': 'self, elapsed', 'OnClick': 'self, button, down', 'PreClick': 'self, button, down',
    'PostClick': 'self, button, down', 'OnDoubleClick': 'self, button', 'OnEnter': 'self, motion',
    'OnLeave': 'self, motion', 'OnMouseDown': 'self, button', 'OnMouseUp': 'self, button, upInside',
    'OnMouseWheel': 'self, delta', 'OnDragStart': 'self, button', 'OnDragStop': 'self',
    'OnReceiveDrag': 'self', 'OnSizeChanged': 'self, width, height', 'OnValueChanged': 'self, value, userInput',
    'OnTextChanged': 'self, userInput', 'OnEnterPressed': 'self', 'OnEscapePressed': 'self',
    'OnSpacePressed': 'self', 'OnTabPressed': 'self', 'OnEditFocusGained': 'self', 'OnEditFocusLost': 'self',
    'OnChar': 'self, text', 'OnKeyDown': 'self, key', 'OnKeyUp': 'self, key', 'OnArrowPressed': 'self, key',
    'OnHyperlinkClick': 'self, link, text, button', 'OnHyperlinkEnter': 'self, link, text',
    'OnHyperlinkLeave': 'self', 'OnPlay': 'self', 'OnFinished': 'self, requested', 'OnStop': 'self, requested',
    'OnLoop': 'self, loopState', 'OnPause': 'self', 'OnAttributeChanged': 'self, name, value',
    'OnVerticalScroll': 'self, offset', 'OnHorizontalScroll': 'self, offset',
    'OnScrollRangeChanged': 'self, xrange, yrange', 'OnMinMaxChanged': 'self, min, max',
    'OnCursorChanged': 'self, x, y, w, h', 'OnTextSet': 'self', 'OnEnable': 'self', 'OnDisable': 'self',
}

SCRIPT_TAGS = set(SCRIPT_ARGS)
LUA_KEYWORDS = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local',
    'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}


def lua_string(value):
    out = ['"']
    for ch in value:
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ch == '\n':
            out.append('\\n')
        elif ch == '\r':
            continue
        elif ch == '\t':
            out.append('\\t')
        elif ord(ch) < 32:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return ''.join(out)


def lua_key(name):
    if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name) and name not in LUA_KEYWORDS:
        return name
    return '[%s]' % lua_string(name)


def strip_namespaces(text):
    text = re.sub(r'\sxmlns(:\w+)?="[^"]*"', '', text)
    text = re.sub(r'\sxsi:schemaLocation="[^"]*"', '', text)
    return text


def dedent_script(body):
    lines = body.replace('\r', '').split('\n')
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        return ''
    indent = min(len(l) - len(l.lstrip()) for l in lines if l.strip())
    return '\n'.join(l[indent:] if l.strip() else '' for l in lines)


class Emitter:
    def __init__(self):
        self.out = []

    def emit(self, text):
        self.out.append(text)

    def element(self, el, depth):
        pad = '    ' * depth
        parts = ['tag = %s' % lua_string(el.tag)]
        if el.attrib:
            attrs = ', '.join('%s = %s' % (lua_key(k), lua_string(v)) for k, v in el.attrib.items())
            parts.append('attr = { %s }' % attrs)

        if el.tag in SCRIPT_TAGS:
            body = dedent_script(el.text or '')
            if body:
                args = SCRIPT_ARGS[el.tag]
                fn_pad = pad + '    '
                code = '\n'.join((fn_pad + '    ' + l) if l else '' for l in body.split('\n'))
                parts.append('func = function(%s)\n%s\n%send' % (args, code, fn_pad))
            self.emit('%s{ %s },' % (pad, ', '.join(parts)))
            return

        children = [c for c in el if isinstance(c.tag, str)]
        text = (el.text or '').strip()
        if text and not children and el.tag not in ('Scripts',):
            parts.append('text = %s' % lua_string(text))

        if not children:
            self.emit('%s{ %s },' % (pad, ', '.join(parts)))
            return

        self.emit('%s{ %s, children = {' % (pad, ', '.join(parts)))
        for child in children:
            self.element(child, depth + 1)
        self.emit('%s} },' % pad)


def convert(src_path, dst_path, label, only=None):
    """Converts one XML file. `only` limits the output to the named top-level elements, for files
    such as SharedUIPanelTemplates.xml that also redefine templates 3.3.5 already has."""
    raw = open(src_path, encoding='utf-8-sig').read()
    root = ET.fromstring(strip_namespaces(raw))
    if root.tag != 'Ui':
        raise ValueError('%s: root element is <%s>, expected <Ui>' % (src_path, root.tag))

    em = Emitter()
    rel = os.path.relpath(src_path, RETAIL).replace(os.sep, '/') if src_path.startswith(RETAIL) else os.path.basename(src_path)
    em.emit('-- Generated by _tools/dc-talents/xml2lua.py from %s %s.' % (label, rel))
    em.emit('-- Do not edit by hand: change the converter or the runtime (Core/Templates.lua) and regenerate.')
    em.emit('local _, ns = ...')
    em.emit('setfenv(1, ns.env)')
    em.emit('')

    includes = []
    elements = []
    for child in root:
        if not isinstance(child.tag, str):
            continue
        if child.tag in ('Script', 'Include'):
            includes.append('%s %s' % (child.tag, child.attrib.get('file', '')))
            continue
        if only is not None and child.attrib.get('name') not in only:
            continue
        elements.append(child)
    if only is not None:
        found = {el.attrib.get('name') for el in elements}
        missing = [name for name in only if name not in found]
        if missing:
            raise ValueError('%s: templates not found: %s' % (src_path, ', '.join(missing)))

    for inc in includes:
        em.emit('-- %s (loaded through the TOC)' % inc)
    if includes:
        em.emit('')

    em.emit('ns.XML.Load(%s, {' % lua_string(rel))
    for el in elements:
        em.element(el, 1)
    em.emit('})')
    em.emit('')

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(em.out))
    return len(elements)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('input', nargs='?')
    ap.add_argument('output', nargs='?')
    ap.add_argument('--batch', action='store_true')
    ap.add_argument('--source-label', default=RETAIL_LABEL)
    args = ap.parse_args()

    if args.batch:
        total = 0
        for entry in MANIFEST:
            src, dst = entry[0], entry[1]
            only = entry[2] if len(entry) > 2 else None
            src_path = os.path.join(RETAIL, src)
            dst_path = os.path.join(ADDON, dst)
            count = convert(src_path, dst_path, args.source_label, only)
            total += count
            print('%-70s %3d top-level elements' % (dst, count))
        print('converted %d files, %d top-level elements' % (len(MANIFEST), total))
        return 0

    if not args.input or not args.output:
        ap.error('input and output are required without --batch')
    count = convert(args.input, args.output, args.source_label)
    print('wrote %s (%d top-level elements)' % (args.output, count))
    return 0


if __name__ == '__main__':
    sys.exit(main())
