// Ball-Skins auf Basis von 3D-Rauschen im Objektraum (rollt sichtbar mit):
// mode 0 = Magma-Kern (gluehende Adern), mode 1 = Blitz-Kugel (elektrische Boegen).
shader_type spatial;
render_mode cull_back;

uniform int mode = 0;
uniform vec3 base_color : source_color = vec3(0.09, 0.05, 0.05);
uniform vec3 glow_color : source_color = vec3(1.0, 0.45, 0.08);
uniform float glow = 3.2;

varying vec3 lpos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	if (mode == 0) {
		float n = noise3(lpos * 9.0) * 0.6 + noise3(lpos * 19.0 + vec3(TIME * 0.3)) * 0.4;
		float crack = smoothstep(0.42, 0.5, n) * (1.0 - smoothstep(0.5, 0.58, n));
		float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
		ALBEDO = mix(base_color, base_color * 2.6, n);
		EMISSION = glow_color * crack * glow * pulse;
		ROUGHNESS = 0.85;
	} else {
		float n = noise3(lpos * 6.5 + vec3(0.0, TIME * 2.2, TIME * 0.7));
		float arcs = pow(clamp(1.0 - abs(n - 0.5) * 2.0, 0.0, 1.0), 9.0);
		ALBEDO = base_color;
		EMISSION = glow_color * (arcs * glow * 1.4 + fres * 1.2 + 0.08);
		ROUGHNESS = 0.25;
		METALLIC = 0.6;
	}
}
