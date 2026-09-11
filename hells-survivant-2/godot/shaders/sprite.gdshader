shader_type canvas_item;
// Flash de coup, contour (télégraphe des boss) et dissolution à la mort,
// pour des sprites fixes qui n'ont pas d'animation image par image.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float outline : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 texel = TEXTURE_PIXEL_SIZE;
	if (outline > 0.0 && c.a < 0.5) {
		float a = texture(TEXTURE, UV + vec2(texel.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(texel.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, texel.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, texel.y)).a;
		if (a > 0.0) {
			c = vec4(outline_color.rgb, outline * outline_color.a);
		}
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash * step(0.01, c.a));
	if (dissolve > 0.0) {
		// Bruit calé sur les texels : la dissolution reste en gros pixels.
		float n = hash(floor(UV / texel));
		if (n < dissolve) {
			c.a = 0.0;
		} else if (n < dissolve + 0.15) {
			c.rgb = dissolve_color.rgb;
		}
	}
	COLOR = c * COLOR;
}
