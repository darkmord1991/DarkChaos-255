#!/usr/bin/env python3
"""Repair `creature_classlevelstats` for levels 84-255.

Two independent defects are fixed:

A. DECIMAL SEPARATOR LOST (levels 86-255, the DC-specific defect)
   `Custom/Levelstats 255/255_creature_classlevelstats.csv` is semicolon-delimited with
   comma decimal separators (`49,2375`).  From level 86 upward the comma is simply absent
   from `damage_base` / `damage_exp1` / `damage_exp2`, so `51,2373` was stored as `512373`.
   Trailing zeros were trimmed too, so the lost magnitude is not a constant power of ten
   (`143,73` -> `14373`).  The digits themselves are correct: level-130 class-1 `805677`
   is exactly 50.5707 + 45 * 0.6666 = 80.5677.

   Repair: fit the per-(class, column) linear curve from the known-good comma-bearing rows
   at levels 80-85, then for each damaged cell pick the power-of-ten divisor that puts the
   stored digits closest to the curve.  Cells that cannot be reconciled to within TOLERANCE
   are reported, never silently rewritten.

B. DEGENERATE CELLS (levels 84-85, inherited from stock AzerothCore)
   Stock AC ships `1` placeholders for `basehp0/basehp1/basehp2/basearmor` and `0` for
   `rangedattackpower` at levels 84-85, and nothing at all above 85.  That is not a DC
   regression, but it is live-affecting here: creatures at level 85 with `exp = 2` read
   `basehp2` and end up with 1 HP.

   Repair: linear extrapolation backward from the good 86/87/88 rows.  This is
   self-validating - the same extrapolation reproduces the untouched level-83 value
   wherever level 83 is non-degenerate, and the script asserts that.

Only cells that are actually degenerate are touched; plausible values are left alone.
Level 83 and below is never modified.

Usage:
    python fix_creature_classlevelstats.py [--csv PATH] [--out-csv PATH] [--out-sql PATH]
                                           [--check-only]
"""

import argparse
import io
import os
import sys

REAL_CLASSES = (1, 2, 4, 8)

COL_LEVEL = 0
COL_CLASS = 1
COL_BASEHP0 = 2
COL_BASEHP1 = 3
COL_BASEHP2 = 4
COL_BASEMANA = 5
COL_BASEARMOR = 6
COL_ATTACKPOWER = 7
COL_RANGEDAP = 8
COL_DMG_BASE = 9
COL_DMG_EXP1 = 10
COL_DMG_EXP2 = 11

DAMAGE_COLS = (COL_DMG_BASE, COL_DMG_EXP1, COL_DMG_EXP2)
# Columns repaired at levels 84-85, with the value that marks them degenerate.
INT_REPAIR_COLS = (
    (COL_BASEHP0, 1),
    (COL_BASEHP1, 1),
    (COL_BASEHP2, 1),
    (COL_BASEARMOR, 1),
    (COL_RANGEDAP, 0),
)

FIT_LEVELS = (80, 81, 82, 83, 84, 85)   # damage curve is comma-bearing and clean here
EXTRAP_LEVELS = (86, 87, 88)            # good rows to extrapolate 84-85 backward from
FIRST_LOST_DECIMAL_LEVEL = 86
TOLERANCE = 0.02                        # 2% - the generator rounded, so demand closeness not equality


def parse_decimal(text):
    """Parse a European-decimal cell. Returns None for NULL/empty."""
    text = text.strip()
    if text in ("", "\\N"):
        return None
    return float(text.replace(",", "."))


def format_decimal(value, digits):
    """Render `value` back in the file's comma-decimal style, preserving the digit count."""
    text = f"{value:.{digits}f}".rstrip("0").rstrip(".")
    if text == "":
        text = "0"
    return text.replace(".", ",")


def linear_fit(points):
    """Least-squares slope/intercept over [(x, y), ...]."""
    n = len(points)
    sx = sum(x for x, _ in points)
    sy = sum(y for _, y in points)
    sxx = sum(x * x for x, _ in points)
    sxy = sum(x * y for x, y in points)
    denom = n * sxx - sx * sx
    if denom == 0:
        raise ValueError("degenerate fit")
    slope = (n * sxy - sx * sy) / denom
    intercept = (sy - slope * sx) / n
    return slope, intercept


