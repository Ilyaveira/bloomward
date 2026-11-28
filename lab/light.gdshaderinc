// Éclairage du laboratoire de styles. mode : 0 peinture, 1 épure, 2 ligne claire.
uniform int mode = 0;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (mode == 0) {
		// Lumière enveloppante, ombres douces : le bleu de l'ambiance colore les ombres.
		float w = smoothstep(-0.3, 0.8, ndl);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * w * mix(vec3(0.85, 0.9, 1.0), vec3(1.0), w) / PI;
	} else if (mode == 3) {
		// Atmosphère : lumière douce et colorée, liseré chaud quand le soleil est en face.
		float w = smoothstep(-0.22, 0.85, ndl);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * w / PI;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * clamp(dot(-VIEW, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * rim * 0.55 / PI;
	} else if (mode == 1) {
		// Deux aplats nets : lumière ou ombre.
		float lit = smoothstep(0.0, 0.03, ndl) * smoothstep(0.35, 0.65, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	} else {
		// Aplat + hachures dans l'ombre.
		float lit = step(0.08, ndl) * step(0.5, ATTENUATION);
		// l'ombre est un aplat plus clair, rayé de fines hachures
		float hatch = step(0.34, fract((FRAGCOORD.x + FRAGCOORD.y) / 6.0));
		DIFFUSE_LIGHT += LIGHT_COLOR * max(lit, hatch * 0.42) / PI;
	}
}
