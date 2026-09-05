class_name GameVersion
extends RefCounted
## Lit `res://version.txt`, généré par `scripts/gen-version.sh` avant l'export
## (voir `scripts/build.sh`). Le fichier n'est pas versionné — absent hors
## build (éditeur, `play.sh` sans avoir lancé le script), auquel cas on
## retombe sur "dev", sur le modèle de `sprite_or_shape.gd`.

const VERSION_FILE := "res://version.txt"

static func read() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "dev"
	return FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
