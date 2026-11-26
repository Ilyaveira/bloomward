// Herbe : courte et jaunie avant, haute et verte après la vague ; ondule au vent.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 dry_root : source_color = vec3(0.70, 0.58, 0.40);
uniform vec3 dry_tip : source_color = vec3(0.86, 0.76, 0.55);
uniform vec3 lush_root : source_color = vec3(0.26, 0.44, 0.22);
uniform vec3 lush_tip : source_color = vec3(0.62, 0.78, 0.38);
uniform float blade_height = 0.42;

varying float vm;
varying float vh;
varying float vn;

void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float n = texture(noise_tex, o.xz * 0.06).r;
	vn = n;
	float d = distance(o.xz, bloom_center.xz) + (texture(noise_tex, o.xz * 0.09 + 0.37).r - 0.5) * 6.0;
	float m = 1.0 - smoothstep(bloom_radius - 5.0, bloom_radius, d);
	vm = m;
	float t = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vh = t;
	VERTEX.y *= mix(0.3 + n * 0.15, 0.75 + n * 0.55, m);
	float w = sin(TIME * 1.6 + o.x * 0.32 + o.z * 0.21) * 0.6 + sin(TIME * 2.9 + o.x * 0.8 - o.z * 0.5) * 0.25;
	vec3 wind_world = vec3(1.0, 0.0, 0.35) * w * t * t * 0.16;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(wind_world, 0.0)).xyz;
}

void fragment() {
	vec3 root = mix(dry_root, lush_root, vm);
	vec3 tip = mix(dry_tip, lush_tip, vm) * (0.92 + vn * 0.16);
	ALBEDO = mix(root, tip, vh);
	// Normale « vers le haut » des deux côtés : l'herbe s'éclaire comme le sol.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}

#include "res://shaders/toon_light.gdshaderinc"
