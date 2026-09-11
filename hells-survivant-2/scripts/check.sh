#!/usr/bin/env bash
# Non-régression sans écran : joue plusieurs parties accélérées (vagues
# ordinaires, boss de mêlée, boss tireur de briques, boss final jusqu'à la
# victoire). Échoue sur toute erreur GDScript ou partie qui n'aboutit pas.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/godot-env.sh"
ensure_import

# Un script qui ne compile pas laisse Godot tourner indéfiniment : sans
# plafond, check.sh ne rendrait jamais la main. SIGINT laisse Godot vider sa
# sortie avant de quitter. `timeout` manque sur macOS (gtimeout via coreutils).
LIMIT=()
for bin in timeout gtimeout; do
  if command -v "$bin" >/dev/null; then
    LIMIT=("$bin" -s INT -k 10 120)
    break
  fi
done

fail=0
run() {
  echo "--- $* ---"
  local out status=0
  out="$("${LIMIT[@]}" "$GODOT" --headless --path "$ROOT/godot" -- --smoke "$@" 2>&1)" || status=$?
  printf '%s\n' "$out" | grep -Ev '^Godot Engine|^$' || true
  if [ "$status" -ne 0 ] || printf '%s\n' "$out" | grep -qE 'SCRIPT ERROR|^ERROR|ÉCHEC'; then
    fail=1
  fi
}

run --element=sang --wave=1
run --element=feu --wave=5
run --element=destruction --wave=10 --difficulty=difficile
run --element=ombre --wave=30

if [ "$fail" -ne 0 ]; then
  echo "check : ÉCHEC" >&2
  exit 1
fi
echo "check : OK"
