extends Node2D

## 演示场景控制器：搭建一个实时可调的控制面板，覆盖 rain 的主要功能场景。
## 直接引用 addon 导出的 Rain 类，演示其公开接口（导出属性 = 实时参数）。
## 布局与交互方式、参数范围与默认值均与雾效演示保持一致，仅视觉表现换为降雨。

# Rain 是 addon 导出的全局类；此处用动态类型以避免对类注册顺序的依赖。
@onready var rain_ambient = $RainAmbient
@onready var rain_zone = $RainZone


const MAIN_MENU := "res://main.tscn"
const FxParamHistory = preload("res://scenes/demo/param_history_store.gd")
const ParamHistoryPanel = preload("res://scenes/demo/param_history_panel.gd")

## 参数改动后的自动保存：用 0.5s 的防抖把最终值记成一条快照，避免拖动滑块时刷屏。
const COMMIT_DELAY := 0.5

var _history: RefCounted
var _commit_timer: Timer
var _control_map := {}
var _ui_layer: CanvasLayer
var _restoring := false

func _ready() -> void:
	_history = FxParamHistory.new("rain")
	_commit_timer = Timer.new()
	_commit_timer.wait_time = COMMIT_DELAY
	_commit_timer.one_shot = true
	add_child(_commit_timer)
	_commit_timer.timeout.connect(_commit)
	_build_ui()
	# 重新打开时自动套用最近一次保存的参数，避免被场景默认值覆盖。
	if _history.records.size() > 0:
		_apply_params(_history.records[_history.records.size() - 1]["params"])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 历史面板打开时，把 ESC 交给面板处理（关闭面板），不要直接回主菜单。
		if _ui_layer != null:
			for child in _ui_layer.get_children():
				if child is ParamHistoryPanel:
					return
		get_tree().change_scene_to_file(MAIN_MENU)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_ui_layer = layer

	var panel := Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(330, 650)
	layer.add_child(panel)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.position = Vector2(1104, 16)
	back_button.size = Vector2(160, 40)
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU))
	layer.add_child(back_button)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_add_title(vbox, "降雨特效演示")
	_add_hint(vbox, "WASD / 方向键 移动角色。右侧雨区常驻显示；勾选「玩家进入淡入」后，走进去会再淡入到满。\n按 ESC 返回主菜单。")

	# —— 全局氛围雨 ——
	_add_checkbox(vbox, "氛围雨（全屏）", true, func(v: bool) -> void: rain_ambient.visible = v, "ambient_visible")
	_add_slider(vbox, "氛围强度", 0.0, 0.3, rain_ambient.density,
		func(v: float) -> void: rain_ambient.density = v, "ambient_density")

	# —— 全局风向角度（同时作用于氛围雨与区域雨）——
	_add_title(vbox, "风向角度")
	_add_slider(vbox, "角度 angle", -60.0, 60.0, rain_zone.angle_deg,
		func(v: float) -> void:
			rain_ambient.angle_deg = v
			rain_zone.angle_deg = v, "angle_deg")

	_add_slider(vbox, "紊乱度 chaos", 0.0, 1.0, rain_zone.chaos,
		func(v: float) -> void:
			rain_ambient.chaos = v
			rain_zone.chaos = v, "chaos")

	# —— 下落速度（同时作用于氛围雨与区域雨）——
	_add_title(vbox, "下落速度")
	_add_slider(vbox, "速度 rain_speed", 0.0, 4.0, rain_zone.rain_speed,
		func(v: float) -> void:
			rain_ambient.rain_speed = v
			rain_zone.rain_speed = v, "rain_speed")

	# —— 雨丝形态（同时作用于氛围雨与区域雨）——
	_add_title(vbox, "雨丝形态")
	_add_slider(vbox, "粗细 thickness", 0.0, 2.0, rain_zone.thickness,
		func(v: float) -> void:
			rain_ambient.thickness = v
			rain_zone.thickness = v, "thickness")
	_add_slider(vbox, "拖影 trail_scale", 0.2, 3.0, rain_zone.trail_scale,
		func(v: float) -> void:
			rain_ambient.trail_scale = v
			rain_zone.trail_scale = v, "trail_scale")

	# —— 区域雨（RainZone）——
	_add_title(vbox, "区域雨 RainZone")
	_add_checkbox(vbox, "区域限制", rain_zone.region_enabled,
		func(v: bool) -> void: rain_zone.region_enabled = v, "region_enabled")
	_add_checkbox(vbox, "椭圆包络", rain_zone.elliptical,
		func(v: bool) -> void: rain_zone.elliptical = v, "elliptical")
	_add_checkbox(vbox, "玩家进入淡入", rain_zone.activate_with_player,
		func(v: bool) -> void: rain_zone.activate_with_player = v, "activate_with_player")
	_add_slider(vbox, "强度 density", 0.0, 1.0, rain_zone.density,
		func(v: float) -> void: rain_zone.density = v, "density")
	_add_slider(vbox, "覆盖率 coverage", 0.0, 1.0, rain_zone.coverage,
		func(v: float) -> void: rain_zone.coverage = v, "coverage")
	_add_slider(vbox, "柔边 softness", 0.01, 1.0, rain_zone.softness,
		func(v: float) -> void: rain_zone.softness = v, "softness")
	_add_color(vbox, "雨颜色", rain_zone.rain_color,
		func(c: Color) -> void: rain_zone.rain_color = c, "rain_color")

	# —— 水珠头（让雨读起来像“雨滴”而非纯雨丝）——
	_add_title(vbox, "水珠头")
	_add_slider(vbox, "水珠淡入 droplet", 0.0, 1.0, rain_zone.droplet,
		func(v: float) -> void:
			rain_ambient.droplet = v
			rain_zone.droplet = v, "droplet")
	_add_slider(vbox, "水珠大小 drop_size", 0.0, 1.0, rain_zone.drop_size,
		func(v: float) -> void:
			rain_ambient.drop_size = v
			rain_zone.drop_size = v, "drop_size")
	_add_slider(vbox, "纵向拉伸 drop_stretch", 0.1, 1.0, rain_zone.drop_stretch,
		func(v: float) -> void:
			rain_ambient.drop_stretch = v
			rain_zone.drop_stretch = v, "drop_stretch")
	_add_slider(vbox, "水珠亮度 drop_brightness", 0.5, 3.0, rain_zone.drop_brightness,
		func(v: float) -> void:
			rain_ambient.drop_brightness = v
			rain_zone.drop_brightness = v, "drop_brightness")

	_add_hint(vbox, "提示：任意参数调整后都会自动保存；点「历史记录」可回看各次调整并恢复到当时状态。")
	_add_history_button(vbox)


