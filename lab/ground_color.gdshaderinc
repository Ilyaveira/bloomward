// Couleur du sol, partagée par le sol et l'herbe pour qu'ils se fondent.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 c1 : source_color = vec3(0.35, 0.60, 0.25);
uniform vec3 c2 : source_color = vec3(0.50, 0.70, 0.28);
uniform vec3 c3 : source_color = vec3(0.80, 0.78, 0.35);
uniform vec3 sand : source_color = vec3(0.85, 0.78, 0.60);
uniform int ground_mode = 0;
uniform float ground_brush = 1.0;

vec3 ground_col(vec3 p) {
	float n1 = texture(noise_tex, p.xz * 0.021).r;
	float n2 = texture(noise_tex, p.xz * 0.063 + vec2(0.37, 0.11)).r;
	vec3 c;
	if (ground_mode == 0) {
		c = mix(c1, c2, smoothstep(0.30, 0.70, n1));
		c = mix(c, c3, smoothstep(0.52, 0.78, n2) * 0.55);
	} else {
		// champs de couleur aux bords nets, comme du papier découpé
		float f1 = texture(noise_tex, p.xz * 0.008 + vec2(0.2, 0.7)).r;
		float f2 = texture(noise_tex, p.xz * 0.019 + vec2(0.37, 0.11)).r;
		c = mix(c1, c2, smoothstep(0.497, 0.503, f1));
		c = mix(c, c3, smoothstep(0.667, 0.673, f2));
	}
	return c;
}
