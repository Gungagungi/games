#!/usr/bin/env python3
"""Rend une planche de sprites lisible sans écran.

Une planche livrée fait 256×32 : à cette taille on ne voit rien, et surtout on
ne voit pas si les cases sont bien cadrées. Ce script l'agrandit au plus proche
voisin sur un damier qui marque les limites de case — un sprite qui déborde sur
la case voisine saute alors aux yeux.

  scripts/preview-sheet.py enemy_zombie              # → tools/shots/…
  scripts/preview-sheet.py --all --zoom 6
  scripts/preview-sheet.py player_mech -o /tmp/x.png
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngtool import Image  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "godot/assets/sprites"
MANIFEST = ROOT / "godot/assets/MANIFEST.md"
SHOTS = ROOT.parent / "tools/shots"

CELL_A = (46, 44, 54, 255)
CELL_B = (68, 52, 52, 255)
GRID = (120, 120, 140, 255)


def tile_sizes() -> dict[str, int]:
    pattern = re.compile(r"^\|\s*`([\w]+)\.png`\s*\|\s*(\d+)×\d+\s*\|")
    out = {}
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        m = pattern.match(line)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def preview(sheet: Image, tile: int, zoom: int) -> Image:
    """Compose la planche sur un damier une case sur deux, puis agrandit."""
    out = Image(sheet.width, sheet.height)
    for y in range(sheet.height):
        for x in range(sheet.width):
            off = (y * sheet.width + x) * 4
            if sheet.pixels[off + 3] > 8:
                out.pixels[off:off + 4] = sheet.pixels[off:off + 4]
            elif x % tile == 0 and tile > 1:
                out.pixels[off:off + 4] = bytes(GRID)
            else:
                out.pixels[off:off + 4] = bytes(CELL_B if (x // tile) % 2 else CELL_A)
    return out.resized(sheet.width * zoom, sheet.height * zoom)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheets", nargs="*", help="noms de planches, sans .png")
    ap.add_argument("--all", action="store_true", help="toutes les planches déposées")
    ap.add_argument("--zoom", type=int, default=8, help="facteur d'agrandissement (8)")
    ap.add_argument("-o", "--out", help="fichier de sortie (une seule planche)")
    args = ap.parse_args()

    sizes = tile_sizes()
    names = args.sheets
    if args.all:
        names = sorted(p.stem for p in SPRITES.glob("*.png"))
    if not names:
        ap.error("donner au moins une planche, ou --all")
    if args.out and len(names) > 1:
        ap.error("-o ne vaut que pour une seule planche")

    for name in names:
        src = SPRITES / f"{name}.png"
        if not src.exists():
            print(f"{name}: pas encore déposée", file=sys.stderr)
            continue
        tile = sizes.get(name)
        if tile is None:
            print(f"{name}: absente du manifeste, taille de case inconnue", file=sys.stderr)
            continue
        sheet = Image.decode(src.read_bytes())
        cases = sheet.width // tile
        if sheet.width % tile or sheet.height != tile:
            print(f"⚠ {name}: {sheet.width}×{sheet.height} n'est pas un multiple "
                  f"de {tile} px — planche mal formée", file=sys.stderr)
        dest = Path(args.out) if args.out else SHOTS / f"sheet-{name}.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(preview(sheet, tile, args.zoom).encode())
        print(f"{name}: {cases} cases de {tile} px → {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
