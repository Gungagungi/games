#!/usr/bin/env python3
"""Manipulation de PCM 16 bits mono, en Python pur.

Pendant de `pngtool.py` pour l'audio : le dépôt tient à rester sans dépendance
à installer, et `wave`/`array`/`struct` de la bibliothèque standard suffisent
largement à ce qu'on demande ici — écrire un WAV, rogner le silence, égaliser
le niveau.

Le format est fixé par le manifeste : WAV mono 44,1 kHz 16 bits. Tout ce
module travaille donc sur des `array("h")` d'échantillons signés, et ne
convertit en octets qu'au moment d'écrire.
"""

from __future__ import annotations

import array
import struct
import sys

RATE = 44100
FULL = 32767


def from_pcm(raw: bytes) -> array.array:
    """Octets PCM 16 bits petit-boutiste → échantillons signés.

    Un octet impair en fin de flux est une réponse tronquée : mieux vaut le
    jeter que de décaler tout le reste d'un demi-échantillon."""
    if len(raw) % 2:
        raw = raw[:-1]
    samples = array.array("h")
    samples.frombytes(raw)
    if sys.byteorder == "big":
        samples.byteswap()
    return samples


def to_pcm(samples: array.array) -> bytes:
    if sys.byteorder == "big":
        samples = array.array("h", samples)
        samples.byteswap()
    return samples.tobytes()


def downmix(samples: array.array, channels: int = 2) -> array.array:
    """Entrelacé → mono, par moyenne des canaux.

    **À ne pas oublier sur un flux PCM brut.** Rien dans les octets ne dit
    combien de canaux ils portent : l'API rend du stéréo entrelacé, et le lire
    comme du mono ne produit aucune erreur — le fichier s'écrit, s'importe et
    se joue. Il dure simplement deux fois trop longtemps et sonne une octave
    trop bas, ce qui ne se voit sur aucun contrôle automatique. Le manifeste
    demande du mono ; c'est ici que la conversion a lieu."""
    if channels <= 1:
        return samples
    usable = len(samples) - len(samples) % channels
    return array.array("h", [
        sum(samples[i:i + channels]) // channels
        for i in range(0, usable, channels)
    ])


def interleave(samples: array.array, channels: int = 2) -> array.array:
    """Mono → entrelacé. Sert au générateur factice, pour qu'il éprouve le même
    chemin de décodage que l'API."""
    if channels <= 1:
        return samples
    out = array.array("h", [0] * (len(samples) * channels))
    for i, s in enumerate(samples):
        for c in range(channels):
            out[i * channels + c] = s
    return out


def duration(samples: array.array, rate: int = RATE) -> float:
    return len(samples) / float(rate)


def peak(samples: array.array) -> int:
    return max((abs(s) for s in samples), default=0)


def normalize(samples: array.array, target_db: float = -1.0) -> array.array:
    """Ramène la crête au niveau voulu.

    Les bruitages sortent du générateur à des niveaux très inégaux — un tir
    discret et une explosion saturée dans la même planche sonore. Les aligner
    tous sur la même crête évite d'avoir à régler vingt et un `volume_db` à la
    main dans le code du jeu."""
    top = peak(samples)
    if top == 0:
        return samples
    gain = (FULL * 10.0 ** (target_db / 20.0)) / top
    return array.array("h", [max(-FULL, min(FULL, int(s * gain))) for s in samples])


def trim(samples: array.array, floor_db: float = -45.0,
         pad_ms: int = 5, rate: int = RATE) -> array.array:
    """Rogne le silence de tête et de queue.

    L'API rend des durées arrondies vers le haut et remplit le reste de
    silence : un clic d'interface demandé à 0,5 s revient en pesant une
    seconde. Sans ce rognage, un son joué à l'impact partirait avec un retard
    audible, et la contrainte « moins de 2 s » du manifeste serait tenue par du
    vide.

    Le seuil est relatif à la crête du son lui-même : un bruitage doux ne doit
    pas être rogné plus sévèrement qu'un bruitage fort."""
    top = peak(samples)
    if top == 0:
        return samples
    floor = top * 10.0 ** (floor_db / 20.0)
    first, last = 0, len(samples) - 1
    while first < len(samples) and abs(samples[first]) < floor:
        first += 1
    if first == len(samples):
        return samples  # entièrement sous le seuil : ne rien jeter
    while last > first and abs(samples[last]) < floor:
        last -= 1
    pad = int(rate * pad_ms / 1000)
    return samples[max(0, first - pad):min(len(samples), last + 1 + pad)]


def fade(samples: array.array, in_ms: int = 3, out_ms: int = 12,
         rate: int = RATE) -> array.array:
    """Fondus très courts aux deux bouts.

    Un son rogné en plein cycle commence et finit sur une discontinuité, qui
    s'entend comme un clic — d'autant plus que le jeu rejoue le même bruitage
    des dizaines de fois par seconde en pleine vague."""
    out = array.array("h", samples)
    n_in = min(int(rate * in_ms / 1000), len(out) // 2)
    n_out = min(int(rate * out_ms / 1000), len(out) // 2)
    for i in range(n_in):
        out[i] = int(out[i] * i / n_in)
    for i in range(n_out):
        out[len(out) - 1 - i] = int(out[len(out) - 1 - i] * i / n_out)
    return out


def cap(samples: array.array, max_s: float, rate: int = RATE) -> array.array:
    """Tronque à la durée maximale, avec un fondu pour ne pas couper net."""
    limit = int(max_s * rate)
    if len(samples) <= limit:
        return samples
    return fade(samples[:limit], in_ms=0, out_ms=25, rate=rate)


def encode_wav(samples: array.array, rate: int = RATE) -> bytes:
    """En-tête RIFF minimal + données. 44 octets, aucun chunk superflu."""
    data = to_pcm(samples)
    return b"".join([
        b"RIFF", struct.pack("<I", 36 + len(data)), b"WAVE",
        b"fmt ", struct.pack("<IHHIIHH", 16, 1, 1, rate, rate * 2, 2, 16),
        b"data", struct.pack("<I", len(data)), data,
    ])


def decode_wav(blob: bytes) -> tuple[array.array, int]:
    """Relit un WAV mono 16 bits écrit par `encode_wav` (ou équivalent)."""
    if blob[:4] != b"RIFF" or blob[8:12] != b"WAVE":
        raise ValueError("pas un fichier WAV")
    pos, rate, data = 12, RATE, b""
    while pos + 8 <= len(blob):
        name = blob[pos:pos + 4]
        size = struct.unpack("<I", blob[pos + 4:pos + 8])[0]
        body = blob[pos + 8:pos + 8 + size]
        if name == b"fmt ":
            _fmt, chans, rate = struct.unpack("<HHI", body[:8])
            if chans != 1:
                raise ValueError(f"{chans} canaux, mono attendu")
        elif name == b"data":
            data = body
        pos += 8 + size + (size % 2)
    return from_pcm(data), rate
