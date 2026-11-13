// Boost-Pad: laufende Pfeil-Chevrons in Schubrichtung (UV.y 0 -> 1 = Richtung des Schubs).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base : source_color = vec3(0.04, 0.08, 0.18);
uniform vec3 arrow : source_color = vec3(0.2, 0.9, 1.0);
uniform float speed = 2.2;
uniform float count = 3.0;

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float ph = fract(UV.y * count + x * 0.5 - TIME * speed);
	float chevron = smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.4, 0.5, ph));
	chevron *= 1.0 - smoothstep(0.82, 0.9, x);
	float border = smoothstep(0.9, 0.96, x);
	ALBEDO = mix(base, arrow, clamp(chevron + border, 0.0, 1.0));
	EMISSION = arrow * (chevron * 2.6 + border * 1.5 + 0.12);
	ROUGHNESS = 0.4;
}
