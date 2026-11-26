// Ciel : dégradé doux, soleil, nuages en aplats qui dérivent lentement.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.38, 0.60, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.88, 0.76);
uniform vec3 ground_color : source_color = vec3(0.80, 0.74, 0.66);
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
uniform float cloud_cover = 0.6;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, h));
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * (smoothstep(0.9994, 0.9997, sd) * 2.0 + pow(max(sd, 0.0), 24.0) * 0.18 + pow(max(sd, 0.0), 4.0) * 0.06);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.18 + vec2(TIME * 0.0025, TIME * 0.001);
		float c = texture(cloud_tex, uv).r;
		float c2 = texture(cloud_tex, uv * 2.3 + 0.5).r;
		float shape = c * 0.75 + c2 * 0.25;
		float cloud = smoothstep(cloud_cover, cloud_cover + 0.06, shape);
		float shade = smoothstep(cloud_cover, cloud_cover + 0.25, shape);
		vec3 cloud_col = mix(vec3(1.0, 0.99, 0.97), vec3(0.86, 0.86, 0.92), shade * 0.6);
		col = mix(col, cloud_col, cloud * smoothstep(0.0, 0.18, h) * 0.92);
	}
	COLOR = col;
}
