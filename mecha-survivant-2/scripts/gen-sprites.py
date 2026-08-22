#!/usr/bin/env python3
"""Génère les planches de sprites du jeu depuis un générateur de pixel art.

Le découpage n'est pas décidé ici : il est lu dans `SHEETS`
(`godot/scenes/fx/sprite_or_shape.gd`) et dans `godot/assets/MANIFEST.md`, qui
restent les deux sources de vérité. Ce script se contente de demander les
frames au générateur, puis de les assembler en planches horizontales aux
dimensions exactes attendues par le code.

  scripts/gen-sprites.py --list              # ce qu'il y a à produire
  scripts/gen-sprites.py --dry-run           # les prompts, sans rien appeler
  scripts/gen-sprites.py --only enemy_zombie # une planche
  scripts/gen-sprites.py --budget 5          # tout, en s'arrêtant à 5 $

Une génération = un appel : une image fixe, ou une animation entière quel que
soit son nombre de frames. Une planche animée coûte donc 1 + le nombre
d'animations. `--redo walk,death` refait une animation sans repayer le reste.

Les gestes se décrivent par leur **état final** : « collapsing into a heap »
rend un zombie toujours debout, « ending flat on the ground » le couche.

Les frames brutes sont mises en cache dans `.gen-cache/` : relancer ne
regénère que ce qui manque. `--force` les jette, `--assemble-only` réassemble
sans appeler quoi que ce soit.

Le jeton d'API est lu dans $PIXELLAB_TOKEN, sinon dans `.pixellab-token` à la
racine du projet (ignoré par git), sinon dans ~/.config/pixellab/token.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngtool import Image, strip  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SHEETS_GD = ROOT / "godot/scenes/fx/sprite_or_shape.gd"
MANIFEST = ROOT / "godot/assets/MANIFEST.md"
PROMPTS = ROOT / "scripts/sprite-prompts.json"
OUT_DIR = ROOT / "godot/assets/sprites"
CACHE = ROOT / ".gen-cache"

API = "https://api.pixellab.ai/v2"
RD_API = "https://api.retrodiffusion.ai/v1"

## L'API refuse toute toile de moins de 32×32 (« Canvas must be size 32x32 area
## or larger »), alors que son propre spec OpenAPI annonce un minimum de 16. Les
## cases de 16 px du manifeste — tous les projectiles — sont donc générées en
## 32 px puis réduites de moitié à l'assemblage : un rapport entier, donc un
## pixel art qui reste net.
GEN_MIN = 32


class Fail(Exception):
    pass


# --------------------------------------------------------------------------
# Spécification : ce qu'il faut produire, lu là où le code le déclare déjà
# --------------------------------------------------------------------------

def read_sheets() -> dict:
    """Extrait le dictionnaire `SHEETS` du GDScript.

    Le bloc est du JSON valide une fois les virgules terminales retirées ; le
    relire plutôt que le recopier ici évite qu'un découpage changé d'un côté
    laisse l'autre en arrière."""
    text = SHEETS_GD.read_text(encoding="utf-8")
    match = re.search(r"const SHEETS := \{(.*?)^\}", text, re.S | re.M)
    if not match:
        raise Fail(f"bloc SHEETS introuvable dans {SHEETS_GD}")
    body = re.sub(r"#.*", "", match.group(1))
    body = re.sub(r",\s*(?=[}\]])", "", "{" + body + "}")
    return json.loads(body)


def read_manifest() -> dict:
    """Taille de tuile et nombre de cases, depuis le tableau du manifeste."""
    rows = {}
    pattern = re.compile(r"^\|\s*`([\w]+)\.png`\s*\|\s*(\d+)×(\d+)\s*\|\s*(\d+)\s*\|")
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        m = pattern.match(line)
        if m:
            name, w, h, cases = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))
            if w != h:
                raise Fail(f"{name}: cases non carrées ({w}×{h}), non géré")
            rows[name] = {"tile": w, "cases": cases}
    if not rows:
        raise Fail(f"aucune ligne d'asset lue dans {MANIFEST}")
    return rows


