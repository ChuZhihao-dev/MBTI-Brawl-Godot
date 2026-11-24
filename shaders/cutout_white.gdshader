shader_type canvas_item;

uniform float enable_white_key : hint_range(0.0, 1.0) = 0.0;
uniform float white_threshold : hint_range(0.75, 0.99) = 0.92;
uniform float feather : hint_range(0.01, 0.15) = 0.05;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float aura_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.28, 0.94, 0.62, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = tex.a;

	// 仅对旧版不透明白底 .jpg 启用白底抠除；真透明 .png 100% 保留原生清晰边缘与白胡子/银剑细节
	if (enable_white_key > 0.5) {
		float min_c = min(tex.r, min(tex.g, tex.b));
		float max_c = max(tex.r, max(tex.g, tex.b));
		float sat = max_c - min_c;
		float is_white = smoothstep(white_threshold - feather, white_threshold, min_c) * (1.0 - smoothstep(0.03, 0.12, sat));
		a *= (1.0 - is_white);
	}

	if (a < 0.02) {
		discard;
	}

	vec3 col = tex.rgb;
	col = mix(col, aura_color.rgb, aura_glow * 0.22);
	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(col, a);
}
