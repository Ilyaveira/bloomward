// Herbe du rendu « atmosphère » : brins fins, rafales de vent, pieds sombres, pointes translucides à contre-jour.
shader_type spatial;
render_mode cull_disabled;
#include "ground_color.gdshaderinc"
uniform vec3 tip : source_color = vec3(0.50, 0.62, 0.32);
uniform vec3 straw : source_color = vec3(0.64, 0.58, 0.36);
uniform vec3 ear : source_color = vec3(0.74, 0.64, 0.42);
uniform float wind = 1.0;
uniform float tint_amount = 1.0;
varying vec3 gcol;
varying float t;
varying float part;
varying vec3 bn;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	t = COLOR.r;
	part = COLOR.g;
	float h1 = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(sin(dot(root.xz, vec2(39.346, 11.135))) * 24634.6345);
	// des rafales traversent la prairie au lieu d'un balancement uniforme
	float gust = smoothstep(0.35, 0.75, texture(noise_tex, root.xz * 0.012 + TIME * vec2(0.035, 0.014)).r);
	float sway = (0.03 + gust * 0.17) * wind + sin(TIME * (2.2 + h1) + h2 * 6.28) * (0.012 + gust * 0.03);
	vec3 ld = normalize(vec3(1.0, 0.0, 0.45) * mat3(MODEL_MATRIX));
	float bend = t * t;
	VERTEX += ld * sway * bend;
	VERTEX.y -= sway * sway * bend * 0.6;
	gcol = ground_col(root);
	float brush = texture(noise_tex, vec2(root.x * 0.55 + root.z * 0.25, root.z * 0.12)).r;
	gcol *= 1.0 + (brush - 0.5) * 0.26 * ground_brush;
	gcol = mix(gcol, straw, h1 * h1 * h1 * 0.5 * tint_amount);
	gcol *= 0.86 + h2 * 0.26;
	bn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 n = normalize((VIEW_MATRIX * vec4(bn, 0.0)).xyz);
	if (!FRONT_FACING) { n = -n; }
	NORMAL = normalize(mix(up, n, 0.28));
	vec3 base = mix(gcol * 0.58, mix(gcol, tip, 0.42), smoothstep(0.0, 0.9, t));
	ALBEDO = mix(base, ear, step(0.5, part));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = smoothstep(-0.6, 0.8, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * w / PI;
	// la lumière traverse les pointes quand le soleil est en face
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * back * t * 0.85 / PI;
}
