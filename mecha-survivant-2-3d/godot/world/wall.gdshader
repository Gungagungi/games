shader_type spatial;
render_mode diffuse_lambert;

// Pierres des murs, projetées selon la face (triplanaire simple) : moellons
// en quinconce sur les côtés, gravats sur le dessus, mousse au pied du mur.
// La couleur de chaque case vient de la couleur de sommet (village_builder.gd).

varying vec3 world_pos;
varying vec3 world_normal;

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
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(world_normal);
	vec3 base = COLOR.rgb;
	vec3 col;
	if (an.y > 0.5) {
		// Dessus : gravats et pierres disjointes.
		vec2 p = world_pos.xz;
		col = base * (0.55 + 0.35 * noise(p * 3.0));
		col = mix(col, vec3(0.1, 0.13, 0.07), smoothstep(0.55, 0.8, noise(p * 0.8)) * 0.6);
	} else {
		vec2 uv = an.x > an.z ? world_pos.zy : world_pos.xy;
		vec2 s = uv * vec2(1.25, 2.6);
		float row = floor(s.y);
		s.x += mod(row, 2.0) * 0.5 + hash(vec2(row, 9.0)) * 0.3;
		vec2 id = floor(s);
		vec2 f = fract(s);
		float edge = min(min(f.x, 1.0 - f.x) * 1.8, min(f.y, 1.0 - f.y));
		float stone = smoothstep(0.03, 0.09, edge);
		vec3 st = base * (0.7 + 0.5 * hash(id));
		st *= 0.85 + 0.25 * noise(uv * 5.0);
		col = mix(base * 0.25, st, stone);
		// Mousse et humidité au pied du mur.
		float moss = smoothstep(0.9, 0.0, world_pos.y) * smoothstep(0.35, 0.7, noise(uv * 1.7));
		col = mix(col, vec3(0.08, 0.12, 0.05), moss * 0.7);
		// Arêtes noircies en haut du mur, comme brûlées.
		col *= 1.0 - smoothstep(0.5, 1.0, noise(uv * 0.6 + vec2(3.0))) * 0.35;
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
