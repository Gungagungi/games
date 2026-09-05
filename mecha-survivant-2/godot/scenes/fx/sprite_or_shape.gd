class_name SpriteOrShape
extends Node2D
## Visuel d'entité tolérant à l'absence d'asset.
##
## Tant qu'aucun PNG n'a été déposé dans `assets/sprites/`, l'entité se dessine en
## placeholder géométrique (comme la v1 Canvas 2D). Dès que le fichier attendu
## existe, il est affiché à sa place — sans changer une ligne du code appelant.
## Voir `assets/MANIFEST.md` pour la liste des fichiers et leur découpage.
##
## `SHEETS` est la source de vérité du découpage : combien de cases contient une
## planche, et quelles plages de cases forment chaque animation. Le régler ici
## plutôt que chez l'appelant évite qu'un `hframes` oublié découpe un sprite de
## travers le jour où le fichier est déposé — l'appelant ne nomme qu'une
## animation (`play("walk")`), jamais un numéro de case.

const DIR := "res://assets/sprites/"

## `hframes` = cases de la planche ; `anims` = nom -> [première case, nombre].
## Un sprite absent de la table est traité comme une planche d'une seule case.
const SHEETS := {
	"player_mech": {"hframes": 13, "fps": 10.0,
		"anims": {"idle": [0, 4], "walk": [4, 6], "dash": [10, 3]}},
	"enemy_zombie": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"enemy_skeleton": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"enemy_risen": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"enemy_shade": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"enemy_flameling": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"enemy_fire_skeleton": {"hframes": 8, "anims": {"walk": [0, 4], "death": [4, 4]}},
	"boss_gravedigger": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_bone_colossus": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_plague": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"megaboss": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_giant_knight": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_sewer_monster": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_zombie_titan": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"boss_galaxy_boss": {"hframes": 8, "anims": {"idle": [0, 4], "attack": [4, 4]}},
	"titan": {"hframes": 14, "fps": 10.0,
		"anims": {"idle": [0, 4], "scythe": [4, 6], "charge": [10, 4]}},
	"proj_fireball": {"hframes": 4, "fps": 12.0, "anims": {"idle": [0, 4]}},
	"proj_ultimate": {"hframes": 4, "fps": 12.0, "anims": {"idle": [0, 4]}},
	"fx_shockwave": {"hframes": 6},
	"fx_hit": {"hframes": 5},
	"hazard_poison": {"hframes": 4, "fps": 6.0},
	"tiles_floor": {"hframes": 4},
	"ui_upgrades": {"hframes": 8},
}

@export var texture_name: String = ""
@export var fps: float = 8.0
@export var radius: float = 16.0
@export var shape_color: Color = Color.WHITE
@export var shape: String = "circle" ## circle | diamond | square

var _sprite: Sprite2D = null
var _time: float = 0.0
var _anim_start: int = 0
var _anim_length: int = 1
var _anim_loops: bool = true
var _anim_done: bool = false
var _return_to: String = ""

## Texture d'une planche, ou `null` si l'asset n'a pas été déposé. Les FX qui
## gardent leur propre rendu géométrique s'en servent pour choisir leur voie.
static func sheet_texture(sheet: String) -> Texture2D:
	var path := DIR + sheet + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## Nombre de cases d'une planche, d'après `SHEETS`.
static func sheet_frames(sheet: String) -> int:
	return int(SHEETS.get(sheet, {}).get("hframes", 1))

func _ready() -> void:
	var tex := sheet_texture(texture_name)
	if tex == null:
		return
	var conf: Dictionary = SHEETS.get(texture_name, {})
	fps = float(conf.get("fps", fps))
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.hframes = maxi(1, int(conf.get("hframes", 1)))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	var anims: Dictionary = conf.get("anims", {})
	if anims.is_empty():
		_anim_length = _sprite.hframes
	else:
		play(str(anims.keys()[0]))

## Bascule sur une animation nommée. Sans planche déposée, ou si le nom est
## inconnu, l'appel est ignoré : l'appelant n'a pas à savoir ce qui existe.
## Oriente le visuel vers la gauche ou vers la droite.
##
## Les sprites sont dessinés face à la caméra, comme dans la v1 : une entité ne
## pivote pas, elle se retourne. Faire tourner un sprite dessiné de face le
## couche sur le flanc dès qu'il se déplace à l'horizontale.
func face(direction_x: float) -> void:
	if _sprite == null or is_zero_approx(direction_x):
		return
	_sprite.flip_h = direction_x < 0.0


func play(anim: String, loops: bool = true) -> void:
	if _sprite == null:
		return
	var anims: Dictionary = SHEETS.get(texture_name, {}).get("anims", {})
	if not anims.has(anim):
		return
	var range_: Array = anims[anim]
	if _anim_start == int(range_[0]) and _anim_loops == loops and not _anim_done:
		return
	_anim_start = int(range_[0])
	_anim_length = maxi(1, int(range_[1]))
	_anim_loops = loops
	_return_to = ""
	_anim_done = false
	_time = 0.0
	_sprite.frame = _anim_start

## Joue une animation jusqu'au bout, puis revient à `fallback`. Sert aux gestes
## ponctuels (l'attaque d'un boss) sans que l'appelant ait à compter le temps.
func play_once(anim: String, fallback: String) -> void:
	if _sprite == null or not SHEETS.get(texture_name, {}).get("anims", {}).has(anim):
		return
	play(anim, false)
	_return_to = fallback

## Vrai quand une animation lancée avec `loops = false` a fini de dérouler.
func animation_finished() -> bool:
	return _anim_done

## Durée d'une animation nommée, pour caler un timing dessus (0 sans planche).
func animation_duration(anim: String) -> float:
	var anims: Dictionary = SHEETS.get(texture_name, {}).get("anims", {})
	if _sprite == null or not anims.has(anim):
		return 0.0
	return float(int(anims[anim][1])) / maxf(1.0, fps)

func _process(delta: float) -> void:
	_time += delta
	if _sprite == null:
		queue_redraw()
		return
	if _anim_length <= 1:
		return
	var step := int(_time * fps)
	if _anim_loops:
		_sprite.frame = _anim_start + step % _anim_length
	else:
		_sprite.frame = _anim_start + mini(step, _anim_length - 1)
		_anim_done = step >= _anim_length - 1
		if _anim_done and _return_to != "":
			var back := _return_to
			_return_to = ""
			play(back)

func _draw() -> void:
	if _sprite != null:
		return
	# Placeholder : disque plein, liseré plus clair, et un point de "regard"
	# pour que l'orientation reste lisible sans sprite.
	var pulse := 1.0 + 0.04 * sin(_time * 6.0)
	var r := radius * pulse
	match shape:
		"diamond":
			var pts := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
			draw_colored_polygon(pts, shape_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), shape_color.lightened(0.4), 2.0)
		"square":
			var rect := Rect2(-r, -r, r * 2.0, r * 2.0)
			draw_rect(rect, shape_color)
			draw_rect(rect, shape_color.lightened(0.4), false, 2.0)
		_:
			draw_circle(Vector2.ZERO, r, shape_color)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, shape_color.lightened(0.45), 2.0)

func flash() -> void:
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
