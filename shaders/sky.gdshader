// Himmel je Welt: Farbverlauf, Sonne/Mond, Wolkenbaender, Sterne (statisch -> Radiance wird nur einmal berechnet).
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.15, 0.4, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.82, 0.95);
uniform vec3 bottom_color : source_color = vec3(0.3, 0.45, 0.55);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_amount = 0.45;
uniform float star_amount = 0.0;
uniform float sun_size = 0.045;

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
	float a = 0.5;
	float f = 0.0;
	for (int i = 0; i < 4; i++) {
		f += a * noise(p);
		p = p * 2.07 + vec2(3.1, 1.3);
		a *= 0.5;
	}
	return f;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, bottom_color, clamp(-h * 3.0, 0.0, 1.0));
	if (star_amount > 0.0 && h > 0.0) {
		vec2 sp = dir.xz / (h + 0.4) * 60.0;
		float s = hash(floor(sp));
		vec2 cell = fract(sp) - vec2(0.5);
		float star = step(1.0 - 0.04 * star_amount, s) * smoothstep(0.35, 0.0, length(cell));
		col += vec3(star) * clamp(h * 4.0, 0.0, 1.0);
	}
	if (LIGHT0_ENABLED) {
		float d = distance(dir, LIGHT0_DIRECTION);
		col += sun_color * smoothstep(sun_size, sun_size * 0.55, d) * 2.5;
		col += sun_color * pow(max(dot(dir, LIGHT0_DIRECTION), 0.0), 48.0) * 0.35;
	}
	if (cloud_amount > 0.0 && h > 0.02) {
		vec2 uv = dir.xz / (h + 0.18) * 1.4;
		float n = fbm(uv + vec2(4.0, 2.0));
		float c = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.25, n);
		col = mix(col, cloud_color, c * clamp(h * 5.0, 0.0, 1.0) * 0.9);
	}
	COLOR = col;
}