def build_specs(config: dict) -> list[dict]:
    """Croise manifeste, SHEETS et prompts en une liste de planches à produire.

    Toute divergence entre les deux sources est une erreur : le manifeste sert
    de contrat avec l'artiste, SHEETS de contrat avec le moteur, et un sprite
    produit sur la foi d'un découpage périmé est un sprite à refaire."""
    sheets = read_sheets()
    manifest = read_manifest()
    assets = config["assets"]
    specs = []

    for name, row in manifest.items():
        sheet = sheets.get(name, {})
        cases = row["cases"]
        if sheet and int(sheet.get("hframes", 1)) != cases:
            raise Fail(f"{name}: MANIFEST annonce {cases} cases, SHEETS "
                       f"{sheet.get('hframes')} — corriger l'un des deux avant de générer")
        entry = assets.get(name)
        if entry is None:
            print(f"  (ignoré) {name}: aucun prompt dans {PROMPTS.name}", file=sys.stderr)
            continue

        anims = sheet.get("anims")
        if entry.get("mode"):
            mode = entry["mode"]
        elif anims:
            mode = "animated"
        elif cases > 1:
            mode = "sequence"
        else:
            mode = "single"

        if mode == "animated":
            parts = [{"anim": a, "start": v[0], "count": v[1],
                      "action": entry["actions"][a]} for a, v in anims.items()]
            covered = sum(p["count"] for p in parts)
            if covered != cases:
                raise Fail(f"{name}: les animations couvrent {covered} cases sur {cases}")
        elif mode == "sequence":
            parts = [{"anim": "sequence", "start": 0, "count": cases,
                      "action": entry["action"]}]
        elif mode == "variations":
            parts = []
        elif mode == "frames":
            if len(entry["frames"]) != cases:
                raise Fail(f"{name}: {len(entry['frames'])} prompts pour {cases} cases")
            parts = []
        elif mode == "single":
            parts = []
        else:
            raise Fail(f"{name}: mode inconnu « {mode} »")
        if mode == "variations" and cases < 2:
            raise Fail(f"{name}: le mode variations demande au moins deux cases")

        specs.append({"name": name, "tile": row["tile"], "cases": cases,
                      "mode": mode, "parts": parts, "entry": entry})
    return specs


def prompt_for(config: dict, entry: dict, subject: str | None = None) -> str:
    """Sujet + style. Le style est surchargeable par asset : une dalle de sol
    ne veut pas du « transparent background » commun aux entités."""
    subject = subject or entry["subject"]
    return f"{subject}, {entry.get('style', config['style'])}"


def options_for(config: dict, entry: dict) -> dict:
    opts = dict(config.get("defaults", {}))
    opts.update(entry.get("options", {}))
    return opts


# --------------------------------------------------------------------------
# Générateur
# --------------------------------------------------------------------------

