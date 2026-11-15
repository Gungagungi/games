#!/usr/bin/env bash
# Joue directement dans Godot, sans export ni serveur (machine avec écran).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import
exec "$GODOT" --path "$ROOT/godot"
