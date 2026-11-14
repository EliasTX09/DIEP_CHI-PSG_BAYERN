// Baeume, Straeucher, Wurzeln und Felsen (ein Shader fuer alle Flora-Meshes, auch in MultiMeshes).
// Vertex-Farbe rgb = Grundfarbe inkl. eingebackenem Schatten (Krone innen/unten dunkler = Ambient Occlusion),
// Vertex-Farbe a = Materialart: 1.0 Laub, 0.5 Rinde/Holz, 0.0 Stein. Die Instanz-Farbe toent zusaetzlich.
// - Laub: Blatt-Klumpen als Bump-Map, Durchscheinen im Gegenlicht, Wind (langsames Wiegen + Flattern)
// - Rinde: senkrechte Borken-Furchen als Bump-Map, wiegt leicht mit
// - Stein: Koernung + Moos auf den Oberseiten (moss > 0)
// Die Normalen-Stoerung arbeitet ohne Tangenten (Ableitungen im Bildraum), damit sie auf jedem Mesh funktioniert.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float wind_strength = 1.0;
uniform float moss = 0.0;
uniform vec3 moss_color : source_color = vec3(0.24, 0.4, 0.15);
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float bump_strength = 1.0;

varying float kind;
varying vec3 opos;
varying vec3 onrm;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// Bump-Mapping ohne Tangenten (Mikkelsen): h = Hoehe, p = Bildraum-Position, n = Normale
vec3 bump(vec3 n, vec3 p, float h, float amount) {
	vec3 dpdx = dFdx(p);
	vec3 dpdy = dFdy(p);
	float hx = dFdx(h) * amount;
	float hy = dFdy(h) * amount;
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	return normalize(abs(det) * n - grad);
}

void vertex() {
	kind = COLOR.a;
	opos = VERTEX;
	onrm = NORMAL;
	if (kind > 0.25 && wind_strength > 0.0) {
		vec3 root = MODEL_MATRIX[3].xyz;
		float phase = root.x * 0.13 + root.z * 0.17;
		float h = max(VERTEX.y, 0.0);
		float bend = h * h * 0.0035 * wind_strength;
		VERTEX.x += sin(TIME * 1.1 + phase) * bend;
		VERTEX.z += cos(TIME * 0.83 + phase * 1.3) * bend * 0.6;
		if (kind > 0.75) {
			// Blaetter flattern
			float fl = sin(TIME * 5.3 + dot(VERTEX, vec3(2.1, 1.7, 2.9))) * 0.035 * wind_strength;
			VERTEX += NORMAL * fl;
		}
	}
}

void fragment() {
	vec3 base = COLOR.rgb * tint;
	// alle Muster ausserhalb von Verzweigungen berechnen (Ableitungen brauchen einheitlichen Kontrollfluss)
	float leaves = noise3(opos * 5.5) * 0.65 + noise3(opos * 13.0) * 0.35;
	float ang = atan(opos.z, opos.x);
	float bark = noise3(vec3(ang * 3.2, opos.y * 1.6, 0.0)) * 0.7 + noise3(opos * 9.0) * 0.3;
	float groove = smoothstep(0.35, 0.6, bark);
	float grain = noise3(opos * 3.0) * 0.6 + noise3(opos * 11.0) * 0.4;
	float is_leaf = step(0.75, kind);
	float is_bark = step(0.25, kind) * (1.0 - is_leaf);
	float is_rock = 1.0 - is_leaf - is_bark;
	float h = leaves * 0.09 * is_leaf + groove * 0.05 * is_bark + grain * 0.06 * is_rock;
	NORMAL = bump(NORMAL, VERTEX, h, bump_strength);
	// Laub: Blatt-Klumpen, helle Spitzen, dunkle Luecken, Durchscheinen
	vec3 leaf_col = base * (0.78 + 0.42 * leaves);
	leaf_col = mix(leaf_col, leaf_col * vec3(1.08, 1.12, 0.8), smoothstep(0.6, 0.9, leaves) * 0.5);
	// Rinde: Furchen dunkel
	vec3 bark_col = base * (0.7 + 0.4 * groove);
	// Stein: Koernung + Moos oben
	vec3 rock_col = base * (0.82 + 0.3 * grain);
	float up = smoothstep(0.35, 0.8, onrm.y);
	float m = moss * up * smoothstep(0.35, 0.65, noise3(opos * 2.2 + 4.0) * 0.7 + grain * 0.3);
	rock_col = mix(rock_col, moss_color * (0.8 + 0.4 * grain), m);
	ALBEDO = leaf_col * is_leaf + bark_col * is_bark + rock_col * is_rock;
	BACKLIGHT = leaf_col * 0.45 * is_leaf;
	ROUGHNESS = 0.72 * is_leaf + 0.95 * is_bark + mix(0.9, 0.97, m) * is_rock;
	SPECULAR = 0.3;
}
