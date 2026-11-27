"""Minimal WDBC reader: records as uint32 arrays + string block, ID -> row index."""
from pathlib import Path

import numpy as np


class DBC:
    def __init__(self, path):
        data = Path(path).read_bytes()
        assert data[:4] == b"WDBC", path
        self.n, self.fields, self.recsize, strsize = np.frombuffer(data, "<u4", 4, 4)
        body = np.frombuffer(data, "<u4", self.n * self.recsize // 4, 20)
        self.rows = body.reshape(self.n, self.recsize // 4)
        self.strings = data[20 + self.n * self.recsize:]
        self.index = {int(i): k for k, i in enumerate(self.rows[:, 0])}

    def has(self, rid):
        return rid in self.index

    def u(self, rid, f):
        return int(self.rows[self.index[rid], f])

    def i(self, rid, f):
        return int(self.rows[self.index[rid], f].astype(np.int32))

    def f(self, rid, f):
        return float(self.rows[self.index[rid], f].view(np.float32))

    def s(self, rid, f):
        off = int(self.rows[self.index[rid], f])
        end = self.strings.find(b"\0", off)
        return self.strings[off:end].decode("utf-8", "replace")

    def ids(self):
        return [int(x) for x in self.rows[:, 0]]

    def row_strings(self, rid, fields):
        return tuple(self.s(rid, f) for f in fields)
