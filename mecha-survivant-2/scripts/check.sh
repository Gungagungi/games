#!/usr/bin/env bash
# Non-régression sans écran : joue quatre parties en accéléré (départ vague 1,
# boss, méga-boss, Titan en phase finale). Toute erreur GDScript apparaît dans
# la sortie.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
run() { echo "--- $* ---"; "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1 | grep -Ev '^Godot Engine|^$'; }
run --wave=1
run --wave=5
run --wave=15
run --titan
