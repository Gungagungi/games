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

## `shoot_mult` allonge le rechargement des tireurs (Ombre, Destruction) :
## Difficile garde la cadence de la v1, les deux autres tirent plus lentement.
## `sprite` : icône du menu, dans `assets/sprites/ui/difficulty_<id>.png`.
const DIFFICULTIES := {
	"facile": {"label": "Facile", "hp_mult": 0.7, "dmg_mult": 0.7, "gold_mult": 0.8, "shoot_mult": 1.7},
	"intermediaire": {"label": "Intermédiaire", "hp_mult": 1.0, "dmg_mult": 1.0, "gold_mult": 1.0, "shoot_mult": 1.3},
	"difficile": {"label": "Difficile", "hp_mult": 1.7, "dmg_mult": 1.6, "gold_mult": 1.6, "shoot_mult": 1.0},
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
	# Mode Chaos, pas un élément de monstre : chaque monstre tire l'un des
	# `MOB_ELEMENTS`, les 7 boss passent dans un ordre aléatoire. Cette entrée ne
	# sert qu'au menu, au HUD et au boss final, d'où les multiplicateurs neutres.
	# Le boss final ne tire pas : il fonce, brûle et vole de la vie.
	"chaos": {"label": "Chaos", "color": Color("#4a0e3a"), "glow": Color("#e040c0"),
		"hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.0, "lifesteal": 0.35, "burn": true,
		"trait": "Tous les éléments, les 7 boss en ordre aléatoire", "sprite": "unseen_horror"},
}
const ELEMENT_ORDER := ["cendres", "sang", "violence", "terre", "feu", "destruction", "ombre", "chaos"]
const CHAOS := "chaos"
## Éléments que peut prendre un monstre ordinaire ou un boss de vague.
const MOB_ELEMENTS := ["cendres", "sang", "violence", "terre", "feu", "destruction", "ombre"]

const BOSS_NAMES := {
	"cendres": "Chevalier de cendres",
	"sang": "Golem de sang",
	"violence": "Soldat blessé",
	"terre": "Voix Putréfiée",
	"feu": "Créature infernale",
	"destruction": "Mangeur de soldats",
	"ombre": "Sbire de l'ombre",
}
## Boss final par mode : le vaincre gagne la partie. `fallen` titre l'écran de
## victoire ; `gold` fixe la prime au lieu du calcul habituel (difficulté, vague).
const FINAL_BOSSES := {
	"ombre": {"wave": 30, "name": "Nécromancien Putréfié",
		"fallen": "Le Nécromancien Putréfié est tombé", "sprite": "zonguldrok_lich"},
	"chaos": {"wave": 40, "name": "Créature cauchemardesque",
		"fallen": "La Créature cauchemardesque est tombée", "sprite": "unseen_horror", "gold": 300},
}

## Conclave des boss, niveau spécial : les 7 boss d'élément et les deux boss
## finals en même temps dans l'arène. `wave` fixe la croissance des PV et de
## l'or, comme si le combat avait lieu à cette vague.
const BOSS_RUSH := {"name": "Conclave des boss", "wave": 10,
	"fallen": "Le conclave des boss est vaincu"}
## Ordre de l'anneau d'apparition, en partant du haut dans le sens horaire :
## [élément, boss final ?]. Les deux boss finals, plus gros, occupent les
## places de droite et de gauche (3e et 7e), là où l'arène est la plus large.
const BOSS_RUSH_ROSTER := [
	["cendres", false], ["sang", false], ["ombre", true], ["violence", false],
	["terre", false], ["feu", false], ["chaos", true], ["destruction", false],
	["ombre", false],
]

## Conclave : attaques décrites dans l'infobulle d'un boss qu'on approche.
## L'icône est `assets/sprites/attacks/<id>.png` (sorts du pack Dungeon Crawl).
const ATTACKS := {
	"melee": "Frappe au contact",
	"heavy": "Coups d'une violence redoutable",
	"fast": "Rapide, mais fragile",
	"tough": "Très résistant, mais lent",
	"charge": "Charge : il luit, puis bondit sur vous",
	"lifesteal": "Vol de vie : se soigne en frappant",
	"burn": "Brûlure : vous enflamme au contact",
	"bricks": "Lance des briques à distance",
	"bolts": "Tirs d'ombre à distance",
	"giant": "Boss final : énorme réserve de vie",
	"laser": "Laser de l'œil, qui balaie vers vous",
	"whip": "Fouet : trois tentacules à longue portée",
	"sweep": "Balayage circulaire quand on est proche",
	"rush": "Ruée en ligne droite",
	"leap": "Saut, puis onde de choc en anneau",
	"summon": "Invoque des mini-créatures",
	"field": "Champ de force : vous projette au loin",
	"split": "Se dédouble à 75, 50 et 25 % de vie",
}

## Attaques de chaque boss du Conclave, dans l'ordre de l'infobulle. Clé :
## l'élément, préfixé de `final_` pour un boss final (voir `boss_attacks`).
const BOSS_ATTACKS := {
	"cendres": ["fast", "melee", "charge"],
	"sang": ["melee", "lifesteal", "charge"],
	"violence": ["heavy", "melee", "charge"],
	"terre": ["tough", "melee", "charge"],
	"feu": ["melee", "burn", "charge"],
	"destruction": ["bricks", "charge"],
	"ombre": ["bolts", "charge"],
	"final_ombre": ["giant", "bolts", "charge"],
	"final_chaos": ["giant", "burn", "lifesteal", "laser", "whip", "sweep", "rush",
		"leap", "summon", "field", "split"],
}

func boss_attacks(element: String, is_final: bool) -> Array:
	return BOSS_ATTACKS.get(("final_" if is_final else "") + element, [])

## Pas de temps de la v1 : tous ses compteurs décomptaient une frame à 60 fps.
const V1_FPS := 60.0

func enemy_count(wave: int) -> int:
	return 3 + int(floor(wave * 1.4))

func is_boss_wave(wave: int) -> bool:
	return wave % 5 == 0

func is_final_boss_wave(element: String, wave: int) -> bool:
	return FINAL_BOSSES.has(element) and wave == FINAL_BOSSES[element]["wave"]

func final_boss(element: String) -> Dictionary:
	return FINAL_BOSSES.get(element, {})
