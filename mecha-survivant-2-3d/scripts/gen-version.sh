#!/usr/bin/env bash
# Génère godot/version.txt (branche@hash court), affiché en bas à gauche de
# l'écran-titre par version.gd. Appelé par scripts/build.sh avant l'export ;
# non versionné, comme /export/, la CI le régénère à chaque déploiement.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

branch="${GITHUB_REF_NAME:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)}"
sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)"
echo "${branch}@${sha}" > "$ROOT/godot/version.txt"
echo "Version : ${branch}@${sha}"
