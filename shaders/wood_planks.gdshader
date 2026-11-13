// Holzplanken quer zur Bahn (Bruecken, Piraten-Stege). UV.y = Bahn-Distanz in m.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.55, 0.36, 0.2);
uniform vec3 color_b : source_color = vec3(0.68, 0.47, 0.27);
uniform float plank = 0.7;

void fragment() {
	float v = UV.y / plank;
	float id = floor(v);
	float f = fract(v);
	float gap = smoothstep(0.0, 0.05, f) * (1.0 - smoothstep(0.95, 1.0, f));
	float h = fract(sin(id * 12.9898) * 43758.5453);
	vec3 col = mix(color_a, color_b, h);
	float grain = sin(UV.x * 38.0 + h * 20.0) * 0.035 + sin(UV.x * 11.0 + id) * 0.025;
	ALBEDO = (col + vec3(grain)) * (0.3 + 0.7 * gap);
	ROUGHNESS = 0.86;
}
