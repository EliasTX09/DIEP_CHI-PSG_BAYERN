// Wehende Fahne (UV.x = 0 am Mast, 1 am freien Ende).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.95, 0.15, 0.15);

void vertex() {
	float w = UV.x;
	VERTEX.z += sin(UV.x * 6.0 - TIME * 6.0) * 0.14 * w;
	VERTEX.y += sin(UV.x * 4.0 - TIME * 4.0) * 0.05 * w;
}

void fragment() {
	ALBEDO = color * (0.82 + 0.18 * sin(UV.x * 6.0 - TIME * 6.0));
	ROUGHNESS = 0.8;
}
