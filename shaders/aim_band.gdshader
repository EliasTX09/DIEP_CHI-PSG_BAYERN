// Gummiband beim Zielen: liegt HINTER dem Ball am Boden, schmal an der Kugel, weitet sich wie ein Trichter bis in den
// Griff-Ring am Finger. Darauf laufen weisse Winkel in Schussrichtung (Richtung Ball).
// UV.x = seitlicher Abstand zur Mittellinie (m, mit Vorzeichen); UV2.x = halbe Breite an dieser Stelle (m),
// UV2.y = Abstand vom Band-Anfang am Ball entlang des Bands (m).
// Farbe = Kraft (gold -> orange -> rot), dunklere Kante fuer Halt auf hellem Rasen. Kanten mit fwidth geglaettet:
// in jeder Entfernung sauber, ohne Treppen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 edge_color : source_color = vec4(0.55, 0.16, 0.02, 1.0);
uniform vec4 chevron_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow = 1.25;
// dunkle Kante: hoechstens edge_w Meter, auf schmalen Stellen hoechstens ein Viertel der halben Breite
uniform float edge_w = 0.02;
uniform float tension = 0.0;
uniform float flow = 1.0;
// Winkel: Abstand (m), Strichstaerke (m), Neigung der Schenkel
uniform float chevron_gap = 0.33;
uniform float chevron_w = 0.07;
uniform float chevron_slope = 0.8;
// Laenge des Bands (m): an beiden Enden blenden die Winkel aus
uniform float band_length = 1.0;

void fragment() {
	float half_w = max(UV2.x, 0.0001);
	float along = UV2.y;
	float xm = abs(UV.x);
	float edge_d = half_w - xm;
	float fw = max(fwidth(edge_d), 0.0001);
	float body = smoothstep(0.0, 1.5 * fw, edge_d);
	float ew = min(edge_w, 0.25 * half_w);
	float edge = 1.0 - smoothstep(ew - fw, ew + fw, edge_d);
	// Winkel: Spitze zeigt zum Ball (kleineres along), Schenkel laufen zum Griff; sie wandern Richtung Ball
	float q = along - xm * chevron_slope + TIME * 0.42 * flow;
	float fq = max(fwidth(along - xm * chevron_slope), 0.0001);
	float ph = fract(q / chevron_gap) * chevron_gap;
	// breiteres Band -> kraeftigerer Strich
	float cw = chevron_w * (0.7 + 1.4 * half_w);
	float chev = smoothstep(0.0, fq, ph) * (1.0 - smoothstep(cw - fq, cw + fq, ph));
	chev *= (1.0 - edge) * smoothstep(0.03, 0.14, along) * (1.0 - smoothstep(band_length - 0.14, band_length - 0.03, along));
	vec3 core = core_color.rgb * glow * (1.0 + 0.12 * tension);
	vec3 col = mix(core, edge_color.rgb, edge);
	col = mix(col, chevron_color.rgb * 1.12, chev * 0.95);
	ALBEDO = col;
	ALPHA = body * 0.97;
}
