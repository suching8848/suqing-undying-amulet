"""Build the two standalone variants for one Project Zomboid Workshop item."""

import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ID = "SuQingUndyingAmulet"
SIMPLE_ID = "SuQingUndyingAmuletSimple"
DEFAULT = ROOT / "Contents" / "mods" / DEFAULT_ID
SIMPLE_OVERLAY = ROOT / "variants" / "simple"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path, help="New Workshop item directory")
    destination = parser.parse_args().destination.resolve()
    if destination.exists():
        parser.error(f"destination already exists: {destination}")

    mods = destination / "Contents" / "mods"
    default = mods / DEFAULT_ID
    simple = mods / SIMPLE_ID
    shutil.copytree(DEFAULT, default)
    shutil.copytree(DEFAULT, simple)
    shutil.copytree(SIMPLE_OVERLAY, simple / "42", dirs_exist_ok=True)
    for mod in (default, simple):
        (mod / "common").mkdir(exist_ok=True)

    publication = ROOT / "publishing"
    shutil.copyfile(publication / "preview.png", destination / "preview.png")
    shutil.copyfile(publication / "workshop.txt", destination / "workshop.txt")


if __name__ == "__main__":
    main()
