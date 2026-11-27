"""Validate the guarded SQL: no stock-533 writes left, and every live statement parses."""
import re
import sys

sys.path.insert(0, '.')
from _guard import STOCK, OWNER, split_statements, resolve, split_row, QUOTE, scan_line


def check(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    live = '\n'.join(l for l in text.split('\n')
                     if l.strip() and not l.strip().startswith('--'))
    variables = {}
    bad_du, bad_ins, bad_syn = [], [], []

    for kind, lines in split_statements(live):
        if kind == 'other':
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
            continue

        # syntax: must start with a statement keyword, end with ';', balanced parens & quotes
        if not re.match(r'(?i)^(INSERT|DELETE|UPDATE|REPLACE|SET|ALTER|DROP|CREATE)\b', flat):
            bad_syn.append(('does not start with a keyword', flat[:110]))
        if not flat.rstrip().endswith(';'):
            bad_syn.append(('unterminated', flat[:110]))
        depth = 0
        inq2, i = False, 0
        while i < len(flat):
            c = flat[i]
            if inq2:
                if c == chr(92):
                    i += 2
                    continue
                if c == QUOTE:
                    if i + 1 < len(flat) and flat[i + 1] == QUOTE:
                        i += 2
                        continue
                    inq2 = False
            else:
                if c == QUOTE:
                    inq2 = True
                elif c == '(':
                    depth += 1
                elif c == ')':
                    depth -= 1
            i += 1
        if depth != 0 or inq2:
            bad_syn.append(('unbalanced parens=%d quote_open=%s' % (depth, inq2), flat[:110]))

        if re.match(r'(?i)^(DELETE\s+FROM|UPDATE)\b', flat):
            res = resolve(flat, variables)
            w = re.search(r'(?i)\bWHERE\b(.*)$', res)
            hits = {int(x) for x in re.findall(r'\b(\d{3,9})\b', w.group(1) if w else '')} & STOCK
            if hits:
                bad_du.append((sorted(hits), flat[:110]))
            continue

        m = re.match(r'(?i)^INSERT\s+(?:IGNORE\s+)?INTO\s+`?(\w+)`?\s*\(([^)]*)\)', flat)
        if m:
            tbl = m.group(1)
            cols = [c.strip().strip('`') for c in m.group(2).split(',')]
            present = [c for c in OWNER.get(tbl, []) if c in cols]
            for c in present[:1]:
                ix = cols.index(c)
                for line in lines:
                    s = line.strip()
                    if not s.startswith('('):
                        continue
                    body = s[1:].rstrip(';').rstrip().rstrip(',').rstrip()
                    if body.endswith(')'):
                        body = body[:-1]
                    vals = split_row(body)
                    if ix < len(vals):
                        rv = resolve(vals[ix], variables).strip()
                        mm = re.fullmatch(r'\(?(\d{2,9})\)?', rv)
                        if mm and int(mm.group(1)) in STOCK:
                            bad_ins.append((tbl, c, mm.group(1), s[:90]))
    return bad_du, bad_ins, bad_syn


total = 0
for p in sys.argv[1:]:
    du, ins, syn = check(p)
    total += len(du) + len(ins) + len(syn)
    print('  %-30s stock D/U=%-2d stock INSERT rows=%-2d syntax=%-2d  %s'
          % (p, len(du), len(ins), len(syn), 'OK' if not (du or ins or syn) else '*** CHECK ***'))
    for h, s in du[:4]:
        print('      D/U %s | %s' % (h, s))
    for t, c, v, s in ins[:4]:
        print('      INS %s.%s=%s | %s' % (t, c, v, s))
    for r, s in syn[:4]:
        print('      SYN %s | %s' % (r, s))
print('\nTOTAL PROBLEMS:', total)
