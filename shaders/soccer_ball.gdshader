// Fussball: schwarze Flecken an den 12 Ikosaeder-Ecken (Objektraum, rollt sichtbar mit).
shader_type spatial;
render_mode cull_back;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec3 a = abs(normalize(lpos));
	float phi = 1.618034;
	float inv = 1.0 / sqrt(1.0 + phi * phi);
	float d = max(max(a.y + phi * a.z, a.x + phi * a.y), phi * a.x + a.z) * inv;
	float spot = smoothstep(0.925, 0.94, d);
	float seam = smoothstep(0.86, 0.87, d) * (1.0 - smoothstep(0.875, 0.885, d));
	vec3 col = mix(vec3(0.95), vec3(0.06), spot);
	ALBEDO = mix(col, vec3(0.55), seam * 0.6);
	ROUGHNESS = 0.45;
}
