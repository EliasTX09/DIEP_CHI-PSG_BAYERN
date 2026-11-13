// Animiertes Wasser: Wellen im Vertex-Shader, Normalen/Schaum/Fresnel im Fragment-Shader.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.12, 0.62, 0.72);
uniform vec3 deep : source_color = vec3(0.02, 0.22, 0.42);
uniform vec3 foam_color : source_color = vec3(0.95, 1.0, 1.0);
uniform float wave_height = 0.18;
uniform float wave_scale = 0.3;
uniform float speed = 1.0;

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

float waves(vec2 p, float t) {
	return sin(p.x * 0.8 + t * 1.3) * 0.5 + sin(p.y * 1.1 + t * 1.7) * 0.3 + noise(p * 1.7 + vec2(t * 0.4)) * 0.6 - 0.3;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += waves(wpos.xz * wave_scale, TIME * speed) * wave_height;
}

void fragment() {
	vec2 p = wpos.xz * wave_scale;
	float t = TIME * speed;
	float e = 0.12;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3(-(hx - h0) / e * wave_height * 2.0, 1.0, -(hz - h0) / e * wave_height * 2.0));
	float cam_dist = length(wpos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(35.0, 130.0, cam_dist);
	n = normalize(mix(vec3(0.0, 1.0, 0.0), n, 0.25 + 0.75 * detail));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float foam = smoothstep(0.72, 0.95, noise(p * 3.1 + vec2(t * 0.25, -t * 0.2)) * 0.65 + h0 * 0.35) * detail;
	vec3 col = mix(deep, shallow, clamp(h0 * 0.5 + 0.5, 0.0, 1.0) * (0.35 + 0.65 * detail) + 0.3 * (1.0 - detail));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	ALBEDO = mix(col, foam_color, foam * 0.55);
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	EMISSION = shallow * fres * 0.3;
}
