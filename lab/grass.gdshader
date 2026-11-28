// Herbe peinte : touffes qui prennent la couleur du sol et s'éclaircissent vers la pointe.
shader_type spatial;
render_mode cull_disabled;
#include "ground_color.gdshaderinc"
uniform vec3 tip : source_color = vec3(0.75, 0.85, 0.35);
varying vec3 gcol;
varying float t;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	t = COLOR.r;
	float sway = sin(TIME * 1.4 + root.x * 0.45 + root.z * 0.35) * 0.10 + sin(TIME * 2.7 + root.x * 1.3) * 0.03;
	VERTEX.x += sway * t * t;
	VERTEX.z += sway * 0.5 * t * t;
	gcol = ground_col(root);
	float brush = texture(noise_tex, vec2(root.x * 0.55 + root.z * 0.25, root.z * 0.12)).r;
	gcol *= 1.0 + (brush - 0.5) * 0.26 * ground_brush;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = mix(gcol * 0.86, mix(gcol, tip, 0.55), t);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
#include "light.gdshaderinc"
