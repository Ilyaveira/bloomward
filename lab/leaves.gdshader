// Feuillage peint : touffes de feuilles sur des quadrilatères, normales « en boule ».
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_tex : filter_linear_mipmap;
uniform vec3 col_dark : source_color = vec3(0.10, 0.32, 0.25);
uniform vec3 col_light : source_color = vec3(0.50, 0.72, 0.25);
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.1 + w.x * 0.6 + w.z * 0.4) * 0.05 + sin(TIME * 2.3 + w.y * 1.7) * 0.02;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}
void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ALBEDO = mix(col_dark, col_light, COLOR.r) * (0.80 + 0.25 * t.r);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float w = smoothstep(-0.45, 0.85, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * w * mix(vec3(0.8, 0.95, 1.0), vec3(1.15, 1.08, 0.75), w) / PI;
}
