// Tal-Gelaende rund um die Bahn: Rough-Streifen an der Bahn, saftige Wiesen mit Farbverlauf,
// Felsklippen an steilen Hangen, Schnee auf den Gipfeln, nasser Fels/Sand an Schluchten und Ufern.
// Vertex-Farbe: r = Abstand zur Bahn (0..1 auf 60 m), g = Schlucht/Ufer.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 rough_color : source_color = vec3(0.17, 0.42, 0.16);
uniform vec3 grass_a : source_color = vec3(0.25, 0.55, 0.2);
uniform vec3 grass_b : source_color = vec3(0.42, 0.62, 0.24);
uniform vec3 rock_color : source_color = vec3(0.48, 0.45, 0.42);
uniform vec3 rock_dark : source_color = vec3(0.3, 0.28, 0.27);
uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform vec3 wet_color : source_color = vec3(0.36, 0.33, 0.28);
uniform vec3 crack_color : source_color = vec3(1.0, 0.35, 0.05);
uniform float snow_height = 9999.0;
uniform float rock_slope = 0.55;
uniform float crack_strength = 0.0;
uniform float grid_strength = 0.0;
uniform vec3 grid_color : source_color = vec3(0.2, 0.9, 1.0);

varying vec3 wpos;
varying vec3 wnrm;

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
	return noise(p) * 0.55 + noise(p * 2.13) * 0.28 + noise(p * 4.7) * 0.17;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float near = COLOR.r;
	float wet = COLOR.g;
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float big = fbm(wpos.xz * 0.035);
	float small = fbm(wpos.xz * 0.6);
	// Wiese: grossflaechiger Farbverlauf + feine Halm-Struktur
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.3, 0.75, big));
	grass *= 0.9 + 0.18 * small;
	// Rough direkt an der Bahn: dunkler, dichter
	vec3 col = mix(rough_color * (0.9 + 0.2 * small), grass, smoothstep(0.08, 0.2, near));
	// Fels an steilen Hangen (Klippen), mit Schichtung
	float strata = sin(wpos.y * 1.7 + big * 6.0) * 0.5 + 0.5;
	vec3 rock = mix(rock_dark, rock_color, 0.45 + 0.35 * strata + 0.2 * small);
	float rk = smoothstep(rock_slope - 0.12, rock_slope + 0.1, slope + (small - 0.5) * 0.18);
	col = mix(col, rock, rk);
	// Nasse Ufer und Schluchtwaende
	col = mix(col, wet_color * (0.85 + 0.3 * small), smoothstep(0.25, 0.8, wet) * (1.0 - rk * 0.5));
	// Schnee auf Gipfeln (weniger an steilen Waenden)
	float snow = smoothstep(snow_height - 4.0, snow_height + 3.0, wpos.y + (big - 0.5) * 8.0) * (1.0 - smoothstep(0.55, 0.8, slope));
	col = mix(col, snow_color, snow);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, rk);
	// Gluehende Risse (Vulkan) bzw. Leucht-Raster (Neon)
	float cn = noise(wpos.xz * 0.2 + vec2(big * 3.0));
	float cracks = smoothstep(0.485, 0.5, cn) * (1.0 - smoothstep(0.5, 0.515, cn)) * (1.0 - rk * 0.7);
	vec2 g = abs(fract(wpos.xz / 6.0) - 0.5);
	float grid = 1.0 - smoothstep(0.0, 0.03, min(g.x, g.y));
	EMISSION = crack_color * cracks * crack_strength * (smoothstep(0.1, 0.6, wet) + 0.25 * (1.0 - smoothstep(0.05, 0.2, near))) + grid_color * grid * grid_strength * (1.0 - rk);
}
