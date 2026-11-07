extends Control
signal closed
var resolution_selector: OptionButton
var fullscreen_toggle: CheckButton
var fps_number: SpinBox
var fps_counter_toggle: CheckButton
var status: Label
var apply_button: Button
var back_button: Button
var sensitivity_sliders: Dictionary = {}
var sensitivity_numbers: Dictionary = {}
var choices: Array[Vector2i] = [Vector2i.ZERO,Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]

var options: RefCounted

func _ready() -> void:
	options = preload("res://scripts/ui/display_options.gd").access(get_tree())
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -340; panel.offset_right = 340
	panel.offset_top = -350; panel.offset_bottom = 350
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171d20")
	style.border_color = Color("968878")
	style.set_border_width_all(2)
	style.content_margin_left = 28; style.content_margin_right = 28
	style.content_margin_top = 24; style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll);scroll.add_child(box)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "НАСТРОЙКИ ИГРЫ"
	title.add_theme_font_size_override("font_size",28)
	box.add_child(title)
	resolution_selector = OptionButton.new()
	resolution_selector.custom_minimum_size.y = 48
	resolution_selector.add_item("Авто · разрешение экрана")
	for size in choices.slice(1): resolution_selector.add_item("%d × %d" % [size.x,size.y])
	box.add_child(resolution_selector)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Полный экран"
	box.add_child(fullscreen_toggle)
	var fps_row:=HBoxContainer.new();box.add_child(fps_row)
	var fps_label:=Label.new();fps_label.text="Ограничение FPS";fps_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;fps_row.add_child(fps_label)
	fps_number=SpinBox.new();fps_number.min_value=0;fps_number.max_value=200;fps_number.step=1;fps_number.suffix="FPS";fps_number.custom_minimum_size.x=150;fps_row.add_child(fps_number)
	var fps_hint:=Label.new();fps_hint.text="0 — стандартный потолок 200 FPS. Можно выбрать ниже.";fps_hint.add_theme_font_size_override("font_size",16);box.add_child(fps_hint)
	fps_counter_toggle=CheckButton.new();fps_counter_toggle.text="Показывать счётчик FPS";box.add_child(fps_counter_toggle)
	var hint := Label.new()
	hint.text = "В окне — размер окна. В полном экране — детализация мира.\nИнтерфейс сохраняет чёткость. Пиксельный стиль может\nиспользовать меньшую детализацию, выбранную в F5."
	hint.add_theme_font_size_override("font_size",17)
	box.add_child(hint)
	var aim_title := Label.new()
	aim_title.text = "Чувствительность прицела"
	aim_title.add_theme_font_size_override("font_size",22)
	box.add_child(aim_title)
	_sensitivity_row(box,"От бедра","hip")
	_sensitivity_row(box,"В прицеливании","ads")
	var aim_hint := Label.new()
	aim_hint.text = "100% — обычная скорость. Оба варианта прицела."
	aim_hint.add_theme_font_size_override("font_size",16)
	box.add_child(aim_hint)
	apply_button = Button.new()
	apply_button.text = "Применить и сохранить"
	apply_button.custom_minimum_size.y = 48
	apply_button.pressed.connect(_apply)
	box.add_child(apply_button)
	back_button = Button.new()
	back_button.text = "Назад"
	back_button.custom_minimum_size.y = 44
	back_button.pressed.connect(close)
	box.add_child(back_button)
	status = Label.new()
	status.add_theme_font_size_override("font_size",16)
	box.add_child(status)
	refresh()
	hide()

func _sensitivity_row(box: VBoxContainer,text: String,key: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 40
	row.add_theme_constant_override("separation",12)
	box.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size",18)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 10; slider.max_value = 300; slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var number := SpinBox.new()
	number.min_value = 10; number.max_value = 300; number.step = 1
	number.suffix = "%"
	number.custom_minimum_size.x = 115
	row.add_child(number)
	slider.value_changed.connect(func(value: float): number.set_value_no_signal(value))
	number.value_changed.connect(func(value: float): slider.set_value_no_signal(value))
	sensitivity_sliders[key] = slider
	sensitivity_numbers[key] = number

func refresh() -> void:
	if not choices.has(options.resolution):
		choices.append(options.resolution)
		resolution_selector.add_item("%d × %d" % [options.resolution.x,options.resolution.y])
	resolution_selector.select(choices.find(options.resolution))
	fullscreen_toggle.set_pressed_no_signal(options.fullscreen)
	fps_number.set_value_no_signal(options.fps_limit)
	fps_counter_toggle.set_pressed_no_signal(options.show_fps)
	for key in ["hip","ads"]:
		var value: float = options.aim_sensitivity(key == "ads")*100.0
		sensitivity_sliders[key].set_value_no_signal(value)
		sensitivity_numbers[key].set_value_no_signal(value)
	status.text = "Выбор сохраняется для следующих запусков."

func open() -> void:
	refresh()
	show()
	apply_button.grab_focus()

func close() -> void:
	hide()
	closed.emit()

func _apply() -> void:
	var result: int = options.apply_preferences(choices[resolution_selector.selected],fullscreen_toggle.button_pressed,sensitivity_sliders.hip.value/100.0,sensitivity_sliders.ads.value/100.0,int(fps_number.value),fps_counter_toggle.button_pressed)
	status.text = "Применено и сохранено." if result == OK else "Применено, но сохранить не удалось (%d)." % result

func _input(event: InputEvent) -> void:
	if resolution_selector and resolution_selector.get_popup().visible: return
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()
