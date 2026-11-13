// Fliessende, gluehende Lava mit dunkler Kruste.
shader_type spatial;
render_mode cull_back;

uniform vec3 hot : source_color = vec3(1.0, 0.85, 0.25);
uniform vec3 mid : source_color = vec3(1.0, 0.33, 0.05);
uniform vec3 crust : source_color = vec3(0.12, 0.03, 0.02);
uniform float scale = 0.11;
uniform float speed = 0.22;
uniform float glow = 1.9;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float f = 0.0;
	for (int i = 0; i < 4; i++) {
		f += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return f;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME * speed;
	float n1 = fbm(p + vec2(t, t * 0.6));
	float n2 = fbm(p * 1.7 - vec2(t * 0.8, t * 0.3) + vec2(n1));
	float heat = smoothstep(0.4, 0.8, n2);
	vec3 col = mix(crust, mid, smoothstep(0.0, 0.5, heat));
	col = mix(col, hot, smoothstep(0.55, 1.0, heat));
	ALBEDO = col * 0.35;
	EMISSION = col * heat * glow;
	ROUGHNESS = 0.9;
}
