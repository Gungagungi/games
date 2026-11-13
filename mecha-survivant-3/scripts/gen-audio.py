#!/usr/bin/env python3
"""Génère les bruitages et les musiques du jeu depuis ElevenLabs.

Pendant de `gen-sprites.py` pour le son, et même discipline : ce script ne
décide de rien. La liste des sons est lue dans `godot/assets/MANIFEST.md` et
recoupée avec les appels réels du code (`AudioManager.sfx(...)`,
`play_music(...)`) ; il refuse de travailler si les deux divergent. Un son
généré sur la foi d'une liste périmée est un son payé pour rien.

  scripts/gen-audio.py --list          # ce qu'il y a à produire
  scripts/gen-audio.py --dry-run       # les prompts, sans rien appeler
  scripts/gen-audio.py --fake          # la chaîne entière, sans dépenser
  scripts/gen-audio.py --only shoot,dash
  scripts/gen-audio.py --kind sfx --budget 1

Deux endpoints suffisent :

  POST /v1/sound-generation  → bruitages. `output_format=pcm_44100` rend du PCM
    brut **stéréo entrelacé** (le nom ne le dit pas, et les octets non plus),
    ramené en mono puis écrit en WAV par `wavtool.py` : pas de `ffmpeg` à
    installer, et le rognage se fait sur les échantillons plutôt qu'au travers
    d'un ré-encodage.
  POST /v1/music             → musiques, en mp3. Godot 4 lit le mp3 nativement
    (`AudioStreamMP3`), inutile de passer par du Vorbis.

La réponse brute est mise en cache dans `.gen-cache/audio/` : une génération
est une génération payée. Le post-traitement (rognage, normalisation, fondus)
est entièrement hors ligne — `--assemble-only` le rejoue autant qu'on veut sans
rappeler l'API, et c'est là qu'on règle un son trop long ou trop faible.

Le jeton est lu dans $ELEVENLABS_TOKEN, sinon dans `.elevenlabs-token` à la
racine du projet (ignoré par git).
"""

from __future__ import annotations

import argparse
import array
import json
import math
import os
import random
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wavtool  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "godot/assets/MANIFEST.md"
PROMPTS = ROOT / "scripts/audio-prompts.json"
GODOT = ROOT / "godot"
SFX_DIR = GODOT / "assets/sfx"
MUSIC_DIR = GODOT / "assets/music"
CACHE = ROOT / ".gen-cache/audio"

API = "https://api.elevenlabs.io/v1"

## Tarifs indicatifs, août 2026 : les bruitages sont facturés au forfait par
## effet quelle que soit leur durée, la musique à la minute produite. Ils ne
## servent qu'à alimenter `--budget` et le récapitulatif ; la facture qui fait
## foi est celle d'ElevenLabs.
COST_SFX = 0.02
COST_MUSIC_PER_MINUTE = 0.15


class Fail(Exception):
    pass


# --------------------------------------------------------------------------
# Spécification : lue là où le jeu la déclare déjà
# --------------------------------------------------------------------------

def read_manifest() -> tuple[list[str], list[str]]:
    """Les clés attendues, depuis le manifeste.

    Les bruitages y sont une liste de noms entre accents graves sous « Effets
    sonores », les musiques un tableau de fichiers `.ogg`/`.mp3` sous
    « Musique »."""
    text = MANIFEST.read_text(encoding="utf-8")

    block = re.search(r"^## Effets sonores.*?\n(.*?)^## ", text, re.S | re.M)
    if not block:
        raise Fail(f"section « Effets sonores » introuvable dans {MANIFEST}")
    sfx = re.findall(r"`([a-z_]+)`", block.group(1))
    # La section décrit aussi le format et cite `shoot.wav` en exemple : ne
    # garder que la liste elle-même, c'est-à-dire les noms sans extension.
    sfx = [s for s in sfx if "." not in s]

    music = re.findall(r"^\|\s*`([a-z_]+)\.(?:ogg|mp3)`\s*\|", text, re.M)
    if not sfx or not music:
        raise Fail(f"liste de sons vide dans {MANIFEST} — format du manifeste changé ?")
    return list(dict.fromkeys(sfx)), list(dict.fromkeys(music))


