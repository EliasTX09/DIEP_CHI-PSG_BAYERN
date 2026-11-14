// Gummiband beim Zielen: ein Band vom Ball zum Griff (UV.x quer 0..1, UV.y laengs: 0 am Ball, 1 am Griff).
// Leuchtender Neon-Kern (orange -> rot mit der Kraft), heisse helle Mittellinie, scharfer weisser Rand.
// Energie-Wellen laufen zum Ball. Werte ueber 1.0 -> der Bloom der Umgebung laesst den Kern strahlen.
// Kanten mit fwidth geglaettet: in jeder Entfernung sauber, ohne Treppen.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.93, 0.72, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float glow = 1.7;
uniform float rim_width = 0.24;
uniform float tension = 0.0;
uniform float flow = 1.0;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float fw = max(fwidth(x), 0.0001);
	float body = 1.0 - smoothstep(1.0 - 1.5 * fw, 1.0, x);
	float rim = smoothstep(1.0 - rim_width - fw, 1.0 - rim_width + fw, x);
	float hot = 1.0 - smoothstep(0.0, 0.5, x);
	float wave = 0.5 + 0.5 * sin(UV.y * 22.0 + TIME * 9.0 * flow);
	vec3 core = mix(core_color.rgb, hot_color.rgb, hot * (0.3 + 0.35 * tension));
	core *= 0.88 + 0.24 * wave;
	vec3 col = mix(core * glow, rim_color.rgb * 1.15, rim);
	// am Ball weich auslaufen (das Band beginnt unter der Kugel)
	float fade_ball = smoothstep(0.0, 0.1, UV.y);
	ALBEDO = col;
	ALPHA = body * mix(0.93, 1.0, rim) * fade_ball;
}