func _add_history_button(parent: Control) -> void:
	var history_button := Button.new()
	history_button.text = "历史记录"
	history_button.custom_minimum_size = Vector2(0, 36)
	history_button.add_theme_font_size_override("font_size", 14)
	history_button.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	history_button.add_theme_stylebox_override("normal", _make_row_style(Color(0.18, 0.24, 0.34), Color(0, 0, 0, 0)))
	history_button.add_theme_stylebox_override("hover", _make_row_style(Color(0.28, 0.4, 0.55), Color(0, 0, 0, 0)))
	history_button.add_theme_stylebox_override("pressed", _make_row_style(Color(0.36, 0.74, 1.0, 0.5), Color(0, 0, 0, 0)))
	history_button.add_theme_stylebox_override("focus", _make_row_style(Color(0, 0, 0, 0), Color(CHECK_ACCENT_COLOR, 0.55)))
	history_button.pressed.connect(_open_history)
	parent.add_child(history_button)


## 收集当前所有关键参数（用于记录与恢复）。
func _collect_params() -> Dictionary:
	return {
		"ambient_visible": rain_ambient.visible,
		"ambient_density": rain_ambient.density,
		"angle_deg": rain_zone.angle_deg,
		"chaos": rain_zone.chaos,
		"rain_speed": rain_zone.rain_speed,
		"thickness": rain_zone.thickness,
		"trail_scale": rain_zone.trail_scale,
		"region_enabled": rain_zone.region_enabled,
		"elliptical": rain_zone.elliptical,
		"activate_with_player": rain_zone.activate_with_player,
		"density": rain_zone.density,
		"coverage": rain_zone.coverage,
		"softness": rain_zone.softness,
		"rain_color": rain_zone.rain_color,
		"droplet": rain_zone.droplet,
		"drop_size": rain_zone.drop_size,
		"drop_stretch": rain_zone.drop_stretch,
		"drop_brightness": rain_zone.drop_brightness,
	}


