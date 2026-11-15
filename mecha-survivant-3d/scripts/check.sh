#!/usr/bin/env bash
# Non-régression sans écran : une partie accélérée en mode smoke (mech
# immortel qui vise et tire tout seul) jusqu'à la vague 4. Toute erreur
# GDScript apparaît dans la sortie. N'asserte rien : la sortie se lit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import
"$GODOT" --headless --path "$ROOT/godot" -- --smoke 2>&1 | grep -Ev '^Godot Engine|^$'