class PixelLab:
    """Client PixelLab minimal, sur `urllib` — pas de dépendance à installer.

    Deux endpoints suffisent : `create-image-pixflux` produit une image fixe à
    la taille voulue (16 à 400 px), `animate-with-text-v3` en déroule une
    animation en gardant la taille de la frame de départ. La v3 impose un
    nombre de frames **pair** entre 4 et 16 : les animations de compte impair
    (le dash à 3 cases, l'impact à 5) sont demandées au pair supérieur puis
    échantillonnées."""

    RETRIES = 4

    def __init__(self, token: str, timeout: int = 420):
        self.token = token
        self.timeout = timeout
        self.spent = 0.0        # en dollars, pour un compte à crédits
        self.generations = 0.0  # en générations, pour un abonnement ou un essai

    def _call(self, path: str, payload: dict | None = None, method: str = "POST") -> dict:
        """Un appel, avec reprise sur incident réseau.

        Une session complète tient l'API une heure durant : une lecture qui
        expire ou un 502 passager ne doit pas emporter les vingt planches
        suivantes. Les erreurs qui ne passeront jamais (jeton refusé, crédits
        épuisés, requête invalide) échouent en revanche du premier coup.

        Réessayer un POST de génération peut le facturer deux fois si la
        réponse s'est perdue en route — l'API n'offre pas de clé
        d'idempotence. C'est le prix d'une session qui va au bout ; le
        `--budget` reste le garde-fou."""
        data = json.dumps(payload).encode() if payload is not None else None
        last = ""
        for attempt in range(1, self.RETRIES + 1):
            req = urllib.request.Request(API + path, data=data, method=method, headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            })
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    body = json.loads(resp.read())
                break
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode(errors="replace")[:400]
                if exc.code == 401:
                    raise Fail("jeton PixelLab refusé (401)") from None
                if exc.code == 402:
                    raise Fail("crédits ou générations PixelLab épuisés (402)") from None
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
        usage = (body or {}).get("usage") or {}
        if usage.get("usd"):
            self.spent += float(usage["usd"])
        if usage.get("generations"):
            self.generations += float(usage["generations"])
        return body

    def balance(self) -> dict:
        return self._call("/balance", method="GET")

    def _wait(self, job_id: str) -> dict:
        """Attend un job asynchrone. Les générations durent des dizaines de
        secondes : on sonde doucement plutôt que de marteler l'API."""
        delay = 3.0
        for _ in range(120):
            time.sleep(delay)
            job = self._call(f"/background-jobs/{job_id}", method="GET")
            status = (job.get("status") or "").lower()
            if status in ("completed", "complete", "succeeded", "success"):
                return job.get("last_response") or {}
            if status in ("failed", "error", "cancelled"):
                raise Fail(f"job {job_id} en échec : {json.dumps(job)[:300]}")
            delay = min(delay * 1.3, 15.0)
        raise Fail(f"job {job_id} toujours en cours après plusieurs minutes")

    @staticmethod
    def _images(payload: dict) -> list[Image]:
        for key in ("images", "frames", "animation", "results"):
            items = payload.get(key)
            if isinstance(items, list) and items:
                out = []
                for item in items:
                    b64 = item.get("base64") if isinstance(item, dict) else item
                    out.append(Image.decode(base64.b64decode(b64)))
                return out
        if "image" in payload:
            return [Image.decode(base64.b64decode(payload["image"]["base64"]))]
        raise Fail(f"aucune image dans la réponse : {json.dumps(payload)[:300]}")

    def create(self, description: str, tile: int, opts: dict, seed: int) -> Image:
        payload = {
            "description": description,
            "image_size": {"width": tile, "height": tile},
            "no_background": bool(opts.get("no_background", True)),
            "seed": seed,
        }
        for key in ("view", "direction", "outline", "shading", "detail",
                    "text_guidance_scale", "isometric"):
            if opts.get(key) not in (None, "none"):
                payload[key] = opts[key]
        return self._images(self._call("/create-image-pixflux", payload))[0]

    def animate(self, first: Image, action: str, count: int, seed: int) -> list[Image]:
        asked = count if count % 2 == 0 else count + 1
        asked = max(4, min(16, asked))
        payload = {
            "first_frame": {"type": "base64", "base64":
                            base64.b64encode(first.encode()).decode(), "format": "png"},
            "action": action,
            "frame_count": asked,
            "no_background": True,
            "seed": seed,
        }
        body = self._call("/animate-with-text-v3", payload)
        if body.get("background_job_id"):
            body = self._wait(body["background_job_id"])
        return fit(self._images(body), count)


