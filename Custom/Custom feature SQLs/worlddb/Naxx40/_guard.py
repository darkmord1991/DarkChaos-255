"""Disable every statement/row that would modify STOCK WotLK Naxxramas (map 533).

Statement-aware: handles multi-line statements, quote-aware ';' detection, and finds
the OWNER column of an INSERT by name rather than assuming it is the first column.
"""
import re
import sys

STOCK = {
    16156, 16157, 16158, 16211, 16218, 16365, 16381, 16448, 16449, 16451, 16452,
    16453, 16697, 16775, 16776, 16777, 16778, 16861, 16998, 29833, 29941, 15953,
    181056, 193166, 181287, 202277, 202278,
    4156, 5191, 5192, 5193, 5194, 5196, 5197, 5198, 5199,
    12247, 12252, 12258, 12265, 12280, 8507, 8516,
    7222, 7223, 7224, 7225, 7226, 7227, 7228, 7231, 7232, 7233,
    27892, 27893, 27915, 27928, 27929, 27931, 27935, 27936, 27937, 28732,
    16608, 16609, 29273, 22708,
}


def is_module(n):
    return ((351000 <= n <= 351099) or (361000 <= n <= 362999) or n == 352042
            or (3610000 <= n <= 3610999) or (5330000 <= n <= 5330999)
            or (5340000 <= n <= 5340200) or (47850 <= n <= 47870)
            or (90001 <= n <= 90008) or n == 314800)


OWNER = {
    'conditions': ['SourceEntry', 'SourceGroup'],
    'transports': ['entry'],
    # Spawn tables: the row is identified by `guid`. A NEW spawn of a stock template at
    # a module-owned guid does not modify stock, so prefer guid and only fall back to
    # the template id when the INSERT omits guid (auto-assigned).
    'gameobject': ['guid', 'id'],
    'creature': ['guid', 'id'],
    'gameobject_template': ['entry'],
    'gameobject_template_locale': ['entry'],
    'creature_template': ['entry'],
    'creature_template_addon': ['entry'],
    'creature_template_locale': ['entry'],
    'creature_template_model': ['CreatureID'],
    'creature_template_movement': ['CreatureId'],
    'creature_template_resistance': ['CreatureID'],
    'creature_template_spell': ['CreatureID'],
    'creature_text': ['CreatureID'],
    'creature_equip_template': ['CreatureID'],
    'creature_model_info': ['DisplayID'],
    'creature_addon': ['guid'],
    'smart_scripts': ['entryorguid'],
    'gossip_menu': ['MenuID'],
    'gossip_menu_option': ['MenuID'],
    'npc_text': ['ID'],
    'broadcast_text': ['ID'],
    'areatrigger_scripts': ['entry'],
    'areatrigger_teleport': ['ID'],
    'pool_gameobject': ['guid'],
    'pool_template': ['entry'],
    'reference_loot_template': ['Entry'],
    'creature_loot_template': ['Entry'],
    'gameobject_loot_template': ['Entry'],
    'spell_dbc': ['ID'],
    'spell_target_position': ['ID'],
    'waypoint_data': ['id'],
}

# Statements that mention a stock id but are already narrowed to naxx40-owned rows.
SAFE_SCOPED = [
    r'ConditionValue3`?\s+BETWEEN\s+36\d{4}\s+AND\s+36\d{4}',   # Gothik visuals: module trigger guids
    r'guid`?\s+BETWEEN\s+5330\d{3}\s+AND\s+5330\d{3}',          # frozen runes: module GO guids
]

MARK = '-- [DC skip stock-533] '
NOTE = ['-- [DC skip stock-533] would modify STOCK WotLK Naxxramas (map 533) - disabled.',
        '-- See 00_STOCK_533_AUDIT.md. Re-add later as naxx40-owned clones if needed.']
QUOTE = chr(39)


def scan_line(line, inq):
    """Track string state across a line. Handles '' and backslash escapes, and stops
    at an unquoted '--' so apostrophes inside SQL comments do not desync the parser.
    Returns (inq_after, code_part_of_line)."""
    i, code = 0, []
    while i < len(line):
        c = line[i]
        if inq:
            if c == chr(92):                      # backslash escape
                code.append(line[i:i + 2])
                i += 2
                continue
            if c == QUOTE:
                if i + 1 < len(line) and line[i + 1] == QUOTE:
                    code.append(QUOTE + QUOTE)
                    i += 2
                    continue
                inq = False
        else:
            if c == '-' and i + 1 < len(line) and line[i + 1] == '-':
                break                             # rest of the line is a comment
            if c == QUOTE:
                inq = True
        code.append(c)
        i += 1
    return inq, ''.join(code)


def split_statements(text):
    """Yield (kind, lines). kind is 'stmt' for a complete SQL statement, else 'other'."""
    out, buf, inq = [], [], False
    for line in text.split('\n'):
        stripped = line.strip()
        if not buf and (not stripped or stripped.startswith('--')):
            out.append(('other', [line]))
            continue
        buf.append(line)
        inq, code = scan_line(line, inq)
        if not inq and code.rstrip().endswith(';'):
            out.append(('stmt', buf))
            buf = []
    if buf:
        out.append(('stmt', buf))
    return out