func _make_label(p: Dictionary) -> String:
	return "强度 %.2f · 覆盖 %.2f · 角度 %.1f° · 速度 %.2f%s" % [
		p.get("density", 0.0),
		p.get("coverage", 0.0),
		p.get("angle_deg", 0.0),
		p.get("rain_speed", 0.0),
		(" · 区域限制" if p.get("region_enabled", false) else ""),
	]


## 把一条记录写回：先同步到控件（会触发原回调写回节点），再同步到特效节点。
func _apply_params(p: Dictionary) -> void:
	_restoring = true
	for key in p.keys():
		if not _control_map.has(key):
			continue
		var ctl = _control_map[key]
		var val = p[key]
		if ctl is HSlider:
			ctl.value = val
		elif ctl is CheckBox:
			ctl.button_pressed = val
		elif ctl is ColorPickerButton:
			ctl.color = val
	_restoring = false


func _open_history() -> void:
	if _ui_layer == null:
		return
	var panel := ParamHistoryPanel.new(_history, _apply_params)
	_ui_layer.add_child(panel)


## 参数改动后用防抖合并成一条记录，避免拖动滑块时频繁写入。
## 接受可选参数以兼容 signal 调用（toggled / value_changed 会传入值）。
func _schedule_commit(_value = null) -> void:
	if _restoring:
		return
	_commit_timer.start()


func _commit() -> void:
	if _history == null:
		return
	_history.record(_collect_params(), _make_label(_collect_params()))


func _add_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	parent.add_child(label)


func _add_hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(label)


const CHECK_BOX_SIZE := 18
const CHECK_BORDER_COLOR := Color(0.42, 0.5, 0.62)
const CHECK_BG_COLOR := Color(0.12, 0.15, 0.21)
const CHECK_ACCENT_COLOR := Color(0.36, 0.74, 1.0)

static var _check_icon_cache: Dictionary = {}


func _add_checkbox(parent: Control, label: String, value: bool, callback: Callable, key := "") -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = value
	cb.custom_minimum_size = Vector2(0, 26)
	cb.add_theme_font_size_override("font_size", 13)
	cb.add_theme_constant_override("h_separation", 8)
	cb.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	cb.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	cb.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	cb.add_theme_icon_override("unchecked", _make_check_icon(false))
	cb.add_theme_icon_override("checked", _make_check_icon(true))
	# 整行可点击区域：常态淡底，悬停/按下高亮，聚焦时描边
	cb.add_theme_stylebox_override("normal", _make_row_style(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0)))
	cb.add_theme_stylebox_override("hover", _make_row_style(Color(CHECK_ACCENT_COLOR, 0.12), Color(0, 0, 0, 0)))
	cb.add_theme_stylebox_override("pressed", _make_row_style(Color(CHECK_ACCENT_COLOR, 0.2), Color(0, 0, 0, 0)))
	cb.add_theme_stylebox_override("focus", _make_row_style(Color(0, 0, 0, 0), Color(CHECK_ACCENT_COLOR, 0.55)))

	cb.toggled.connect(callback)
	cb.toggled.connect(_schedule_commit)
	if key != "":
		_control_map[key] = cb
	parent.add_child(cb)


func _make_row_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _make_check_icon(pressed: bool) -> ImageTexture:
	var key := 1 if pressed else 0
	if _check_icon_cache.has(key):
		return _check_icon_cache[key]

	var size := CHECK_BOX_SIZE
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 圆角方框：外层描边 + 内缩 2px 的底色/强调色
	for y in size:
		for x in size:
			if _inside_round_rect(x, y, size, size, 5):
				img.set_pixel(x, y, CHECK_BORDER_COLOR)
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			if _inside_round_rect(x - 2, y - 2, size - 4, size - 4, 3):
				img.set_pixel(x, y, CHECK_ACCENT_COLOR if pressed else CHECK_BG_COLOR)

	if pressed:
		_draw_icon_line(img, Vector2(4.5, 9.2), Vector2(7.6, 12.4), 1.5, Color.WHITE)
		_draw_icon_line(img, Vector2(7.6, 12.4), Vector2(13.2, 5.6), 1.5, Color.WHITE)

	var texture := ImageTexture.create_from_image(img)
	_check_icon_cache[key] = texture
	return texture


