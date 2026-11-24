shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float aura_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 aura_color : source_color = vec4(0.35, 0.95, 0.68, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.02) {
		discard;
	}
	// 柔和阳光边缘高光（与天空竞技场暖光源一致）
	vec2 px = TEXTURE_PIXEL_SIZE * 2.5;
	float a_top_right = texture(TEXTURE, UV + vec2(px.x, -px.y)).a;
	float rim_mask = clamp(1.0 - a_top_right, 0.0, 1.0) * tex.a;

	vec3 col = tex.rgb;
	col = mix(col, rim_color.rgb, rim_mask * rim_strength);
	col = mix(col, aura_color.rgb, rim_mask * aura_glow * 0.75 + aura_glow * 0.14);
	col = mix(col, flash_color.rgb, flash_amount);
	COLOR = vec4(col, tex.a);
}
