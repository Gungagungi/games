extends Node
## Les 8 pouvoirs de la v1, à l'identique. 3 sont tirés au sort entre deux vagues.
## `owned` alimente le HUD ; un pouvoir n'est jamais perdu.

const ALL: Array[Dictionary] = [
	{"id": "firerate", "short": "Cadence",  "icon": "⚡",  "name": "Cadence de tir",        "desc": "Tire nettement plus vite."},
	{"id": "damage", "short": "Dégâts",    "icon": "💥", "name": "Puissance de feu",      "desc": "+7 dégâts par projectile."},
	{"id": "maxhp", "short": "Coque",     "icon": "🛡️", "name": "Coque renforcée",       "desc": "+30 PV max, et soin complet."},
	{"id": "speed", "short": "Vitesse",     "icon": "🚀", "name": "Propulseurs",           "desc": "+0.5 de vitesse de déplacement."},
	{"id": "multishot", "short": "Salve", "icon": "🔱", "name": "Tir supplémentaire",    "desc": "Un projectile de plus par salve."},
	{"id": "shield", "short": "Bouclier",    "icon": "🔵", "name": "Bouclier d'énergie",    "desc": "+50 de bouclier régénérant."},
	{"id": "aoe", "short": "Onde",       "icon": "🌀", "name": "Onde de choc",          "desc": "Débloque l'onde de choc (F)."},
	{"id": "stamina", "short": "Endurance",   "icon": "🌬️", "name": "Réacteurs d'endurance", "desc": "+30 d'endurance max."},
]

var owned: Array[String] = []

func reset() -> void:
	owned.clear()

## Trois pouvoirs distincts. `aoe` ne ressort pas une fois débloqué.
func draw_choices(player: Node, count: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for up in ALL:
		if up["id"] == "aoe" and player.aoe_unlocked:
			continue
		pool.append(up)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func apply(id: String, player: Node) -> void:
	match id:
		"firerate":
			player.fire_interval *= 0.78
		"damage":
			player.bullet_damage += 7.0
		"maxhp":
			player.max_hp += 30.0
			player.hp = player.max_hp
		"speed":
			player.speed += 30.0
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
