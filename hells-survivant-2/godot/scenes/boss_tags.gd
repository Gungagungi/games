class_name BossTags
extends Node2D
## Conclave des boss : nom et barre de vie au-dessus de chaque boss, et
## infobulle des attaques du boss que le héros approche
## (`World.inspected_boss`). Hors du Conclave, la barre unique du HUD suffit et
## rien n'est dessiné.

const FONT := preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_SIZE := 13
const TIP_TITLE_SIZE := 15
const TIP_ICON := 24.0
const TIP_LINE := 27.0
const TIP_PAD := 8.0
## Apparition et disparition de l'infobulle, en part d'opacité par seconde.
const TIP_FADE := 6.0
## Au-delà, les attaques se rangent sur deux colonnes (la Créature en a 11) :
## sur une seule, l'infobulle ne trouve de place nulle part dans l'arène.
const TIP_ONE_COLUMN := 6

var world: World
var _icons := {}
## Boss de l'infobulle, gardé le temps qu'elle s'efface.
var _tip_boss: Enemy = null
var _tip_alpha := 0.0

func _ready() -> void:
	# Lisible dans l'obscurité, comme les textes flottants.
	material = Fx.unshaded()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	var e: Enemy = world.inspected_boss() if world != null else null
	if e != null and e != _tip_boss:
		_tip_boss = e
		_tip_alpha = 0.0
	if e != null:
		_tip_alpha = minf(1.0, _tip_alpha + delta * TIP_FADE)
	else:
		_tip_alpha = maxf(0.0, _tip_alpha - delta * TIP_FADE)
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
	if _tip_alpha > 0.0 and is_instance_valid(_tip_boss) and world.enemies.has(_tip_boss):
		_draw_tip(_tip_boss, _tip_alpha)

## Cadre près du boss (voir `_tip_box`) : son nom, puis une ligne par attaque,
## icône et description, sur une ou deux colonnes.
func _draw_tip(e: Enemy, a: float) -> void:
	var attacks := Data.boss_attacks(e.element, e.is_final)
	if attacks.is_empty():
		return
	var title := World.boss_name(e)
	var cols := 2 if attacks.size() > TIP_ONE_COLUMN else 1
	var rows := ceili(float(attacks.size()) / cols)
	var col_w := 0.0
	for id: String in attacks:
		var tw := FONT.get_string_size(Data.ATTACKS[id], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		col_w = maxf(col_w, TIP_ICON + 8.0 + tw)
	var title_w := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_TITLE_SIZE).x
	var w := maxf(title_w, col_w * cols + TIP_PAD * 2.0 * (cols - 1)) + TIP_PAD * 2.0
	var h := TIP_PAD * 2.0 + 22.0 + TIP_LINE * rows
	var box := _tip_box(e, Vector2(w, h))
	var x := box.position.x
	var y := box.position.y
	draw_rect(box, Color(0.07, 0.02, 0.02, 0.9 * a))
	draw_rect(box, Color(e.glow, a), false, 2.0)
	var tpos := Vector2(x + TIP_PAD, y + TIP_PAD + 14.0)
	draw_string_outline(FONT, tpos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_TITLE_SIZE, 4, Color(0.08, 0, 0, a))
	draw_string(FONT, tpos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TIP_TITLE_SIZE, Color(UiTheme.GOLD, a))
	# Remplissage colonne par colonne : l'ordre de lecture reste celui de `Data`.
	for i in attacks.size():
		var id: String = attacks[i]
		var lx := x + TIP_PAD + (col_w + TIP_PAD * 2.0) * (i / rows)
		var ly := y + TIP_PAD + 22.0 + TIP_LINE * (i % rows)
		draw_texture_rect(_icon(id), Rect2(lx, ly, TIP_ICON, TIP_ICON), false, Color(1, 1, 1, a))
		var lpos := Vector2(lx + TIP_ICON + 8.0, ly + TIP_ICON / 2.0 + 5.0)
		draw_string(FONT, lpos, Data.ATTACKS[id], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(UiTheme.PARCH, a))

## Place de l'infobulle : de préférence à l'opposé du héros, qui arrive vers le
## boss et ne doit pas disparaître dessous. On essaie au-dessus du nom du boss,
## en dessous, puis sur ses côtés ; la première place qui tient dans l'arène
## sans couvrir le héros l'emporte. À défaut, une place recadrée dans l'arène
## qui ne couvre ni le héros ni le boss.
func _tip_box(e: Enemy, size: Vector2) -> Rect2:
	var p := world.player.position
	var top := e.top()
	var above := Rect2(e.position.x - size.x / 2.0, e.position.y - top - 34.0 - size.y, size.x, size.y)
	var below := Rect2(e.position.x - size.x / 2.0, e.position.y + top + 10.0, size.x, size.y)
	var left := Rect2(e.position.x - top - 14.0 - size.x, e.position.y - size.y / 2.0, size.x, size.y)
	var right := Rect2(e.position.x + top + 14.0, e.position.y - size.y / 2.0, size.x, size.y)
	var order := [above, below] if p.y > e.position.y else [below, above]
	order.append_array([right, left] if p.x < e.position.x else [left, right])
	var hero := Rect2(p - Vector2(28, 40), Vector2(56, 72))
	var lo := Vector2(4.0, World.RUSH_HUD_TOP + 4.0)
	var hi := Data.ARENA - size - Vector2(4.0, 4.0)
	for r: Rect2 in order:
		var fits := r.position.x >= lo.x and r.position.y >= lo.y and r.position.x <= hi.x and r.position.y <= hi.y
		if fits and not r.intersects(hero):
			return r
	var boss := Rect2(e.position - Vector2(top, top), Vector2(top, top) * 2.0)
	var r0: Rect2 = order[0]
	for r: Rect2 in order:
		var c := Rect2(r.position.clamp(lo, hi), size)
		if not c.intersects(hero) and not c.intersects(boss):
			return c
	return Rect2(r0.position.clamp(lo, hi), size)

func _icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = load("res://assets/sprites/attacks/%s.png" % id)
	return _icons[id]
