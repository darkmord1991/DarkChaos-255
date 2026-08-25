#!/usr/bin/env python3
"""Static integrity check for the DC client addon suite.

Catches the classes of defect found in the 2026-08 architecture review, so they
fail a build instead of accumulating silently:

  MISSING     a .toc references a file that does not exist  -> addon breaks at login
  ORPHAN      a .lua exists that no .toc or .xml references -> dead code
  DUPKEY      a .toc declares the same directive twice      -> the second silently wins
  NOOP        a .toc uses a directive 3.3.5 does not honour -> ordering that never happens
  TOCNAME     the .toc basename does not match its folder   -> the addon never loads
  POLYFILL    an all-or-nothing shim guard (the C-1 pattern)
  FRAMEXML    an addon replaces a stock 3.3.5 Blizzard global UI-wide

Exit code is non-zero if any error-level finding is present. ORPHAN and
POLYFILL are warnings by default; pass --strict to make them fail too.

usage: python check_addons.py [--strict] [--quiet]
"""
import fnmatch
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Third-party code we vendor but do not own.
VENDORED = re.compile(r'[\\/](Libs?|Libraries|WeakAuras|WeakAurasArchive|Ace3|LibStub|'
                      r'Archivist|LibDeflate|LibCompress)[\\/]', re.I)

# Directives the 3.3.5 client silently ignores. Load order comes only from
# Dependencies / RequiredDeps / OptionalDeps.
NOOP_DIRECTIVES = {
    'loadfirst', 'loadafter', 'loadbefore', 'name', 'load order', 'license',
}

# Directives that must not be repeated: the last one wins, silently.
SINGLE_VALUE = {
    'interface', 'title', 'version', 'author', 'notes',
    'dependencies', 'requireddeps', 'optionaldeps', 'loadondemand',
}

# Shared globals that more than one addon polyfills. Duplication alone is not
# the defect -- an all-or-nothing guard is.
SHARED_GLOBALS = ('C_Timer',)

# The pattern that caused the 2026-08 queue-refresh outage: a shim that claims
# the whole API surface only when the global is entirely absent. Another addon
# loading first with a PARTIAL table makes this block a no-op, so the functions
# it alone provides stay nil for the rest of the session -- silently, because
# every call site is type-guarded.
#
# A shim must fill in each function independently:
#     C_Timer = C_Timer or {}
#     if type(C_Timer.NewTicker) ~= "function" then ... end
ALL_OR_NOTHING = re.compile(
    r'^[ 	]*if[ 	]+not[ 	]+(?:_G\.)?(%s)[ 	]+then[ 	]*$'
    % '|'.join(SHARED_GLOBALS), re.M)


# Globals defined by stock 3.3.5 FrameXML/GlueXML, and the overrides of them
# that have been reviewed. Assigning one of these names replaces Blizzard's
# implementation for the whole UI, for every addon, silently -- so a new one has
# to be diffed against stock and recorded before it is allowed.
STOCK_GLOBALS_FILE = os.path.join(HERE, 'stock_framexml_globals.txt')
OVERRIDES_FILE = os.path.join(HERE, 'framexml_overrides.txt')

# A top-level global definition: `X = ...` or `function X(...)` at column 0.
G_ASSIGN = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
G_FUNC = re.compile(r'^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')


