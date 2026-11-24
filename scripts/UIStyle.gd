class_name UIStyle
extends RefCounted

static func make_box(
	bg: Color,
	border: Color = Color(0, 0, 0, 0),
	border_w: int = 0,
	radius: int = 10,
	pad_x: int = 14,
	pad_y: int = 8,
	shadow_alpha: float = 0.12,
	shadow_size: int = 6
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	if shadow_size > 0 and shadow_alpha > 0.0:
		sb.shadow_color = Color(0.06, 0.09, 0.16, shadow_alpha)
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0, 3)
	return sb

static func style_primary_btn(btn: Button, accent_gold: bool = false) -> void:
	var border := Color("#fbbf24") if accent_gold else Color("#0f172a")
	var normal := make_box(Color("#1e293b"), border, 2, 10, 22, 10, 0.24, 8)
	var hover := make_box(Color("#334155"), Color("#fde047") if accent_gold else Color("#0f172a"), 2, 10, 22, 10, 0.3, 10)
	var pressed := make_box(Color("#0f172a"), border, 2, 10, 22, 10, 0.12, 3)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color("#fef3c7") if accent_gold else Color("#ffffff"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	btn.add_theme_color_override("font_pressed_color", Color("#fde68a"))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func style_secondary_btn(btn: Button, active_color: Color = Color(0, 0, 0, 0)) -> void:
	var is_active := active_color.a > 0.1
	var bg := active_color if is_active else Color(1.0, 0.992, 0.973, 0.94)
	var border := active_color.darkened(0.2) if is_active else Color("#1e293b")
	var text_col := Color("#ffffff") if is_active else Color("#1e293b")
	var normal := make_box(bg, border, 2, 10, 18, 9, 0.14, 5)
	var hover := make_box(bg.lightened(0.06) if is_active else Color("#f1f5f9"), border, 2, 10, 18, 9, 0.2, 7)
	var pressed := make_box(bg.darkened(0.08) if is_active else Color("#e2e8f0"), border, 2, 10, 18, 9, 0.08, 2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", text_col)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func style_frosted_panel(panel: PanelContainer, border_col: Color = Color(0.12, 0.16, 0.23, 0.16), border_w: int = 2) -> void:
	var sb := make_box(Color(1.0, 0.992, 0.973, 0.84), border_col, border_w, 14, 16, 12, 0.12, 12)
	panel.add_theme_stylebox_override("panel", sb)

static func style_hp_bar(bar: ProgressBar, fill_col: Color) -> void:
	var bg := make_box(Color(0.06, 0.09, 0.16, 0.2), Color(0.06, 0.09, 0.16, 0.45), 2, 6, 0, 0, 0.0, 0)
	var fill := make_box(fill_col, Color(0, 0, 0, 0), 0, 4, 0, 0, 0.0, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
