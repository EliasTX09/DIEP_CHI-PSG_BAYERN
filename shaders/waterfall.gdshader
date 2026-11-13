// Wasserfall / Lavafall: nach unten laufende Schlieren.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.55, 0.82, 1.0);
uniform vec3 streak : source_color = vec3(1.0, 1.0, 1.0);
uniform float speed = 1.6;
uniform float emission_strength = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = vec2(UV.x * 8.0, UV.y * 2.0 - TIME * speed);
	float n = noise(uv * vec2(1.0, 3.0)) * 0.6 + noise(uv * vec2(3.0, 8.0)) * 0.4;
	vec3 col = mix(color * 0.75, streak, smoothstep(0.45, 0.8, n));
	ALBEDO = col;
	ROUGHNESS = 0.2;
	EMISSION = col * emission_strength;
}
