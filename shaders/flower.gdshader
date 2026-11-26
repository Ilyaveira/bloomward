// Fleurs : éclosent juste derrière la vague de restauration.
shader_type spatial;
render_mode specular_disabled, cull_disabled;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(o.xz, bloom_center.xz);
	float m = 1.0 - smoothstep(bloom_radius - 10.0, bloom_radius - 5.0, d);
	VERTEX *= m;
	float w = sin(TIME * 1.6 + o.x * 0.32 + o.z * 0.21) * 0.6;
	VERTEX.x += w * 0.04 * VERTEX.y * 4.0;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	EMISSION = COLOR.rgb * 0.08;
}

#include "res://shaders/toon_light.gdshaderinc"
