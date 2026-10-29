extends Node2D

## 演示场景控制器：搭建一个实时可调的控制面板，覆盖 fog 的主要功能场景。
## 直接引用 addon 导出的 Fog 类，演示其公开接口（导出属性 = 实时参数）。

# Fog 是 addon 导出的全局类；此处用动态类型以避免对类注册顺序的依赖。
@onready var fog_ambient = $FogAmbient
@onready var fog_zone = $FogZone


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel := Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(330, 460)
	layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_add_title(vbox, "环境特效演示")
	_add_hint(vbox, "WASD / 方向键 移动角色。右侧雾区常驻显示；勾选「玩家进入淡入」后，走进去会再淡入到满。")

	# —— 全局氛围雾 ——
	_add_checkbox(vbox, "氛围雾（全屏）", true, func(v: bool) -> void: fog_ambient.visible = v)
	_add_slider(vbox, "氛围浓度", 0.0, 0.3, fog_ambient.density,
		func(v: float) -> void: fog_ambient.density = v)

	# —— 区域雾（FogZone）——
	_add_title(vbox, "区域雾 FogZone")
	_add_checkbox(vbox, "区域限制", fog_zone.region_enabled,
		func(v: bool) -> void: fog_zone.region_enabled = v)
	_add_checkbox(vbox, "椭圆包络", fog_zone.elliptical,
		func(v: bool) -> void: fog_zone.elliptical = v)
	_add_checkbox(vbox, "玩家进入淡入", fog_zone.activate_with_player,
		func(v: bool) -> void: fog_zone.activate_with_player = v)
	_add_slider(vbox, "浓度 density", 0.0, 1.0, fog_zone.density,
		func(v: float) -> void: fog_zone.density = v)
	_add_slider(vbox, "覆盖率 coverage", 0.0, 1.0, fog_zone.coverage,
		func(v: float) -> void: fog_zone.coverage = v)
	_add_slider(vbox, "柔边 softness", 0.01, 1.0, fog_zone.softness,
		func(v: float) -> void: fog_zone.softness = v)
	_add_color(vbox, "雾颜色", fog_zone.fog_color,
		func(c: Color) -> void: fog_zone.fog_color = c)


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


func _add_checkbox(parent: Control, label: String, value: bool, callback: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = value
	cb.toggled.connect(callback)
	parent.add_child(cb)


func _add_slider(parent: Control, label: String, minv: float, maxv: float, value: float, callback: Callable) -> void:
	var hb := HBoxContainer.new()

	var label_node := Label.new()
	label_node.text = label
	label_node.custom_minimum_size = Vector2(110, 0)
	label_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label_node)

	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.value = value
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	hb.add_child(slider)

	parent.add_child(hb)


func _add_color(parent: Control, label: String, value: Color, callback: Callable) -> void:
	var hb := HBoxContainer.new()

	var label_node := Label.new()
	label_node.text = label
	label_node.custom_minimum_size = Vector2(110, 0)
	label_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(label_node)

	var picker := ColorPickerButton.new()
	picker.color = value
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.color_changed.connect(callback)
	hb.add_child(picker)

	parent.add_child(hb)
