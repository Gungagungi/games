shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Dalles de pierre : quadrillage de 4 m, teinte qui varie d'une dalle à
// l'autre. Les joints donnent la sensation de vitesse en vue à la 3e personne.
uniform vec3 base_color : source_color = vec3(0.17, 0.155, 0.14);
uniform vec3 joint_color : source_color = vec3(0.07, 0.065, 0.06);
uniform float tile = 4.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = world_pos.xz / tile;
	vec2 cell = floor(g);
	vec2 f = abs(fract(g) - 0.5);
	float w = max(fwidth(g.x), fwidth(g.y));
	float joint = smoothstep(0.47 - w, 0.49 + w, max(f.x, f.y));
	float tint = 0.85 + hash(cell) * 0.3;
	float speck = 0.94 + hash(floor(world_pos.xz * 3.0)) * 0.12;
	ALBEDO = mix(base_color * tint * speck, joint_color, joint);
	ROUGHNESS = 0.95;
}
