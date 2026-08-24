class_name Hud
extends CanvasLayer
## Barres de vie / endurance / bouclier, vague en cours, pouvoirs acquis,
## barre de boss. Construit en code : c'est de l'UI purement dynamique.

var player: Player

var _hp := ProgressBar.new()
var _stamina := ProgressBar.new()
var _shield := ProgressBar.new()
var _wave_label := Label.new()
var _powers := Label.new()
var _boss_box := VBoxContainer.new()
var _boss_label := Label.new()
var _boss_bar := ProgressBar.new()

func _ready() -> void:
	layer = 10
	visible = false
	var left := VBoxContainer.new()
	left.position = Vector2(20, 16)
	left.custom_minimum_size = Vector2(280, 0)
	left.add_theme_constant_override("separation", 4)
	add_child(left)

	_wave_label.add_theme_font_size_override("font_size", 20)
	left.add_child(_wave_label)
	left.add_child(_styled(_hp, Color(0.85, 0.25, 0.3)))
	left.add_child(_styled(_stamina, Color(0.35, 0.8, 0.5)))
	left.add_child(_styled(_shield, Color(0.35, 0.7, 1.0)))
	_powers.add_theme_font_size_override("font_size", 13)
	_powers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_powers.custom_minimum_size = Vector2(280, 0)
	left.add_child(_powers)

	_boss_box.position = Vector2(340, 16)
	_boss_box.custom_minimum_size = Vector2(600, 0)
	_boss_label.add_theme_font_size_override("font_size", 18)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_label)
	_boss_box.add_child(_styled(_boss_bar, Color(0.9, 0.35, 0.25), 600.0))
	_boss_box.visible = false
	add_child(_boss_box)

	EventBus.player_stats_changed.connect(_refresh)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.player_died.connect(func() -> void: visible = false)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_phase_changed.connect(_on_boss_phase)
	EventBus.boss_defeated.connect(func() -> void: _boss_box.visible = false)

func _styled(bar: ProgressBar, color: Color, width: float = 280.0) -> ProgressBar:
	bar.custom_minimum_size = Vector2(width, 16)
	bar.show_percentage = false
	bar.max_value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	bg.border_color = Color(0.23, 0.28, 0.38)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _refresh() -> void:
	if player == null:
		return
	_hp.max_value = player.max_hp
	_hp.value = maxf(0.0, player.hp)
	_stamina.max_value = player.max_stamina
	_stamina.value = player.stamina
	_shield.visible = player.shield_max > 0.0
	_shield.max_value = maxf(1.0, player.shield_max)
	_shield.value = player.shield
	_powers.text = _powers_summary()

## Un pouvoir peut être pris plusieurs fois : on l'affiche une seule fois, avec
## son nombre de cumuls. Les libellés sont du texte, pas des emoji — la police
## par défaut de Godot ne rend pas ces derniers.
func _powers_summary() -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for id in UpgradeManager.owned:
		if not counts.has(id):
			counts[id] = 0
			order.append(id)
		counts[id] += 1
	var parts: PackedStringArray = []
	for id in order:
		var label := str(UpgradeManager.find(id).get("short", id))
		parts.append(label if counts[id] == 1 else "%s x%d" % [label, counts[id]])
	return " · ".join(parts)

func _on_wave_started(n: int) -> void:
	_wave_label.text = "VAGUE %d" % n
	visible = true

func _on_boss_spawned(_boss: Node, display_name: String, _max_hp: float) -> void:
	_boss_label.text = display_name
	_boss_bar.max_value = 1.0
	_boss_bar.value = 1.0
	_boss_box.visible = true

func _on_boss_hp(ratio: float) -> void:
	_boss_bar.value = ratio

func _on_boss_phase(phase: int, count: int) -> void:
	if count > 1:
		_boss_label.text = "%s — phase %d/%d" % [_boss_label.text.split(" — ")[0], phase, count]
