// Golfball mit echten Dellen (Dimples): prozedurale Normalen aus einem gleichmaessig verteilten Punktgitter
// auf der Kugel (ca. 330 Dellen), jede Delle eine flache Schuessel mit Kontaktschatten.
// Darueber eine glaenzende Klarlack-Schicht. Farbiger Aequator-Streifen = Spielerfarbe.
// Feine Details blenden mit der Entfernung aus (kein Flimmern, wenn der Ball nur ein paar Pixel gross ist).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.96);
uniform vec3 stripe_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float surface_metallic = 0.0;
uniform float surface_roughness = 0.32;
// Dellen pro Einheit auf der Einheitskugel (5.2 -> etwa 330 Dellen)
uniform float dimple_density = 5.2;
uniform float dimple_depth = 0.55;
uniform float clearcoat_amount = 1.0;
uniform float clearcoat_roughness = 0.08;

varying vec3 obj_n;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// Naechster Dellen-Mittelpunkt (auf die Kugel projiziert) und Abstand in der Tangentialebene.
// Rueckgabe: xyz = Richtung zur Dellen-Mitte (tangential, normiert auf den Dellen-Radius), w = Abstand / Radius
vec4 nearest_dimple(vec3 n) {
	vec3 p = n * dimple_density;
	vec3 cell = floor(p);
	float best = 1e9;
	vec3 best_c = p;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				// wenig Zufall -> fast regelmaessiges Muster wie bei echten Baellen
				vec3 f = c + 0.5 + (hash3(c) - 0.5) * 0.35;
				vec3 fs = normalize(f) * dimple_density;
				float d = dot(fs - p, fs - p);
				if (d < best) {
					best = d;
					best_c = fs;
				}
			}
		}
	}
	vec3 d = best_c - p;
	vec3 dt = d - n * dot(d, n);
	// Dellen-Radius relativ zum Gitter: kleiner als der halbe Abstand -> runde Dellen mit flachem Steg dazwischen
	float radius = 0.37;
	return vec4(dt / radius, length(dt) / radius);
}

void vertex() {
	obj_n = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(obj_n);
	float band = 1.0 - smoothstep(0.1, 0.14, abs(n.y));
	vec3 col = mix(base_color, stripe_color, band);
	// Detailgrad nach Bildschirmgroesse der Dellen
	float fw = length(fwidth(n * dimple_density));
	float detail = 1.0 - smoothstep(0.35, 0.8, fw);
	vec4 dm = nearest_dimple(n);
	float r = dm.w;
	float inside = 1.0 - smoothstep(0.82, 1.0, r);
	// Schuessel: Normale kippt zur Dellen-Mitte, am Rand ein schmaler Grat
	vec3 tilt = dm.xyz * inside * dimple_depth;
	float rim = smoothstep(0.85, 1.0, r) * (1.0 - smoothstep(1.0, 1.25, r));
	vec3 n_obj = normalize(n + tilt * detail - normalize(dm.xyz + vec3(1e-5)) * rim * 0.08 * detail);
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_obj));
	float cavity = inside * (1.0 - r * r) * detail;
	ALBEDO = col * (1.0 - cavity * 0.1);
	AO = 1.0 - cavity * 0.35;
	AO_LIGHT_AFFECT = 0.4;
	ROUGHNESS = surface_roughness + cavity * 0.15;
	METALLIC = surface_metallic;
	SPECULAR = 0.6;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
}
