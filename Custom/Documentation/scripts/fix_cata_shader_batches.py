#!/usr/bin/env python3
"""Repair M2 .skin batches that a 3.3.5 client silently refuses to draw.

THE DEFECT
----------
Cataclysm+ encodes M2Batch.shader_id with the high bit set (0x8000 | n) for its
newer multi-texture combiners. A 3.3.5 client cannot resolve those and DROPS the
batch entirely -- no error, no warning, no missing-texture placeholder. The
geometry is present and valid, the textures resolve, and the model still renders,
just without whatever those batches covered.

That is why the Horde Haulers appeared as two loose panels: four of their six
batches are 2-texture Cata batches (diffuse + SMOOTHREFLECT env-map) and only the
two 1-texture batches survived. Models where EVERY batch is affected
(koboldmale 48/48, azsharanaga 46/46, drogbar 27/27) are invisible outright.

THE REPAIR
----------
For each batch whose shader_id has 0x8000 set:
  * shader_id -> 0      -- the plain single-texture diffuse combiner, which every
                           3.3.5 client supports
  * textureCount -> 1   -- drop the extra env-map/specular layers
  * flags &= ~0x80      -- clear the Cata-only flag bit

The extra layers are lost; the diffuse layer is not. That is the right trade for a
downport, and it is conservative in the way that matters: **blend mode and
transparency come from the batch's materialIndex (M2Material), not from shader_id**,
so an additive glow stays additive and does not turn into a solid block. Only the
texture combiner changes.

Nothing else in the file is touched -- offsets, geometry, and bone data are
untouched, so this is safe to run on a shipped .skin.

USAGE
    python fix_cata_shader_batches.py --scan  <dir>       report only
    python fix_cata_shader_batches.py --fix   <dir>       rewrite in place (.bak kept)
Operates on a directory tree of extracted .skin files.
"""
import os, sys, struct, shutil, argparse

BATCH_SIZE = 24


def scan_skin(data):
    """Return (nBatches, list of affected batch indices)."""
    if data[:4] != b"SKIN":
        return None, None
    try:
        vals = struct.unpack_from("<10I", data, 4)
    except struct.error:
        return None, None
    nTU, ofsTU = vals[8], vals[9]
    if ofsTU + nTU * BATCH_SIZE > len(data):
        return None, None
    bad = []
    for k in range(nTU):
        o = ofsTU + k * BATCH_SIZE
        shader = struct.unpack_from("<h", data, o + 2)[0]
        if shader & 0x8000:
            bad.append(k)
    return nTU, bad


def fix_skin(data):
    """Return (newdata, nFixed)."""
    b = bytearray(data)
    vals = struct.unpack_from("<10I", b, 4)
    nTU, ofsTU = vals[8], vals[9]
    fixed = 0
    for k in range(nTU):
        o = ofsTU + k * BATCH_SIZE
        flags = struct.unpack_from("<H", b, o)[0]
        shader = struct.unpack_from("<h", b, o + 2)[0]
        if not (shader & 0x8000):
            continue
        struct.pack_into("<H", b, o, flags & ~0x80)      # clear the Cata flag bit
        struct.pack_into("<h", b, o + 2, 0)              # plain diffuse combiner
        struct.pack_into("<H", b, o + 14, 1)             # textureCount -> 1
        fixed += 1
    return bytes(b), fixed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scan", metavar="DIR")
    ap.add_argument("--fix", metavar="DIR")
    a = ap.parse_args()
    root = a.scan or a.fix
    if not root:
        ap.error("pass --scan or --fix")

    files = 0
    aff_files = 0
    aff_batches = 0
    tot_batches = 0
    for dirpath, _, names in os.walk(root):
        for n in names:
            if not n.lower().endswith(".skin"):
                continue
            p = os.path.join(dirpath, n)
            d = open(p, "rb").read()
            nTU, bad = scan_skin(d)
            if nTU is None:
                continue
            files += 1
            tot_batches += nTU
            if not bad:
                continue
            aff_files += 1
            aff_batches += len(bad)
            if a.fix:
                if not os.path.exists(p + ".pre_shaderfix.bak"):
                    shutil.copyfile(p, p + ".pre_shaderfix.bak")
                nd, k = fix_skin(d)
                open(p, "wb").write(nd)
                # verify from the bytes we just produced
                _, still = scan_skin(nd)
                if still:
                    raise SystemExit("ABORT: %s still has %d Cata batches after fixing" % (p, len(still)))

    print("%s: %d .skin files, %d batches" % ("FIXED" if a.fix else "SCANNED", files, tot_batches))
    print("  affected files   : %d" % aff_files)
    print("  affected batches : %d" % aff_batches)


if __name__ == "__main__":
    main()
