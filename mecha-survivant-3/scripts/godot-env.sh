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

# Godot ne connaît les `class_name` que via .godot/global_script_class_cache.cfg,
# qu'il génère à l'import. Ce dossier est volontairement hors du dépôt : au
# premier lancement d'un clone, il manque, et tous les types déclarés par
# `class_name` sont introuvables. On l'amorce donc si besoin.
# Un `class_name` ajouté après coup n'est pas non plus dans le cache : tant
# qu'on n'a pas réimporté, le nouveau type est « introuvable » et rien ne
# démarre. On réimporte donc aussi dès qu'un script est plus récent que le
# cache — un import à vide coûte deux secondes, la panne coûte plus cher.
ensure_import() {
  cache="$ROOT/godot/.godot/global_script_class_cache.cfg"
  if [ ! -f "$cache" ]; then
    echo "Premier lancement : import des ressources…" >&2
  elif [ -n "$(find "$ROOT/godot" -name '*.gd' -newer "$cache" -print -quit)" ]; then
    echo "Scripts modifiés depuis le dernier import : réimport…" >&2
  else
    return 0
  fi
  "$GODOT" --headless --path "$ROOT/godot" --import >/dev/null 2>&1 || true
}
