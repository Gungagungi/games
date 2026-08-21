# Résolution du binaire Godot, partagé par les autres scripts.
# À sourcer, pas à exécuter. Définit GODOT et ROOT.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${GODOT:-}" ]; then
  for candidate in \
      "$HOME/.local/bin/godot" \
      "$(command -v godot || true)" \
      "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
      "/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      GODOT="$candidate"
      break
    fi
  done
fi

if [ -z "${GODOT:-}" ] || [ ! -x "$GODOT" ]; then
  echo "Godot introuvable. Lancez scripts/install-godot.sh, ou indiquez le binaire :" >&2
  echo "  GODOT=/chemin/vers/godot $0" >&2
  exit 1
fi
