extends Control

## 参数调整记录面板：以模态浮层展示某类特效的历史快照（时间戳 + 关键参数摘要 + 颜色样本），
## 支持点「恢复」把选中记录套用到当前场景，也支持「清空」全部记录。
## store         : FxParamHistory 实例（已含加载好的记录）
## apply_callback: 接收一条 params 字典，由调用方负责写回节点并刷新控件

const FxParamHistory = preload("res://scenes/demo/param_history_store.gd")

var store: RefCounted
var apply_callback: Callable

var _main_panel: Panel
var _list: VBoxContainer
var _count_label: Label

const ACCENT := Color(0.36, 0.74, 1.0)


func _init(p_store: RefCounted, p_apply: Callable) -> void:
	store = p_store
	apply_callback = p_apply


func _ready() -> void:
	set_process_unhandled_input(true)
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	_main_panel = Panel.new()
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.size = Vector2(460, 560)
	_main_panel.position = (get_viewport_rect().size - _main_panel.size) * 0.5
	_main_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_main_panel)

	# 顶部装饰条
	var accent_bar := Panel.new()
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_bar.position = Vector2(0, 0)
	accent_bar.size = Vector2(_main_panel.size.x, 4)
	var ab_style := StyleBoxFlat.new()
	ab_style.bg_color = ACCENT
	accent_bar.add_theme_stylebox_override("panel", ab_style)
	_main_panel.add_child(accent_bar)

	# 标题栏
	var header := HBoxContainer.new()
	header.position = Vector2(18, 18)
	header.size = Vector2(_main_panel.size.x - 36, 36)
	_main_panel.add_child(header)

	var title := Label.new()
	title.text = "参数调整记录"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	header.add_child(title)

	var close_btn := _text_button("关闭", Color(0.3, 0.36, 0.46), Color(0.42, 0.5, 0.62))
	close_btn.pressed.connect(func() -> void: queue_free())
	header.add_child(close_btn)

	# 分隔线
	var divider := HSeparator.new()
	divider.position = Vector2(18, 58)
	divider.size = Vector2(_main_panel.size.x - 36, 2)
	divider.add_theme_stylebox_override("separator", _divider_style())
	_main_panel.add_child(divider)

	# 列表
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 70)
	scroll.size = Vector2(_main_panel.size.x - 28, _main_panel.size.y - 70 - 56)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_panel.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

	# 底部栏
	var footer := HBoxContainer.new()
	footer.position = Vector2(18, _main_panel.size.y - 46)
	footer.size = Vector2(_main_panel.size.x - 36, 34)
	_main_panel.add_child(footer)

	_count_label = Label.new()
	_count_label.text = ""
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_label.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82))
	_count_label.add_theme_font_size_override("font_size", 12)
	footer.add_child(_count_label)

	var clear_btn := _text_button("清空记录", Color(0.34, 0.2, 0.24), Color(0.5, 0.3, 0.34))
	clear_btn.pressed.connect(_on_clear)
	footer.add_child(clear_btn)

	_refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


func _on_clear() -> void:
	store.clear()
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if store.records.is_empty():
		var empty := VBoxContainer.new()
		empty.add_theme_constant_override("separation", 4)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := Label.new()
		t.text = "暂无记录"
		t.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
		t.add_theme_font_size_override("font_size", 14)
		empty.add_child(t)
		var s := Label.new()
		s.text = "调整任意参数后会自动保存到这里"
		s.add_theme_color_override("font_color", Color(0.6, 0.66, 0.76))
		s.add_theme_font_size_override("font_size", 12)
		empty.add_child(s)
		_list.add_child(empty)
	else:
		# 最新的排在最上面
		for i in range(store.records.size() - 1, -1, -1):
			_list.add_child(_make_row(store.records[i]))
	_count_label.text = "共 %d 条 · 最近一次在最上方" % store.records.size()


func _make_row(rec: Dictionary) -> Control:
	# 整行是一张卡片（PanelContainer 会随内容自动撑高），点击任意处即可恢复
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 56)
	var base_bg := Color(0.16, 0.2, 0.28, 0.55)
	card.add_theme_stylebox_override("panel", _card_style(base_bg))
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_restore(rec))
	card.mouse_entered.connect(func() -> void:
		card.add_theme_stylebox_override("panel", _card_style(Color(0.26, 0.4, 0.58, 0.95))))
	card.mouse_exited.connect(func() -> void:
		card.add_theme_stylebox_override("panel", _card_style(base_bg)))

	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("h_separation", 12)
	hb.add_theme_constant_override("margin_left", 14)
	hb.add_theme_constant_override("margin_right", 14)
	hb.add_theme_constant_override("margin_top", 10)
	hb.add_theme_constant_override("margin_bottom", 10)
	card.add_child(hb)

	var swatch := _make_swatch(rec)
	if swatch != null:
		hb.add_child(swatch)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 5)
	hb.add_child(info)

	var time := Label.new()
	time.text = _format_time(rec.get("time", 0))
	time.add_theme_color_override("font_color", ACCENT)
	time.add_theme_font_size_override("font_size", 12)
	info.add_child(time)

	var summary := Label.new()
	summary.text = rec.get("summary", "")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("line_spacing", 3)
	summary.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	summary.add_theme_font_size_override("font_size", 12)
	info.add_child(summary)

	# 恢复按钮固定在最右侧
	var restore := _text_button("恢复", ACCENT, Color(0.46, 0.84, 1.0))
	restore.custom_minimum_size = Vector2(60, 36)
	restore.size_flags_horizontal = Control.SIZE_SHRINK_END
	restore.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(func() -> void: _restore(rec))
	hb.add_child(restore)

	return card


## 在行首画一个小色块，直观反映该次记录的雾/雨颜色。
func _make_swatch(rec: Dictionary) -> Control:
	var p: Dictionary = rec.get("params", {})
	var col := Color.WHITE
	if p.has("fog_color"):
		col = p["fog_color"]
	elif p.has("rain_color"):
		col = p["rain_color"]
	else:
		return null
	var sw := Panel.new()
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.custom_minimum_size = Vector2(18, 18)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.3)
	sw.add_theme_stylebox_override("panel", sb)
	return sw


func _restore(rec: Dictionary) -> void:
	if apply_callback.is_valid():
		apply_callback.call(rec.get("params", {}))
	queue_free()


func _format_time(unix: float) -> String:
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d-%02d %02d:%02d:%02d" % [t["month"], t["day"], t["hour"], t["minute"], t["second"]]


## 通用胶囊按钮。bg / hover 可自定义，按 accent 风格绘制。
func _text_button(text: String, bg: Color = Color(0.2, 0.26, 0.36), hover: Color = Color(0.3, 0.42, 0.58)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	b.add_theme_stylebox_override("normal", _row_style(bg))
	b.add_theme_stylebox_override("hover", _row_style(hover))
	b.add_theme_stylebox_override("pressed", _row_style(ACCENT))
	b.add_theme_stylebox_override("focus", _row_style(Color(0, 0, 0, 0)))
	return b


func _row_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## 历史行卡片样式：仅做背景与圆角，内边距交给内部 HBox 控制。
func _card_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


func _divider_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ACCENT, 0.35)
	sb.set_corner_radius_all(1)
	return sb


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.17, 0.99)
	sb.border_color = Color(ACCENT, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_border_width(SIDE_TOP, 0)
	return sb
