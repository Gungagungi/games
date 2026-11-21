#!/usr/bin/env bash
# Non-régression sans écran : quatre parties accélérées en mode smoke (mech
# immortel qui vise, se déplace et tire tout seul, pouvoirs choisis seuls).
#   1. vagues 1 à 4 : le début, avec ses premiers types d'ennemis ;
#   2. vagues 12 et 13 : tous les types, une douzaine de pouvoirs ;
#   3. vagues 29 et 30 : la fin, jusqu'à l'écran de victoire.
#   4. dès la vague 22, mech mortel : jusqu'à sa destruction (dégâts,
#      embrasement, bouclier et mort, que les parties immortelles ne voient pas).
# Chaque partie se conclut par « [smoke] OK » ou « [smoke] ÉCHEC » (temps de
# jeu dépassé : un ennemi qu'on ne peut plus atteindre, une vague bloquée).
# Toute erreur GDScript apparaît dans la sortie. Code de sortie non nul si une
# partie échoue.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import
status=0
run() {
  echo "=== smoke $*"
  "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1 | grep -Ev '^Godot Engine|^$'
  [ "${PIPESTATUS[0]}" -eq 0 ] || status=1
}
run
run --wave=12 --waves=2
run --wave=29 --waves=2
run --wave=22 --waves=8 --mortal
exit "$status"
