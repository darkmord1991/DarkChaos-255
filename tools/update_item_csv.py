#!/usr/bin/env python3
"""Retired helper for the old clone-based item upgrade DBC workflow."""


def main() -> None:
    raise SystemExit(
        "Retired: Item.csv is no longer updated from clone-generated item_template rows. "
        "Dynamic upgrades keep canonical data in SQL/runtime state instead."
    )


if __name__ == "__main__":
    main()