static func _inside_round_rect(x: int, y: int, w: int, h: int, r: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var cx := clampi(x, r, w - 1 - r)
	var cy := clampi(y, r, h - 1 - r)
	var dx := float(x - cx)
	var dy := float(y - cy)
	return dx * dx + dy * dy <= float(r * r) + 0.5


func _draw_icon_line(img: Image, from: Vector2, to: Vector2, radius: float, color: Color) -> void:
	var min_x := maxi(0, int(floor(minf(from.x, to.x) - radius)))
	var max_x := mini(img.get_width() - 1, int(ceil(maxf(from.x, to.x) + radius)))
	var min_y := maxi(0, int(floor(minf(from.y, to.y) - radius)))
	var max_y := mini(img.get_height() - 1, int(ceil(maxf(from.y, to.y) + radius)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _segment_distance(Vector2(x, y), from, to) <= radius:
				img.set_pixel(x, y, color)


static func _segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	var direction := to - from
	var length_squared := direction.length_squared()
	var t := 0.0
	if length_squared > 0.0:
		t = clampf((point - from).dot(direction) / length_squared, 0.0, 1.0)
	return point.distance_to(from + direction * t)


const SLIDER_TRACK_COLOR := Color(0.16, 0.2, 0.28)
const SLIDER_FILL_COLOR := Color(0.36, 0.74, 1.0)
const SLIDER_GRABBER_COLOR := Color(0.95, 0.98, 1.0)

static var _grabber_texture: GradientTexture2D


func _add_slider(parent: Control, label: String, minv: float, maxv: float, value: float, callback: Callable, key := "") -> void:
	var hb := HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 8)

	# 固定宽度的标签容器，避免长短不一的文本把滑块起点顶歪
	var label_box := Control.new()
	label_box.custom_minimum_size = Vector2(108, 0)
	hb.add_child(label_box)

	var label_node := Label.new()
	label_node.text = label
	label_node.clip_text = true
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.add_theme_font_size_override("font_size", 13)
	label_box.add_child(label_node)
	label_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	# step 必须在 value 之前设置，否则默认 step = 1 会把小数初值吸附成 0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(120, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 轨道
	var track := StyleBoxFlat.new()
	track.bg_color = SLIDER_TRACK_COLOR
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track)

	# 已填充部分
	var fill := StyleBoxFlat.new()
	fill.bg_color = SLIDER_FILL_COLOR
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	slider.add_theme_stylebox_override("grabber_area", fill)

	var fill_highlight := fill.duplicate() as StyleBoxFlat
	fill_highlight.bg_color = SLIDER_FILL_COLOR.lightened(0.18)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_highlight)

	# 滑块圆点
	slider.add_theme_icon_override("grabber", _get_grabber_texture())
	slider.add_theme_icon_override("grabber_highlight", _get_grabber_texture())

	slider.value_changed.connect(callback)
	slider.value_changed.connect(_schedule_commit)
	hb.add_child(slider)

	# 数值
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	slider.value_changed.connect(func(v: float) -> void: value_label.text = "%.2f" % v)
	hb.add_child(value_label)

	if key != "":
		_control_map[key] = slider
	parent.add_child(hb)


func _get_grabber_texture() -> GradientTexture2D:
	if _grabber_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		gradient.colors = PackedColorArray([
			SLIDER_GRABBER_COLOR,
			SLIDER_GRABBER_COLOR,
			Color(SLIDER_GRABBER_COLOR, 0.0),
		])

		_grabber_texture = GradientTexture2D.new()
		_grabber_texture.gradient = gradient
		_grabber_texture.fill = GradientTexture2D.FILL_RADIAL
		_grabber_texture.fill_from = Vector2(0.5, 0.5)
		_grabber_texture.fill_to = Vector2(1.0, 0.5)
		_grabber_texture.width = 16
		_grabber_texture.height = 16
	return _grabber_texture


func _add_color(parent: Control, label: String, value: Color, callback: Callable, key := "") -> void:
	var hb := HBoxContainer.new()

	var label_node := Label.new()
	label_node.text = label
	label_node.custom_minimum_size = Vector2(108, 0)
	label_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label_node)

	var picker := ColorPickerButton.new()
	picker.color = value
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.color_changed.connect(callback)
	picker.color_changed.connect(_schedule_commit)
	hb.add_child(picker)

	if key != "":
		_control_map[key] = picker
	parent.add_child(hb)
