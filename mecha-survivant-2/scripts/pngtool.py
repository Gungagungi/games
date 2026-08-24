"""Lecture/écriture PNG et composition de planches, sans dépendance.

Pillow n'est pas installé sur la machine de développement et le dépôt tient à
rester sans dépendance : ce module fait le strict nécessaire à la main, sur la
seule bibliothèque standard (`zlib` suffit à dé/compresser les données PNG).

Tout circule en RGBA 8 bits, un `bytearray` de `width * height * 4` octets.
"""

from __future__ import annotations

import struct
import zlib

MAGIC = b"\x89PNG\r\n\x1a\n"


class PngError(Exception):
    pass


def _chunks(data: bytes):
    if data[:8] != MAGIC:
        raise PngError("ce n'est pas un PNG")
    pos = 8
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        yield kind, payload
        pos += 12 + length  # longueur + type + données + CRC


def _unfilter(raw: bytes, width: int, height: int, bpp: int) -> bytearray:
    """Défiltre les scanlines PNG (filtres 0 à 4, cf. RFC 2083 §6)."""
    stride = width * bpp
    out = bytearray(stride * height)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        method = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if method == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif method == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif method == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif method == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif method != 0:
            raise PngError(f"filtre PNG inconnu : {method}")
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return out


class Image:
    """Bitmap RGBA 8 bits."""

    __slots__ = ("width", "height", "pixels")

    def __init__(self, width: int, height: int, pixels: bytearray | None = None):
        self.width = width
        self.height = height
        self.pixels = pixels if pixels is not None else bytearray(width * height * 4)

    # -- lecture ----------------------------------------------------------
    @classmethod
    def decode(cls, data: bytes) -> "Image":
        width = height = depth = color = 0
        palette = b""
        trns = b""
        idat = bytearray()
        for kind, payload in _chunks(data):
            if kind == b"IHDR":
                width, height, depth, color, _comp, _filt, interlace = struct.unpack(
                    ">IIBBBBB", payload)
                if depth != 8:
                    raise PngError(f"profondeur {depth} bits non gérée (8 attendu)")
                if interlace:
                    raise PngError("PNG entrelacé non géré")
            elif kind == b"PLTE":
                palette = payload
            elif kind == b"tRNS":
                trns = payload
            elif kind == b"IDAT":
                idat += payload
            elif kind == b"IEND":
                break
        if not width:
            raise PngError("IHDR manquant")

        channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
        if channels is None:
            raise PngError(f"type de couleur {color} non géré")
        raw = _unfilter(zlib.decompress(bytes(idat)), width, height, channels)

        img = cls(width, height)
        px = img.pixels
        for i in range(width * height):
            src = i * channels
            dst = i * 4
            if color == 6:
                px[dst:dst + 4] = raw[src:src + 4]
            elif color == 2:
                px[dst:dst + 3] = raw[src:src + 3]
                px[dst + 3] = 255
            elif color == 0:
                g = raw[src]
                px[dst:dst + 4] = bytes((g, g, g, 255))
            elif color == 4:
                g = raw[src]
                px[dst:dst + 4] = bytes((g, g, g, raw[src + 1]))
            else:  # palette
                idx = raw[src]
                px[dst:dst + 3] = palette[idx * 3:idx * 3 + 3]
                px[dst + 3] = trns[idx] if idx < len(trns) else 255
        return img

    # -- écriture ---------------------------------------------------------
    def encode(self) -> bytes:
        stride = self.width * 4
        raw = bytearray()
        for y in range(self.height):
            raw.append(0)  # filtre « None » : le pixel art compresse déjà bien
            raw += self.pixels[y * stride:(y + 1) * stride]

        def chunk(kind: bytes, payload: bytes) -> bytes:
            return (struct.pack(">I", len(payload)) + kind + payload
                    + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

        header = struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)
        return (MAGIC + chunk(b"IHDR", header)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
                + chunk(b"IEND", b""))

    # -- opérations -------------------------------------------------------
    def resized(self, width: int, height: int) -> "Image":
        """Redimensionne au plus proche voisin : jamais d'interpolation, sans
        quoi le pixel art se retrouve flou et la palette explose."""
        if (width, height) == (self.width, self.height):
            return self
        out = Image(width, height)
        for y in range(height):
            sy = min(self.height - 1, y * self.height // height)
            row = sy * self.width * 4
            for x in range(width):
                sx = min(self.width - 1, x * self.width // width)
                src = row + sx * 4
                dst = (y * width + x) * 4
                out.pixels[dst:dst + 4] = self.pixels[src:src + 4]
        return out

    def blit(self, other: "Image", at_x: int, at_y: int) -> None:
        for y in range(other.height):
            dy = at_y + y
            if not 0 <= dy < self.height:
                continue
            src = y * other.width * 4
            dst = (dy * self.width + at_x) * 4
            self.pixels[dst:dst + other.width * 4] = other.pixels[src:src + other.width * 4]

    def crop(self, x: int, y: int, width: int, height: int) -> "Image":
        out = Image(width, height)
        for row in range(height):
            sy = y + row
            if not 0 <= sy < self.height:
                continue
            src = (sy * self.width + x) * 4
            dst = row * width * 4
            out.pixels[dst:dst + width * 4] = self.pixels[src:src + width * 4]
        return out

    def opaque_ratio(self) -> float:
        """Proportion de pixels non transparents — sert à repérer une frame
        vide rendue par le générateur avant de l'assembler."""
        opaque = sum(1 for i in range(3, len(self.pixels), 4) if self.pixels[i] > 8)
        return opaque / (self.width * self.height)


def strip(frames: list[Image], tile: int) -> Image:
    """Assemble des frames en planche horizontale de cases carrées `tile`."""
    out = Image(tile * len(frames), tile)
    for i, frame in enumerate(frames):
        out.blit(frame.resized(tile, tile), i * tile, 0)
    return out
