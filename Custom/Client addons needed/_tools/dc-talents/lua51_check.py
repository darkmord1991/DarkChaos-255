"""Flag Lua 5.2+ syntax in an addon: the 3.3.5 client runs Lua 5.1, the headless tests run 5.4, so
code the tests accept can still fail to load in game.

Looks (outside strings and comments) for goto / ::labels::, integer division //, the bitwise
operators & | ~ << >>, and inside strings for the \\x \\z \\u{} escapes 5.1 lacks.

Usage: python lua51_check.py [addon dir]      (default: ../../DC-Talents)
"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Talents'))

ESCAPE_52 = re.compile(r'\\x[0-9a-fA-F]|\\z|\\u\{')
CHECKS = [
    (re.compile(r'\bgoto\b'), 'goto'),
    (re.compile(r'::[A-Za-z_]\w*::'), 'label'),
    (re.compile(r'//'), 'integer division'),
    (re.compile(r'&'), 'bitwise and'),
    (re.compile(r'(?<!\|)\|(?!\|)'), 'bitwise or'),
    (re.compile(r'<<|>>'), 'shift'),
    (re.compile(r'~(?!=)'), 'bitwise xor/not'),
]


def strip(source):
    """Code with strings replaced by "" and comments removed; also returns 5.2-only string escapes."""
    out, escapes = [], []
    i, n = 0, len(source)
    while i < n:
        if source.startswith('--', i):
            long = re.match(r'--\[(=*)\[', source[i:])
            if long:
                end = source.find(']' + long.group(1) + ']', i)
                i = n if end < 0 else end + len(long.group(1)) + 2
            else:
                end = source.find('\n', i)
                i = n if end < 0 else end
            continue
        long = re.match(r'\[(=*)\[', source[i:])
        if long:
            end = source.find(']' + long.group(1) + ']', i)
            out.append('""')
            i = n if end < 0 else end + len(long.group(1)) + 2
            continue
        char = source[i]
        if char in '"\'':
            j = i + 1
            body = []
            while j < n and source[j] != char and source[j] != '\n':
                if source[j] == '\\':
                    body.append(source[j:j + 2])
                    j += 2
                    continue
                body.append(source[j])
                j += 1
            text = ''.join(body)
            if ESCAPE_52.search(text):
                escapes.append(source[:i].count('\n') + 1)
            out.append('""')
            i = j + 1
            continue
        out.append(char)
        i += 1
    return ''.join(out), escapes


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    findings = 0
    files = sorted(glob.glob(os.path.join(root, '**', '*.lua'), recursive=True))
    for path in files:
        code, escapes = strip(open(path, encoding='utf-8', errors='replace').read())
        rel = os.path.relpath(path, root)
        for line in escapes:
            print('%s:%d string escape not in Lua 5.1' % (rel, line))
            findings += 1
        for pattern, label in CHECKS:
            for m in pattern.finditer(code):
                print('%s:%d %s' % (rel, code[:m.start()].count('\n') + 1, label))
                findings += 1
    print('%d files, %d Lua 5.2+ findings' % (len(files), findings))
    return 1 if findings else 0


if __name__ == '__main__':
    sys.exit(main())
