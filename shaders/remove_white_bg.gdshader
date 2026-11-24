shader_type canvas_item;
uniform float threshold : hint_range(0.0, 1.0) = 0.95;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// 如果 RGB 接近纯白 (#FFFFFF)，将 Alpha 设为 0
	if (col.r > threshold && col.g > threshold && col.b > threshold) {
		col.a = 0.0;
	}
	COLOR = col;
}
