// Fairway und Gruen aus sattem, frisch gemaehtem Rasen:
// - kontrastreiches Schachbrett aus dunkel- und hellgruenen Feldern (Maeh-Bahnen laengs und quer), Kanten mit
//   fwidth geglaettet; die Felder wirken zusaetzlich je nach Blickrichtung heller oder dunkler (Halme liegen
//   abwechselnd mit und gegen die Spielrichtung)
// - feiner Glanz: die hellen Felder spiegeln das Himmelslicht (niedrigere Rauheit), an streifenden Winkeln gedaempft,
//   damit der Rasen nie milchig wird
// - grossflaechige Farbverlaeufe, trockene Flecken, Halm-Koernung als Bump-Map (faengt das Streiflicht)
// - Kontaktschatten an den Banden (Ambient Occlusion) und feine, konzentrische Putt-Linien
// UV.x = seitliche Position in m (0 = Mitte), UV.y = Bahn-Distanz in m; UV2.x = seitliche Position / halbe Breite,
// UV2.y = 1 wenn an dieser Seite eine Bande steht (siehe TrackKit).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.09, 0.4, 0.13);
uniform vec3 color_b : source_color = vec3(0.2, 0.6, 0.2);
uniform vec3 dry_color : source_color = vec3(0.5, 0.56, 0.24);
// Laenge der Felder entlang der Bahn und Breite quer (m)
uniform float stripe_length = 2.5;
uniform float checker_width = 1.25;
// 0 = nur Laengsstreifen, 1 = volles Schachbrett
uniform float checker = 1.0;
uniform float contrast = 1.0;
uniform float half_width = 2.5;
uniform float grass_detail = 1.0;
uniform float sheen = 0.22;
uniform float edge_shadow = 0.5;
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

// Rechteck-Welle 0/1 mit geglaetteten Kanten (Kanten bei ganzen Zahlen). fw = Pixelbreite in denselben Einheiten.
float square_aa(float x, float fw) {
	float tri = abs(fract((x + 0.5) * 0.5) * 2.0 - 1.0);
	return smoothstep(0.5 - fw, 0.5 + fw, tri);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cam_dist = length(wpos - CAMERA_POSITION_WORLD);
	// --- Schachbrett: Felder laengs (UV.y) und quer (UV.x) ---
	vec2 cell = vec2(UV.x / checker_width, UV.y / stripe_length);
	vec2 fw = max(fwidth(cell), vec2(0.0001));
	float sx = square_aa(cell.x, fw.x);
	float sy = square_aa(cell.y, fw.y);
	// XOR mit weichen Werten; checker = 0 -> nur Laengsstreifen
	float board = mix(sy, sx + sy - 2.0 * sx * sy, checker);
	// in der Ferne (Felder kleiner als ein paar Pixel) sanft zum Mittelwert -> kein Flimmern
	float far_fade = 1.0 - smoothstep(0.25, 0.6, max(fw.x, fw.y));
	float lane = (board * 2.0 - 1.0) * far_fade;
	// Blickrichtungs-Glanz: Felder mit den Halmen zur Kamera wirken heller
	vec3 dir = dFdx(wpos) * dFdx(UV.y) + dFdy(wpos) * dFdy(UV.y);
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float along = dot(normalize(dir.xz + vec2(1e-5)), normalize(view_w.xz + vec2(1e-5)));
	float light_cell = clamp(0.5 + 0.5 * lane * contrast * (0.78 + 0.22 * along), 0.0, 1.0);
	vec3 col = mix(color_a, color_b, light_cell);
	// --- grossflaechige Verlaeufe: sattes Gruen, trockene Flecken ---
	float big = noise(wpos.xz * 0.08) * 0.55 + noise(wpos.xz * 0.27) * 0.45;
	float dry = smoothstep(0.66, 0.88, noise(wpos.xz * 0.05 + 7.3)) * 0.25;
	col *= mix(1.0, 0.9 + 0.2 * big, grass_detail);
	col = mix(col, dry_color * (0.85 + 0.3 * big), dry * grass_detail);
	// --- Halm-Koernung: helle Spitzen, dunkler Grund ---
	float blades = hash(floor(wpos.xz * 26.0)) * 0.55 + noise(wpos.xz * 9.0) * 0.45;
	col *= mix(1.0, 0.92 + 0.16 * blades, grass_detail);
	// Bump aus der Koernung (Streiflicht), blendet mit der Entfernung aus
	float near = (1.0 - smoothstep(8.0, 30.0, cam_dist)) * grass_detail;
	float h = (blades * 0.6 + noise(wpos.xz * 3.0) * 0.4) * 0.012 * near;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	// --- Kontaktschatten an den Banden: dunkler, weich auslaufender Saum ---
	float edge_in = abs(UV2.x);
	float edge = (smoothstep(0.62, 1.0, edge_in) * 0.55 + smoothstep(0.9, 1.0, edge_in) * 0.45) * UV2.y;
	float ao = 1.0 - edge * edge_shadow;
	// --- Putt-Ringe ums Loch ---
	float rd = length(wpos.xz - ring_center);
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(fract(rd / ring_spacing) - 0.5) * ring_spacing);
	float ring_mask = ring_strength * smoothstep(0.85, 1.1, rd) * (1.0 - smoothstep(ring_reach * 0.6, ring_reach, rd));
	col = mix(col, col * 1.18 + vec3(0.02), ring * ring_mask);
	ALBEDO = col * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	// --- Glanz: helle Felder glatter (spiegeln den Himmel), an streifenden Winkeln gedaempft (kein Milchschleier) ---
	float facing = smoothstep(0.08, 0.55, clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	ROUGHNESS = mix(0.8, 0.58, light_cell * sheen / 0.22);
	SPECULAR = (0.2 + sheen * 1.1 * light_cell) * mix(0.35, 1.0, facing) * ao;
}
