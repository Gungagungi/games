#!/usr/bin/env bash
# Non-régression sans écran : joue quatre parties en accéléré (départ vague 1,
# boss de vague 5, Zombie Titan en vague 15, leurre + Boss Galaxie en vague
# 20). Toute erreur GDScript apparaît dans la sortie.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import

run() { echo "--- $* ---"; "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1 | grep -Ev '^Godot Engine|^$'; }
run --wave=1
run --wave=5
run --wave=15
run --wave=20
