// Shader commun aux sprites d'entité (mech, ennemis, boss), posé par
// `SpriteOrShape`. Trois effets pilotés depuis le code, tous à 0 au repos :
//
// - `flash`    : silhouette blanche à l'impact (0 → rien, 1 → blanc pur) ;
// - `dissolve` : désintégration à la mort, par un bruit de hachage en cases
//                de pixel art (0 → intact, 1 → disparu), avec une lisière
//                incandescente de la couleur `edge_color` ;
// - `outline`  : contour d'un pixel de texture, pour détacher l'entité du sol.
//
// Pas de texture de bruit : le hachage tient dans le shader et suit la grille
// de la texture, donc la désintégration reste « pixel art » à toute échelle.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.2, 1.0);
uniform vec4 outline_color : source_color = vec4(0.04, 0.03, 0.06, 0.85);
uniform bool outline = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (outline && c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n > 0.0) {
			c = outline_color;
		}
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	if (dissolve > 0.0) {
		float h = hash(floor(UV / TEXTURE_PIXEL_SIZE));
		if (h < dissolve) {
			c.a = 0.0;
		} else if (h < dissolve + 0.12) {
			c.rgb = edge_color.rgb;
		}
	}
	COLOR = c * COLOR;
}
