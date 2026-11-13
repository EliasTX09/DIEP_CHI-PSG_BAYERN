// Bahn-Belag: Maeh-Streifen entlang der Bahn (UV.x = seitliche Position in m, UV.y = Bahn-Distanz in m),
// optional Schachbrett und leuchtende Randlinie (Neon-Welt).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.22, 0.62, 0.27);
uniform vec3 color_b : source_color = vec3(0.27, 0.70, 0.32);
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float stripe_length = 2.5;
uniform float half_width = 2.5;
uniform float line_strength = 0.0;
uniform float emission_strength = 0.0;
uniform float surface_roughness = 0.9;
uniform float surface_metallic = 0.0;
uniform float checker = 0.0;

void fragment() {
	float s = floor(UV.y / stripe_length);
	float c = floor((UV.x + 100.0) / stripe_length);
	float stripe = mod(s + checker * c, 2.0);
	vec3 col = mix(color_a, color_b, stripe);
	float n = fract(sin(dot(floor(UV * 6.0), vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.96 + 0.08 * n;
	float edge = smoothstep(half_width - 0.24, half_width - 0.1, abs(UV.x));
	col = mix(col, line_color, edge * clamp(line_strength, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	EMISSION = line_color * edge * line_strength * emission_strength + col * emission_strength * 0.06;
}
