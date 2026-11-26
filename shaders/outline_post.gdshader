// Fins contours « ligne claire » en post-traitement : détection des ruptures
// de profondeur et d'orientation des surfaces, sur toute l'image.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec3 line_color : source_color = vec3(0.20, 0.16, 0.15);
uniform float strength = 0.8;
uniform float fade_start = 35.0;
uniform float fade_end = 110.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 nrm(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = max(1.0, VIEWPORT_SIZE.y / 1080.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = lin_depth(uv, INV_PROJECTION_MATRIX);
	float dl = lin_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = lin_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = lin_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dd = lin_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float lap = abs(dl + dr - 2.0 * d0) + abs(du + dd - 2.0 * d0);
	float depth_edge = smoothstep(0.04, 0.12, lap / max(d0, 0.001));
	vec3 n0 = nrm(uv);
	float nd = min(min(dot(n0, nrm(uv + vec2(px.x, 0.0))), dot(n0, nrm(uv - vec2(px.x, 0.0)))),
		min(dot(n0, nrm(uv + vec2(0.0, px.y))), dot(n0, nrm(uv - vec2(0.0, px.y)))));
	float normal_edge = 1.0 - smoothstep(0.55, 0.8, nd);
	float edge = max(depth_edge, normal_edge * 0.85);
	edge *= 1.0 - smoothstep(fade_start, fade_end, d0);
	ALBEDO = line_color;
	ALPHA = edge * strength;
}
