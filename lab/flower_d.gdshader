// Fleurs à pétales : tige, corolle teintée par l'instance, cœur ; elles suivent les rafales de l'herbe.
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 stem : source_color = vec3(0.28, 0.44, 0.24);
uniform vec3 heart : source_color = vec3(1.0, 0.80, 0.30);
uniform float glow = 0.0;
varying float part;
varying float hgt;
varying vec3 icol;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	part = UV.x;
	hgt = UV.y;
	float gust = smoothstep(0.35, 0.75, texture(noise_tex, root.xz * 0.012 + TIME * vec2(0.035, 0.014)).r);
	float sway = 0.02 + gust * 0.10 + sin(TIME * 2.0 + root.x * 3.1 + root.z * 1.7) * 0.012;
	vec3 ld = normalize(vec3(1.0, 0.0, 0.45) * mat3(MODEL_MATRIX));
	VERTEX += ld * sway * UV.y * UV.y;
	icol = COLOR.rgb;
}
void fragment() {
	vec3 c = part < 0.5 ? stem * (0.6 + 0.4 * hgt) : (part < 1.5 ? icol : heart);
	ALBEDO = c;
	EMISSION = (part > 0.5 ? c : vec3(0.0)) * glow;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
#include "light.gdshaderinc"