def resolve(txt, variables):
    for k, v in sorted(variables.items(), key=lambda kv: -len(kv[0])):
        txt = txt.replace(k, v)
    for _ in range(4):
        txt = re.sub(r'(?<![\w.])(\d{3,9})\s*\+\s*(\d{1,5})(?![\w.])',
                     lambda m: str(int(m.group(1)) + int(m.group(2))), txt)
    return txt


def split_row(row):
    """Split a VALUES tuple body on top-level commas, quote-aware."""
    parts, cur, depth, inq, i = [], '', 0, False, 0
    while i < len(row):
        c = row[i]
        if inq and c == chr(92):          # MySQL backslash escape inside a string
            cur += row[i:i + 2]
            i += 2
            continue
        if c == QUOTE:
            if inq and i + 1 < len(row) and row[i + 1] == QUOTE:
                cur += QUOTE + QUOTE
                i += 2
                continue
            inq = not inq
        if not inq:
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif c == ',' and depth == 0:
                parts.append(cur)
                cur = ''
                i += 1
                continue
        cur += c
        i += 1
    parts.append(cur)
    return [p.strip() for p in parts]


def guard(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    variables, out, n_stmt, n_row = {}, [], 0, 0

    for kind, lines in split_statements(text):
        if kind == 'other':
            out.extend(lines)
            continue

        inq_f, code_lines = False, []
        for l in lines:
            inq_f, code = scan_line(l, inq_f)
            code_lines.append(code)
        flat = ' '.join(' '.join(code_lines).split())

        sv = re.match(r'(?i)^SET\s+(@\w+)\s*:?=\s*(.+?);\s*$', flat)
        if sv:
            val = resolve(sv.group(2), variables)
            try:
                val = str(int(eval(val, {'__builtins__': {}}, {})))
            except Exception:
                pass
            variables[sv.group(1)] = val
            out.extend(lines)
            continue

        if re.match(r'(?i)^(DELETE\s+FROM|UPDATE)\b', flat):
            res = resolve(flat, variables)
            # Already scoped to naxx40-owned rows even though a stock id appears in the
            # WHERE (e.g. the Gothik visual conditions, narrowed by ConditionValue3 to
            # the module's own trigger guids). Leave these alone.
            if any(re.search(pat, res, re.I) for pat in SAFE_SCOPED):
                out.extend(lines)
                continue
            where = re.search(r'(?i)\bWHERE\b(.*)$', res)
            nums = {int(x) for x in re.findall(r'\b(\d{3,9})\b', where.group(1) if where else '')}
            stock_hits = nums & STOCK
            if stock_hits:
                if any(is_module(x) for x in nums):
                    blk = '\n'.join(lines)
                    for sid in sorted(stock_hits):
                        blk = re.sub(r'(?<![\w.@+])' + str(sid) + r'(?![\w.])\s*,\s*', '', blk)
                        blk = re.sub(r',\s*(?<![\w.@+])' + str(sid) + r'(?![\w.])', '', blk)
                    out.append(MARK + 'stock ids removed: ' + ', '.join(map(str, sorted(stock_hits))))
                    out.extend(blk.split('\n'))
                else:
                    out.extend(NOTE)
                    out.extend(MARK + l for l in lines)
                n_stmt += 1
                continue
            out.extend(lines)
            continue

        m = re.match(r'(?i)^INSERT\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?\s*\(([^)]*)\)', flat)
        if m:
            tbl = m.group(1)
            cols = [c.strip().strip('`') for c in m.group(2).split(',')]
            owners = [c for c in OWNER.get(tbl, []) if c in cols]
            if owners:
                idxs = [cols.index(owners[0])]   # first listed present column wins
                kill, keep = [], []
                for i, line in enumerate(lines):
                    s = line.strip()
                    if not s.startswith('('):
                        continue
                    body = s[1:].rstrip(';').rstrip().rstrip(',').rstrip()
                    if body.endswith(')'):
                        body = body[:-1]
                    vals = split_row(body)
                    bad = False
                    for ix in idxs:
                        if ix < len(vals):
                            rv = resolve(vals[ix], variables).strip()
                            mm = re.fullmatch(r'\(?(\d{2,9})\)?', rv)
                            if mm and int(mm.group(1)) in STOCK:
                                bad = True
                    (kill if bad else keep).append(i)
                if kill:
                    if not keep:
                        out.extend(NOTE)
                        out.extend(MARK + l for l in lines)
                        n_stmt += 1
                        continue
                    new = list(lines)
                    for i in kill:
                        new[i] = MARK + new[i]
                    last = max(keep)
                    new[last] = re.sub(r',\s*$', ';', new[last].rstrip())
                    if not new[last].rstrip().endswith(';'):
                        new[last] = new[last].rstrip().rstrip(',') + ';'
                    out.extend(new)
                    n_row += len(kill)
                    continue
        out.extend(lines)

    open(path, 'w', encoding='utf-8', newline='').write('\n'.join(out))
    return n_stmt, n_row


if __name__ == '__main__':
    for p in sys.argv[1:]:
        a, b = guard(p)
        print('  %-30s statements disabled=%-3d rows disabled=%d' % (p, a, b))
