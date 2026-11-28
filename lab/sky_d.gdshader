// Ciel « atmosphère » : dégradé à trois tons, grand halo solaire, nuages en strates éclairés par le soleil.
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.20, 0.45, 0.85);
uniform vec3 mid_color : source_color = vec3(0.60, 0.78, 0.92);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.90, 0.75);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.95, 0.88);
uniform vec3 cloud_shade : source_color = vec3(0.70, 0.72, 0.85);
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
uniform float cloud_cover = 0.55;
uniform float halo = 0.35;
void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, -0.05);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, h));
	col = mix(col, top_color, smoothstep(0.15, 0.75, h));
	float sd = LIGHT0_ENABLED ? max(dot(d, LIGHT0_DIRECTION), 0.0) : 0.0;
	// halo large autour du soleil : c'est lui qui « colore » toute l'image
	col += LIGHT0_COLOR * (pow(sd, 6.0) * halo * 0.25 + pow(sd, 40.0) * halo * 0.5);
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.10);
		float c = texture(cloud_tex, uv * vec2(0.05, 0.16) + vec2(TIME * 0.002, 0.0)).r * 0.7
			+ texture(cloud_tex, uv * vec2(0.13, 0.40) + 0.3).r * 0.3;
		float cloud = smoothstep(cloud_cover, cloud_cover + 0.16, c) * smoothstep(0.0, 0.10, d.y);
		float lit = smoothstep(cloud_cover + 0.22, cloud_cover, c);
		vec3 cc = mix(cloud_shade, cloud_light + LIGHT0_COLOR * pow(sd, 3.0) * 0.25, lit);
		col = mix(col, cc, cloud * 0.85);
	}
	col += LIGHT0_COLOR * smoothstep(0.9990, 0.9995, sd) * 2.0;
	COLOR = col;
}
