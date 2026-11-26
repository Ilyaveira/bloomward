// Sol : couleurs sèches → verdoyantes selon la vague de restauration (globales bloom_*).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

global uniform float bloom_radius;
global uniform vec3 bloom_center;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 dry_a : source_color = vec3(0.80, 0.68, 0.50);
uniform vec3 dry_b : source_color = vec3(0.70, 0.56, 0.40);
uniform vec3 lush_a : source_color = vec3(0.42, 0.60, 0.30);
uniform vec3 lush_b : source_color = vec3(0.55, 0.66, 0.32);
uniform vec3 rock_col : source_color = vec3(0.70, 0.64, 0.58);
uniform vec3 bed_col : source_color = vec3(0.55, 0.47, 0.38);

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.018).r;
	float n2 = texture(noise_tex, wpos.xz * 0.09 + 0.37).r;
	float n3 = texture(noise_tex, wpos.xz * 0.45).r;
	vec3 dry = mix(dry_a, dry_b, smoothstep(0.35, 0.68, n1));
	dry = mix(dry, dry * 0.92, step(0.62, n2));
	vec3 lush = mix(lush_a, lush_b, smoothstep(0.3, 0.72, n1));
	lush = mix(lush, lush * vec3(0.9, 1.02, 0.85), smoothstep(0.55, 0.75, n2));
	float d = distance(wpos.xz, bloom_center.xz) + (n2 - 0.5) * 6.0;
	float m = 1.0 - smoothstep(bloom_radius - 4.0, bloom_radius, d);
	vec3 col = mix(dry, lush, m);
	// Pentes : roche
	float slope = 1.0 - wnormal.y;
	col = mix(col, rock_col * (0.92 + n3 * 0.16), smoothstep(0.32, 0.45, slope));
	// Lit de la rivière et bassin : plus sombre et humide
	col = mix(col, bed_col, smoothstep(-0.18, -0.42, wpos.y));
	// Grain léger
	col *= 0.96 + n3 * 0.08;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	// Liseré lumineux au front de la vague
	float edge = smoothstep(bloom_radius - 3.0, bloom_radius - 0.5, d) * (1.0 - smoothstep(bloom_radius - 0.5, bloom_radius + 1.0, d));
	EMISSION = vec3(1.0, 0.88, 0.55) * edge * 0.35 * step(0.5, bloom_radius) * (1.0 - step(90.0, bloom_radius));
}

#include "res://shaders/toon_light.gdshaderinc"
