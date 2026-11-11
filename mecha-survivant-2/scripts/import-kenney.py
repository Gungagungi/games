#!/usr/bin/env python3
"""Découpe les tuiles de décor dans les packs Kenney (CC0) et les range en
planches prêtes pour le moteur.

Les packs ne sont pas versionnés : seules les tuiles réellement employées le
sont, assemblées en quatre planches de cases de 16 px (affichées ×2 en jeu).
Choisir une autre tuile, c'est changer une coordonnée ici et relancer.

  scripts/import-kenney.py --rpg "Roguelike pack.zip" --indoor "Roguelike Indoor pack.zip"

Les deux zips viennent d'OpenGameArt ou de kenney.nl :
  https://opengameart.org/content/roguelikerpg-pack-1700-tiles
  https://opengameart.org/content/roguelike-indoor-pack

Les coordonnées sont en cases (colonne, ligne) de la planche source, dont les
tuiles de 16 px sont séparées par une marge de 1 px (pas de 17).
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngtool import Image, strip  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "godot/assets/sprites"
LICENSE = ROOT / "godot/assets/KENNEY-LICENSE.txt"

TILE = 16
PITCH = 17

RPG_SHEET = "Spritesheet/roguelikeSheet_transparent.png"
INDOOR_SHEET = "Spritesheet/roguelikeIndoor_transparent.png"

# Ordre des cases = contrat avec `scenes/level.gd` (constantes `GROUND_*`,
# `WALL_*`, `PROP_*`) et avec `SHEETS` : ne pas réordonner sans les suivre.
PLANCHES = {
    # herbe ×2, herbe caillouteuse, terre ×2, pierre, pavés
    "tiles_ground": [("rpg", 5, 0), ("rpg", 5, 1), ("rpg", 9, 1), ("rpg", 6, 0),
                     ("rpg", 6, 1), ("rpg", 7, 0), ("rpg", 9, 0)],
    # sols intérieurs : brique brune, brique grise, parquet ×3
    "tiles_indoor": [("rpg", 5, 2), ("rpg", 6, 2), ("rpg", 8, 2), ("rpg", 8, 3),
                     ("rpg", 9, 4)],
    # faces de mur : une lisse, cinq fissurées ; puis deux pans écroulés
    "tiles_wall": [("rpg", 20, 15), ("rpg", 23, 19), ("rpg", 24, 19), ("rpg", 25, 19),
                   ("rpg", 23, 20), ("rpg", 24, 20), ("rpg", 20, 18), ("rpg", 21, 18)],
    # arbres morts ×3, tombes ×5, rochers ×4, tonneaux ×2, puis mobilier
    # renversé : chaises ×3, table ronde, table
    "tiles_props": [("rpg", 27, 9), ("rpg", 27, 10), ("rpg", 27, 11),
                    ("rpg", 51, 10), ("rpg", 52, 10), ("rpg", 53, 10), ("rpg", 51, 11),
                    ("rpg", 52, 11),
                    ("rpg", 54, 19), ("rpg", 55, 19), ("rpg", 54, 21), ("rpg", 55, 21),
                    ("rpg", 23, 0), ("rpg", 24, 0),
                    ("indoor", 1, 2), ("indoor", 2, 3), ("indoor", 3, 3), ("indoor", 7, 0),
                    ("indoor", 4, 3)],
}


# Étalonnage « village mort » : Kenney est vif et gai, le jeu ne l'est pas.
# Désaturation partielle, assombrissement, léger froid dans les ombres. Fait
# ici plutôt qu'en `modulate` dans le moteur : un modulate multiplie, il ne
# sait pas retirer de la couleur.
DESATURATE = 0.6
DARKEN = 0.68
COOL = (0.94, 1.0, 1.1)


def grade(img: Image) -> Image:
    px = img.pixels
    for i in range(0, len(px), 4):
        if px[i + 3] == 0:
            continue
        r, g, b = px[i], px[i + 1], px[i + 2]
        lum = 0.3 * r + 0.59 * g + 0.11 * b
        for k, c in enumerate((r, g, b)):
            v = (c + (lum - c) * DESATURATE) * DARKEN * COOL[k]
            px[i + k] = max(0, min(255, int(v)))
    return img


def load_sheet(zip_path: Path, member: str) -> Image:
    with zipfile.ZipFile(zip_path) as z:
        return Image.decode(z.read(member))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--rpg", type=Path, required=True, help="Roguelike pack.zip")
    ap.add_argument("--indoor", type=Path, required=True, help="Roguelike Indoor pack.zip")
    args = ap.parse_args()

    sources = {"rpg": load_sheet(args.rpg, RPG_SHEET),
               "indoor": load_sheet(args.indoor, INDOOR_SHEET)}
    for name, cells in PLANCHES.items():
        frames = []
        for src, col, row in cells:
            sheet = sources[src]
            if (col + 1) * PITCH - 1 > sheet.width or (row + 1) * PITCH - 1 > sheet.height:
                print(f"{name}: case {src} ({col},{row}) hors de la planche", file=sys.stderr)
                return 1
            frames.append(sheet.crop(col * PITCH, row * PITCH, TILE, TILE))
        out = SPRITES / f"{name}.png"
        out.write_bytes(grade(strip(frames, TILE)).encode())
        print(f"{out.relative_to(ROOT)}  {len(frames)} cases")

    with zipfile.ZipFile(args.rpg) as z:
        LICENSE.write_bytes(z.read("License.txt"))
    print(f"{LICENSE.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
