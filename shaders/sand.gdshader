// Sandbunker: feine Koernung, Wind-Rippel, dunklerer Rand zur Gras-Lippe hin.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 sand_light : source_color = vec3(0.96, 0.88, 0.64);
uniform vec3 sand_dark : source_color = vec3(0.82, 0.71, 0.47);

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(UV);
	float ripple = sin(wpos.x * 5.5 + wpos.z * 2.2 + noise(wpos.xz * 1.3) * 3.0) * 0.5 + 0.5;
	float grain = hash(floor(wpos.xz * 60.0));
	float blot = noise(wpos.xz * 0.9);
	vec3 col = mix(sand_dark, sand_light, 0.55 + 0.25 * blot + 0.12 * ripple);
	col *= 0.93 + 0.12 * grain;
	col = mix(col, sand_dark * 0.85, smoothstep(0.78, 1.0, r) * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
