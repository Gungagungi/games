class_name EnemyStats
extends RefCounted
## Stats des ennemis ordinaires, reprises de la v1 avec le même scaling par tier.
## Les vitesses sont converties en pixels/seconde (v1 : pixels/frame × 60).

const DEFS: Dictionary = {
	"zombie": {
		"radius": 15.0, "radius_per_tier": 1.5,
		"hp": 30.0, "hp_per_tier": 18.0,
		"speed": 39.0, "speed_per_tier": 4.8,
		"damage": 8.0, "damage_per_tier": 2.0,
		"color": Color(0.42, 0.62, 0.35),
		"min_wave": 1,
	},
	"skeleton": {
		"radius": 13.0, "radius_per_tier": 0.0,
		"hp": 18.0, "hp_per_tier": 10.0,
		"speed": 78.0, "speed_per_tier": 6.0,
		"damage": 6.0, "damage_per_tier": 1.5,
		"color": Color(0.85, 0.86, 0.80),
		"min_wave": 2,
	},
	"risen": {
		"radius": 17.0, "radius_per_tier": 0.0,
		"hp": 45.0, "hp_per_tier": 22.0,
		"speed": 54.0, "speed_per_tier": 6.0,
		"damage": 12.0, "damage_per_tier": 2.5,
		"color": Color(0.55, 0.36, 0.28),
		"min_wave": 3,
	},
	"shade": {
		"radius": 14.0, "radius_per_tier": 0.0,
		"hp": 24.0, "hp_per_tier": 12.0,
		"speed": 87.0, "speed_per_tier": 6.6,
		"damage": 10.0, "damage_per_tier": 2.0,
		"color": Color(0.45, 0.32, 0.72),
		"min_wave": 4,
	},
	"flameling": {
		"radius": 15.0, "radius_per_tier": 0.0,
		"hp": 26.0, "hp_per_tier": 14.0,
		"speed": 45.0, "speed_per_tier": 4.2,
		"damage": 9.0, "damage_per_tier": 2.0,
		"color": Color(0.95, 0.48, 0.18),
		"min_wave": 2,
	},
}

## Types disponibles à cette vague. Comme dans la v1, le flameling est exclu
## de la vague 1 et des vagues de boss.
static func available_types(wave: int) -> Array[String]:
	var out: Array[String] = []
	for type in DEFS:
		var def: Dictionary = DEFS[type]
		if wave < int(def["min_wave"]):
			continue
		if type == "flameling" and (wave == 1 or GameState.is_boss_wave(wave)):
			continue
		out.append(type)
	return out

static func scaled(type: String, tier: int) -> Dictionary:
	var d: Dictionary = DEFS[type]
	return {
		"type": type,
		"radius": float(d["radius"]) + float(d["radius_per_tier"]) * tier,
		"max_hp": float(d["hp"]) + float(d["hp_per_tier"]) * tier,
		"speed": float(d["speed"]) + float(d["speed_per_tier"]) * tier,
		"damage": float(d["damage"]) + float(d["damage_per_tier"]) * tier,
		"color": d["color"],
	}
