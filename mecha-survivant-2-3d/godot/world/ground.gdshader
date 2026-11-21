shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Sol du village, en un seul shader : la nature de chaque case est lue dans
// `cell_map` (une texture COLS × ROWS écrite par village_builder.gd, canal R =
// nature de la case, G = variante). Herbe et terre suivent un bruit continu
// pour que les plaques ne dessinent pas la grille ; rues pavées et planchers
// des maisons, eux, s'arrêtent net au bord des cases, comme une vraie bordure.

uniform sampler2D cell_map : filter_nearest;
uniform float cell = 2.0;
uniform int cols = 112;
uniform int rows = 64;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Pavés en quinconce, joints sombres, teinte qui varie d'un pavé à l'autre.
vec3 cobbles(vec2 p) {
	vec2 s = p * vec2(2.3, 2.9);
	float row = floor(s.y);
	s.x += mod(row, 2.0) * 0.5;
	vec2 id = floor(s);
	vec2 f = fract(s);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float w = fwidth(s.x) * 1.5;
	float stone = smoothstep(0.05, 0.1 + w, edge);
	vec3 c = vec3(0.2, 0.185, 0.17) * (0.65 + 0.55 * hash(id));
	c *= 0.9 + 0.2 * noise(p * 6.0);
	return mix(vec3(0.06, 0.06, 0.065), c, stone);
}

// Planches de bois, joints entre lames, nœuds ; `tint` change d'une maison
// à l'autre.
vec3 planks(vec2 p, float tint) {
	vec2 s = p * vec2(0.55, 2.4);
	float row = floor(s.y);
	s.x += hash(vec2(row, 3.0)) * 4.0;
	vec2 id = vec2(floor(s.x), row);
	vec2 f = fract(s);
	float seam = smoothstep(0.0, 0.06, f.y) * smoothstep(0.0, 0.06, 1.0 - f.y);
	seam *= smoothstep(0.0, 0.015, f.x) * smoothstep(0.0, 0.015, 1.0 - f.x);
	vec3 wood = mix(vec3(0.22, 0.14, 0.08), vec3(0.3, 0.2, 0.11), tint);
	wood *= 0.75 + 0.45 * hash(id);
	wood *= 0.9 + 0.15 * noise(vec2(p.x * 7.0, p.y * 0.8));
	return mix(vec3(0.05, 0.035, 0.02), wood, seam);
}

void fragment() {
	vec2 g = world_pos.xz / cell;
	ivec2 c = clamp(ivec2(floor(g)), ivec2(0), ivec2(cols - 1, rows - 1));
	vec4 m = texelFetch(cell_map, c, 0);
	int kind = int(m.r * 255.0 + 0.5);
	vec2 p = world_pos.xz;

	float n = noise(p * 0.18) * 0.55 + noise(p * 0.7) * 0.3 + noise(p * 3.1) * 0.15;
	vec3 grass = mix(vec3(0.075, 0.1, 0.055), vec3(0.15, 0.17, 0.085), n);
	vec3 dirt = mix(vec3(0.14, 0.105, 0.07), vec3(0.22, 0.16, 0.1), noise(p * 1.4));
	float dirt_mask = smoothstep(0.5, 0.62, noise(p * 0.07 + vec2(13.0, 7.0)));
	vec3 col = mix(grass, dirt, dirt_mask);
	// Cailloux épars sur l'herbe.
	float pebble = step(0.93, hash(floor(p * 4.0))) * step(0.4, noise(p * 0.3));
	col = mix(col, vec3(0.2, 0.2, 0.19), pebble * 0.6);

	if (kind == 1) {
		col = cobbles(p);
		// Herbe qui perce entre les pavés.
		col = mix(col, grass, smoothstep(0.62, 0.8, noise(p * 0.9 + vec2(4.0))) * 0.55);
	} else if (kind == 2) {
		col = planks(p, m.g);
		col = mix(col, dirt * 0.8, smoothstep(0.6, 0.85, noise(p * 0.5)) * 0.6);
	} else if (kind == 3 || kind == 4) {
		col = mix(dirt, vec3(0.08, 0.075, 0.07), 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
