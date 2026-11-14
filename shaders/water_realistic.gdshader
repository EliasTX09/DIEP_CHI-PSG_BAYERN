// Realistisches Wasser: vier gerichtete Gerstner-Wellen im Vertex-Shader (spitze Kaemme, flache Taeler),
// zwei gegeneinander laufende Detail-Ebenen fuer feine Kraeuselung, Fresnel-Spiegelung des Himmels,
// tiefe Farbe bei Aufsicht / helle Farbe bei flachem Blick, Schaum auf den Wellenkaemmen und Glitzern (Bloom).
// Kein Tiefenpuffer noetig (laeuft im Mobile-Renderer).
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.12, 0.62, 0.72);
uniform vec3 deep : source_color = vec3(0.02, 0.22, 0.42);
uniform vec3 foam_color : source_color = vec3(0.95, 1.0, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.62, 0.78, 0.92);
uniform float wave_height = 0.18;
uniform float wave_scale = 0.3;
uniform float speed = 1.0;
uniform float foam_amount = 1.0;
uniform float sparkle = 1.0;

varying vec3 wpos;
varying float crest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 - 1.3) * 0.15;
}

// Eine Gerstner-Welle: Rueckgabe = Verschiebung (xyz), dir = Laufrichtung, k = Wellenzahl, q = Steilheit
vec3 gerstner(vec2 p, vec2 dir, float k, float q, float t) {
	float ph = k * dot(dir, p) - t * sqrt(9.8 * k);
	float a = 1.0 / k;
	return vec3(dir.x * q * a * cos(ph), a * sin(ph), dir.y * q * a * cos(ph));
}

vec3 swell(vec2 p, float t) {
	vec3 d = gerstner(p, normalize(vec2(1.0, 0.35)), 1.1, 0.55, t);
	d += gerstner(p, normalize(vec2(-0.4, 1.0)), 1.7, 0.45, t * 1.07) * 0.6;
	d += gerstner(p, normalize(vec2(0.8, -0.7)), 2.6, 0.35, t * 0.93) * 0.35;
	d += gerstner(p, normalize(vec2(-1.0, -0.2)), 3.9, 0.3, t * 1.13) * 0.2;
	return d;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wpos.xz * wave_scale;
	float t = TIME * speed;
	vec3 d = swell(p, t);
	crest = d.y;
	VERTEX.y += d.y * wave_height;
	VERTEX.xz += d.xz * wave_height * 0.6;
}

void fragment() {
	vec2 p = wpos.xz * wave_scale;
	float t = TIME * speed;
	float cam_dist = length(wpos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(30.0, 140.0, cam_dist);
	// Normale der Duenung (finite Differenzen) + zwei Kraeusel-Ebenen
	float e = 0.08;
	float h0 = swell(p, t).y;
	float hx = swell(p + vec2(e, 0.0), t).y;
	float hz = swell(p + vec2(0.0, e), t).y;
	vec3 n = vec3(-(hx - h0) / e * wave_height * wave_scale * 4.0, 1.0, -(hz - h0) / e * wave_height * wave_scale * 4.0);
	vec2 q1 = wpos.xz * 0.9 + vec2(t * 0.35, t * 0.22);
	vec2 q2 = wpos.xz * 1.6 + vec2(-t * 0.28, t * 0.4);
	float r0 = fbm(q1) + fbm(q2) * 0.6;
	float rx = fbm(q1 + vec2(0.05, 0.0)) + fbm(q2 + vec2(0.05, 0.0)) * 0.6;
	float rz = fbm(q1 + vec2(0.0, 0.05)) + fbm(q2 + vec2(0.0, 0.05)) * 0.6;
	n += vec3(-(rx - r0) * 3.0, 0.0, -(rz - r0) * 3.0) * detail;
	n = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(n), 0.35 + 0.65 * detail));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float ndv = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	// Aufsicht = tief und klar, flacher Blick = Himmel spiegelt sich
	vec3 body = mix(shallow, deep, clamp(ndv * 1.1 - 0.1 + crest * 0.15, 0.0, 1.0));
	body = mix(body, shallow * 1.15, smoothstep(0.35, 1.0, crest) * 0.35);
	// Schaum auf den Kaemmen, in Streifen aufgerissen
	float foam_noise = fbm(wpos.xz * 1.3 + vec2(t * 0.2, -t * 0.15));
	float foam = smoothstep(0.55, 0.95, crest * 0.6 + foam_noise * 0.55) * foam_amount * (0.4 + 0.6 * detail);
	vec3 col = mix(body, sky_tint, fres * 0.75);
	ALBEDO = mix(col, foam_color, foam * 0.7);
	ROUGHNESS = mix(0.04, 0.5, foam);
	SPECULAR = 0.75;
	METALLIC = 0.0;
	// Glitzerpunkte: einzelne Facetten blitzen auf (wird vom Bloom aufgegriffen)
	float glint = step(0.985, hash(floor(wpos.xz * 9.0) + floor(t * 6.0))) * detail * sparkle * (1.0 - foam);
	EMISSION = sky_tint * fres * 0.18 + vec3(1.0, 0.97, 0.9) * glint * 0.6 * (1.0 - ndv);
}
