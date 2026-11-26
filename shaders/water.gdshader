// Eau stylisée : profondeur, écume sur les berges, reflets qui suivent le courant.
// Le niveau monte avec la vague de restauration.
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform int ssr_steps = 24; // 0 = pas de reflets calculés (mode léger)
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

	// Reflets à l'écran : on suit le rayon réfléchi dans l'image déjà rendue
	// (arbres, colonnes, berges se reflètent ; le ciel vient du reflet par défaut).
	if (ssr_steps > 0) {
		vec3 n_view = normalize((VIEW_MATRIX * vec4(normalize(vec3((ripple2 - 0.5) * 0.12, 1.0, (ripple - 0.5) * 0.12)), 0.0)).xyz);
		vec3 rd = reflect(normalize(VERTEX), n_view);
		vec3 p = VERTEX;
		float step_len = 0.35;
		vec3 hit = vec3(0.0);
		float found = 0.0;
		for (int i = 0; i < ssr_steps; i++) {
			p += rd * step_len;
			step_len *= 1.15;
			vec4 clip = PROJECTION_MATRIX * vec4(p, 1.0);
			vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
			if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;
			float d = texture(depth_tex, uv).r;
			vec4 v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, d, 1.0);
			float sz = -v.z / v.w;
			float dz = -p.z - sz;
			if (dz > 0.0 && dz < step_len * 2.5) {
				vec2 edge = smoothstep(vec2(0.0), vec2(0.12), uv) * smoothstep(vec2(0.0), vec2(0.12), 1.0 - uv);
				hit = textureLod(screen_tex, uv, 1.0).rgb;
				found = edge.x * edge.y * (1.0 - float(i) / float(ssr_steps));
				break;
			}
		}
		float fres = pow(1.0 - clamp(dot(-normalize(VERTEX), n_view), 0.0, 1.0), 3.0);
		float k = found * mix(0.25, 0.85, fres) * (1.0 - clamp(shore + streak, 0.0, 1.0));
		ALBEDO = mix(ALBEDO, ALBEDO * 0.4, k);
		EMISSION += hit * k * 0.75;
	}
}
