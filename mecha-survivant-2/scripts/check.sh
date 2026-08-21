#!/usr/bin/env bash
# Non-régression sans écran : charge le projet, puis joue quatre parties en
# accéléré (départ vague 1, boss, méga-boss, Titan en phase finale).
# Toute erreur GDScript apparaît dans la sortie.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
run() { echo "--- $* ---"; "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1 | grep -Ev '^Godot Engine|^$'; }
run --wave=1
run --wave=5
run --wave=15
run --titan
