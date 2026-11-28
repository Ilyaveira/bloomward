// Éclairage stylisé partagé : ombre propre en deux paliers doux + liseré de lumière.
// Inclus à la fin des shaders « spatial » qui veulent ce rendu.
uniform float rim_strength = 0.18;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float bands = smoothstep(-0.04, 0.06, ndl) * 0.62 + smoothstep(0.42, 0.52, ndl) * 0.38;
	float shadow = smoothstep(0.25, 0.6, ATTENUATION);
	float lit = bands * mix(0.0, 1.0, shadow);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	SPECULAR_LIGHT += LIGHT_COLOR * rim * rim_strength * lit / PI;
}
