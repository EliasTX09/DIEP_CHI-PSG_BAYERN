// Deko-Gelaende (Inseln, Felsen, Vulkanhaenge): Farbe nach Hoehe und Hangneigung.
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 low_color : source_color = vec3(0.85, 0.78, 0.55);
uniform vec3 mid_color : source_color = vec3(0.25, 0.6, 0.28);
uniform vec3 high_color : source_color = vec3(0.45, 0.42, 0.4);
uniform float mid_height = 0.8;
uniform float high_height = 6.0;
uniform float emission_strength = 0.0;
uniform float slope_strength = 1.0;

varying float height;
varying float slope;

void vertex() {
	height = VERTEX.y;
	slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
}

void fragment() {
	vec3 col = mix(low_color, mid_color, smoothstep(mid_height * 0.4, mid_height, height));
	col = mix(col, high_color, smoothstep(high_height * 0.7, high_height, height));
	col = mix(col, high_color, smoothstep(0.35, 0.7, slope) * slope_strength);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = col * emission_strength;
}
