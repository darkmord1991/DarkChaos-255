"""Extract the 3.3.5 client API for the headless test simulator.

Source: the milkyway-codex dataset (World of Warcraft Programming reference + client 12340), the same
data ACMCP's get_widget / get_event / get_function serve. Output: _tests/wow335_api.lua,
    {
      widgets = { [WidgetType] = { inherits = {...}, methods = {...}, scripts = {...} } },
      events = { "EVENT", ... },
      functions = { "GlobalApiFunction", ... },
      fonts = { "GameFontNormal", ... },
      templates = { [TemplateName] = "Tag", ... },
    }
Widget methods and script handlers include inherited ones; fonts, native templates and the events
the stock UI registers come from the real 3.3.5a FrameXML. The simulator builds its widget types from
this, so a method, script handler or event the 3.3.5 client does not have is missing in the tests too.

Usage: python extract_widget_api.py [--codex DIR]
"""
import argparse
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', '_tests', 'wow335_api.lua'))
DEFAULT_CODEX = r'K:/Dark-Chaos/milkyway-codex'
# The real 3.3.5a (12340) FrameXML: native templates, fonts and the events the stock UI registers.
DEFAULT_FRAMEXML = r'K:/Dark-Chaos/Custom/Client addons needed/Archive/3.3.5-interface-files-main'
# DC-Journal's Sirus SharedXML loads into every DC client and replaces some stock templates globally.
DEFAULT_OVERRIDES = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Journal', 'Interface'))

WIDGET_RE = re.compile(r'^\s{2}\{\s*$')
NAME_RE = re.compile(r'^\s{4}name: "([A-Za-z]+)",')
INHERITS_RE = re.compile(r'^\s{4}inherits: \[(.*)\],')
METHOD_RE = re.compile(r'\{ name: "(?:[^"]*? = )?[A-Za-z]+:([A-Za-z0-9_]+)\(')
SCRIPT_RE = re.compile(r'"name":"(On[A-Za-z]+|PreClick|PostClick)"')
EVENT_RE = re.compile(r"^\s{4}name: '([A-Z0-9_]+)',")
FUNCTION_RE = re.compile(r"^\s{4}name: '([A-Za-z0-9_.]+)',")

# Methods the book documents on some 3.3.5 types but lists under the wrong type, or omits although
# Blizzard's 3.3.5 FrameXML calls them (checked against Archive/3.3.5-interface-files-main).
EXTRA = {
    'Frame': ['HookScript', 'GetEffectiveScale', 'GetScale', 'SetScale'],
    'Texture': ['SetRotation'],
}


def parse(path):
    widgets = {}
    current = None
    section = None
    for line in open(path, encoding='utf-8'):
        match = NAME_RE.match(line)
        if match:
            current = {'name': match.group(1), 'inherits': [], 'methods': set(), 'scripts': set()}
            widgets[current['name']] = current
            section = None
            continue
        if current is None:
            continue
        match = INHERITS_RE.match(line)
        if match:
            current['inherits'] = re.findall(r'"([A-Za-z]+)"', match.group(1))
            continue
        stripped = line.strip()
        if stripped.startswith('methods:') or stripped.startswith('inheritedMethods:'):
            section = 'methods'
            continue
        if stripped.startswith('scriptHandlers:'):
            current['scripts'] |= set(SCRIPT_RE.findall(line))
            section = None
            continue
        if stripped.startswith('category:'):
            section = None
            continue
        if section == 'methods':
            for method in METHOD_RE.findall(line):
                current['methods'].add(method)
    return widgets


def names(path, pattern):
    found = []
    for line in open(path, encoding='utf-8'):
        match = pattern.match(line)
        if match:
            found.append(match.group(1))
    return sorted(set(found))


def lua_list(values, indent):
    lines = []
    for index in range(0, len(values), 6):
        lines.append(indent + ' '.join('"%s",' % value for value in values[index:index + 6]))
    return lines


