// Sandbunker: sauberer, warmer Sand mit gerechten Rillen (Licht und Schatten), weichen Flecken und einem dunkleren
// Rand zum Rasen hin. Feine Details blenden mit fwidth aus, damit nichts flimmert (Mobile-Renderer, kein MSAA).
shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 sand_light : source_color = vec3(0.96, 0.87, 0.63);
uniform vec3 sand_dark : source_color = vec3(0.80, 0.68, 0.45);
// Rillen pro Meter und ihre Richtung (Weltkoordinaten)
uniform float rake_density = 8.0;
uniform vec2 rake_dir = vec2(0.8, 0.6);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = UV.x;   // 0 = Mitte, 1 = Rand
	// weiche Flecken (zwei Oktaven)
	float blot = noise(wpos.xz * 0.7) * 0.6 + noise(wpos.xz * 2.1) * 0.4;
	// gerechte Rillen: parallel, sanft gewellt
	float u = dot(wpos.xz, normalize(rake_dir)) + 0.07 * sin(dot(wpos.xz, vec2(-0.6, 0.8)) * 1.8);
	float f = u * rake_density;
	float w = fwidth(f);
	float fade = clamp(1.6 - w * 3.0, 0.0, 1.0);
	float wave = sin(f * 6.2831853);
	// Rillen nicht bis ganz an den Rand (dort ist der Sand glattgestrichen)
	float inner = 1.0 - smoothstep(0.7, 0.92, r);
	float groove = wave * fade * inner;
	vec3 col = mix(sand_dark, sand_light, clamp(0.62 + 0.35 * (blot - 0.5), 0.0, 1.0));
	col *= 1.0 - 0.06 * groove;
	// Rand: zum Rasen hin dunkler und kraeftiger
	float rim = smoothstep(0.74, 1.0, r);
	col = mix(col, sand_dark * 0.8, rim * 0.6);
	// feine Koernung nur in der Naehe
	float gf = clamp(1.4 - fwidth(wpos.x * 30.0) * 2.0, 0.0, 1.0);
	col *= 1.0 + (noise(wpos.xz * 30.0) - 0.5) * 0.12 * gf;
	// Rillen als leichte Neigung der Normale -> Licht und Schatten wie bei echtem gerechtem Sand
	vec2 rd = normalize(rake_dir);
	vec3 tilt = vec3(rd.x, 0.0, rd.y) * cos(f * 6.2831853) * 0.22 * fade * inner;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(tilt, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.2;
}
