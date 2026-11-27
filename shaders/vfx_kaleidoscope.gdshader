shader_type canvas_item;

uniform sampler2D domain_tex : filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.5) = 0.0;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 100% 保持原图锐利几何直线，零旋转、零橡胶扭曲！仅做电影级缓慢纵深推镜
	vec2 centered = UV - vec2(0.5);
	float zoom = 1.0 / (1.0 + progress * 0.07 + collapse * 0.06);
	vec2 suv = centered * zoom + vec2(0.5);
	vec4 col = texture(domain_tex, clamp(suv, vec2(0.002), vec2(0.998)));

	// 锐利八边形几何菱形展开遮罩（0.0~0.16s 从中心干脆切开领域！）
	vec2 p = abs(centered * vec2(1.7778, 1.0));
	float oct_dist = max(max(p.x, p.y), (p.x + p.y) * 0.7071);
	float open_r = clamp(progress * 8.5, 0.0, 1.55);
	float iris = 1.0 - smoothstep(open_r - 0.02, open_r + 0.015, oct_dist);
	// 展开边缘附带一道极锐利的翡翠金几何边框高光
	float edge_glow = smoothstep(open_r - 0.045, open_r - 0.01, oct_dist) * iris;

	// 一道干脆利落的斜向棱镜高光扫过画面
	float sweep_pos = -0.6 + progress * 1.9;
	float diag = (centered.x * 0.8 + centered.y * 0.6);
	float sheen = exp(-pow((diag - sweep_pos) * 14.0, 2.0)) * 0.22;

	// 中央轻微通透对比，确保前景两位角色的 16 帧大招与受击动作极其锐利清晰
	float r = length(p);
	col.rgb *= mix(0.76, 1.06, smoothstep(0.12, 0.62, r));
	col.rgb += vec3(0.55, 0.95, 0.72) * sheen + vec3(0.99, 0.92, 0.55) * edge_glow * 0.85;

	COLOR = vec4(col.rgb, alpha_mult * iris);
}
