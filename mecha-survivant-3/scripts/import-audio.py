#!/usr/bin/env python3
"""Dépose les bruitages et musiques de la v3, tirés de banques libres (CC0)
d'OpenGameArt, à la place de ceux générés par ElevenLabs pour la v2.

  scripts/import-audio.py <dossier des téléchargements>
  scripts/build.sh && scripts/import-audio.py --loops && scripts/build.sh

Le dossier contient les fichiers tels que téléchargés (zips compris), aux noms
de `SOURCES`. Rien de tout cela n'est versionné : seuls les sons retenus le
sont, sous la clé que le code appelle (`AudioManager.sfx("shoot")` →
`assets/sfx/shoot.ogg`).

L'`AudioManager` essaie `.ogg`, puis `.wav`, puis `.mp3` : déposer un `.ogg`
ne suffirait pas à remplacer un `.mp3`, mais un `.wav` resté à côté d'un `.ogg`
serait ignoré en silence tout en pesant dans l'export. Le script retire donc
toute autre version de la même clé, `.import` compris.

Une musique ne boucle que si son `.import` porte `loop=true`. Ce fichier est
créé par l'import de Godot, d'où `--loops`, à lancer **après** un build, puis
un second build pour que le réimport prenne le changement.

Pas de rognage ni de normalisation : ni `ffmpeg` ni décodeur Vorbis ne sont
disponibles sans dépendance. Les sons ont été choisis courts (moins de 2 s,
mesuré dans les en-têtes Ogg) ; les volumes relatifs, eux, sont à juger à
l'oreille.
"""

from __future__ import annotations

import argparse
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "godot/assets"
CREDITS = ASSETS / "AUDIO-CREDITS.md"
EXTS = (".ogg", ".wav", ".mp3")

# téléchargement -> (titre, auteur, page OpenGameArt). Tous CC0.
SOURCES = {
    "80-CC0-creature-SFX_0.zip": ("80 CC0 creature SFX", "rubberduck",
                                  "https://opengameart.org/content/80-cc0-creature-sfx"),
    "80-CC0-creature-sfx-2.zip": ("80 CC0 creature SFX #2", "rubberduck",
                                  "https://opengameart.org/content/80-cc0-creture-sfx-2"),
    "sci-fi-sfx.zip": ("50 CC0 Sci-Fi SFX", "rubberduck",
                       "https://opengameart.org/content/50-cc0-sci-fi-sfx"),
    "sci-fi_sounds.zip": ("Sci-fi Sounds", "Kenney",
                          "https://opengameart.org/content/sci-fi-sounds"),
    "ambient_horror_track_01_0.zip": ("Ambient Horror Track 01", "CleytonKauffman",
                                      "https://opengameart.org/content/ambient-horror-track-01"),
    "Battle.mp3": ("Battle Theme", "Wolfgang_",
                   "https://opengameart.org/content/battle-theme-0"),
    "boss_battle_loop_0.mp3": ("Boss Battle Loop", "Pro Sensory",
                               "https://opengameart.org/content/boss-battle-loop"),
    "heavy_boss_battle_2_bpm110_0.ogg": ("Heavy Boss Battle 2", "MintoDog",
                                         "https://opengameart.org/content/heavy-boss-battle-2"),
}

C1, C2 = "80-CC0-creature-SFX_0.zip", "80-CC0-creature-sfx-2.zip"
SF, KN = "sci-fi-sfx.zip", "sci-fi_sounds.zip"

