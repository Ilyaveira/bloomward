// Objets : couleur du bas vers le haut, mousse éventuelle sur le dessus.
shader_type spatial;
uniform vec3 color : source_color = vec3(0.8);
uniform vec3 color_top : source_color = vec3(0.8);
uniform float grad_low = 0.0;
uniform float grad_high = 1.0;
uniform vec3 moss : source_color = vec3(0.4, 0.6, 0.3);
uniform float moss_amount = 0.0;
uniform bool use_instance_color = false;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float brush = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
varying float ly;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	ly = VERTEX.y;
}
void fragment() {
	vec3 c = mix(color, color_top, smoothstep(grad_low, grad_high, ly));
	if (use_instance_color) { c = COLOR.rgb; }
	float n = texture(noise_tex, wpos.xz * 0.35 + wpos.yy * 0.21).r;
	c *= 1.0 + (n - 0.5) * brush;
	c = mix(c, moss, moss_amount * smoothstep(0.55, 0.8, wnrm.y + (n - 0.5) * 0.5 * brush));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
#include "light.gdshaderinc"
