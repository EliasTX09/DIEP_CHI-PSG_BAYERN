// Fairway und Gruen aus echtem Rasen: Maeh-Streifen, die je nach Blickrichtung hell oder dunkel wirken
// (die Halme liegen abwechselnd in Spielrichtung und dagegen), grossflaechige Farbverlaeufe, Halm-Koernung
// als Bump-Map (faengt das Streiflicht), Kontaktschatten an den Banden und feine, konzentrische Putt-Linien.
// UV.x = seitliche Position in m, UV.y = Bahn-Distanz in m; UV2.x = seitliche Position / halbe Breite,
// UV2.y = 1 wenn an dieser Seite eine Bande steht (siehe TrackKit).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.2, 0.6, 0.26);
uniform vec3 color_b : source_color = vec3(0.26, 0.69, 0.31);
uniform vec3 dry_color : source_color = vec3(0.55, 0.6, 0.28);
uniform float stripe_length = 2.5;
uniform float half_width = 2.5;
uniform float grass_detail = 1.0;
uniform float sheen = 0.16;
uniform float edge_shadow = 0.32;
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
	// --- Maeh-Streifen: Halme abwechselnd mit / gegen die Spielrichtung gelegt ---
	float fy = fract(UV.y / stripe_length);
	float lane = mod(floor(UV.y / stripe_length), 2.0) * 2.0 - 1.0;
	float soft = smoothstep(0.0, 0.12, fy) * (1.0 - smoothstep(0.88, 1.0, fy));
	// Spielrichtung in Welt-Koordinaten aus den Bildschirm-Ableitungen von UV.y
	vec3 dir = dFdx(wpos) * dFdx(UV.y) + dFdy(wpos) * dFdy(UV.y);
	vec3 view_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float along = dot(normalize(dir.xz + vec2(1e-5)), normalize(view_w.xz + vec2(1e-5)));
	float stripe = 0.5 + 0.5 * lane * soft * along;
	vec3 col = mix(color_a, color_b, mix(0.5, stripe, 0.65));
	// --- grossflaechige Verlaeufe: sattes Gruen, trockene Flecken, leichte Wolken-Schatten ---
	float big = noise(wpos.xz * 0.08) * 0.55 + noise(wpos.xz * 0.27) * 0.45;
	float dry = smoothstep(0.62, 0.85, noise(wpos.xz * 0.05 + 7.3)) * 0.35;
	col *= mix(1.0, 0.88 + 0.24 * big, grass_detail);
	col = mix(col, dry_color * (0.85 + 0.3 * big), dry * grass_detail);
	// --- Halm-Koernung: helle Spitzen, dunkler Grund ---
	float blades = hash(floor(wpos.xz * 26.0)) * 0.55 + noise(wpos.xz * 9.0) * 0.45;
	col *= mix(1.0, 0.9 + 0.18 * blades, grass_detail);
	// Bump aus der Koernung (Streiflicht), blendet mit der Entfernung aus
	float cam_dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = (1.0 - smoothstep(8.0, 30.0, cam_dist)) * grass_detail;
	float h = (blades * 0.6 + noise(wpos.xz * 3.0) * 0.4) * 0.012 * near;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	// --- Kontaktschatten an den Banden (Ambient Occlusion) ---
	float edge = smoothstep(0.72, 1.0, abs(UV2.x)) * UV2.y;
	float ao = 1.0 - edge * edge_shadow;
	// --- Putt-Ringe ums Loch ---
	float rd = length(wpos.xz - ring_center);
	float ring = 1.0 - smoothstep(0.0, 0.035, abs(fract(rd / ring_spacing) - 0.5) * ring_spacing);
	float ring_mask = ring_strength * smoothstep(0.85, 1.1, rd) * (1.0 - smoothstep(ring_reach * 0.6, ring_reach, rd));
	col = mix(col, col * 1.2 + vec3(0.02), ring * ring_mask);
	ALBEDO = col * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = 0.82 - sheen * 0.4 * stripe;
	SPECULAR = 0.25 + sheen * stripe;
}