def read_code() -> tuple[set[str], set[str]]:
    """Les clés réellement jouées par le jeu.

    `AudioManager.sfx()` peut recevoir une variable (`impact_sfx`) : les
    affectations littérales de ces variables comptent donc aussi."""
    sfx: set[str] = set()
    music: set[str] = set()
    for path in GODOT.rglob("*.gd"):
        if path.name == "audio_manager.gd":
            continue
        source = path.read_text(encoding="utf-8")
        sfx.update(re.findall(r'AudioManager\.sfx\(\s*"([a-z_]+)"', source))
        # `sfx("boss_hurt" if is_boss else "hit_enemy")` : les deux branches.
        for call in re.findall(r'AudioManager\.sfx\(([^)]*)\)', source):
            sfx.update(re.findall(r'"([a-z_]+)"', call))
        sfx.update(re.findall(r'impact_sfx\s*=\s*"([a-z_]+)"', source))
        for call in re.findall(r'play_music\(([^)]*)\)', source):
            music.update(re.findall(r'"([a-z_]+)"', call))
    return sfx, music


def build_specs(config: dict) -> list[dict]:
    """Croise manifeste, code et prompts en une liste de sons à produire.

    Le manifeste est le contrat avec le générateur, le code celui avec le
    moteur. Un écart entre les deux se corrige avant de dépenser, pas après."""
    m_sfx, m_music = read_manifest()
    c_sfx, c_music = read_code()

    for label, declared, played in (("bruitage", set(m_sfx), c_sfx),
                                    ("musique", set(m_music), c_music)):
        if declared != played:
            orphelins = ", ".join(sorted(declared - played)) or "—"
            manquants = ", ".join(sorted(played - declared)) or "—"
            raise Fail(f"{label}s : le manifeste et le code divergent.\n"
                       f"  déclarés mais jamais joués : {orphelins}\n"
                       f"  joués mais non déclarés    : {manquants}\n"
                       f"  corriger l'un des deux avant de générer")

    defaults = config.get("defaults", {})
    specs = []
    for kind, keys, out_dir, ext in (("sfx", m_sfx, SFX_DIR, ".wav"),
                                     ("music", m_music, MUSIC_DIR, ".mp3")):
        for key in keys:
            entry = config.get(kind, {}).get(key)
            if entry is None:
                raise Fail(f"{kind}/{key} : aucun prompt dans {PROMPTS.name}")
            spec = dict(defaults)
            spec.update(entry)
            spec.update({"kind": kind, "key": key, "out": out_dir / (key + ext)})
            if not spec.get("prompt"):
                raise Fail(f"{kind}/{key} : prompt vide")
            specs.append(spec)
    return specs


def prompt_for(config: dict, spec: dict) -> str:
    """Sujet + style. Le style commun ne vaut que pour les bruitages : une
    musique se décrit entièrement dans son propre prompt."""
    if spec["kind"] != "sfx":
        return spec["prompt"]
    style = spec.get("sfx_style", config["style"])
    return f"{spec['prompt']}, {style}"


# --------------------------------------------------------------------------
# Générateur
# --------------------------------------------------------------------------

