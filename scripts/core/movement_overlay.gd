class_name CoreMovementOverlay
extends Control

signal export_requested
signal import_requested
signal settings_changed

var settings: Resource
var defaults: Resource
var params: Array = CoreMovementSettings.PARAMS
var groups := ["Бег","Прыжок","Дэш","Лестница","Склоны"]
var heading_text := "НАСТРОЙКА ДВИЖЕНИЯ · F3"
var help_text := "Изменения применяются сразу. Проверяйте на площадке."
var current_values_text := "Текущие значения · новые тайминги со следующего действия"
var settings_path := CoreMovementSettings.SAVE_PATH
var panel: PanelContainer
var tabs: TabContainer
var rows: Dictionary = {}
var readout: Label
var status: Label
var saved_values: Dictionary = {}
var flash_left := 0.0
var syncing := false
var save_button: Button
var reset_button: Button
var load_button: Button
var pointer_position := Vector2.ZERO
var fire_mode_selector: OptionButton
var camera_limits_toggle: CheckButton
var export_button: Button
var import_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	pointer_position = get_viewport().get_mouse_position()
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color","Label",Color("d3dfe3"))
	ui_theme.set_stylebox("normal","Button",_style(Color("334551"),8))
	ui_theme.set_stylebox("hover","Button",_style(Color("465d6b"),8))
	ui_theme.set_stylebox("pressed","Button",_style(Color("273742"),8))
	theme = ui_theme
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(Color(.075,.115,.15,.97),14))
	panel.size = Vector2(530,700)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",6)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label(heading_text,19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("Закрыть",toggle))
	content.add_child(_label(help_text,15))
	if settings is CoreShootingSettings:
		var mode_row := HBoxContainer.new()
		content.add_child(mode_row)
		var mode_label := _label("Режим огня · B",16)
		mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_row.add_child(mode_label)
		fire_mode_selector = OptionButton.new()
		fire_mode_selector.focus_mode = Control.FOCUS_NONE
		fire_mode_selector.add_item("Автоматический")
		fire_mode_selector.add_item("Одиночный")
		fire_mode_selector.item_selected.connect(_change_fire_mode)
		mode_row.add_child(fire_mode_selector)
	if settings is CoreCameraSettings:
		camera_limits_toggle = CheckButton.new()
		camera_limits_toggle.text = "Учитывать края уровня по горизонтали"
		camera_limits_toggle.focus_mode = Control.FOCUS_NONE
		camera_limits_toggle.toggled.connect(_change_camera_limits)
		content.add_child(camera_limits_toggle)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 320
	tabs.set_tab_focus_mode(Control.FOCUS_NONE)
	content.add_child(tabs)
	for group in groups:
		var scroll := ScrollContainer.new()
		scroll.name = group
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.focus_mode = Control.FOCUS_NONE
		tabs.add_child(scroll)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation",6)
		scroll.add_child(box)
		if settings is CoreMovementSettings and group == "Склоны":
			var hint := _label("Множители от скорости бега: 1× — обычный темп.\nЭффект плавно растёт между заданными углами.\nПрименяется к бегу; дэш и лестница сохраняют свой темп.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		for param in params:
			if param[6] == group: _add_row(box,param)
	readout = _label("",16)
	readout.add_theme_color_override("font_color",Color("91c6de"))
	content.add_child(readout)
	tabs.tab_changed.connect(func(_index: int): _update_readout())
	content.add_child(_label("Числа — точный ввод. Enter — закончить ввод.",14))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation",6)
	content.add_child(buttons)
	save_button = _button("Сохранить",save_profile)
	load_button = _button("Загрузить",load_profile)
	reset_button = _button("Сброс",reset_profile)
	for button in [save_button,load_button,reset_button,_button("Копировать",copy_profile)]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	var file_buttons := HBoxContainer.new()
	file_buttons.add_theme_constant_override("separation",6)
	content.add_child(file_buttons)
	export_button = _button("Экспорт в файл",func(): export_requested.emit())
	import_button = _button("Импорт из файла",func(): import_requested.emit())
	for button in [export_button,import_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "Все настройки: движение, стрельба, камера и зомби"
		file_buttons.add_child(button)
	status = _label("",14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 38
	content.add_child(status)
	saved_values = settings.as_dictionary()
	resized.connect(_layout_panel)
	_layout_panel()
	_sync()

func _style(color: Color,margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("526977")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(margin)
	return style

func _label(text: String,font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _button(text: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _add_row(parent: VBoxContainer,param: Array) -> void:
	var key: String = param[0]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",2)
	parent.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var label := _label(param[1],15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	var number := SpinBox.new()
	number.min_value = param[2]
	number.max_value = param[3]
	number.step = param[4]
	number.suffix = param[5]
	number.custom_minimum_size.x = 145
	number.value_changed.connect(_change_value.bind(key))
	number.get_line_edit().text_submitted.connect(_finish_editing)
	heading.add_child(number)
	var slider := HSlider.new()
	slider.min_value = param[2]
	slider.max_value = param[3]
	slider.step = param[4]
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.y = 18
	slider.value_changed.connect(_change_value.bind(key))
	box.add_child(slider)
	rows[key] = {"slider":slider,"number":number}

func _layout_panel() -> void:
	if not panel: return
	panel.position = Vector2(maxf(12,size.x-552),148)
	panel.size = Vector2(530,maxf(500,minf(700,size.y-168)))
	if readout and settings is CoreCameraSettings: _update_readout()

func toggle() -> void:
	_finish_editing("")
	visible = not visible
	if visible: _sync()

func blocks_gameplay_input() -> bool:
	return visible and get_viewport().gui_get_focus_owner() is LineEdit

func blocks_mouse_input() -> bool:
	return visible and (blocks_gameplay_input() or panel.get_global_rect().has_point(pointer_position))

func _finish_editing(_text: String) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		for row in rows.values():
			if row.number.get_line_edit() == focus:
				row.number.apply()
				break
		focus.release_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_position = event.position
	if blocks_gameplay_input() and event.is_action_pressed("core_pause"):
		_finish_editing("")
		get_viewport().set_input_as_handled()

func _change_value(value: float,key: String) -> void:
	if syncing: return
	settings.set_parameter(key,value)
	_sync()
	settings_changed.emit()
	flash_left = 0

func _change_fire_mode(index: int) -> void:
	settings.set_fire_mode(index)
	_sync()
	flash_left = 0

func _change_camera_limits(enabled: bool) -> void:
	if syncing: return
	settings.limit_to_level = enabled
	_sync()
	flash_left = 0

func _sync() -> void:
	syncing = true
	if fire_mode_selector: fire_mode_selector.select(settings.fire_mode)
	if camera_limits_toggle: camera_limits_toggle.set_pressed_no_signal(settings.limit_to_level)
	for key in rows:
		rows[key].slider.set_value_no_signal(settings.get(key))
		rows[key].number.set_value_no_signal(settings.get(key))
	syncing = false
	_update_readout()
	_update_status()

func _update_readout() -> void:
	if settings is CoreZombieSettings:
		match tabs.get_tab_title(tabs.current_tab):
			"Зрение": readout.text = "Сектор: %.0f° · Обнаружение: %.0f px\nСмещение X: %.0f px · X+ вперёд, X− назад\nF1 — сектор и слух; со спины может услышать." % [settings.vision_angle,settings.detection_range,settings.vision_offset_x]
			"Слух": readout.text = "Шаги: %.0f px · выстрел: %.0f px\nДэш: %.0f px · через преграду: %.0f%%\nШум запоминается на %.1f с; 0 px — глухой." % [settings.hearing_range*settings.movement_noise_multiplier,settings.hearing_range*settings.shot_noise_multiplier,settings.hearing_range*settings.movement_noise_multiplier*2,settings.noise_occlusion_multiplier*100,settings.noise_memory_time]
			"Движение": readout.text = "Патруль: ±%.0f px от исходной точки\nС одной ногой: патруль %.0f · погоня %.0f px/с\nБез обеих ног: %.0f px/с, пока есть руки" % [settings.patrol_radius,settings.patrol_speed*.55,settings.chase_speed*.55,settings.crawl_speed]
			"Бой": readout.text = "Удар: %.0f HP · одной рукой: %.2f HP\nЦикл атаки: %.2f с · дальность %.0f px\nПрочность конечностей — F4 → «Урон»." % [settings.attack_damage,settings.attack_damage*.65,settings.attack_windup+settings.attack_recovery,settings.attack_range]
		return
	if settings is CoreCameraSettings:
		readout.text = "Масштаб: %.2f× · Видимая ширина ≈ %.0f px\nX+: камера правее героя · Y+: ниже\nСкорость слежения 0 — без сглаживания" % [settings.zoom,get_viewport_rect().size.x/settings.zoom]
		return
	if settings is CoreShootingSettings:
		readout.text = "От бедра: %.1f–%.1f° · Темп: %.0f/мин\nСкорость очереди: %.0f%% · В прицеле: %.0f%%" % [settings.hip_spread,settings.hip_max_spread,settings.rounds_per_minute,settings.hip_move_multiplier*100,settings.ads_move_multiplier*100]
		if tabs.get_tab_title(tabs.current_tab) == "Урон":
			readout.text = "Урон: голова %.1f · корпус %.1f HP\nРуки %.1f · ноги %.1f HP в здоровье\nОтрыв: рука %.0f · нога %.0f базового урона\nПрочность снимается без множителя зоны." % [settings.damage*settings.head_damage_multiplier,settings.damage*settings.torso_damage_multiplier,settings.damage*settings.arm_damage_multiplier,settings.damage*settings.leg_damage_multiplier,settings.arm_durability,settings.leg_durability]
		return
	var height: float = settings.jump_speed*settings.jump_speed/(2*settings.gravity)
	var distance: float = settings.dash_speed*settings.dash_duration
	var braking: float = settings.run_speed*settings.run_speed/(2*settings.braking)
	readout.text = "Прыжок ≈ %.0f px · Дэш ≈ %.0f px\nРазгон ≈ %.2f с · Тормозной путь ≈ %.0f px" % [height,distance,settings.run_speed/settings.acceleration,braking]
	if tabs.get_tab_title(tabs.current_tab) == "Склоны":
		readout.text = "Скорость по поверхности, без стрельбы:\n20°: вверх ≈ %.0f · вниз ≈ %.0f px/с\n35°: вверх ≈ %.0f · вниз ≈ %.0f px/с\nЗамедление от стрельбы умножается на эти скорости." % [settings.run_speed*settings.slope_multiplier(20,true),settings.run_speed*settings.slope_multiplier(20,false),settings.run_speed*settings.slope_multiplier(35,true),settings.run_speed*settings.slope_multiplier(35,false)]

func _update_status() -> void:
	if flash_left > 0: return
	status.text = "Изменения не сохранены" if settings.as_dictionary() != saved_values else current_values_text

func _process(delta: float) -> void:
	if not visible: return
	flash_left = maxf(0,flash_left-delta)
	_update_status()

func _flash(message: String) -> void:
	status.text = message
	flash_left = 3.5

func save_profile() -> void:
	_finish_editing("")
	var result: int = settings.save_saved(settings_path)
	if result == OK:
		saved_values = settings.as_dictionary()
		_flash("Сохранено. Эти значения загрузятся при следующем запуске.")
	else: _flash("Не удалось сохранить (%d)" % result)

func load_profile() -> void:
	_finish_editing("")
	var result: int = settings.load_saved(settings_path)
	if result == OK:
		saved_values = settings.as_dictionary()
		_sync()
		settings_changed.emit()
		_flash("Сохранённые значения загружены")
	else: _flash("Сохранённого профиля пока нет" if result == ERR_FILE_NOT_FOUND else "Не удалось загрузить (%d)" % result)

func reset_profile() -> void:
	_finish_editing("")
	settings.apply_values(defaults.as_dictionary())
	_sync()
	settings_changed.emit()
	_flash("Базовые значения восстановлены. Сохраните, чтобы оставить их.")

func copy_profile() -> void:
	DisplayServer.clipboard_set(settings.as_text())
	_flash("Значения скопированы")