def read(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as fh:
            return fh.read()
    except OSError:
        return ''


def load_name_list(path):
    names = set()
    for line in read(path).splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            names.add(line)
    return names


def is_guarded(lines, i, name):
    """True when this definition only fills a gap rather than replacing."""
    if re.search(r'=\s*' + re.escape(name) + r'\s+or\b', lines[i]):
        return True
    for back in range(1, 6):
        if i - back < 0:
            break
        prev = lines[i - back]
        if re.search(r'if\s+not\s+(?:_G\.)?' + re.escape(name) + r'\b', prev):
            return True
        if re.search(r'if\s+type\s*\(\s*(?:_G\.)?' + re.escape(name) + r'\s*\)', prev):
            return True
    return False


def addon_dirs():
    for name in sorted(os.listdir(HERE)):
        path = os.path.join(HERE, name)
        if not os.path.isdir(path):
            continue
        # An addon folder is one containing a .toc named after it.
        if os.path.isfile(os.path.join(path, name + '.toc')):
            yield name, path, os.path.join(path, name + '.toc')
            continue
        # Tolerate case differences (Windows clients match case-insensitively).
        for entry in os.listdir(path):
            if entry.lower() == (name + '.toc').lower():
                yield name, path, os.path.join(path, entry)
                break


def parse_toc(text):
    """Return (directives, file_entries, allowed_orphans).

    A plain-comment line of the form

        # addon-check: allow-orphan <glob>
        # addon-check: allow-missing-addon <AddOnName>

    marks a file that is deliberately present but not loaded, so the exemption
    is reviewable in the diff rather than invisible. Same idea as the
    `-- sql-ok:` convention the C++ tree uses.
    """
    directives, files, allowed, allow_missing = [], [], [], []
    for raw in text.splitlines():
        line = raw.strip().lstrip('﻿')
        if not line:
            continue
        if line.startswith('##'):
            body = line[2:].strip()
            if ':' in body:
                key, value = body.split(':', 1)
                directives.append((key.strip().lower(), value.strip()))
            continue
        if line.startswith('#'):
            m = re.match(r'#\s*addon-check:\s*allow-orphan\s+(\S+)', line, re.I)
            if m:
                allowed.append(m.group(1).replace('\\', '/'))
                continue
            m = re.match(r'#\s*addon-check:\s*allow-missing-addon\s+(\S+)', line, re.I)
            if m:
                allow_missing.append(m.group(1))
            continue
        files.append(line)
    return directives, files, allowed, allow_missing


def main():
    strict = '--strict' in sys.argv
    quiet = '--quiet' in sys.argv

    errors, warnings = [], []
    polyfills = {}
    framexml_hits = []
    stock_globals = load_name_list(STOCK_GLOBALS_FILE)
    reviewed_overrides = load_name_list(OVERRIDES_FILE)
    if not stock_globals:
        warnings.append('SKIPPED  stock_framexml_globals.txt missing - cannot check for overrides of Blizzard functions')

    for name, path, toc_path in addon_dirs():
        text = read(toc_path)
        directives, entries, allow_orphan, allow_missing = parse_toc(text)

        expected = name + '.toc'
        if os.path.basename(toc_path) != expected:
            warnings.append(
                'TOCNAME  %s: toc is %s, folder is %s (works on Windows, fails on a '
                'case-sensitive host)' % (name, os.path.basename(toc_path), name))

        seen = {}
        for key, value in directives:
            if key in NOOP_DIRECTIVES:
                warnings.append('NOOP     %s/%s: "## %s: %s" is not honoured by 3.3.5'
                                % (name, os.path.basename(toc_path), key, value))
            if key in SINGLE_VALUE:
                if key in seen:
                    errors.append('DUPKEY   %s: "## %s" declared twice (%r then %r) - '
                                  'the second silently wins'
                                  % (name, key, seen[key], value))
                seen[key] = value

        referenced = set()
        for entry in entries:
            rel = entry.replace('\\', os.sep).replace('/', os.sep)
            full = os.path.join(path, rel)
            if not os.path.isfile(full):
                errors.append('MISSING  %s: toc lists %s but it does not exist'
                              % (name, entry))
            referenced.add(os.path.normcase(os.path.basename(rel)))

        # XML files pull in further scripts.
        for dirpath, _, filenames in os.walk(path):
            for fn in filenames:
                if fn.lower().endswith('.xml'):
                    for m in re.finditer(r'file=["\']([^"\']+)["\']',
                                         read(os.path.join(dirpath, fn)), re.I):
                        referenced.add(os.path.normcase(
                            os.path.basename(m.group(1).replace('\\', '/'))))

        # Dynamically loaded companion addons.
        dynamic = set()
        for dirpath, _, filenames in os.walk(path):
            for fn in filenames:
                if not fn.endswith('.lua'):
                    continue
                body = read(os.path.join(dirpath, fn))
                for m in re.finditer(r'LoadAddOn\s*\(\s*["\']([^"\']+)', body):
                    dynamic.add(m.group(1))
                for m in ALL_OR_NOTHING.finditer(body):
                    polyfills.setdefault(m.group(1), []).append(
                        '%s/%s' % (name, os.path.relpath(
                            os.path.join(dirpath, fn), path).replace(os.sep, '/')))

                if stock_globals:
                    rel = os.path.relpath(os.path.join(dirpath, fn),
                                          path).replace(os.sep, '/')
                    body_lines = body.split('\n')
                    for i, ln in enumerate(body_lines):
                        m = G_ASSIGN.match(ln) or G_FUNC.match(ln)
                        if not m:
                            continue
                        gname = m.group(1)
                        if gname not in stock_globals:
                            continue
                        key = '%s/%s' % (name, gname)
                        if key in reviewed_overrides:
                            continue
                        if is_guarded(body_lines, i, gname):
                            continue
                        framexml_hits.append(
                            'FRAMEXML %s: replaces stock 3.3.5 FrameXML global "%s" '
                            '(%s:%d) for the WHOLE UI. Diff it against stock, then '
                            'record the verdict in framexml_overrides.txt.'
                            % (name, gname, rel, i + 1))

        for target in dynamic:
            if target in allow_missing:
                continue
            if not os.path.isdir(os.path.join(HERE, target)):
                warnings.append('MISSING  %s: LoadAddOn("%s") but no such top-level '
                                'addon folder' % (name, target))

        for dirpath, _, filenames in os.walk(path):
            for fn in filenames:
                if not fn.endswith('.lua'):
                    continue
                full = os.path.join(dirpath, fn)
                if VENDORED.search(full):
                    continue
                if os.path.normcase(fn) in referenced:
                    continue
                rel = os.path.relpath(full, path).replace(os.sep, '/')
                if any(fnmatch.fnmatch(rel, pat) for pat in allow_orphan):
                    continue
                warnings.append('ORPHAN   %s/%s: referenced by no toc or xml'
                                % (name, rel))

    errors.extend(framexml_hits)

    for global_name, owners in polyfills.items():
        for owner in sorted(owners):
            errors.append(
                'POLYFILL %s: all-or-nothing guard "if not %s then". A partial %s '
                'installed by an earlier-loading addon makes this a no-op and the '
                'functions it provides stay nil. Guard each function separately.'
                % (owner, global_name, global_name))

    if not quiet:
        for line in errors:
            print('ERROR   ' + line)
        for line in warnings:
            print('warn    ' + line)

    orphans = sum(1 for w in warnings if w.startswith('ORPHAN'))
    print('\n%d error(s), %d warning(s)  [%d orphaned files]'
          % (len(errors), len(warnings), orphans))

    if errors:
        return 1
    if strict and warnings:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
