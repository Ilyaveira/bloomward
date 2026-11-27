// Peinture : filtre de Kuwahara (aplats de pinceau qui respectent les contours) + grain de toile.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform int radius = 4;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	vec2 px = max(1.0, VIEWPORT_SIZE.y / 900.0) / VIEWPORT_SIZE;
	vec3 mean[4];
	vec3 sq[4];
	for (int k = 0; k < 4; k++) { mean[k] = vec3(0.0); sq[k] = vec3(0.0); }
	for (int j = 0; j <= radius; j++) {
		for (int i = 0; i <= radius; i++) {
			vec3 c;
			c = texture(screen_tex, SCREEN_UV + vec2(float(-i), float(-j)) * px).rgb; mean[0] += c; sq[0] += c * c;
			c = texture(screen_tex, SCREEN_UV + vec2(float(i), float(-j)) * px).rgb; mean[1] += c; sq[1] += c * c;
			c = texture(screen_tex, SCREEN_UV + vec2(float(-i), float(j)) * px).rgb; mean[2] += c; sq[2] += c * c;
			c = texture(screen_tex, SCREEN_UV + vec2(float(i), float(j)) * px).rgb; mean[3] += c; sq[3] += c * c;
		}
	}
	float n = float((radius + 1) * (radius + 1));
	float best = 1e9;
	vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 m = mean[k] / n;
		vec3 v = abs(sq[k] / n - m * m);
		float s = v.r + v.g + v.b;
		if (s < best) { best = s; col = m; }
	}
	float grain = texture(noise_tex, SCREEN_UV * vec2(9.0, 5.0)).r;
	col *= 0.965 + 0.07 * grain;
	ALBEDO = col;
}
