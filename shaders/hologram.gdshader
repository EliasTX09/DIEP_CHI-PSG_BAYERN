// Cyber-Hologramm-Ball: additive Scanlines, Gitter und Fresnel-Rand.
shader_type spatial;
render_mode unshaded, cull_back, blend_add;

uniform vec3 color_a : source_color = vec3(0.1, 0.9, 1.0);
uniform vec3 color_b : source_color = vec3(0.9, 0.2, 1.0);

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float scan = sin(UV.y * 70.0 - TIME * 6.0) * 0.5 + 0.5;
	float grid = step(0.9, fract(UV.x * 16.0)) + step(0.9, fract(UV.y * 8.0));
	vec3 col = mix(color_a, color_b, clamp(UV.y + 0.25 * sin(TIME * 1.5), 0.0, 1.0));
	ALBEDO = col * (0.3 + fres * 1.3 + scan * 0.25 + grid * 0.45);
	ALPHA = 0.9;
}
