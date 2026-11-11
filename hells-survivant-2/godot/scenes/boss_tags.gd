class_name BossTags
extends Node2D
## Conclave des boss : nom et barre de vie au-dessus de chaque boss. Hors du
## Conclave, la barre unique du HUD suffit et rien n'est dessiné.

const FONT := preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_SIZE := 13

var world: World

func _ready() -> void:
	# Lisible dans l'obscurité, comme les textes flottants.
	material = Fx.unshaded()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if world == null or not Game.boss_rush:
		return
	for e in world.enemies:
		if not e.is_boss:
			continue
		var label := World.boss_name(e)
		var w := 30.0 * e.sprite_scale
		var y := e.position.y - e.top() - 10.0
		var x := e.position.x
		draw_rect(Rect2(x - w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x - w / 2.0, y, w * clampf(e.hp / e.max_hp, 0.0, 1.0), 4.0), e.glow)
		var size := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var pos := Vector2(x - size.x / 2.0, y - 5.0)
		draw_string_outline(FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.08, 0, 0))
		draw_string(FONT, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiTheme.PARCH)