class RetroDiffusion:
    """Client Retro Diffusion.

    Mieux taillé que PixelLab pour ce jeu : les tuiles de 16 px passent
    nativement (12 à 512), `num_images` rend plusieurs images en un appel — donc
    une planche de variantes pour le prix d'une — et les styles `rd_tile__*`
    produisent des textures **raccordables par construction**, ce qui était le
    défaut du premier sol.

    Le style compte autant que le prompt : il est déclaré par asset dans
    `sprite-prompts.json` sous `rd_style`. `GET /v1/styles/selector` en donne la
    liste avec, pour chacun, ses bornes de dimensions."""

    RETRIES = 4

    def __init__(self, token: str, timeout: int = 420):
        self.token = token
        self.timeout = timeout
        self.spent = 0.0
        self.generations = 0.0

    def _call(self, payload: dict | None = None, path: str = "/inferences",
              method: str = "POST") -> dict:
        data = json.dumps(payload).encode() if payload is not None else None
        last = ""
        for attempt in range(1, self.RETRIES + 1):
            req = urllib.request.Request(RD_API + path, data=data, method=method, headers={
                "X-RD-Token": self.token, "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    body = json.loads(resp.read())
                break
            except urllib.error.HTTPError as exc:
                detail = exc.read().decode(errors="replace")[:400]
                if exc.code in (401, 403):
                    raise Fail("jeton Retro Diffusion refusé") from None
                if exc.code == 402:
                    raise Fail("solde Retro Diffusion épuisé") from None
                if exc.code == 400:
                    # Un champ refusé par le style choisi : réessayer n'y changera
                    # rien. C'est ainsi que `tile_x` sur un style `rd_tile__*` se
                    # signale — ces styles sont déjà raccordables.
                    raise Fail(f"requête refusée (400) : {detail}") from None
                last = f"HTTP {exc.code} : {detail}"
            except (urllib.error.URLError, TimeoutError, OSError) as exc:
                last = f"{type(exc).__name__} : {getattr(exc, 'reason', exc)}"
            if attempt == self.RETRIES:
                raise Fail(f"Retro Diffusion après {self.RETRIES} tentatives — {last}")
            pause = 5 * 2 ** (attempt - 1)
            print(f"    {last} — nouvelle tentative dans {pause} s", file=sys.stderr)
            time.sleep(pause)
        self.spent += float(body.get("balance_cost") or 0.0)
        return body

    def balance(self) -> dict:
        b = self._call(path="/inferences/credits", method="GET")
        return {"credits": f"{b.get('balance')} $ ({b.get('credits')} crédits)"}

    @staticmethod
    def _images(body: dict) -> list[Image]:
        images = body.get("base64_images") or []
        if not images:
            raise Fail(f"aucune image rendue : {json.dumps(body)[:300]}")
        return [Image.decode(base64.b64decode(b)) for b in images]

    def _payload(self, description: str, tile: int, opts: dict, seed: int) -> dict:
        style = opts.get("rd_style")
        if not style:
            raise Fail("aucun `rd_style` déclaré pour cet asset "
                       "(voir GET /v1/styles/selector)")
        return {"prompt": description, "prompt_style": style,
                "width": tile, "height": tile, "seed": seed,
                "remove_bg": bool(opts.get("no_background", True))}

    def cost(self, description: str, tile: int, opts: dict, seed: int, n: int) -> float:
        """Chiffrage à blanc, gratuit : `check_cost` ne génère ni ne facture."""
        p = dict(self._payload(description, tile, opts, seed), num_images=n, check_cost=True)
        return float(self._call(p).get("balance_cost") or 0.0)

    def create(self, description: str, tile: int, opts: dict, seed: int) -> Image:
        return self._images(self._call(
            dict(self._payload(description, tile, opts, seed), num_images=1)))[0]

    def create_many(self, description: str, tile: int, opts: dict, seed: int,
                    n: int) -> list[Image]:
        """`n` images en un seul appel — nettement moins cher que `n` appels."""
        return self._images(self._call(
            dict(self._payload(description, tile, opts, seed), num_images=n)))

    def vary(self, base: Image, description: str, tile: int, opts: dict, seed: int,
             n: int) -> list[Image]:
        """Variantes d'une image existante, qui en gardent la texture et la
        palette. C'est ce qui donne un jeu de dalles cohérent là où `n` tirages
        indépendants donnent un patchwork."""
        p = dict(self._payload(description, tile, opts, seed), num_images=n,
                 prompt_style=opts.get("rd_vary_style", "rd_tile__tile_variation"),
                 input_image=base64.b64encode(base.encode()).decode())
        return self._images(self._call(p))

    def animate(self, first: Image, action: str, count: int, seed: int) -> list[Image]:
        """Animation rendue en planche, puis redécoupée.

        Les styles d'animation imposent leur taille d'entrée (64 ou 128 px) :
        la frame de base y est ramenée, et les frames rendues repartent à la
        taille de la case à l'assemblage. `frames_duration` n'accepte que
        4, 6, 8, 10, 12 ou 16."""
        allowed = [4, 6, 8, 10, 12, 16]
        asked = next((a for a in allowed if a >= count), 16)
        size = 128 if first.width > 64 else 64
        body = self._call({
            "prompt": action,
            "prompt_style": "rd_animation__big_animation" if size == 128
                            else "rd_animation__any_animation",
            "width": size, "height": size, "num_images": 1,
            "frames_duration": asked, "return_spritesheet": True,
            "remove_bg": True, "seed": seed,
            "input_image": base64.b64encode(first.resized(size, size).encode()).decode(),
        })
        sheet = self._images(body)[0]
        frames = [sheet.crop(i * size, 0, size, size)
                  for i in range(max(1, sheet.width // size))]
        return fit(frames, count)


class Fake:
    """Générateur factice : des aplats colorés aux bonnes dimensions.

    Il ne sert qu'à valider la chaîne — découpage, assemblage, import Godot,
    rendu en jeu — sans appeler l'API ni dépenser de crédit. Chaque case reçoit
    une teinte distincte et un repère de coin, de quoi voir immédiatement une
    planche découpée de travers."""

    spent = 0.0
    generations = 0.0

    def __init__(self, *_a, **_kw):
        self._n = 0

    @staticmethod
    def balance() -> dict:
        return {"credits": "factice"}

    def _tint(self, tile: int) -> Image:
        self._n += 1
        hue = (self._n * 37) % 360
        sector, frac = divmod(hue / 60.0, 1.0)
        top = 230
        low = 60
        mid = int(low + (top - low) * frac)
        wheel = [(top, mid, low), (mid, top, low), (low, top, mid),
                 (low, mid, top), (mid, low, top), (top, low, mid)]
        r, g, b = wheel[int(sector) % 6]
        img = Image(tile, tile)
        for y in range(tile):
            for x in range(tile):
                inside = 2 <= x < tile - 2 and 2 <= y < tile - 2
                corner = x < tile // 4 and y < tile // 4
                px = (255, 255, 255, 255) if corner else (r, g, b, 255 if inside else 0)
                off = (y * tile + x) * 4
                img.pixels[off:off + 4] = bytes(px)
        return img

    def create(self, _description: str, tile: int, _opts: dict, _seed: int) -> Image:
        return self._tint(tile)

    def animate(self, first: Image, _action: str, count: int, _seed: int) -> list[Image]:
        return [self._tint(first.width) for _ in range(count)]


def fit(frames: list[Image], count: int) -> list[Image]:
    """Ramène une séquence au nombre de cases attendu, en échantillonnant
    régulièrement : le générateur ne rend pas toujours le compte demandé, et
    les comptes impairs sont demandés au pair supérieur."""
    if len(frames) == count:
        return frames
    if not frames:
        raise Fail("séquence vide")
    return [frames[min(len(frames) - 1, round(i * len(frames) / count))] for i in range(count)]


# --------------------------------------------------------------------------
# Cache disque : une frame générée est payée, elle ne se regénère pas seule
# --------------------------------------------------------------------------

def cached(path: Path) -> Image | None:
    if path.exists():
        try:
            return Image.decode(path.read_bytes())
        except Exception as exc:  # cache abîmé : on le refait plutôt que planter
            print(f"  cache illisible ({path.name}: {exc}), régénération", file=sys.stderr)
    return None


def store(path: Path, img: Image) -> Image:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(img.encode())
    return img


# --------------------------------------------------------------------------
# Production d'une planche
# --------------------------------------------------------------------------

def generate(spec: dict, config: dict, client: PixelLab | None, args) -> Image | None:
    name, tile, cases = spec["name"], spec["tile"], spec["cases"]
    entry, mode = spec["entry"], spec["mode"]
    gen_tile = max(tile, GEN_MIN)
    opts = options_for(config, entry)
    work = CACHE / name
    seed = args.seed + (abs(hash(name)) % 10_000)
    frames: list[Image | None] = [None] * cases
    redo = {r.strip() for r in (args.redo or "").split(",") if r.strip()}

    def stale(key: str) -> bool:
        """Une frame en cache est une frame payée : elle n'est refaite que sur
        demande explicite (`--force`, ou `--redo <animation>`)."""
        return args.force or key in redo

    if mode == "variations":
        # Une dalle de base, puis ses variantes : elles en héritent la texture et
        # la palette. Quatre tirages indépendants donneraient un patchwork.
        base_path = work / "base.png"
        base = None if stale("base") else cached(base_path)
        if base is None:
            if client is None:
                print(f"    base : {prompt_for(config, entry)}")
                print(f"    ×{cases - 1} variantes : {entry['variations']}")
                return None
            base = store(base_path, client.create(
                prompt_for(config, entry), gen_tile, opts, seed))
        frames[0] = base
        paths = [work / f"var_{i:02d}.png" for i in range(cases - 1)]
        got = [None if stale("variations") else cached(q) for q in paths]
        if any(g is None for g in got):
            if not hasattr(client, "vary"):
                raise Fail(f"{name}: le mode variations demande --provider retrodiffusion")
            got = [store(q, v) for q, v in zip(paths, client.vary(
                base, entry["variations"], gen_tile, opts, seed, cases - 1))]
        for i, img in enumerate(got):
            frames[i + 1] = img
    elif mode == "frames":
        for i, subject in enumerate(entry["frames"]):
            path = work / f"case_{i:02d}.png"
            img = None if stale(f"case_{i}") else cached(path)
            if img is None:
                if client is None:
                    print(f"    case {i}: {prompt_for(config, entry, subject)}")
                    continue
                img = store(path, client.create(
                    prompt_for(config, entry, subject), gen_tile, opts, seed + i))
            frames[i] = img
    else:
        base_path = work / "base.png"
        base = None if stale("base") else cached(base_path)
        if base is None:
            if client is None:
                print(f"    base : {prompt_for(config, entry)}")
            else:
                base = store(base_path, client.create(
                    prompt_for(config, entry), gen_tile, opts, seed))
        if base is None and mode != "single":
            base = cached(base_path)  # récupérée du cache pour servir de référence
        if mode == "single":
            frames[0] = base
        else:
            for part in spec["parts"]:
                anim, count, start = part["anim"], part["count"], part["start"]
                paths = [work / f"{anim}_{i:02d}.png" for i in range(count)]
                got = [None if stale(anim) else cached(p) for p in paths]
                if any(g is None for g in got):
                    if client is None:
                        print(f"    {anim} ({count} cases {start}-{start + count - 1}) : "
                              f"{part['action']}")
                        continue
                    if base is None:
                        raise Fail(f"{name}: pas de frame de base pour animer")
                    got = client.animate(base, part["action"], count, seed)
                    got = [store(p, g) for p, g in zip(paths, got)]
                for i, img in enumerate(got):
                    frames[start + i] = img

    if client is None:
        return None
    missing = [i for i, f in enumerate(frames) if f is None]
    if missing:
        raise Fail(f"{name}: cases manquantes {missing}")
    for i, img in enumerate(frames):
        if img.opaque_ratio() < 0.01:
            print(f"  ⚠ {name}: la case {i} est quasi vide — prompt à revoir", file=sys.stderr)
    return strip(frames, tile)


def assemble_from_cache(spec: dict) -> Image | None:
    """Réassemble une planche depuis le cache, sans rien générer."""
    work = CACHE / spec["name"]
    frames: list[Image | None] = [None] * spec["cases"]
    if spec["mode"] == "variations":
        frames[0] = cached(work / "base.png")
        for i in range(spec["cases"] - 1):
            frames[i + 1] = cached(work / f"var_{i:02d}.png")
    elif spec["mode"] == "frames":
        for i in range(spec["cases"]):
            frames[i] = cached(work / f"case_{i:02d}.png")
    elif spec["mode"] == "single":
        frames[0] = cached(work / "base.png")
    else:
        for part in spec["parts"]:
            for i in range(part["count"]):
                frames[part["start"] + i] = cached(work / f"{part['anim']}_{i:02d}.png")
    if any(f is None for f in frames):
        return None
    return strip(frames, spec["tile"])


# --------------------------------------------------------------------------

PROVIDERS = {
    "retrodiffusion": (RetroDiffusion, "RETRODIFFUSION_TOKEN", ".retrodiffusion-token"),
    "pixellab": (PixelLab, "PIXELLAB_TOKEN", ".pixellab-token"),
}


def find_token(explicit: str | None, provider: str) -> str:
    _cls, env, filename = PROVIDERS[provider]
    if explicit:
        return explicit.strip()
    if os.environ.get(env):
        return os.environ[env].strip()
    for path in (ROOT / filename, Path.home() / f".config/{provider}/token"):
        if path.exists():
            return path.read_text(encoding="utf-8").strip()
    raise Fail(f"aucun jeton {provider} : définir ${env}, ou écrire le jeton "
               f"dans {filename} (ignoré par git)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="planches à produire, séparées par des virgules")
    ap.add_argument("--list", action="store_true", help="lister sans rien produire")
    ap.add_argument("--dry-run", action="store_true", help="afficher les prompts, sans appel")
    ap.add_argument("--assemble-only", action="store_true",
                    help="réassembler depuis le cache, sans appel")
    ap.add_argument("--force", action="store_true", help="ignorer le cache et tout regénérer")
    ap.add_argument("--redo", help="ne refaire que ces étapes : base, ou des noms "
                                   "d'animation (walk,death), séparés par des virgules")
    ap.add_argument("--budget", type=float, default=0.0,
                    help="arrêter dès que le coût cumulé dépasse ce montant (USD)")
    ap.add_argument("--max-generations", type=float, default=0.0,
                    help="arrêter après ce nombre de générations (abonnement ou essai, "
                         "où le coût n'est pas facturé en dollars)")
    ap.add_argument("--seed", type=int, default=1789, help="graine, pour des rendus stables")
    ap.add_argument("--token", help="jeton d'API (par défaut : $PIXELLAB_TOKEN)")
    ap.add_argument("--provider", choices=sorted(PROVIDERS), default="retrodiffusion",
                    help="générateur à piloter (retrodiffusion par défaut)")
    ap.add_argument("--fake", action="store_true",
                    help="générateur factice : valide la chaîne sans appeler l'API")
    args = ap.parse_args()
    # Une session complète dure des dizaines de minutes : sans cela la
    # progression reste coincée dans le tampon dès que la sortie est redirigée.
    sys.stdout.reconfigure(line_buffering=True)

    config = json.loads(PROMPTS.read_text(encoding="utf-8"))
    specs = build_specs(config)
    if args.only:
        wanted = {s.strip() for s in args.only.split(",")}
        unknown = wanted - {s["name"] for s in specs}
        if unknown:
            raise Fail(f"planche(s) inconnue(s) : {', '.join(sorted(unknown))}")
        specs = [s for s in specs if s["name"] in wanted]

    if args.list:
        for spec in specs:
            done = "✓" if (OUT_DIR / f"{spec['name']}.png").exists() else " "
            detail = ", ".join(f"{p['anim']}×{p['count']}" for p in spec["parts"]) or spec["mode"]
            print(f" {done} {spec['name']:22} {spec['tile']:>3}px × {spec['cases']:>2} cases   {detail}")
        return 0

    client = None
    if args.fake:
        client = Fake()
    elif not (args.dry_run or args.assemble_only):
        client = PROVIDERS[args.provider][0](find_token(args.token, args.provider))
    if client is not None:
        balance = client.balance()
        print(f"Solde {args.provider} : {balance.get('credits') or balance}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    produced = []
    failed: list[str] = []
    for spec in specs:
        name = spec["name"]
        print(f"» {name} ({spec['tile']}px × {spec['cases']})")
        if args.assemble_only:
            sheet = assemble_from_cache(spec)
            if sheet is None:
                print("  cache incomplet, ignoré")
                continue
        else:
            try:
                sheet = generate(spec, config, client, args)
            except Fail as exc:
                # Un asset qui casse (prompt refusé, dimension interdite) ne doit
                # pas emporter les vingt suivants : on note et on continue.
                print(f"  échec : {exc}", file=sys.stderr)
                failed.append(name)
                continue
        if sheet is None:
            continue
        out = OUT_DIR / f"{name}.png"
        out.write_bytes(sheet.encode())
        produced.append(name)
        print(f"  → {out.relative_to(ROOT)} ({sheet.width}×{sheet.height})")
        if client and args.budget and client.spent >= args.budget:
            print(f"Budget de {args.budget:.2f} $ atteint, arrêt.", file=sys.stderr)
            break
        if client and args.max_generations and client.generations >= args.max_generations:
            print(f"Plafond de {args.max_generations:g} générations atteint, arrêt.",
                  file=sys.stderr)
            break

    if client:
        print(f"\nCoût de la session : {client.spent:.2f} $ / "
              f"{client.generations:g} génération(s)")
    if produced:
        print(f"{len(produced)} planche(s) écrite(s). Vérifier avec :\n"
              f"  scripts/build.sh && scripts/check.sh")
    if failed:
        print(f"{len(failed)} planche(s) en échec : {', '.join(failed)}", file=sys.stderr)
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