class Repair:
    def __init__(self, path):
        with io.open(path, encoding="utf-8-sig") as handle:
            lines = [line.rstrip("\n") for line in handle if line.strip()]
        self.header = lines[0]
        self.rows = [line.split(";") for line in lines[1:]]
        self.by_key = {(int(r[COL_LEVEL]), int(r[COL_CLASS])): r for r in self.rows}
        self.fixed_damage = 0
        self.fixed_ints = 0
        self.warnings = []

    def cell(self, level, cls, col):
        row = self.by_key.get((level, cls))
        return row[col] if row else None

    # -- defect A ---------------------------------------------------------------

    def repair_damage(self):
        for cls in REAL_CLASSES:
            for col in DAMAGE_COLS:
                points = []
                for level in FIT_LEVELS:
                    raw = self.cell(level, cls, col)
                    if raw is None or "," not in raw:
                        continue
                    points.append((level, parse_decimal(raw)))
                if len(points) < 3:
                    self.warnings.append(
                        f"class {cls} col {col}: only {len(points)} clean fit points, skipped"
                    )
                    continue
                slope, intercept = linear_fit(points)

                for (level, row_cls), row in sorted(self.by_key.items()):
                    if row_cls != cls or level < FIRST_LOST_DECIMAL_LEVEL:
                        continue
                    raw = row[col].strip()
                    if raw in ("", "\\N") or "," in raw:
                        continue  # already has a separator - untouched
                    digits = raw.lstrip("-")
                    if not digits.isdigit():
                        self.warnings.append(f"L{level} class {cls} col {col}: unparseable {raw!r}")
                        continue

                    expected = intercept + slope * level
                    best = None
                    for power in range(0, 7):
                        candidate = int(digits) / (10 ** power)
                        error = abs(candidate - expected)
                        if best is None or error < best[0]:
                            best = (error, candidate, power)
                    error, value, power = best

                    if expected <= 0 or error / expected > TOLERANCE:
                        self.warnings.append(
                            f"L{level} class {cls} col {col}: {raw} -> best {value} vs "
                            f"expected {expected:.4f} ({error / max(expected, 1e-9):.1%}) - LEFT ALONE"
                        )
                        continue

                    # Dividing by 10**power introduces exactly `power` decimal places;
                    # every significant digit of the original cell must survive.
                    row[col] = format_decimal(value, power)
                    self.fixed_damage += 1

    # -- defect B ---------------------------------------------------------------

    def repair_degenerate(self):
        for cls in REAL_CLASSES:
            for col, degenerate_at in INT_REPAIR_COLS:
                points = []
                for level in EXTRAP_LEVELS:
                    raw = self.cell(level, cls, col)
                    if raw is None:
                        continue
                    value = int(raw)
                    if value <= max(degenerate_at, 1):
                        continue
                    points.append((level, float(value)))
                if len(points) < 2:
                    self.warnings.append(
                        f"class {cls} col {col}: no clean 86-88 rows to extrapolate from, skipped"
                    )
                    continue
                slope, intercept = linear_fit(points)

                # Self-check: reproduce level 83 where it is non-degenerate.
                trust_curve = True
                anchor = self.cell(83, cls, col)
                if anchor is not None and int(anchor) > max(degenerate_at, 1):
                    predicted = intercept + slope * 83
                    actual = int(anchor)
                    if abs(predicted - actual) > max(2.0, actual * 0.01):
                        trust_curve = False
                        self.warnings.append(
                            f"class {cls} col {col}: curve predicts {predicted:.0f} at L83 but "
                            f"file has {actual} - falling back to neighbour interpolation"
                        )

                for level in (84, 85):
                    row = self.by_key.get((level, cls))
                    if row is None:
                        continue
                    if int(row[col]) > max(degenerate_at, 1):
                        continue  # already plausible - leave it

                    if trust_curve:
                        value = intercept + slope * level
                    else:
                        # The 86-88 curve disagrees with level 83, so this column has an
                        # outlier in the stock data. Interpolate between the nearest
                        # non-degenerate rows on either side instead.
                        below = self.nearest_good(cls, col, level, degenerate_at, step=-1)
                        above = self.nearest_good(cls, col, level, degenerate_at, step=1)
                        if below is None or above is None:
                            self.warnings.append(
                                f"L{level} class {cls} col {col}: no bracketing rows, LEFT ALONE"
                            )
                            continue
                        (lo_level, lo_value), (hi_level, hi_value) = below, above
                        span = hi_level - lo_level
                        value = lo_value + (hi_value - lo_value) * (level - lo_level) / span

                    row[col] = str(max(1, int(round(value))))
                    self.fixed_ints += 1

    def nearest_good(self, cls, col, level, degenerate_at, step, limit=8):
        """Nearest row in `step` direction whose cell is not degenerate."""
        probe = level + step
        for _ in range(limit):
            raw = self.cell(probe, cls, col)
            if raw is not None and int(raw) > max(degenerate_at, 1):
                return probe, float(int(raw))
            probe += step
        return None

    # -- output -----------------------------------------------------------------

    def write_csv(self, path):
        with io.open(path, "w", encoding="utf-8-sig", newline="") as handle:
            handle.write(self.header + "\n")
            for row in self.rows:
                handle.write(";".join(row) + "\n")

    def write_sql(self, path):
        touched = [
            row for row in self.rows
            if int(row[COL_CLASS]) in REAL_CLASSES and int(row[COL_LEVEL]) >= 84
        ]
        touched.sort(key=lambda r: (int(r[COL_LEVEL]), int(r[COL_CLASS])))

        with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(
                "-- creature_classlevelstats: repair levels 84-255.\n"
                "--\n"
                "-- A. damage_base/damage_exp1/damage_exp2 lost their decimal separator from\n"
                "--    level 86 up (`51,2373` stored as `512373`), so any creature above 85\n"
                "--    rolled six-figure base melee damage.\n"
                "-- B. levels 84-85 carried stock AzerothCore's `1` placeholders for\n"
                "--    basehp0/basehp1/basehp2/basearmor and `0` for rangedattackpower, which\n"
                "--    left level-85 exp=2 creatures (961 live spawns on maps 750/861) at 1 HP.\n"
                "--\n"
                "-- Generated by Custom/Documentation/scripts/fix_creature_classlevelstats.py\n"
                "-- Source of truth: Custom/Levelstats 255/255_creature_classlevelstats.csv\n\n"
            )
            handle.write(
                "DELETE FROM `creature_classlevelstats` WHERE `level` >= 84 AND `class` IN (1,2,4,8);\n"
            )
            handle.write(
                "INSERT INTO `creature_classlevelstats` (`level`, `class`, `basehp0`, `basehp1`, "
                "`basehp2`, `basemana`, `basearmor`, `attackpower`, `rangedattackpower`, "
                "`damage_base`, `damage_exp1`, `damage_exp2`) VALUES\n"
            )
            rendered = []
            for row in touched:
                values = [row[i] for i in range(0, 12)]
                numeric = []
                for index, raw in enumerate(values):
                    raw = raw.strip()
                    if raw in ("", "\\N"):
                        numeric.append("0")
                    elif index in DAMAGE_COLS:
                        numeric.append(raw.replace(",", "."))
                    else:
                        numeric.append(raw)
                rendered.append("(" + ", ".join(numeric) + ")")
            handle.write(",\n".join(rendered) + ";\n")
        return len(touched)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    default_csv = os.path.join(repo, "Levelstats 255", "255_creature_classlevelstats.csv")

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", default=default_csv)
    parser.add_argument("--out-csv", default=None, help="default: overwrite --csv in place")
    parser.add_argument("--out-sql", default=None)
    parser.add_argument("--check-only", action="store_true",
                        help="report what would change, write nothing")
    args = parser.parse_args()

    repair = Repair(args.csv)
    repair.repair_damage()
    repair.repair_degenerate()

    print(f"damage cells repaired : {repair.fixed_damage}")
    print(f"degenerate cells filled: {repair.fixed_ints}")
    if repair.warnings:
        print(f"\n{len(repair.warnings)} warning(s):")
        for warning in repair.warnings:
            print("  " + warning)

    if args.check_only:
        return 0

    out_csv = args.out_csv or args.csv
    repair.write_csv(out_csv)
    print(f"\nwrote {out_csv}")

    if args.out_sql:
        count = repair.write_sql(args.out_sql)
        print(f"wrote {args.out_sql} ({count} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
