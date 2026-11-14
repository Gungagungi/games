#!/usr/bin/env python3
"""Fabrique les planches du mech, des ennemis, des boss et du décor depuis le
pack Dungeon Crawl Stone Soup (CC0), pour la refonte visuelle de la v3.

  scripts/import-dcss.py "Dungeon Crawl Stone Soup Full.zip"

Le zip vient d'OpenGameArt (non versionné, 5,7 Mo) :
  https://opengameart.org/content/dungeon-crawl-32x32-tiles

Le pack ne donne qu'**une image de 32 px par monstre**. Les cases d'animation
attendues par `SHEETS` (`scenes/fx/sprite_or_shape.gd`) sont donc dérivées de
cette image par des transformations au pixel près, faites sur la source de
32 px **avant** l'agrandissement, pour rester sur la grille du pixel art :
balancement (décalage vertical), inclinaison (cisaillement qui garde les pieds
en place), enfoncement et fondu pour la mort, éclaircissement pour l'attaque.

Le décor (`TUILES`) remplace les planches Kenney de la v2 case pour case :
même nombre de cases, même rôle à chaque rang, lu par les constantes
`GROUND_*`, `WALL_*`, `PROP_*` de `scenes/level.gd`. Les tuiles passent de
16 à 32 px sans toucher au code : `level.gd` déduit la taille d'une case de
la largeur de la planche. **Ne plus lancer `import-kenney.py` sur la v3**, il
écraserait ces planches.

L'ordre et le nombre des cases sont le contrat avec `SHEETS` et le tableau de
`godot/assets/MANIFEST.md` : ne pas les changer sans les suivre.
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
LICENSE = ROOT / "godot/assets/DCSS-LICENSE.txt"
BASE = "Dungeon Crawl Stone Soup Full/"
SRC = 32
FEET = 29  # ligne des pieds : le cisaillement la laisse en place

# -- transformations d'une image source de 32 px -----------------------------

def frame(src: Image, dx: int = 0, dy: int = 0, shear: int = 0,
          tint: tuple[int, int, int] | None = None, amount: float = 0.0,
          alpha: float = 1.0) -> Image:
    """Copie décalée de `(dx, dy)`, cisaillée de `shear` pixels au sommet de la
    tête (0 aux pieds), teintée vers `tint` à hauteur d'`amount`, opacité
    multipliée par `alpha`. Ce qui sort de la case est perdu."""
    out = Image(SRC, SRC)
    for y in range(SRC):
        lean = round(shear * (FEET - y) / FEET) if y < FEET else 0
        sy = y - dy
        if not 0 <= sy < SRC:
            continue
        for x in range(SRC):
            sx = x - dx - lean
            if not 0 <= sx < SRC:
                continue
            s = (sy * SRC + sx) * 4
            r, g, b, a = src.pixels[s:s + 4]
            if a == 0:
                continue
            if tint is not None and amount > 0.0:
                r = round(r + (tint[0] - r) * amount)
                g = round(g + (tint[1] - g) * amount)
                b = round(b + (tint[2] - b) * amount)
            d = (y * SRC + x) * 4
            out.pixels[d:d + 4] = bytes((r, g, b, round(a * alpha)))
    return out


def recolor(src: Image, ramp: list[tuple[int, int, int]]) -> Image:
    """Remplace chaque couleur par la teinte de `ramp` de même luminance :
    le squelette de feu est le squelette ordinaire passé au dégradé du feu."""
    out = Image(SRC, SRC, bytearray(src.pixels))
    for i in range(0, len(out.pixels), 4):
        r, g, b, a = out.pixels[i:i + 4]
        if a == 0:
            continue
        lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
        pos = lum * (len(ramp) - 1)
        lo = min(int(pos), len(ramp) - 2)
        t = pos - lo
        c = [round(ramp[lo][k] + (ramp[lo + 1][k] - ramp[lo][k]) * t) for k in range(3)]
        out.pixels[i:i + 3] = bytes(c)
    return out


WHITE = (255, 255, 255)
RED = (255, 60, 40)
DARK = (24, 12, 28)
CYAN = (110, 230, 255)
FIRE = [(40, 6, 4), (150, 24, 8), (240, 96, 20), (255, 190, 60), (255, 250, 200)]

# -- recettes d'animation (une liste de cases par animation) -----------------

def idle(s: Image) -> list[Image]:
    return [frame(s), frame(s), frame(s, dy=-1), frame(s, dy=-1)]

def walk(s: Image, n: int = 4) -> list[Image]:
    if n == 6:
        return [frame(s), frame(s, dy=-1, shear=1), frame(s, dy=-1, shear=1),
                frame(s), frame(s, dy=-1, shear=-1), frame(s, dy=-1, shear=-1)]
    return [frame(s), frame(s, dy=-1, shear=1), frame(s), frame(s, dy=-1, shear=-1)]

def death(s: Image) -> list[Image]:
    return [frame(s, dy=1, tint=DARK, amount=0.2, alpha=0.95),
            frame(s, dy=3, tint=DARK, amount=0.35, alpha=0.8),
            frame(s, dy=6, tint=DARK, amount=0.5, alpha=0.6),
            frame(s, dy=10, tint=DARK, amount=0.65, alpha=0.4)]

def attack(s: Image) -> list[Image]:
    return [frame(s, dy=-1, tint=WHITE, amount=0.15),
            frame(s, dy=-2, tint=RED, amount=0.3),
            frame(s, shear=2, tint=WHITE, amount=0.35),
            frame(s, shear=1)]

def dash(s: Image) -> list[Image]:
    return [frame(s, shear=2, tint=CYAN, amount=0.3),
            frame(s, shear=3, tint=CYAN, amount=0.45),
            frame(s, shear=2, tint=CYAN, amount=0.3)]

def scythe(s: Image) -> list[Image]:
    return [frame(s, shear=k, tint=WHITE, amount=a)
            for k, a in ((-2, 0.1), (-1, 0.2), (0, 0.3), (1, 0.35), (2, 0.25), (1, 0.1))]

def charge(s: Image) -> list[Image]:
    return [frame(s, dx=k, shear=k, tint=RED, amount=a)
            for k, a in ((0, 0.15), (1, 0.3), (2, 0.4), (1, 0.25))]

# -- ce que le jeu attend ----------------------------------------------------

# fichier de sortie -> (source dans le zip, agrandissement, recette, retouche)
ENEMY = lambda s: walk(s) + death(s)          # noqa: E731
BOSS = lambda s: idle(s) + attack(s)          # noqa: E731
PLANCHES = {
    "player_mech": ("monster/nonliving/guardian_golem.png", 2,
                    lambda s: idle(s) + walk(s, 6) + dash(s), ("tint", CYAN, 0.18)),
    "enemy_zombie": ("monster/undead/ghoul.png", 1, ENEMY, None),
    "enemy_skeleton": ("monster/undead/skeletal_warrior_new.png", 1, ENEMY, None),
    "enemy_risen": ("monster/undead/wight_new.png", 1, ENEMY, None),
    "enemy_shade": ("monster/undead/shadow_new.png", 1, ENEMY, None),
    "enemy_flameling": ("monster/nonliving/fire_elemental_new.png", 1, ENEMY, None),
    "enemy_fire_skeleton": ("monster/undead/skeletons/skeleton_humanoid_small_new.png", 1,
                            ENEMY, ("fire",)),
    "boss_giant_knight": ("monster/hell_knight_new.png", 3, BOSS, None),
    "boss_sewer_monster": ("monster/demons/tentacled_monstrosity.png", 3, BOSS, None),
    "boss_zombie_titan": ("monster/undead/zombies/zombie_ogre.png", 3, BOSS, None),
    "boss_galaxy_boss": ("monster/demons/blue_death.png", 4, BOSS, None),
    "titan": ("monster/demons/reaper_new.png", 5,
              lambda s: idle(s) + scythe(s) + charge(s), None),
}


# -- décor --------------------------------------------------------------------

def grade(src: Image, bright: float, sat: float) -> Image:
    """Étalonnage : luminosité multipliée par `bright`, saturation par `sat`.
    L'herbe du pack est d'un vert vif qui jure avec la palette froide du jeu."""
    out = Image(SRC, SRC, bytearray(src.pixels))
    for i in range(0, len(out.pixels), 4):
        r, g, b = out.pixels[i:i + 3]
        lum = 0.3 * r + 0.59 * g + 0.11 * b
        c = [min(255, max(0, round((lum + (v - lum) * sat) * bright))) for v in (r, g, b)]
        out.pixels[i:i + 3] = bytes(c)
    return out


D = "dungeon/"
GROUND_GRADE = (0.72, 0.6)
# planche -> (liste de tuiles, étalonnage ou None). L'ordre est lu par level.gd.
TUILES = {
    # herbe ×2, « herbe caillouteuse » (une 3e herbe : le mélange herbe-terre
    # du pack ressortait en carrés criards), terre ×2, pierre, pavés
    "tiles_ground": ([D + "floor/grass/grass_0_new.png", D + "floor/grass/grass_2_new.png",
                      D + "floor/grass/grass_1_new.png", D + "floor/dirt_0_new.png",
                      D + "floor/dirt_1_new.png", D + "floor/grey_dirt_0_new.png",
                      D + "floor/pebble_brown_0_new.png"], GROUND_GRADE),
    # sols intérieurs : dalles de calcaire ×5
    "tiles_indoor": ([D + f"floor/limestone_{k}.png" for k in range(5)], (0.62, 0.6)),
    # faces de mur : lisse, fissurées ×5 ; pans écroulés ×2
    "tiles_wall": ([D + f"wall/catacombs_{k}.png" for k in range(6)]
                   + [D + "statues/crumbled_column.png", D + "statues/crumbled_column_1.png"], None),
    # arbres ×3, tombes ×5, rochers ×4, tonneaux ×2, mobilier ×5
    "tiles_props": ([D + "trees/tree_1_red.png", D + "trees/mangrove_1.png", D + "trees/mangrove_2.png",
                     D + "altars/altar_base.png", D + "statues/statue_wraith.png",
                     D + "statues/statue_angel.png", D + "statues/statue_ancient_evil.png",
                     D + "statues/granite_stump_new.png",
                     D + "boulder.png", D + "statues/granite_stump_old.png",
                     D + "statues/crumbled_column_4.png", D + "statues/crumbled_column_5.png",
                     D + "large_box.png", D + "chest_2_closed.png",
                     D + "chest.png", D + "vaults/sarcophagus_sealed.png", D + "statues/pedestal.png",
                     D + "altars/altar_kikubaaqudgha.png", D + "altars/altar_lugonu.png"], None),
    # pavés des rues et de la place
    "tiles_floor": ([D + f"floor/rect_gray_{k}_new.png" for k in range(4)], (2.4, 0.7)),
}


def build_tiles(z: zipfile.ZipFile, out: Path) -> None:
    for name, (paths, grading) in TUILES.items():
        tiles = []
        for path in paths:
            t = Image.decode(z.read(BASE + path))
            if (t.width, t.height) != (SRC, SRC):
                raise SystemExit(f"{path} : {t.width}×{t.height}, {SRC}×{SRC} attendu")
            tiles.append(grade(t, *grading) if grading else t)
        (out / f"{name}.png").write_bytes(strip(tiles, SRC).encode())
        print(f"{name:22} {len(tiles):2} cases de {SRC} px")


def build(z: zipfile.ZipFile, out: Path) -> None:
    for name, (path, scale, recipe, retouch) in PLANCHES.items():
        src = Image.decode(z.read(BASE + path))
        if (src.width, src.height) != (SRC, SRC):
            raise SystemExit(f"{path} : {src.width}×{src.height}, {SRC}×{SRC} attendu")
        if retouch and retouch[0] == "fire":
            src = recolor(src, FIRE)
        elif retouch and retouch[0] == "tint":
            src = frame(src, tint=retouch[1], amount=retouch[2])
        frames = recipe(src)
        tile = SRC * scale
        sheet = strip([f.resized(tile, tile) for f in frames], tile)
        (out / f"{name}.png").write_bytes(sheet.encode())
        print(f"{name:22} {len(frames):2} cases de {tile} px  ← {path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("zip", type=Path, help="Dungeon Crawl Stone Soup Full.zip")
    ap.add_argument("--out", type=Path, default=SPRITES)
    args = ap.parse_args()
    with zipfile.ZipFile(args.zip) as z:
        build(z, args.out)
        build_tiles(z, args.out)
        LICENSE.write_bytes(z.read(BASE + "LICENSE.txt"))
    print(LICENSE.relative_to(ROOT))


if __name__ == "__main__":
    main()