ELEMENT_RE = re.compile(r'<([A-Za-z]+)\s([^>]*)>')
ATTR_NAME_RE = re.compile(r'\bname="([A-Za-z0-9_]+)"')
REGISTER_EVENT_RE = re.compile(r'RegisterEvent\("([A-Z0-9_]+)"\)')


def scan_framexml(root):
    """Virtual templates (name -> tag), font objects and registered events of the stock 3.3.5 FrameXML."""
    templates, fonts, events = {}, set(), set()
    for folder, _, files in os.walk(root):
        for file in files:
            path = os.path.join(folder, file)
            if file.endswith('.xml'):
                text = open(path, encoding='utf-8', errors='replace').read()
                for tag, attrs in ELEMENT_RE.findall(text):
                    match = ATTR_NAME_RE.search(attrs)
                    if not match:
                        continue
                    if tag == 'Font':
                        fonts.add(match.group(1))
                    elif 'virtual="true"' in attrs:
                        templates[match.group(1)] = tag
                events.update(REGISTER_EVENT_RE.findall(text))
            elif file.endswith('.lua'):
                events.update(REGISTER_EVENT_RE.findall(open(path, encoding='utf-8', errors='replace').read()))
    return templates, sorted(fonts), events


LUA_FUNCTION_RE = re.compile(r'^function\s+([A-Za-z_][A-Za-z0-9_.:]*)\s*\(', re.M)
ONLOAD_CALL_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*self\b')


def lua_function_bodies(roots):
    """Global Lua function name -> body text (from its `function` line to the next column-0 `end`)."""
    bodies = {}
    for root in roots:
        for folder, _, files in os.walk(root):
            for file in files:
                if not file.endswith('.lua'):
                    continue
                text = open(os.path.join(folder, file), encoding='utf-8', errors='replace').read()
                for match in LUA_FUNCTION_RE.finditer(text):
                    end = re.compile(r'^end\b', re.M).search(text, match.end())
                    bodies[match.group(1)] = text[match.start():end.end() if end else len(text)]
    return bodies