class ElevenLabs:
    """Client ElevenLabs minimal, sur `urllib` — pas de dépendance à installer.

    Les deux endpoints utilisés répondent directement par le fichier audio, pas
    par du JSON : `_call` rend donc des octets bruts, et ne décode du JSON que
    pour lire un message d'erreur."""

    RETRIES = 4

    def __init__(self, token: str, timeout: int = 300):
        self.token = token
        self.timeout = timeout
        self.spent = 0.0

    def _call(self, path: str, payload: dict, query: str = "") -> bytes:
        """Un appel, avec reprise sur incident réseau.

        Réessayer peut facturer deux fois une génération dont la réponse s'est
        perdue en route — l'API n'offre pas de clé d'idempotence. C'est le prix
        d'une session qui va au bout, et `--budget` reste le garde-fou. Les
        erreurs définitives (jeton refusé, quota épuisé, requête invalide)
        échouent en revanche du premier coup."""
        data = json.dumps(payload).encode()
        last = ""
        for attempt in range(1, self.RETRIES + 1):
            req = urllib.request.Request(API + path + query, data=data, method="POST",
                                         headers={"xi-api-key": self.token,
                                                  "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    return resp.read()
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode(errors="replace")[:400]
                if exc.code == 401:
                    raise Fail(f"jeton ElevenLabs refusé (401) : {detail}") from None
                if exc.code == 402:
                    # Deux causes distinctes sous le même code : le quota épuisé,
                    # et l'endpoint réservé aux plans payants. La Music API en
                    # fait partie, la Sound Effects API non — un compte gratuit
                    # produit donc les 21 bruitages mais aucune musique.
                    if "paid_plan_required" in detail:
                        raise Fail(f"endpoint réservé aux plans payants (402) : {detail}") from None
                    raise Fail(f"crédits ElevenLabs épuisés (402) : {detail}") from None
                if exc.code == 422:
                    raise Fail(f"{path} → requête invalide (422) : {detail}") from None
                last = f"HTTP {exc.code} : {detail}"
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                # `socket.timeout` est un `TimeoutError`, pas une `URLError` :
                # ne l'attraper que par `URLError` laissait la session mourir.
                last = f"{type(exc).__name__} : {getattr(exc, 'reason', exc)}"
            if attempt == self.RETRIES:
                raise Fail(f"{path} après {self.RETRIES} tentatives — {last}")
            pause = 5 * 2 ** (attempt - 1)
            print(f"    {last} — nouvelle tentative dans {pause} s "
                  f"({attempt}/{self.RETRIES - 1})", file=sys.stderr)
            time.sleep(pause)
        raise Fail("inatteignable")

    def sfx(self, prompt: str, spec: dict) -> bytes:
        """PCM 16 bits mono 44,1 kHz, brut. Le WAV est écrit ici, pas là-bas."""
        payload = {
            "text": prompt,
            "duration_seconds": float(spec["seconds"]),
            "prompt_influence": float(spec.get("prompt_influence", 0.45)),
            "loop": bool(spec.get("loop", False)),
        }
        raw = self._call("/sound-generation", payload, "?output_format=pcm_44100")
        self.spent += COST_SFX
        return raw

    def music(self, prompt: str, spec: dict) -> bytes:
        payload = {
            "prompt": prompt,
            "music_length_ms": int(float(spec["seconds"]) * 1000),
        }
        raw = self._call("/music", payload, "?output_format=mp3_44100_128")
        self.spent += COST_MUSIC_PER_MINUTE * float(spec["seconds"]) / 60.0
        return raw


class Fake:
    """Générateur factice : valide toute la chaîne sans dépenser un crédit.

    Il ne cherche pas à imiter le prompt, seulement à rendre un signal aux
    bonnes dimensions, audible et reconnaissable : un bruit filtré pour les
    bruitages, avec une enveloppe percussive, un silence de tête et de queue
    pour éprouver le rognage. Une hauteur par clé, donc un son différent par
    bruitage — de quoi entendre au premier coup d'œil, ou d'oreille, un fichier
    tombé sous le mauvais nom.

    La musique factice reste du PCM déguisé : produire un vrai mp3 sans
    encodeur n'a pas de sens, et le point à vérifier ici est le nommage et le
    bouclage de l'import, pas le contenu."""

    def __init__(self):
        self.spent = 0.0

    def sfx(self, _prompt: str, spec: dict) -> bytes:
        rate = wavtool.RATE
        rng = random.Random(spec["key"])
        base = 110.0 * 2 ** (rng.randrange(0, 24) / 12.0)
        # L'API arrondit la durée demandée vers le haut et remplit de silence :
        # le faux la reproduit, sinon `--fake` ne testerait jamais le rognage.
        head = int(rate * 0.08)
        body = int(rate * float(spec["seconds"]))
        tail = int(rate * 0.35)
        out = array.array("h", [0] * (head + body + tail))
        phase = 0.0
        for i in range(body):
            t = i / body
            env = math.exp(-3.5 * t)
            phase += 2 * math.pi * base * (1.0 + 0.5 * (1.0 - t)) / rate
            noise = rng.uniform(-0.35, 0.35) * env
            out[head + i] = int(22000 * env * (0.65 * math.sin(phase) + noise))
        return wavtool.to_pcm(wavtool.interleave(out))

    def music(self, _prompt: str, spec: dict) -> bytes:
        rate = wavtool.RATE
        rng = random.Random(spec["key"])
        root = 55.0 * 2 ** (rng.randrange(0, 12) / 12.0)
        total = int(rate * float(spec["seconds"]))
        out = array.array("h", [0] * total)
        for i in range(total):
            t = i / rate
            beat = math.exp(-6.0 * (t % 0.5))
            out[i] = int(9000 * beat * math.sin(2 * math.pi * root * t))
        return wavtool.to_pcm(wavtool.interleave(out))


# --------------------------------------------------------------------------
# Post-traitement, hors ligne
# --------------------------------------------------------------------------

def render_sfx(raw: bytes, spec: dict) -> bytes:
    """PCM brut → WAV prêt à déposer.

    Cinq passes, dans cet ordre : ramener le flux entrelacé en mono, rogner le
    silence que l'API ajoute,
    plafonner à la durée du manifeste, fondre les deux bouts pour ne pas
    claquer, puis aligner la crête. Normaliser en dernier garantit que le
    niveau annoncé est bien celui du fichier écrit."""
    samples = wavtool.downmix(wavtool.from_pcm(raw), int(spec.get("channels", 2)))
    if not samples:
        raise Fail("réponse audio vide")
    samples = wavtool.trim(samples, floor_db=float(spec.get("trim_db", -45.0)))
    samples = wavtool.cap(samples, float(spec.get("max_seconds", 2.0)))
    samples = wavtool.fade(samples)
    samples = wavtool.normalize(samples, float(spec.get("target_db", -1.0)))
    return wavtool.encode_wav(samples)


def render_music(raw: bytes, spec: dict) -> bytes:
    """La musique est déjà encodée par l'API : rien à retoucher ici.

    Sauf en `--fake`, où le contenu est du PCM : on l'habille en WAV pour qu'il
    soit au moins lisible, en gardant le nom en `.mp3` — la vérification porte
    sur le branchement, pas sur le codec."""
    if raw[:3] == b"ID3" or raw[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
        return raw
    return wavtool.encode_wav(wavtool.downmix(wavtool.from_pcm(raw)))


def set_loop(path: Path) -> bool:
    """Force `loop=true` dans le `.import` d'une musique.

    Sans cela la piste se joue une fois et le combat continue en silence. Le
    `.import` est écrit par Godot au premier `scripts/build.sh` : tant qu'il
    n'existe pas, il n'y a rien à corriger — d'où `--loops`, à relancer après
    le build."""
    meta = path.with_suffix(path.suffix + ".import")
    if not meta.exists():
        return False
    text = meta.read_text(encoding="utf-8")
    if re.search(r"^loop=true$", text, re.M):
        return False
    if re.search(r"^loop=", text, re.M):
        text = re.sub(r"^loop=.*$", "loop=true", text, count=1, flags=re.M)
    else:
        text = re.sub(r"^\[params\]$", "[params]\n\nloop=true", text, count=1, flags=re.M)
    meta.write_text(text, encoding="utf-8")
    return True


# --------------------------------------------------------------------------

def find_token(explicit: str | None) -> str:
    if explicit:
        return explicit.strip()
    if os.environ.get("ELEVENLABS_TOKEN"):
        return os.environ["ELEVENLABS_TOKEN"].strip()
    for path in (ROOT / ".elevenlabs-token", Path.home() / ".config/elevenlabs/token"):
        if path.exists():
            return path.read_text(encoding="utf-8").strip()
    raise Fail("aucun jeton ElevenLabs : définir $ELEVENLABS_TOKEN, ou écrire le "
               "jeton dans .elevenlabs-token (ignoré par git)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="sons à produire, séparés par des virgules")
    ap.add_argument("--kind", choices=("sfx", "music"), help="ne traiter qu'une famille")
    ap.add_argument("--list", action="store_true", help="lister sans rien produire")
    ap.add_argument("--dry-run", action="store_true", help="afficher les prompts, sans appel")
    ap.add_argument("--assemble-only", action="store_true",
                    help="rejouer le post-traitement depuis le cache, sans appel")
    ap.add_argument("--force", action="store_true", help="ignorer le cache et tout regénérer")
    ap.add_argument("--budget", type=float, default=0.0,
                    help="arrêter dès que le coût estimé dépasse ce montant (USD)")
    ap.add_argument("--loops", action="store_true",
                    help="forcer loop=true dans les .import des musiques, puis sortir")
    ap.add_argument("--token", help="jeton d'API (par défaut : $ELEVENLABS_TOKEN)")
    ap.add_argument("--fake", action="store_true",
                    help="générateur factice : valide la chaîne sans appeler l'API")
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)

    config = json.loads(PROMPTS.read_text(encoding="utf-8"))
    specs = build_specs(config)

    if args.loops:
        touched = [s["key"] for s in specs
                   if s["kind"] == "music" and s["out"].exists() and set_loop(s["out"])]
        if touched:
            print(f"loop=true posé sur : {', '.join(touched)}")
        else:
            print("rien à corriger (déjà bouclées, ou .import pas encore créés — "
                  "lancer scripts/build.sh d'abord)")
        return 0

    if args.kind:
        specs = [s for s in specs if s["kind"] == args.kind]
    if args.only:
        wanted = {s.strip() for s in args.only.split(",")}
        unknown = wanted - {s["key"] for s in specs}
        if unknown:
            raise Fail(f"son(s) inconnu(s) : {', '.join(sorted(unknown))}")
        specs = [s for s in specs if s["key"] in wanted]

    if args.list:
        for spec in specs:
            done = "✓" if spec["out"].exists() else " "
            print(f" {done} {spec['kind']:<5} {spec['key']:<16} {spec['seconds']:>5.1f}s   "
                  f"{spec['out'].relative_to(GODOT)}")
        estimate = sum(COST_SFX if s["kind"] == "sfx"
                       else COST_MUSIC_PER_MINUTE * s["seconds"] / 60.0 for s in specs)
        print(f"\n{len(specs)} son(s), coût estimé si tout est regénéré : {estimate:.2f} $")
        return 0

    client = None
    if args.fake:
        client = Fake()
    elif not (args.dry_run or args.assemble_only):
        client = ElevenLabs(find_token(args.token))

    produced: list[str] = []
    failed: list[str] = []
    for spec in specs:
        kind, key = spec["kind"], spec["key"]
        prompt = prompt_for(config, spec)
        print(f"» {kind}/{key} ({spec['seconds']:g}s)")
        if args.dry_run:
            print(f"    {prompt}")
            continue

        blob = CACHE / kind / (key + ".raw")
        raw = blob.read_bytes() if blob.exists() and not args.force else None
        if raw is None:
            if args.assemble_only:
                print("  pas en cache, ignoré")
                continue
            try:
                raw = client.sfx(prompt, spec) if kind == "sfx" else client.music(prompt, spec)
            except Fail as exc:
                # Un son qui casse ne doit pas emporter les vingt suivants.
                print(f"  échec : {exc}", file=sys.stderr)
                failed.append(key)
                continue
            blob.parent.mkdir(parents=True, exist_ok=True)
            blob.write_bytes(raw)
        else:
            print("  (cache)")

        out = spec["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        try:
            rendered = render_sfx(raw, spec) if kind == "sfx" else render_music(raw, spec)
        except Fail as exc:
            print(f"  échec : {exc}", file=sys.stderr)
            failed.append(key)
            continue
        out.write_bytes(rendered)
        produced.append(key)
        if kind == "sfx":
            samples, rate = wavtool.decode_wav(rendered)
            print(f"  → {out.relative_to(ROOT)} ({wavtool.duration(samples, rate):.2f}s)")
        else:
            set_loop(out)
            print(f"  → {out.relative_to(ROOT)} ({len(rendered) / 1024:.0f} Ko)")

        if client and args.budget and client.spent >= args.budget:
            print(f"Budget de {args.budget:.2f} $ atteint, arrêt.", file=sys.stderr)
            break

    if client:
        print(f"\nCoût estimé de la session : {client.spent:.2f} $")
    if produced:
        print(f"{len(produced)} son(s) écrit(s). Vérifier avec :\n"
              f"  scripts/build.sh && scripts/check.sh && scripts/gen-audio.py --loops")
    if failed:
        print(f"{len(failed)} son(s) en échec : {', '.join(failed)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Fail as exc:
        print(f"erreur : {exc}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\ninterrompu — le cache est conservé, relancer reprendra où on en était",
              file=sys.stderr)
        sys.exit(130)
