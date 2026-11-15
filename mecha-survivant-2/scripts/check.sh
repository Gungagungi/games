#!/usr/bin/env bash
# Non-régression sans écran : joue neuf parties en accéléré (leurre Titan de
# la Mort en vague 1, boss de vague 5, Zombie Titan en vague 15, Boss Galaxie
# en vague 20, Esclave du Destructeur en vague 25, Robot géant mutant en
# vague 30 — la dernière —, niveau spécial du Destructeur d'univers, puis son raccourci
# « PHASE 5 » à 1 % de vie, et l'entraînement contre le Cristal). Toute erreur
# GDScript apparaît dans la sortie.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import

run() { echo "--- $* ---"; "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1 | grep -Ev '^Godot Engine|^$'; }
run --wave=1
run --wave=5
run --wave=15
run --wave=20
run --wave=25
run --wave=30
run --destroyer
run --destroyer --destroyer-final
run --crystal
