extends Node
## Progression persistante (or, épée, armure, Yeux corrompus et enchantements)
## et préférence son. Distincte de la v1 : `user://` est stocké en IndexedDB
## dans le navigateur, sans lien avec le localStorage de `hells-survivant/`.

const PATH := "user://save.cfg"

var gold := 0
var sword_tier := 0
var armor_tier := 0
## Yeux corrompus ramassés et pas encore dépensés à la forge.
var eyes := 0
## Équipement enchanté par un Œil corrompu : l'enchantement est lié à la pièce
## (épée ou armure), pas au niveau, et survit donc aux achats suivants.
var sword_corrupt := false
var armor_corrupt := false
var muted := false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	gold = int(cfg.get_value("save", "gold", 0))
	sword_tier = clampi(int(cfg.get_value("save", "sword_tier", 0)), 0, Data.SWORDS.size() - 1)
	armor_tier = clampi(int(cfg.get_value("save", "armor_tier", 0)), 0, Data.ARMORS.size() - 1)
	eyes = maxi(0, int(cfg.get_value("save", "eyes", 0)))
	sword_corrupt = bool(cfg.get_value("save", "sword_corrupt", false))
	armor_corrupt = bool(cfg.get_value("save", "armor_corrupt", false))
	muted = bool(cfg.get_value("save", "muted", false))

func write() -> void:
	if Game.smoke_test:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("save", "gold", gold)
	cfg.set_value("save", "sword_tier", sword_tier)
	cfg.set_value("save", "armor_tier", armor_tier)
	cfg.set_value("save", "eyes", eyes)
	cfg.set_value("save", "sword_corrupt", sword_corrupt)
	cfg.set_value("save", "armor_corrupt", armor_corrupt)
	cfg.set_value("save", "muted", muted)
	cfg.save(PATH)

func sword() -> Dictionary:
	return Data.SWORDS[sword_tier]

func armor() -> Dictionary:
	return Data.ARMORS[armor_tier]

## Nom d'une pièce de la forge, suivi de « Corrompu » (accordé) si la pièce
## de ce type est enchantée.
func item_name(item: Dictionary, is_sword: bool) -> String:
	var corrupt := sword_corrupt if is_sword else armor_corrupt
	return "%s %s" % [item["name"], item["corrupt"]] if corrupt else String(item["name"])

## Vitesse de marche du héros : +25 % avec l'armure corrompue.
func speed_mult() -> float:
	return Data.CORRUPT_SPEED if armor_corrupt else 1.0
