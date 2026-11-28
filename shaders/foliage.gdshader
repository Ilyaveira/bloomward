// Feuillage : touffes sèches et rabougries avant, pleines et vertes après la vague.
shader_type spatial;
render_mode specular_disabled;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

instance uniform vec3 lush_color : source_color = vec3(0.40, 0.62, 0.30);
uniform vec3 dry_color : source_color = vec3(0.70, 0.52, 0.34);
uniform float delay = 2.5;
uniform float dry_scale = 0.32;

varying float vm;
varying vec3 wnormal;

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = distance(o.xz, bloom_center.xz);
	float m = 1.0 - smoothstep(bloom_radius - 6.0 - delay, bloom_radius - delay, d);
	vm = m;
	VERTEX *= mix(dry_scale, 1.0, m);
	float w = sin(TIME * 1.2 + o.x * 0.45 + o.z * 0.3);
	VERTEX.x += w * 0.05 * (VERTEX.y + 1.0) * m;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = mix(dry_color, lush_color, vm);
	c *= mix(0.88, 1.12, smoothstep(-0.3, 0.9, wnormal.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

#include "res://shaders/toon_light.gdshaderinc"
