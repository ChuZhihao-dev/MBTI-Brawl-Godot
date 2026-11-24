shader_type canvas_item;

uniform float white_threshold : hint_range(0.75, 0.99) = 0.93;
uniform float feather : hint_range(0.01, 0.15) = 0.06;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_strength : hint_range(0.0, 1.0) = 0.45;
uniform vec4 outline_color : source_color = vec4(0.11, 0.15, 0.22, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float aura_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.28, 0.94, 0.62, 1.0);

float sample_clean_alpha(sampler2D tex_sampler, vec2 uv) {
	vec4 t = texture(tex_sampler, uv);
	float min_c = min(t.r, min(t.g, t.b));
	float max_c = max(t.r, max(t.g, t.b));
	float sat = max_c - min_c;
	float is_white = smoothstep(white_threshold - feather, white_threshold, min_c) * (1.0 - smoothstep(0.03, 0.13, sat));
	return clamp(t.a * (1.0 - is_white), 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float a = sample_clean_alpha(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;

	// 外部 1.5px 柔和深色轮廓线：让 16p 低多边形角色从明亮背景中清晰立出来
	if (a < 0.15) {
		if (outline_strength > 0.01) {
			float na = max(
				max(sample_clean_alpha(TEXTURE, UV + vec2(px.x, 0.0)), sample_clean_alpha(TEXTURE, UV - vec2(px.x, 0.0))),
				max(sample_clean_alpha(TEXTURE, UV + vec2(0.0, px.y)), sample_clean_alpha(TEXTURE, UV - vec2(0.0, px.y)))
			);
			if (na > 0.35) {
				vec3 out_rgb = mix(outline_color.rgb, aura_color.rgb, aura_glow * 0.75);
				COLOR = vec4(out_rgb, na * outline_strength * (1.0 + aura_glow * 0.5));
			} else {
				discard;
			}
		} else {
			discard;
		}
	} else {
		// 柔和阳光边缘高光（与天空竞技场暖光源一致）
		float a_tr = sample_clean_alpha(TEXTURE, UV + vec2(px.x * 1.3, -px.y * 1.3));
		float rim_mask = clamp(1.0 - a_tr, 0.0, 1.0);

		vec3 col = tex.rgb;
		col = mix(col, rim_color.rgb, rim_mask * rim_strength);
		col = mix(col, aura_color.rgb, rim_mask * aura_glow * 0.7 + aura_glow * 0.12);
		col = mix(col, flash_color.rgb, flash_amount);
		COLOR = vec4(col, a);
	}
}
