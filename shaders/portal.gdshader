// Teleporter-Portal / Schwarzes-Loch-Scheibe: additiver Farbwirbel. core_dark = 1 -> dunkles Zentrum.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec3 color_a : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 color_b : source_color = vec3(0.9, 0.2, 1.0);
uniform float spin = 4.0;
uniform float core_dark = 0.0;
uniform float intensity = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 9.0 - TIME * spin) * 0.5 + 0.5;
	float ring = smoothstep(1.0, 0.82, r) * smoothstep(0.05, 0.4, r);
	float core = smoothstep(0.5, 0.0, r) * (1.0 - core_dark);
	vec3 col = mix(color_a, color_b, swirl);
	ALBEDO = col * (ring * (0.35 + 0.65 * swirl) + core * 0.7) * intensity;
	ALPHA = clamp(ring + core, 0.0, 1.0);
}
