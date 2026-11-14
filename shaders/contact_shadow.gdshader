// Weicher Kontaktschatten (Ambient Occlusion) direkt unter einem Ball: dunkler, weich auslaufender Fleck auf
// einem flachen Quad, das am Boden liegt. Mit der Flughoehe wird er groesser und blasser (Skript setzt strength).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float strength = 0.6;

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.7);
	ALBEDO = vec3(0.01, 0.015, 0.01);
	ALPHA = a * strength;
}
