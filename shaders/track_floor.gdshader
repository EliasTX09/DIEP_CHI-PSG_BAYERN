// Bahn-Belag: weiche Maeh-Streifen entlang der Bahn (UV.x = seitliche Position in m, UV.y = Bahn-Distanz in m),
// grossflaechiger Farbverlauf + Halm-Struktur, optional Schachbrett und leuchtende Randlinie (Neon-Welt).
// Gruen: feine, konzentrische Putt-Linien rund ums Loch (ring_strength > 0).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.22, 0.62, 0.27);
uniform vec3 color_b : source_color = vec3(0.27, 0.70, 0.32);
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float stripe_length = 2.5;
uniform float half_width = 2.5;
uniform float line_strength = 0.0;
uniform float emission_strength = 0.0;
uniform float surface_roughness = 0.9;
uniform float surface_metallic = 0.0;
uniform float checker = 0.0;
uniform float grass_detail = 1.0;
uniform vec2 ring_center = vec2(0.0, 0.0);
uniform float ring_strength = 0.0;
uniform float ring_spacing = 0.55;
uniform float ring_reach = 6.5;

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
	float s = floor(UV.y / stripe_length);
	float c = floor((UV.x + 100.0) / stripe_length);
	float stripe = mod(s + checker * c, 2.0);
	// weiche Streifenkante (keine harte Plastik-Kante)
	float fy = fract(UV.y / stripe_length);
	float soft = smoothstep(0.0, 0.1, fy) * (1.0 - smoothstep(0.9, 1.0, fy));
	stripe = mix(0.5, stripe, mix(soft, 1.0, checker));
	vec3 col = mix(color_a, color_b, stripe);
	// Farbverlauf ueber groessere Flaechen + Halm-Koernung
	float big = noise(wpos.xz * 0.12) * 0.6 + noise(wpos.xz * 0.37) * 0.4;
	float blades = hash(floor(wpos.xz * 22.0)) * 0.6 + noise(wpos.xz * 7.0) * 0.4;
	col *= mix(1.0, 0.9 + 0.2 * big, grass_detail);
	col *= mix(1.0, 0.93 + 0.12 * blades, grass_detail);
	col = mix(col, col * vec3(1.05, 1.08, 0.85), smoothstep(0.55, 0.85, big) * 0.35 * grass_detail);
	float edge = smoothstep(half_width - 0.24, half_width - 0.1, abs(UV.x));
	col = mix(col, line_color, edge * clamp(line_strength, 0.0, 1.0));
	// Putt-Ringe ums Loch
	float rd = length(wpos.xz - ring_center);
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(fract(rd / ring_spacing) - 0.5) * ring_spacing);
	float ring_mask = ring_strength * smoothstep(0.85, 1.1, rd) * (1.0 - smoothstep(ring_reach * 0.6, ring_reach, rd));
	col = mix(col, col * 1.22 + vec3(0.02), ring * ring_mask);
	ALBEDO = col;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	EMISSION = line_color * edge * line_strength * emission_strength + col * emission_strength * 0.06;
}
