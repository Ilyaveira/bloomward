// Eau stylisée : profondeur, écume sur les berges, reflets qui suivent le courant.
// Le niveau monte avec la vague de restauration.
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.45, 0.80, 0.85);
uniform vec3 deep : source_color = vec3(0.16, 0.45, 0.62);
uniform vec3 foam : source_color = vec3(0.97, 0.98, 1.0);
uniform float flow_speed = 0.35;

varying vec3 wpos;
varying float fill;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wpos.xz, bloom_center.xz);
	fill = 1.0 - smoothstep(bloom_radius - 4.0, bloom_radius, d);
	VERTEX.y -= (1.0 - fill) * 0.9;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -view.z / view.w;
	float diff = scene_z - (-VERTEX.z);
	float ripple = texture(noise_tex, vec2(UV.x * 0.6, UV.y * 0.25 - TIME * flow_speed)).r;
	float ripple2 = texture(noise_tex, wpos.xz * 0.15 + vec2(TIME * 0.02, -TIME * 0.03)).r;
	float shore = 1.0 - smoothstep(0.0, 0.22 + ripple * 0.15, diff);
	float streak = smoothstep(0.68, 0.74, ripple) * 0.6;
	vec3 col = mix(shallow, deep, smoothstep(0.05, 0.9, diff));
	col = mix(col, foam, clamp(shore + streak, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(mix(0.55, 0.92, smoothstep(0.0, 0.8, diff)) + shore, 0.0, 1.0) * smoothstep(0.0, 0.3, fill);
	ROUGHNESS = 0.08;
	SPECULAR = 0.5;
	NORMAL_MAP = normalize(vec3(ripple2 - 0.5, ripple - 0.5, 1.0) * vec3(0.6, 0.6, 1.0)) * 0.5 + 0.5;
	EMISSION = foam * streak * 0.15;
}
