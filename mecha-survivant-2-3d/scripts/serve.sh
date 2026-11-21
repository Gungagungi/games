#!/usr/bin/env bash
# Sert le build web sur http://localhost:8123.
# Un export Godot ne peut pas s'ouvrir en file:// : il charge son .pck et son
# .wasm par requête réseau.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/export"
[ -d "$DIR" ] || { echo "Aucun build : lancez d'abord scripts/build.sh" >&2; exit 1; }
exec python3 -m http.server "${1:-8123}" --directory "$DIR"
