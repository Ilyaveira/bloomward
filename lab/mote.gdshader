// Poussières de lumière et lucioles : petits halos qui dérivent et scintillent.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.92, 0.70);
uniform float size = 0.03;
uniform float energy = 2.0;
uniform float drift = 1.0;
uniform float blink = 0.0;
varying float tw;
void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float h1 = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(sin(dot(root.xy, vec2(39.346, 11.135))) * 24634.6345);
	vec3 off = vec3(sin(TIME * 0.23 * (0.6 + h1) + h2 * 6.28), sin(TIME * 0.17 * (0.6 + h2) + h1 * 6.28) * 0.6, cos(TIME * 0.19 * (0.6 + h2) + h1 * 6.28)) * drift;
	vec3 center = root + off;
	tw = 0.55 + 0.45 * sin(TIME * (1.0 + h1 * 2.0) + h2 * 20.0);
	if (blink > 0.5) { tw = smoothstep(0.35, 1.0, sin(TIME * (0.8 + h1) + h2 * 20.0)); }
	float s = size * (0.6 + h1 * 0.9);
	vec3 wp = center + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * s * 2.0;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wp, 1.0));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - d, 0.0), 2.2);
	ALBEDO = color * energy;
	ALPHA = a * tw;
}
