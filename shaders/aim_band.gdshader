// Zug-Pfeil beim Zielen: duenner, leuchtender Neon-Pfeil hinter dem Ball.
// UV.x = seitlicher Abstand zur Mittellinie (m, mit Vorzeichen); UV2.x = halbe Breite an dieser Stelle (m),
// UV2.y = Abstand zur Pfeilspitze entlang des Pfeils (m).
// Leuchtender Kern (gold -> orange -> rot mit der Kraft), heisse helle Mittellinie, scharfer weisser Rand - auch an
// den Schultern der Spitze. Energie-Pulse laufen zur Spitze. Werte ueber 1.0 -> der Bloom laesst den Kern strahlen.
// Kanten mit fwidth geglaettet: in jeder Entfernung sauber, ohne Treppen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow = 1.9;
// weisser Rand: hoechstens rim_max Meter, auf duennen Stellen hoechstens rim_rel der halben Breite
uniform float rim_max = 0.024;
uniform float rim_rel = 0.34;
uniform float tension = 0.0;
uniform float flow = 1.0;
// Laenge der Spitze und halbe Schaftbreite an der Schulter (m) -> Rand an der Hinterkante der Spitze
uniform float head_len = 0.3;
uniform float shaft_half = 0.08;
// Gesamtlaenge (m): das Ende am Griff laeuft weich aus
uniform float arrow_length = 1.0;

void fragment() {
	float half_w = max(UV2.x, 0.0001);
	float along = UV2.y;
	float xm = abs(UV.x);
	float edge_d = half_w - xm;
	float fw = max(fwidth(edge_d), 0.0001);
	float body = smoothstep(0.0, 1.5 * fw, edge_d);
	float rim_w = min(rim_max, rim_rel * half_w);
	float rim = 1.0 - smoothstep(rim_w - fw, rim_w + fw, edge_d);
	// Schulter: Hinterkante der Spitze ausserhalb des Schafts
	float sd = head_len - along;
	float fy = max(fwidth(along), 0.0001);
	float in_head = smoothstep(-fy, fy, sd);
	float shoulder = in_head * (1.0 - smoothstep(rim_max - fy, rim_max + fy, sd)) * smoothstep(shaft_half - fw, shaft_half + fw, xm);
	rim = max(rim, shoulder);
	float hot = 1.0 - smoothstep(0.0, 0.55, xm / half_w);
	float wave = 0.5 + 0.5 * sin(along * 11.0 + TIME * 10.0 * flow);
	vec3 core = mix(core_color.rgb, hot_color.rgb, hot * (0.35 + 0.35 * tension));
	core *= 0.86 + 0.28 * wave;
	vec3 col = mix(core * glow, rim_color.rgb * 1.2, rim);
	float fade_tail = 1.0 - smoothstep(arrow_length - 0.1, arrow_length, along);
	ALBEDO = col;
	ALPHA = body * mix(0.95, 1.0, rim) * fade_tail;
}