# clé -> (téléchargement, fichier dans le zip ou None). La liste des clés est
# celle du manifeste : 21 bruitages, 4 musiques.
SFX = {
    "shoot": (KN, "laserSmall_000.ogg"),
    "hit_enemy": (KN, "impactMetal_004.ogg"),
    "enemy_death": (C2, "die_01.ogg"),
    "enemy_groan": (C1, "monster_03.ogg"),
    "player_hurt": (KN, "impactMetal_000.ogg"),
    "dash": (SF, "teleport_01.ogg"),
    "shockwave": (KN, "lowFrequency_explosion_001.ogg"),
    "upgrade_pick": (SF, "retro_beep_04.ogg"),
    "ui_click": (SF, "beep_03.ogg"),
    "wave_start": (C1, "howl.ogg"),
    "boss_spawn": (C2, "roar_04.ogg"),
    "boss_hurt": (C2, "grunt_07.ogg"),
    "boss_death": (C2, "roar_05.ogg"),
    "game_over": (KN, "explosionCrunch_001.ogg"),
    "fireball_impact": (KN, "explosionCrunch_000.ogg"),
    "flameling_cast": (C1, "spit_02.ogg"),
    "shade_phase": (C1, "weird_02.ogg"),
    "bone_sweep": (C2, "attack_02.ogg"),
    "laser_charge": (KN, "forceField_002.ogg"),
    "titan_charge": (C1, "roar_02.ogg"),
    "titan_ultimate": (KN, "lowFrequency_explosion_000.ogg"),
}
MUSIC = {
    "menu": ("ambient_horror_track_01_0.zip", "ambient_horror_track01.ogg"),
    "dungeon": ("Battle.mp3", None),
    "boss": ("boss_battle_loop_0.mp3", None),
    "titan": ("heavy_boss_battle_2_bpm110_0.ogg", None),
}


def read(src_dir: Path, download: str, member: str | None) -> tuple[bytes, str]:
    path = src_dir / download
    if member is None:
        return path.read_bytes(), path.suffix
    with zipfile.ZipFile(path) as z:
        name = next(n for n in z.namelist() if n.rsplit("/", 1)[-1] == member)
        return z.read(name), Path(member).suffix


def place(folder: Path, key: str, data: bytes, ext: str) -> None:
    for old in EXTS:
        for f in (folder / f"{key}{old}", folder / f"{key}{old}.import"):
            if old != ext and f.exists():
                f.unlink()
    (folder / f"{key}{ext}").write_bytes(data)


def set_loop(imp: Path) -> bool:
    """Force `loop=true` dans le `.import` d'une musique (même logique que
    `gen-audio.py` en v2)."""
    text = imp.read_text()
    if re.search(r"^loop=true$", text, re.M):
        return False
    if re.search(r"^loop=", text, re.M):
        text = re.sub(r"^loop=.*$", "loop=true", text, count=1, flags=re.M)
    else:
        text = re.sub(r"^\[params\]$", "[params]\n\nloop=true", text, count=1, flags=re.M)
    imp.write_text(text)
    return True


def write_credits() -> None:
    used: dict[str, list[str]] = {}
    for key, (dl, _m) in SFX.items():
        used.setdefault(dl, []).append(f"`sfx/{key}`")
    for key, (dl, _m) in MUSIC.items():
        used.setdefault(dl, []).append(f"`music/{key}`")
    lines = ["# Crédits audio (v3)", "",
             "Tous ces sons sont sous licence **CC0** (domaine public) : aucun crédit",
             "n'est exigé, il est donné ici par courtoisie. Produit par",
             "`scripts/import-audio.py`.", "",
             "| Source | Auteur | Utilisé pour |", "| --- | --- | --- |"]
    for dl, keys in used.items():
        title, author, url = SOURCES[dl]
        lines.append(f"| [{title}]({url}) | {author} | {', '.join(keys)} |")
    CREDITS.write_text("\n".join(lines) + "\n")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src", type=Path, nargs="?", help="dossier des téléchargements")
    ap.add_argument("--loops", action="store_true",
                    help="poser loop=true dans les .import des musiques, puis sortir")
    args = ap.parse_args()
    if args.loops:
        for key in MUSIC:
            for ext in EXTS:
                imp = ASSETS / "music" / f"{key}{ext}.import"
                if imp.exists() and set_loop(imp):
                    print(f"loop=true : music/{key}{ext}")
        return
    if args.src is None:
        ap.error("dossier des téléchargements manquant")
    for folder, table in ((ASSETS / "sfx", SFX), (ASSETS / "music", MUSIC)):
        for key, (dl, member) in table.items():
            data, ext = read(args.src, dl, member)
            place(folder, key, data, ext)
            print(f"{folder.name}/{key}{ext:5} ← {dl}{':' + member if member else ''}")
    write_credits()
    print(CREDITS.relative_to(ROOT))


if __name__ == "__main__":
    main()
