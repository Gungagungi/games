extends Node
## Progression persistante (or, épée, armure) et préférence son.
## Distincte de la v1 : `user://` est stocké en IndexedDB dans le navigateur,
## sans lien avec le localStorage de `hells-survivant/`.

const PATH := "user://save.cfg"

var gold := 0
var sword_tier := 0
var armor_tier := 0
var muted := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	gold = int(cfg.get_value("save", "gold", 0))
	sword_tier = clampi(int(cfg.get_value("save", "sword_tier", 0)), 0, Data.SWORDS.size() - 1)
	armor_tier = clampi(int(cfg.get_value("save", "armor_tier", 0)), 0, Data.ARMORS.size() - 1)
	muted = bool(cfg.get_value("save", "muted", false))

func write() -> void:
	if Game.smoke_test:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("save", "gold", gold)
	cfg.set_value("save", "sword_tier", sword_tier)
	cfg.set_value("save", "armor_tier", armor_tier)
	cfg.set_value("save", "muted", muted)
	cfg.save(PATH)

func sword() -> Dictionary:
	return Data.SWORDS[sword_tier]

func armor() -> Dictionary:
	return Data.ARMORS[armor_tier]
