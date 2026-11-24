shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float start_angle = -1.2;
uniform float end_angle = 1.0;
uniform float facing = 1.0;
uniform vec4 tint_color : source_color = vec4(0.35, 0.95, 0.65, 1.0);
uniform float hdr_boost : hint_range(1.0, 4.0) = 2.2;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= facing;
	float dist = length(uv);
	if (dist > 1.0 || dist < 0.22) {
		discard;
	}
	float ang = atan(uv.y, uv.x);
	float lo = min(start_angle, end_angle);
	float hi = max(start_angle, end_angle);
	float span = max(0.05, hi - lo);
	float norm_a = (ang - lo) / span;
	if (end_angle < start_angle) {
		norm_a = 1.0 - norm_a;
	}

	float lead = min(1.0, progress * 2.4);
	float tail = max(0.0, (progress - 0.18) / 0.82);
	if (norm_a < tail || norm_a > lead) {
		discard;
	}
	float along = clamp((norm_a - tail) / max(0.001, lead - tail), 0.0, 1.0);
	float taper = sin(along * 3.14159265);
	float radial_center = 0.76;
	float half_w = 0.21 * (0.28 + 0.72 * taper);
	float radial_mask = 1.0 - smoothstep(0.0, half_w, abs(dist - radial_center));
	float outer_edge = smoothstep(radial_center - 0.02, radial_center + half_w * 0.55, dist) * radial_mask;

	// 能量条纹流动感
	float streak = 0.82 + 0.18 * sin(dist * 46.0 - progress * 18.0 + along * 8.0);
	float fade = pow(1.0 - progress, 1.35);
	vec3 col = mix(tint_color.rgb, vec3(1.0, 1.0, 0.96), pow(outer_edge, 1.6) * 0.85 + pow(along, 3.0) * 0.35) * hdr_boost * streak;
	COLOR = vec4(col, radial_mask * taper * fade * 0.95);
}
