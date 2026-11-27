"""Read-only access to a client's whole MPQ set through DC's StormLib ctypes bindings.

Archives stay open for the life of the object, so probing hundreds of names costs one open per archive.
The bindings and their success rules (non-null handle; GetLastError() == 0 for file opens) are the ones
documented in wow.export-main/tools/mpq_stormlib_locate.py.
"""
import ctypes
import importlib.util
from pathlib import Path

TOOLS = Path(r"K:/Dark-Chaos/wow.export-main/tools")


def _module(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_extract = _module("mpq_stormlib_extract")
_locate = _module("mpq_stormlib_locate")


class MpqSet:
    """archives: paths in ascending priority (the last one that holds a name wins)."""

    def __init__(self, archives):
        self.dll = _extract.load()
        self.handles = []
        for path in archives:
            h = _locate.open_archive(self.dll, str(path))
            if h:
                self.handles.append((Path(path), h))
            else:
                print(f"  (could not open {path})")

    def close(self):
        for _p, h in self.handles:
            self.dll.SFileCloseArchive(h)
        self.handles = []

    def where(self, name):
        return [p for p, h in self.handles if _locate.has_file(self.dll, h, name)]

    def winner(self, name):
        hits = self.where(name)
        return hits[-1] if hits else None

    def read(self, name):
        for path, h in reversed(self.handles):
            fh = ctypes.c_void_p()
            ctypes.set_last_error(0)
            self.dll.SFileOpenFileEx(h, name.replace("/", "\\").encode("ascii"), 0, ctypes.byref(fh))
            if not (fh.value and ctypes.get_last_error() == 0):
                continue
            try:
                size = self.dll.SFileGetFileSize(fh, None)
                buf = ctypes.create_string_buffer(size if size else 1)
                got = ctypes.c_uint32(0)
                self.dll.SFileReadFile(fh, buf, size, ctypes.byref(got), None)
                return path, buf.raw[:got.value]
            finally:
                self.dll.SFileCloseFile(fh)
        return None, None


def client_archives(data_dir, locale):
    """A 3.3.5 Data dir in load order: base archives, the locale chain, then the custom root patches."""
    data_dir = Path(data_dir)
    base = [data_dir / n for n in ("common.MPQ", "common-2.MPQ", "expansion.MPQ", "lichking.MPQ", "patch.MPQ",
                                   "patch-2.MPQ", "patch-3.MPQ")]
    loc = sorted((data_dir / locale).glob("*.MPQ"), key=lambda p: (not p.name.lower().startswith(("locale",
                                                                                                    "base",
                                                                                                    "backup",
                                                                                                    "expansion",
                                                                                                    "lichking",
                                                                                                    "speech")),
                                                                 p.name.lower()))
    custom = sorted((p for p in data_dir.glob("patch-*.MPQ") if p not in base), key=lambda p: p.name.lower())
    return [p for p in base if p.exists()] + loc + custom
