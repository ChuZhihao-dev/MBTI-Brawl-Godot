shader_type canvas_item;

uniform vec3 bg_color = vec3(0.898, 0.898, 0.898); // #e5e5e5 (229, 229, 229)
uniform float threshold = 0.06;
uniform float feather = 0.04;
uniform float alpha_mult = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float dist = distance(tex.rgb, bg_color);
	float a = smoothstep(threshold, threshold + feather, dist) * tex.a * alpha_mult;
	if (a < 0.01) {
		discard;
	}
	COLOR = vec4(tex.rgb, a);
}
