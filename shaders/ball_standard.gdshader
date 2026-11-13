// Standard-Golfball: weiss mit farbigem Aequator-Streifen (Spielerfarbe) und Noppen-Andeutung.
shader_type spatial;
render_mode cull_back;

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.96);
uniform vec3 stripe_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float surface_metallic = 0.0;
uniform float surface_roughness = 0.35;

varying vec3 lpos;

void vertex() {
	lpos = normalize(VERTEX);
}

void fragment() {
	float band = 1.0 - smoothstep(0.1, 0.14, abs(lpos.y));
	vec3 q = lpos * 9.0;
	float dimple = smoothstep(0.75, 1.0, sin(q.x) * sin(q.y) * sin(q.z) * 0.5 + 0.5);
	vec3 col = mix(base_color, stripe_color, band);
	ALBEDO = col * (1.0 - dimple * 0.12);
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
}
