// Papillons : ailes qui battent, couleur donnée par la particule.
shader_type spatial;
render_mode cull_disabled, unshaded;

void vertex() {
	float flap = sin(TIME * 16.0 + float(INSTANCE_ID) * 1.7);
	VERTEX.y += abs(VERTEX.x) * flap * 1.2;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
