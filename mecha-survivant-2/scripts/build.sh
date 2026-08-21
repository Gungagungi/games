#!/usr/bin/env bash
# Importe les assets puis exporte le jeu en HTML5 dans ../export/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
[ -x "$GODOT" ] || { echo "Godot introuvable ($GODOT) — lancez scripts/install-godot.sh" >&2; exit 1; }
mkdir -p "$ROOT/export"
"$GODOT" --headless --path "$ROOT/godot" --import
"$GODOT" --headless --path "$ROOT/godot" --export-release "Web" ../export/index.html
echo "Build : $ROOT/export ($(du -sh "$ROOT/export" | cut -f1))"
