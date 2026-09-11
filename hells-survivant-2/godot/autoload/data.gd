extends Node
## Données de jeu reprises de la v1 (`hells-survivant/game.js`).
## La v1 comptait en pixels/frame et en frames : ici tout est en pixels/seconde
## et en secondes (×60 ou ÷60), l'arène gardant ses 900×600 px.

const ARENA := Vector2(900, 600)

const SWORDS := [
	{"name": "Poings nus", "cost": 0, "dmg": 3, "range": 70},
	{"name": "Épée rouillée", "cost": 25, "dmg": 6, "range": 82},
	{"name": "Épée en acier", "cost": 75, "dmg": 11, "range": 92},
	{"name": "Épée enchantée", "cost": 180, "dmg": 18, "range": 102},
	{"name": "Lame des enfers", "cost": 400, "dmg": 30, "range": 112},
	{"name": "Excalibur déchue", "cost": 900, "dmg": 50, "range": 126},
]

const ARMORS := [
	{"name": "Peau nue", "cost": 0, "hp": 50, "def": 0.0},
	{"name": "Haillons", "cost": 25, "hp": 65, "def": 0.05},
	{"name": "Cuir clouté", "cost": 75, "hp": 85, "def": 0.12},
	{"name": "Cotte de mailles", "cost": 180, "hp": 115, "def": 0.20},
	{"name": "Armure infernale", "cost": 400, "hp": 160, "def": 0.30},
	{"name": "Armure du Damné", "cost": 900, "hp": 230, "def": 0.40},
]

const DIFFICULTIES := {
	"facile": {"label": "Facile", "hp_mult": 0.7, "dmg_mult": 0.7, "gold_mult": 0.8},
	"intermediaire": {"label": "Intermédiaire", "hp_mult": 1.0, "dmg_mult": 1.0, "gold_mult": 1.0},
	"difficile": {"label": "Difficile", "hp_mult": 1.7, "dmg_mult": 1.6, "gold_mult": 1.6},
}
const DIFFICULTY_ORDER := ["facile", "intermediaire", "difficile"]

## `sprite` / `boss_sprite` : fichiers de `assets/sprites/monsters/`.
const ELEMENTS := {
	"cendres": {"label": "Cendres", "color": Color("#9a9a9a"), "glow": Color("#c8c8c8"),
		"hp_mult": 0.7, "dmg_mult": 0.8, "speed_mult": 1.5, "trait": "Rapides, fragiles",
		"sprite": "smoke_demon", "boss_sprite": "skeletal_warrior"},
	"sang": {"label": "Sang", "color": Color("#7a0d18"), "glow": Color("#c81e2e"),
		"hp_mult": 1.0, "dmg_mult": 1.1, "speed_mult": 1.0, "lifesteal": 0.35, "trait": "Vol de vie",
		"sprite": "flayed_ghost", "boss_sprite": "flesh_golem"},
	"violence": {"label": "Violence", "color": Color("#c2410c"), "glow": Color("#ff7a3c"),
		"hp_mult": 0.9, "dmg_mult": 1.6, "speed_mult": 1.1, "trait": "Dégâts élevés",
		"sprite": "imp", "boss_sprite": "warmonger"},
	"terre": {"label": "Terre", "color": Color("#5a3a1e"), "glow": Color("#8a6238"),
		"hp_mult": 1.9, "dmg_mult": 1.0, "speed_mult": 0.6, "trait": "Résistants, lents",
		"sprite": "earth_elemental", "boss_sprite": "rotting_hulk"},
	"feu": {"label": "Feu", "color": Color("#ff8c1a"), "glow": Color("#ffd23c"),
		"hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.0, "burn": true, "trait": "Brûlure",
		"sprite": "fire_elemental", "boss_sprite": "balrug"},
	"destruction": {"label": "Destruction", "color": Color("#2a0a0a"), "glow": Color("#ff2020"),
		"hp_mult": 1.4, "dmg_mult": 1.4, "speed_mult": 0.9, "ranged": true, "bricks": true,
		"trait": "Lance des briques", "sprite": "hell_sentinel", "boss_sprite": "pit_fiend"},
	"ombre": {"label": "Ombre", "color": Color("#3c1a5a"), "glow": Color("#a855f7"),
		"hp_mult": 1.0, "dmg_mult": 0.9, "speed_mult": 0.9, "ranged": true, "trait": "Tirs à distance",
		"sprite": "shadow_imp", "boss_sprite": "shadow_fiend"},
}
const ELEMENT_ORDER := ["cendres", "sang", "violence", "terre", "feu", "destruction", "ombre"]

const BOSS_NAMES := {
	"cendres": "Chevalier de cendres",
	"sang": "Golem de sang",
	"violence": "Soldat blessé",
	"terre": "Voix Putréfiée",
	"feu": "Créature infernale",
	"destruction": "Mangeur de soldats",
	"ombre": "Sbire de l'ombre",
}
const FINAL_BOSS_ELEMENT := "ombre"
const FINAL_BOSS_WAVE := 30
const FINAL_BOSS_NAME := "Nécromancien Putréfié"
const FINAL_BOSS_SPRITE := "zonguldrok_lich"

## Pas de temps de la v1 : tous ses compteurs décomptaient une frame à 60 fps.
const V1_FPS := 60.0

func enemy_count(wave: int) -> int:
	return 3 + int(floor(wave * 1.4))

func is_boss_wave(wave: int) -> bool:
	return wave % 5 == 0

func is_final_boss_wave(element: String, wave: int) -> bool:
	return element == FINAL_BOSS_ELEMENT and wave == FINAL_BOSS_WAVE