def scan_needs_name(roots):
    """Virtual templates whose OnLoad builds names from self:GetName() (directly, or in the function it
    calls with `self`), inheritance included. Later roots replace earlier definitions of a template, as an
    addon's XML replaces the stock template in the client (DC-Journal redefines UIPanelScrollFrameTemplate).
    Creating such a template on an unnamed frame fails in its OnLoad: "attempt to concatenate a nil value"."""
    import xml.etree.ElementTree as ET
    bodies = lua_function_bodies(roots)
    definitions = {}   # template -> (inherits list, own OnLoad uses the name)
    unparsed = 0
    for root in roots:
        for folder, _, files in os.walk(root):
            for file in files:
                if not file.endswith('.xml'):
                    continue
                try:
                    tree = ET.parse(os.path.join(folder, file))
                except ET.ParseError:
                    unparsed += 1
                    continue
                for element in tree.iter():
                    if element.get('virtual') != 'true' or not element.get('name'):
                        continue
                    uses_name = False
                    for scripts in element:
                        if not scripts.tag.endswith('Scripts'):
                            continue
                        for handler in scripts:
                            if not handler.tag.endswith('OnLoad'):
                                continue
                            code = handler.text or ''
                            called = [handler.get('function')] if handler.get('function') else ONLOAD_CALL_RE.findall(code)
                            if 'GetName()' in code or any('GetName()' in bodies.get(name or '', '') for name in called):
                                uses_name = True
                    inherits = [part.strip() for part in (element.get('inherits') or '').split(',') if part.strip()]
                    definitions[element.get('name')] = (inherits, uses_name)

    resolved = {}

    def needs(name, seen=()):
        if name in resolved:
            return resolved[name]
        if name not in definitions or name in seen:
            return False
        inherits, uses_name = definitions[name]
        result = uses_name or any(needs(parent, seen + (name,)) for parent in inherits)
        resolved[name] = result
        return result

    return sorted(name for name in definitions if needs(name)), unparsed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--codex', default=DEFAULT_CODEX)
    ap.add_argument('--framexml', default=DEFAULT_FRAMEXML)
    ap.add_argument('--overrides', default=DEFAULT_OVERRIDES,
                    help="addon UI that replaces stock templates in the live client (DC-Journal's Sirus SharedXML)")
    args = ap.parse_args()
    data = os.path.join(args.codex, 'src', 'data')
    widgets = parse(os.path.join(data, 'widgets.ts'))
    templates, fonts, framexml_events = scan_framexml(args.framexml)
    needs_name, unparsed = scan_needs_name([args.framexml] + ([args.overrides] if os.path.isdir(args.overrides) else []))
    print('  %d templates build part names from self:GetName() in OnLoad (%d XML files unparsable)' % (len(needs_name), unparsed))
    events = sorted(set(names(os.path.join(data, 'events.ts'), EVENT_RE)) | framexml_events)
    functions = names(os.path.join(data, 'api-functions.ts'), FUNCTION_RE)

    # Inherited methods are listed per type, but fold ancestors in as well in case a list is short.
    def all_methods(name, seen=None):
        seen = seen or set()
        if name in seen or name not in widgets:
            return set()
        seen.add(name)
        methods = set(widgets[name]['methods']) | set(EXTRA.get(name, []))
        for parent in widgets[name]['inherits']:
            methods |= all_methods(parent, seen)
        return methods

    def all_scripts(name, seen=None):
        seen = seen or set()
        if name in seen or name not in widgets:
            return set()
        seen.add(name)
        scripts = set(widgets[name]['scripts'])
        for parent in widgets[name]['inherits']:
            scripts |= all_scripts(parent, seen)
        return scripts

    lines = [
        '-- Generated by _tools/dc-talents/extract_widget_api.py from the milkyway-codex dataset',
        '-- (3.3.5 client API). Do not edit by hand.',
        'return {',
        '\twidgets = {',
    ]
    for name in sorted(widgets):
        inherits = ', '.join('"%s"' % parent for parent in widgets[name]['inherits'])
        lines.append('\t\t%s = {' % name)
        lines.append('\t\t\tinherits = { %s },' % inherits)
        lines.append('\t\t\tmethods = {')
        lines.extend(lua_list(sorted(all_methods(name)), '\t\t\t\t'))
        lines.append('\t\t\t},')
        lines.append('\t\t\tscripts = {')
        lines.extend(lua_list(sorted(all_scripts(name)), '\t\t\t\t'))
        lines.append('\t\t\t},')
        lines.append('\t\t},')
    lines.append('\t},')
    lines.append('\tevents = {')
    lines.extend(lua_list(events, '\t\t'))
    lines.append('\t},')
    lines.append('\tfunctions = {')
    lines.extend(lua_list(functions, '\t\t'))
    lines.append('\t},')
    lines.append('\tfonts = {')
    lines.extend(lua_list(fonts, '\t\t'))
    lines.append('\t},')
    lines.append('\t-- Templates whose OnLoad builds part names from self:GetName() (stock + DC-Journal overrides).')
    lines.append('\tneedsName = {')
    lines.extend(lua_list(needs_name, '\t\t'))
    lines.append('\t},')
    lines.append('\ttemplates = {')
    for name in sorted(templates):
        lines.append('\t\t["%s"] = "%s",' % (name, templates[name]))
    lines.append('\t},')
    lines.append('}')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(lines) + '\n')
    print('wrote %s: %d widget types, %d events, %d functions, %d fonts, %d templates' % (
        OUT, len(widgets), len(events), len(functions), len(fonts), len(templates)))
    for name in ('Frame', 'Button', 'Texture', 'FontString', 'GameTooltip', 'EditBox', 'AnimationGroup'):
        if name in widgets:
            print('  %-14s %3d methods' % (name, len(all_methods(name))))


if __name__ == '__main__':
    main()
