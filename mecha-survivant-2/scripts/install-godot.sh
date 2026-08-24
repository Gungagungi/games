#!/usr/bin/env bash
# Installe Godot 4 et le template d'export Web, hors du dépôt.
# Fonctionne sur Linux x86_64 et sur macOS (Intel comme Apple Silicon : le
# téléchargement macOS est universel).
# Idempotent : ne retélécharge rien si le binaire et le template sont en place.
set -euo pipefail

VERSION="4.7.2"
FLAVOR="stable"
TAG="${VERSION}-${FLAVOR}"
BIN_DIR="${HOME}/.local/bin"
BIN="${BIN_DIR}/godot"

case "$(uname -s)" in
  Darwin)
    SLUG="macos.universal.zip"
    PLATFORM="macos"
    # Sur macOS, Godot cherche ses templates ici, pas dans ~/.local/share.
    TPL_DIR="${HOME}/Library/Application Support/Godot/export_templates/${VERSION}.${FLAVOR}"
    ;;
  Linux)
    SLUG="linux.x86_64.zip"
    PLATFORM="linux.64"
    TPL_DIR="${HOME}/.local/share/godot/export_templates/${VERSION}.${FLAVOR}"
    ;;
  *)
    echo "Système non géré : $(uname -s)" >&2
    exit 1
    ;;
esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$BIN_DIR" "$TPL_DIR"

if [ -x "$BIN" ] && "$BIN" --version 2>/dev/null | grep -q "^${VERSION}\.${FLAVOR}"; then
  echo "Binaire Godot ${TAG} déjà présent : $BIN"
else
  echo "Téléchargement du binaire Godot ${TAG} (${PLATFORM})…"
  curl -fsSL -o "$WORK/godot.zip" \
    "https://downloads.godotengine.org/?version=${VERSION}&flavor=${FLAVOR}&slug=${SLUG}&platform=${PLATFORM}"
  python3 -m zipfile -e "$WORK/godot.zip" "$WORK/godot/"
  if [ "$PLATFORM" = "macos" ]; then
    # Le téléchargement macOS est un Godot.app : on installe l'app dans
    # ~/Applications et on pointe le binaire dessus.
    APP_DST="${HOME}/Applications/Godot.app"
    rm -rf "$APP_DST"
    mkdir -p "${HOME}/Applications"
    cp -R "$WORK/godot/Godot.app" "$APP_DST"
    chmod +x "$APP_DST/Contents/MacOS/Godot"
    # Sans cela, Gatekeeper refuse de lancer une app téléchargée en ligne
    # de commande (« Godot est endommagé »).
    xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
    ln -sf "$APP_DST/Contents/MacOS/Godot" "$BIN"
  else
    install -m 755 "$WORK/godot/Godot_v${TAG}_linux.x86_64" "$BIN"
  fi
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
