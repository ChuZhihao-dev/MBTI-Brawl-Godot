shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.3, 0.95, 0.65, 1.0);
uniform float hdr_boost : hint_range(1.0, 4.0) = 2.1;
uniform float ring_thickness : hint_range(0.02, 0.35) = 0.14;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	if (dist > 1.0) {
		discard;
	}
	float ease_p = 1.0 - pow(1.0 - progress, 3.0);
	float radius = mix(0.12, 0.92, ease_p);
	float thick = ring_thickness * (1.0 - progress * 0.62);

	// 锐利外环 + 柔和内拖尾
	float d = dist - radius;
	float outer = smoothstep(thick * 0.45, 0.0, abs(d));
	float inner_tail = smoothstep(-thick * 2.2, 0.0, d) * (1.0 - smoothstep(0.0, thick * 0.4, d));
	float mask = clamp(outer * 0.95 + inner_tail * 0.55, 0.0, 1.0);

	// 随扩散自然淡出
	float fade = pow(1.0 - progress, 1.35);
	float core = pow(outer, 2.5);
	vec3 col = mix(tint_color.rgb, vec3(1.0), core * 0.72) * hdr_boost;
	COLOR = vec4(col, mask * fade);
}
