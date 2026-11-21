extends Node
## Les 8 pouvoirs de la v2, à l'identique : 3 tirés au sort entre deux vagues,
## jamais perdus. Seule la vitesse change d'unité (+30 px/s → mètres).

const ALL: Array[Dictionary] = [
	{"id": "firerate", "short": "Cadence", "name": "Cadence de tir", "desc": "Tire nettement plus vite."},
	{"id": "damage", "short": "Dégâts", "name": "Puissance de feu", "desc": "+7 dégâts par projectile."},
	{"id": "maxhp", "short": "Coque", "name": "Coque renforcée", "desc": "+30 PV max, et soin complet."},
	{"id": "speed", "short": "Vitesse", "name": "Propulseurs", "desc": "Se déplace plus vite."},
	{"id": "multishot", "short": "Salve", "name": "Tir supplémentaire", "desc": "Un projectile de plus par salve."},
	{"id": "shield", "short": "Bouclier", "name": "Bouclier d'énergie", "desc": "+50 de bouclier régénérant."},
	{"id": "aoe", "short": "Onde", "name": "Onde de choc", "desc": "Débloque l'onde de choc (F)."},
	{"id": "stamina", "short": "Endurance", "name": "Réacteurs d'endurance", "desc": "+30 d'endurance max."},
]

var owned: Array[String] = []

func reset() -> void:
	owned.clear()

## Trois pouvoirs distincts. `aoe` ne ressort pas une fois débloqué.
func draw_choices(player: Mech, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for up in ALL:
		if up["id"] == "aoe" and player.aoe_unlocked:
			continue
		pool.append(up)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func apply(id: String, player: Mech) -> void:
	match id:
		"firerate":
			player.fire_interval *= 0.78
		"damage":
			player.bullet_damage += 7.0
		"maxhp":
			player.max_hp += 30.0
			player.hp = player.max_hp
		"speed":
			player.speed += 30.0 * Units.PX
		"multishot":
			player.multi_shot += 1
		"shield":
			player.shield_max += 50.0
			player.shield = player.shield_max
		"aoe":
			player.aoe_unlocked = true
		"stamina":
			player.max_stamina += 30.0
			player.stamina = player.max_stamina
	owned.append(id)
	EventBus.upgrade_taken.emit(id)
	EventBus.player_stats_changed.emit()

func find(id: String) -> Dictionary:
	for up in ALL:
		if up["id"] == id:
			return up
	return {}

func index_of(id: String) -> int:
	for i in ALL.size():
		if ALL[i]["id"] == id:
			return i
	return 0

## Résumé « Cadence x2 · Onde » pour le HUD : un pouvoir pris plusieurs fois
## n'apparaît qu'une fois, avec son nombre de cumuls.
func summary() -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for id in owned:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var parts: PackedStringArray = []
	for id in order:
		var label := str(find(id).get("short", id))
		parts.append(label if counts[id] == 1 else "%s x%d" % [label, counts[id]])
	return " · ".join(parts)
