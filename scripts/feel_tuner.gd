class_name FeelTuner
extends Control
# F3 overlay with a slider per GunFeel value. Changes apply instantly, so the
# gun can be tuned while firing; the cursor only appears over the panel.

var game: Node2D
var panel: PanelContainer
var rows := {}
var readout: Label
var status: Label
var status_left := 0.0
var drag_from_panel := false

func _ready() -> void:
	size = Vector2(1440,900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["DIN Condensed","Arial Narrow","Noto Sans"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 13
	panel = PanelContainer.new()
	panel.position = Vector2(36,146)
	panel.custom_minimum_size = Vector2(400,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.046,0.058,0.9)
	style.border_color = Color(0.61,0.63,0.56,0.35)
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",1)
	panel.add_child(box)
	box.add_child(_label("НАСТРОЙКА СТРЕЛЬБЫ  ·  F3",15,StationHUD.GOLD))
	readout = _label("",12,StationHUD.MUTED)
	box.add_child(readout)
	var feel: GunFeel = game.feel
	for param in GunFeel.PARAMS:
		var row := HBoxContainer.new()
		var title := _label(param[1],13,StationHUD.PAPER)
		title.custom_minimum_size.x = 200
		row.add_child(title)
		var slider := HSlider.new()
		slider.min_value = param[2]
		slider.max_value = param[3]
		slider.step = param[4]
		slider.value = feel.get(param[0])
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_value_changed.bind(param[0]))
		row.add_child(slider)
		var value := _label("",13,StationHUD.GOLD)
		value.custom_minimum_size.x = 46
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		box.add_child(row)
		rows[param[0]] = {"slider":slider,"value":value,"step":param[4]}
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",6)
	buttons.add_child(_button("Сброс",_on_reset))
	buttons.add_child(_button("Сохранить",_on_save))
	buttons.add_child(_button("Копировать",_on_copy))
	box.add_child(buttons)
	status = _label("",12,StationHUD.GOLD)
	box.add_child(status)
	_sync()

func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _button(content: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func toggle() -> void:
	visible = not visible
	drag_from_panel = false
	if visible: _sync()
	elif game.state == "playing": Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func blocks_fire() -> bool:
	return visible and (drag_from_panel or _mouse_over_panel())

func _mouse_over_panel() -> bool:
	return panel.get_global_rect().has_point(get_global_mouse_position())

func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		drag_from_panel = event.pressed and _mouse_over_panel()

func _process(delta: float) -> void:
	if not visible: return
	if game.state == "playing":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _mouse_over_panel() or drag_from_panel else Input.MOUSE_MODE_HIDDEN
	var player: Soldier = game.player
	readout.text = "сейчас: разброс %.1f°  ·  подъём %.1f°  ·  тряска %.2f" % [rad_to_deg(player.current_spread()),rad_to_deg(player.climb),game.trauma]
	status_left = maxf(0,status_left-delta)
	if status_left <= 0: status.text = ""

func _sync() -> void:
	var feel: GunFeel = game.feel
	for key in rows:
		rows[key].slider.set_value_no_signal(feel.get(key))
		_show_value(key)

func _show_value(key: String) -> void:
	var row: Dictionary = rows[key]
	var value: float = row.slider.value
	var step: float = row.step
	row.value.text = str(int(value)) if step >= 1 else ("%.1f" % value if step >= 0.1 else "%.2f" % value)

func _on_value_changed(value: float, key: String) -> void:
	game.feel.set(key,value)
	_show_value(key)

func _flash_status(message: String) -> void:
	status.text = message
	status_left = 2.5

func _on_reset() -> void:
	game.feel.reset()
	_sync()
	_flash_status("Значения по умолчанию")

func _on_save() -> void:
	var result: Error = game.feel.save()
	_flash_status("Сохранено: "+GunFeel.SAVE_PATH if result == OK else "Не удалось сохранить (%d)" % result)

func _on_copy() -> void:
	DisplayServer.clipboard_set(game.feel.as_text())
	_flash_status("Значения скопированы в буфер обмена")
