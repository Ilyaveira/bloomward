// Eau du rendu « atmosphère » : rides en relief, lit de galets vu par transparence, caustiques,
// écume qui va et vient sur la rive, reflets du ciel et étincelles.
shader_type spatial;
uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform float extent = 60.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.45, 0.80, 0.85);
uniform vec3 deep : source_color = vec3(0.16, 0.45, 0.62);
uniform vec3 foam : source_color = vec3(1.0);
uniform vec3 sand : source_color = vec3(0.82, 0.70, 0.50);
uniform float sparkle = 1.0;
varying vec3 wpos;
float hgt(vec2 p) {
	float a = texture(noise_tex, p * 0.11 + TIME * vec2(0.010, -0.034)).r;
	float b = texture(noise_tex, p * 0.31 + TIME * vec2(-0.022, -0.058)).r;
	float c = texture(noise_tex, p * 0.83 + TIME * vec2(0.031, -0.090)).r;
	return a * 0.55 + b * 0.30 + c * 0.15;
}
float ridge(float v) { return 1.0 - abs(v * 2.0 - 1.0); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = texture(ground_tex, wpos.xz / (2.0 * extent) + 0.5).rg;
	if (g.g < 0.5) { discard; }
	float depth = max(wpos.y - g.r, 0.0);
	vec2 p = wpos.xz;
	float e = 0.12;
	float h0 = hgt(p);
	vec2 grad = vec2(hgt(p + vec2(e, 0.0)) - h0, hgt(p + vec2(0.0, e)) - h0) / e;
	vec3 nw = normalize(vec3(-grad.x * 0.6, 1.0, -grad.y * 0.6));
	// lit : sable et galets, décalés par les rides comme à travers une vitre mouvante
	vec2 bp = p + nw.xz * depth * 1.2;
	float pn = texture(noise_tex, bp * 0.9).r;
	float pebble = smoothstep(0.50, 0.60, texture(noise_tex, bp * 2.3 + 0.37).r);
	vec3 bed = sand * (0.66 + pn * 0.5);
	bed = mix(bed, bed * vec3(0.60, 0.62, 0.70), pebble * 0.75);
	float ca = ridge(texture(noise_tex, bp * 0.55 + TIME * vec2(0.03, 0.02)).r);
	float cb = ridge(texture(noise_tex, bp * 0.62 - TIME * vec2(0.025, 0.035) + 0.5).r);
	bed *= 1.0 + pow(ca * cb, 5.0) * 2.4 * smoothstep(0.02, 0.22, depth);
	// l'eau absorbe d'abord le rouge : turquoise sur les bords, bleu profond au milieu
	vec3 trans = exp(-depth * vec3(3.6, 1.5, 1.2));
	vec3 c = mix(deep, bed * mix(vec3(1.0), shallow * 1.5, 0.55), trans);
	float lap = sin(TIME * 1.2 + h0 * 14.0) * 0.5 + 0.5;
	float shore = 1.0 - smoothstep(0.0, 0.03 + lap * 0.05, depth);
	float streak = smoothstep(0.022, 0.0, abs(depth - (0.10 + lap * 0.05))) * step(0.5, texture(noise_tex, p * 0.6 + TIME * 0.02).r);
	c = mix(c, foam, clamp(shore * 0.9 + streak * 0.4, 0.0, 1.0));
	ALBEDO = c;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = 0.08;
	SPECULAR = 0.65;
	float sp = texture(noise_tex, p * 3.7 + TIME * vec2(0.11, -0.07)).r * texture(noise_tex, p * 2.9 - TIME * vec2(0.09, 0.05)).r;
	EMISSION = vec3(1.0, 0.96, 0.86) * smoothstep(0.42, 0.50, sp) * sparkle * smoothstep(0.03, 0.15, depth);
}
