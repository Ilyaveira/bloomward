// Fins contours « ligne claire » : technique de la coque inversée.
// On redessine l'objet légèrement gonflé, faces avant masquées, dans une couleur sombre unie.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.16, 0.13, 0.12, 1.0);
uniform float width = 0.025;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
