shader_type spatial;
#include "ground_color.gdshaderinc"
uniform vec3 rock : source_color = vec3(0.6, 0.55, 0.5);
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec3 c = ground_col(wpos);
	float slope = 1.0 - wnrm.y;
	if (ground_mode == 0) {
		float brush = texture(noise_tex, vec2(wpos.x * 0.55 + wpos.z * 0.25, wpos.z * 0.12)).r;
		c *= 0.88 + 0.26 * brush;
		c = mix(c, rock, smoothstep(0.22, 0.42, slope + (brush - 0.5) * 0.12));
		c = mix(c, sand, smoothstep(0.06, -0.14, wpos.y + (brush - 0.5) * 0.1));
	} else {
		c = mix(c, rock, step(0.30, slope));
		c = mix(c, sand, step(wpos.y, -0.04));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
#include "light.gdshaderinc"
