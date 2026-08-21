#!/usr/bin/env bash
# Lance le jeu directement dans Godot, sans passer par l'export web.
# C'est le moyen le plus rapide d'y jouer sur une machine avec écran : pas de
# build, pas de serveur, pas de template d'export à télécharger.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
exec "$GODOT" --path "$ROOT/godot" "$@"
