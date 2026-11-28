// Ligne claire : trait d'encre légèrement tremblé + grain de papier.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 ink : source_color = vec3(0.13, 0.12, 0.22);
uniform float width = 1.4;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
float lin_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}
vec3 nrm(vec2 uv) { return texture(normal_tex, uv).xyz * 2.0 - 1.0; }
void fragment() {
	vec2 px = width * max(1.0, VIEWPORT_SIZE.y / 900.0) / VIEWPORT_SIZE;
	// tremblé de la main
	vec2 wob = (vec2(texture(noise_tex, SCREEN_UV * 3.0).r, texture(noise_tex, SCREEN_UV * 3.0 + 0.5).r) - 0.5) * 0.0022;
	vec2 uv = clamp(SCREEN_UV + wob, px * 2.0, 1.0 - px * 2.0);
	float d0 = lin_depth(uv, INV_PROJECTION_MATRIX);
	float dl = lin_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float dr = lin_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float du = lin_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float dd = lin_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float lap = abs(dl + dr - 2.0 * d0) + abs(du + dd - 2.0 * d0);
	float depth_edge = smoothstep(0.03, 0.09, lap / max(d0, 0.001));
	vec3 n0 = nrm(uv);
	float nd = min(min(dot(n0, nrm(uv + vec2(px.x, 0.0))), dot(n0, nrm(uv - vec2(px.x, 0.0)))),
		min(dot(n0, nrm(uv + vec2(0.0, px.y))), dot(n0, nrm(uv - vec2(0.0, px.y)))));
	float normal_edge = 1.0 - smoothstep(0.60, 0.82, nd);
	float edge = max(depth_edge, normal_edge);
	edge *= 1.0 - smoothstep(90.0, 200.0, d0);
	// le trait s'amincit par endroits, comme à la plume
	edge *= 0.75 + 0.25 * smoothstep(0.3, 0.6, texture(noise_tex, SCREEN_UV * 7.0).r);
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float paper = texture(noise_tex, SCREEN_UV * vec2(14.0, 8.0)).r;
	col *= 0.95 + 0.08 * paper;
	ALBEDO = mix(col, ink, clamp(edge, 0.0, 1.0));
}
