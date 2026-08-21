#!/usr/bin/env bash
# Installe Godot 4 et le template d'export Web dans ~/.local, hors du dépôt.
# Idempotent : ne retélécharge rien si le binaire et le template sont déjà en place.
set -euo pipefail

VERSION="4.7.2"
FLAVOR="stable"
TAG="${VERSION}-${FLAVOR}"
TPL_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.${FLAVOR}"
BIN_DIR="${HOME}/.local/bin"
BIN="${BIN_DIR}/godot"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$BIN_DIR" "$TPL_DIR"

if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "^${VERSION}\.${FLAVOR}"; then
  echo "Binaire Godot ${TAG} déjà présent : $BIN"
else
  echo "Téléchargement du binaire Godot ${TAG}…"
  curl -fsSL -o "$WORK/godot.zip" \
    "https://downloads.godotengine.org/?version=${VERSION}&flavor=${FLAVOR}&slug=linux.x86_64.zip&platform=linux.64"
  python3 -m zipfile -e "$WORK/godot.zip" "$WORK/godot/"
  install -m 755 "$WORK/godot/Godot_v${TAG}_linux.x86_64" "$BIN"
  echo "Installé : $BIN"
fi

if [ -f "${TPL_DIR}/web_nothreads_release.zip" ]; then
  echo "Template Web déjà présent : ${TPL_DIR}"
else
  echo "Téléchargement des export templates ${TAG} (~1 Go, seul le Web est conservé)…"
  curl -fsSL -o "$WORK/tpl.tpz" \
    "https://downloads.godotengine.org/?version=${VERSION}&flavor=${FLAVOR}&slug=export_templates.tpz&platform=templates"
  python3 - "$WORK/tpl.tpz" "$TPL_DIR" <<'PY'
import sys, zipfile, os
src, dest = sys.argv[1], sys.argv[2]
wanted = ("web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt")
with zipfile.ZipFile(src) as z:
    names = z.namelist()
    for w in wanted:
        hit = next((n for n in names if os.path.basename(n) == w), None)
        if hit is None:
            print(f"  ATTENTION : {w} absent de l'archive", file=sys.stderr)
            continue
        with z.open(hit) as fin, open(os.path.join(dest, w), "wb") as fout:
            fout.write(fin.read())
        print(f"  extrait : {w}")
PY
fi

echo
echo "Godot prêt. Vérification :"
"$BIN" --version
