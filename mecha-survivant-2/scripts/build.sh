#!/usr/bin/env bash
# Importe les assets puis exporte le jeu en HTML5 dans ../export/.
# Pour juste jouer sur une machine avec écran, scripts/play.sh suffit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
mkdir -p "$ROOT/export"
"$GODOT" --headless --path "$ROOT/godot" --import
"$GODOT" --headless --path "$ROOT/godot" --export-release "Web" ../export/index.html
echo "Build : $ROOT/export ($(du -sh "$ROOT/export" | cut -f1))"
