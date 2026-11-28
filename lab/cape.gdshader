// Cape : même teinte que les objets, avec un tissu qui ondule et se soulève à la marche.
shader_type spatial;
render_mode cull_back;
uniform vec3 color : source_color = vec3(0.8);
uniform vec3 color_top : source_color = vec3(0.8);
uniform float grad_low = 0.0;
uniform float grad_high = 1.0;
uniform vec3 moss : source_color = vec3(0.4, 0.6, 0.3);
uniform float moss_amount = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float brush = 0.0;
uniform float motion = 0.0;
uniform float stride = 0.0;
varying float ly;
void vertex() {
	ly = VERTEX.y;
	float w = clamp((1.47 - VERTEX.y) / 0.97, 0.0, 1.0);
	w *= w;
	float back = smoothstep(-0.05, 0.22, -VERTEX.z);
	float side = VERTEX.x;
	VERTEX.z -= w * (motion * 0.20 * (0.35 + 0.65 * back) + sin(TIME * 2.3 + side * 7.0) * 0.012 * (1.0 + motion * 2.5));
	// la cape se soulève un peu derrière et retombe à chaque pas
	VERTEX.y += w * motion * (0.06 * back + 0.028 * sin(2.0 * stride - 0.8));
	VERTEX.z -= w * motion * 0.05 * back * sin(2.0 * stride - 1.3);
	VERTEX.x += w * sin(TIME * 1.7 + ly * 5.0 + stride) * 0.010 * (1.0 + motion * 3.0);
	VERTEX.x *= 1.0 + w * motion * 0.06 * sin(stride * 2.0 + side * 3.0);
}
void fragment() {
	ALBEDO = mix(color, color_top, smoothstep(grad_low, grad_high, ly));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
#include "light.gdshaderinc"
