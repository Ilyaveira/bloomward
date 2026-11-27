// Ciel épuré : dégradé, grand soleil pâle, deux bandes de nuages.
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.45, 0.75, 0.80);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.88, 0.76);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.88);
void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.6, h));
	// bandes de nuages très fines
	float band = smoothstep(0.004, 0.0, abs(h - 0.11 - sin(atan(d.x, d.z) * 2.0) * 0.012))
		+ smoothstep(0.003, 0.0, abs(h - 0.19 - sin(atan(d.x, d.z) * 3.0 + 1.0) * 0.010)) * 0.7;
	col = mix(col, vec3(1.0, 0.97, 0.93), clamp(band, 0.0, 1.0) * 0.7);
	if (LIGHT0_ENABLED) {
		float sd = dot(d, LIGHT0_DIRECTION);
		col = mix(col, sun_color, smoothstep(0.9930, 0.9940, sd));
		col += sun_color * pow(max(sd, 0.0), 12.0) * 0.12;
	}
	COLOR = col;
}
