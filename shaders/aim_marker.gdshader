// Ziel-Markierungen: Winkel und Punkte der Flugbahn, Zielkreis (pulsiert dezent), Aufsetz-Ring und Griff-Ring des
// Gummibands.
// Gezeichnet auf einem Quad: flach auf dem Boden (PlaneMesh) oder als Billboard zur Kamera gedreht (QuadMesh,
// billboard = true, auch in MultiMeshes). Die Form kommt aus den UVs, die Kanten werden mit fwidth geglaettet ->
// gestochen scharf in jeder Groesse. Helligkeit ueber 1.0 -> feiner Bloom-Schein.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.98, 0.86, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.22, 1.0);
uniform float glow = 1.3;
// 0 = Punkt (Kern + Rand), 1 = Ring, 2 = Winkel (zeigt in -Z des Quads, also zur UV-Oberkante)
uniform int shape = 0;
// Ring: Innenradius (Anteil); Punkt: Breite des Randes (Anteil)
uniform float ring_inner = 0.62;
uniform float rim_width = 0.3;
// 0 = ruhig, 1 = pulsiert (Groesse +-6 %, Helligkeit)
uniform float pulse = 0.0;
uniform float pulse_speed = 3.4;
uniform bool billboard = false;
uniform float opacity = 1.0;
// Ring: leichte Fuellung der Mitte (0 = hohl) und feiner heller Glanzbogen auf dem Ring (0 = aus)
uniform float ring_fill = 0.0;
uniform float ring_gloss = 0.0;
// true: Deckkraft je Instanz aus den Custom-Daten des MultiMesh (x = 0..1) - die Kette blendet zur Ferne aus
uniform bool instance_fade = false;
varying float v_fade;

void vertex() {
	v_fade = instance_fade ? INSTANCE_CUSTOM.x : 1.0;
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wobble = sin(TIME * pulse_speed);
	float d = length(p) / (1.0 + 0.06 * pulse * wobble);
	float fw = max(fwidth(d), 0.0001);
	float outer = 1.0 - smoothstep(0.94 - fw, 0.94 + fw, d);
	float inner = smoothstep(ring_inner - fw, ring_inner + fw, d);
	float rim = smoothstep(0.94 - rim_width - fw, 0.94 - rim_width + fw, d);
	float is_ring = shape == 1 ? 1.0 : 0.0;
	float a = outer * mix(1.0, inner, is_ring);
	// Punkt: heller Kern, farbiger Rand; Ring: innen hell, aussen farbig
	float ring_t = smoothstep(ring_inner, 0.94, d);
	vec3 dot_col = mix(core_color.rgb * (1.0 + 0.2 * (1.0 - d)), rim_color.rgb, rim);
	vec3 ring_col = mix(core_color.rgb, rim_color.rgb, ring_t);
	vec3 col = mix(dot_col, ring_col, is_ring);
	if (shape == 1) {
		// Mitte leicht gefuellt (wie eine Linse), feiner Glanzbogen auf dem Ring
		float inside = 1.0 - smoothstep(ring_inner - fw, ring_inner + fw, d);
		a = max(a, inside * ring_fill);
		float mid = mix(ring_inner, 0.94, 0.5);
		float line = 1.0 - smoothstep(0.018, 0.018 + 2.0 * fw, abs(d - mid));
		float arc = smoothstep(0.55, 0.85, abs(sin(atan(p.y, p.x) + 0.7)));
		col = mix(col, vec3(1.0), ring_gloss * line * arc * outer * inner);
	}
	if (shape == 2) {
		// Winkel: Spitze vorn (zur UV-Oberkante), Schenkel laufen nach hinten aussen; Kern + farbiger Rand
		float ax = abs(p.x);
		float c = p.y + 0.4 - ax * 0.95;
		float fc = max(fwidth(c), 0.0001);
		float fx = max(fwidth(ax), 0.0001);
		float half_t = 0.25;
		float stroke = 1.0 - smoothstep(half_t - fc, half_t + fc, abs(c));
		float ends = 1.0 - smoothstep(0.86 - fx, 0.86 + fx, ax);
		float core_t = (1.0 - smoothstep(half_t * (1.0 - rim_width) - fc, half_t * (1.0 - rim_width) + fc, abs(c)))
			* (1.0 - smoothstep(0.86 - 0.5 * rim_width * half_t - fx, 0.86 - 0.5 * rim_width * half_t + fx, ax));
		a = stroke * ends;
		col = mix(rim_color.rgb, core_color.rgb, core_t);
	}
	float shine = 1.0 + 0.18 * pulse * wobble;
	ALBEDO = col * glow * shine;
	ALPHA = a * opacity * core_color.a * v_fade;
}
