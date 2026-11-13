class_name Vignette
extends CanvasLayer
## Assombrissement des bords de l'écran, qui vire au rouge et bat comme un
## pouls quand la coque du mech passe sous `DANGER` de sa vie max (v3).
##
## Sous le HUD (couche 10), au-dessus du monde. N'intercepte aucun clic ni
## toucher : la moitié gauche de l'écran porte le joystick tactile.

const DANGER := 0.35

const SHADER := """
shader_type canvas_item;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.35, 0.85, length(d * vec2(1.0, 0.8)) * 1.4);
	vec3 tint = mix(vec3(0.02, 0.02, 0.05), vec3(0.55, 0.0, 0.02), danger);
	COLOR = vec4(tint, edge * (0.45 + danger * (0.25 + 0.2 * pulse)));
}
"""

var player: Player = null

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0

func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_rect.material = _mat
	add_child(_rect)

func _process(delta: float) -> void:
	_t += delta
	var danger := 0.0
	if player != null and player.alive and player.max_hp > 0.0:
		danger = clampf(1.0 - (player.hp / player.max_hp) / DANGER, 0.0, 1.0)
	_mat.set_shader_parameter("danger", danger)
	_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 7.0))
