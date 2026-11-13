// Neon-Hochhaus: dunkle Fassade mit zufaellig leuchtenden Fenstern (Weltraum-Koordinaten).
shader_type spatial;
render_mode cull_back;

uniform vec3 wall_color : source_color = vec3(0.03, 0.04, 0.08);
uniform vec3 window_a : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 window_b : source_color = vec3(1.0, 0.25, 0.8);
uniform float glow = 1.6;

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float side = abs(wnormal.x) > abs(wnormal.z) ? wpos.z : wpos.x;
	vec2 cell = vec2(floor(side / 2.2), floor(wpos.y / 3.0));
	vec2 f = vec2(fract(side / 2.2), fract(wpos.y / 3.0));
	float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
	win *= 1.0 - step(0.5, abs(wnormal.y));
	float r = hash(cell);
	float lit = step(0.55, r);
	vec3 wc = mix(window_a, window_b, step(0.8, r));
	ALBEDO = wall_color;
	EMISSION = wc * win * lit * glow;
	ROUGHNESS = 0.5;
	METALLIC = 0.3;
}
