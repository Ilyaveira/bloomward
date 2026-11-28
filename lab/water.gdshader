// Eau opaque : la profondeur vient d'une carte de hauteurs du terrain.
shader_type spatial;
uniform sampler2D ground_tex : filter_linear, repeat_disable;
uniform float extent = 60.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform int mode = 0;
uniform vec3 shallow : source_color = vec3(0.45, 0.80, 0.85);
uniform vec3 deep : source_color = vec3(0.16, 0.45, 0.62);
uniform vec3 foam : source_color = vec3(1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = texture(ground_tex, wpos.xz / (2.0 * extent) + 0.5).rg;
	if (g.g < 0.5) { discard; }
	float depth = wpos.y - g.r;
	float r1 = texture(noise_tex, wpos.xz * 0.16 + vec2(TIME * 0.02, -TIME * 0.05)).r;
	float r2 = texture(noise_tex, wpos.xz * 0.45 + vec2(-TIME * 0.03, -TIME * 0.09)).r;
	if (mode == 0) {
		float shore = 1.0 - smoothstep(0.0, 0.10 + r2 * 0.10, depth);
		vec3 c = mix(shallow, deep, smoothstep(0.05, 0.5, depth));
		c = mix(c, foam, shore * 0.85);
		ALBEDO = c;
		ROUGHNESS = 0.12;
		SPECULAR = 0.6;
		NORMAL_MAP = normalize(vec3((r1 - 0.5) * 0.7, (r2 - 0.5) * 0.7, 1.0)) * 0.5 + 0.5;
	} else {
		float shore = 1.0 - step(0.07 + (r2 - 0.5) * 0.04, depth);
		float glint = step(0.71, r1 * 0.6 + r2 * 0.4) * step(0.12, depth);
		vec3 c = mix(shallow, deep, step(0.33, depth));
		c = mix(c, foam, max(shore, glint * (mode == 1 ? 0.9 : 0.6)));
		ALBEDO = vec3(0.0);
		EMISSION = c;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
