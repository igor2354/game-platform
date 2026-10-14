class_name CoreMovementOverlay
extends Control

signal export_requested
signal import_requested
signal settings_changed
signal toggle_requested

var settings: Resource
var defaults: Resource
var params: Array = CoreMovementSettings.PARAMS
var groups := ["Бег","Прыжок","Дэш","Лестница","Склоны","Приседание","Спринт","Подкат","Ходьба","Движение задом","Разгон","Здоровье"]
var heading_text := "НАСТРОЙКА ДВИЖЕНИЯ · F3"
var help_text := "Изменения применяются сразу. Проверяйте на площадке."
var current_values_text := "Текущие значения · новые тайминги со следующего действия"
var settings_path := CoreMovementSettings.SAVE_PATH
var panel: PanelContainer
var tabs: TabContainer
var rows: Dictionary = {}
var acceleration_preview: CoreAccelerationPreview
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
var character_filter_toggle: CheckButton
var camera_limits_toggle: CheckButton
var damage_reaction_toggle: CheckButton
var zombie_toggles: Dictionary = {}
var slide_knockdown_toggle: CheckButton
var air_dash_toggle: CheckButton
var export_button: Button
var import_button: Button
var hosted := false

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
	if not hosted: heading.add_child(_button("Закрыть",toggle))
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
	tabs.custom_minimum_size.y = 240 if hosted else 320
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
		if settings is CoreCameraSettings and group == "Визуал":
			character_filter_toggle = CheckButton.new()
			character_filter_toggle.text = "Сглаживание спрайта тела"
			character_filter_toggle.focus_mode = Control.FOCUS_NONE
			character_filter_toggle.toggled.connect(_change_character_filter)
			box.add_child(character_filter_toggle)
			var hint := _label("Для тестов: интенсивность 0 и сглаживание выключено.\nБлюр затрагивает тело, руки и оружие героя.\nПрицел, интерфейс и окружение остаются чёткими.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreMovementSettings and group == "Разгон":
			var hint := _label("0 с — прежний линейный отклик; выше — мягче.\nУскорение плавно включается и сходит к нулю у цели.\nТемп: «Бег → Разгон» / «Ходьба → Разгон ходьбы».",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
			acceleration_preview = CoreAccelerationPreview.new()
			acceleration_preview.settings = settings
			acceleration_preview.custom_minimum_size = Vector2(0,170)
			acceleration_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(acceleration_preview)
		if settings is CoreMovementSettings and group == "Здоровье":
			var hint := _label("Запас HP при возрождении героя; сохраняется в профиле и JSON.\nУменьшение ограничивает текущие HP, увеличение не лечит.\nТекущие HP, лечение и бессмертие — в «Тестировании».",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreMovementSettings and group == "Склоны":
			var hint := _label("Множители от скорости движения: 1× — обычный темп.\nВлияет на ходьбу, бег и спринт; лестница — без изменений.\nПараметры дэша на склонах находятся во вкладке «Дэш».",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreMovementSettings and group == "Дэш":
			air_dash_toggle = CheckButton.new()
			air_dash_toggle.text = "Дэш в воздухе"
			air_dash_toggle.tooltip_text = "Выключено: начать дэш можно только с земли. Уже начатый дэш завершится по своему таймеру."
			air_dash_toggle.focus_mode = Control.FOCUS_NONE
			air_dash_toggle.toggled.connect(_change_air_dash)
			box.add_child(air_dash_toggle)
		if settings is CoreMovementSettings and group == "Спринт":
			var hint := _label("Shift — спринт; Alt — дэш.\nЗапас восстанавливается при обычном движении и отдыхе.\nПосле истощения нужен полный запас.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreMovementSettings and group == "Движение задом":
			var hint := _label("Назад относительно курсора: 1× — полный темп.\nСтрельба и склоны дополнительно меняют скорость.\nСпринт разворачивает героя по направлению движения.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreMovementSettings and group == "Подкат":
			var hint := _label("C — новое нажатие во время спринта.\nНачальная скорость — множитель от фактического разгона.\nОдин удар по каждому врагу за подкат.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreZombieSettings:
			for entry in CoreZombieSettings.SWITCHES:
				if entry[2] != group: continue
				var switch := CheckButton.new()
				switch.text = entry[1]
				switch.tooltip_text = entry[3]
				switch.focus_mode = Control.FOCUS_NONE
				switch.toggled.connect(_change_zombie_switch.bind(entry[0]))
				box.add_child(switch)
				zombie_toggles[entry[0]] = switch
				if entry[0] == "damage_reaction_enabled": damage_reaction_toggle = switch
		if settings is CoreZombieSettings and group == "Ползание":
			var hint := _label("При потере ноги: угол — склон, высота — ступень.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		if settings is CoreZombieSettings and group == "Попадания":
			var hint := _label("Множитель — к погоне и ползанию до обнаружения.\nУвидев игрока, использует обычную скорость.\nЗрение и слух работают независимо от переключателя.",14)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(hint)
		for param in params:
			if param[6] != group: continue
			if settings is CoreMovementSettings and param[0] == "dash_uphill_multiplier":
				_add_section(box,"Наклонные поверхности","Множители от скорости дэша; 1× — обычный темп.\nСобственные углы; на ровном полу и в воздухе — базовая скорость.")
			if settings is CoreMovementSettings and param[0] == "slide_knockdown_chance":
				_add_section(box,"Сбивание врагов","Отключение сбивания сохраняет урон подката.")
				slide_knockdown_toggle = CheckButton.new()
				slide_knockdown_toggle.text = "Сбивать врага с ног"
				slide_knockdown_toggle.tooltip_text = "Отключение сохраняет урон. Враг, которого не сбило, останавливает подкат. Уже начавшееся падение завершится по своему таймеру."
				slide_knockdown_toggle.focus_mode = Control.FOCUS_NONE
				slide_knockdown_toggle.toggled.connect(_change_slide_knockdown)
				box.add_child(slide_knockdown_toggle)
			_add_row(box,param)
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
	file_buttons.visible = not hosted
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

func _add_section(parent: VBoxContainer,title: String,hint: String) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_label(title,17))
	var label := _label(hint,14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

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
	if hosted: return
	panel.position = Vector2(maxf(12,size.x-552),148)
	panel.size = Vector2(530,maxf(500,minf(700,size.y-168)))
	if readout and settings is CoreCameraSettings: _update_readout()

func toggle() -> void:
	_finish_editing("")
	if hosted:
		toggle_requested.emit()
		return
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
				focus.release_focus()
				return

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

func _change_character_filter(enabled: bool) -> void:
	if syncing: return
	settings.character_linear_filter = enabled
	_sync()
	flash_left = 0

func _change_camera_limits(enabled: bool) -> void:
	if syncing: return
	settings.limit_to_level = enabled
	_sync()
	flash_left = 0

func _change_damage_reaction(enabled: bool) -> void:
	_change_zombie_switch(enabled,"damage_reaction_enabled")

func _change_zombie_switch(enabled: bool,key: String) -> void:
	if syncing: return
	settings.set(key,enabled)
	_sync()
	settings_changed.emit()
	flash_left = 0

func _change_air_dash(enabled: bool) -> void:
	if syncing: return
	settings.air_dash_enabled = enabled
	_sync()
	settings_changed.emit()
	flash_left = 0

func _change_slide_knockdown(enabled: bool) -> void:
	if syncing: return
	settings.slide_knockdown_enabled = enabled
	_sync()
	settings_changed.emit()
	flash_left = 0

func _sync() -> void:
	syncing = true
	if fire_mode_selector: fire_mode_selector.select(settings.fire_mode)
	if camera_limits_toggle: camera_limits_toggle.set_pressed_no_signal(settings.limit_to_level)
	if character_filter_toggle: character_filter_toggle.set_pressed_no_signal(settings.character_linear_filter)
	for key in zombie_toggles: zombie_toggles[key].set_pressed_no_signal(settings.get(key))
	if slide_knockdown_toggle: slide_knockdown_toggle.set_pressed_no_signal(settings.slide_knockdown_enabled)
	if air_dash_toggle: air_dash_toggle.set_pressed_no_signal(settings.air_dash_enabled)
	for key in rows:
		rows[key].slider.set_value_no_signal(settings.get(key))
		rows[key].number.set_value_no_signal(settings.get(key))
	syncing = false
	_update_readout()
	_update_status()

func _update_readout() -> void:
	if acceleration_preview: acceleration_preview.queue_redraw()
	if settings is CoreZombieSettings:
		match tabs.get_tab_title(tabs.current_tab):
			"Зрение": readout.text = "Сектор: %.0f° · Обнаружение: %.0f px\nСмещение X: %.0f px · X+ вперёд, X− назад\nF1 — сектор и слух; со спины может услышать." % [settings.vision_angle,settings.detection_range,settings.vision_offset_x]
			"Слух": readout.text = "Шаги: %.0f px · выстрел: %.0f px\nДэш: %.0f px · через преграду: %.0f%%\nШум запоминается на %.1f с; 0 px — глухой." % [settings.hearing_range*settings.movement_noise_multiplier,settings.hearing_range*settings.shot_noise_multiplier,settings.hearing_range*settings.movement_noise_multiplier*2,settings.noise_occlusion_multiplier*100,settings.noise_memory_time]
			"Движение": readout.text = "Патруль: ±%.0f px · скорость %.0f px/с\nПогоня: %.0f px/с\nПотеря любой ноги: падение и ползание %.0f px/с\nЛёжа реагирует на игрока, шум и попадания." % [settings.patrol_radius,settings.patrol_speed,settings.chase_speed,settings.crawl_speed]
			"Попадания": readout.text = "Реакция на урон: %s · память %.1f с\nК источнику: %.1f px/с · лёжа %.1f px/с\nСкорость и сокращение памяти — сразу.\nБольше памяти — со следующего попадания." % ["включена" if settings.damage_reaction_enabled else "выключена",settings.damage_memory_time,settings.chase_speed*settings.damage_chase_multiplier,settings.crawl_speed*settings.damage_chase_multiplier]
			"Ползание":
				var speeds := PackedStringArray()
				for angle in [20.0,35.0]:
					speeds.append("%.0f°: вверх %.1f · вниз %.1f px/с" % [angle,settings.crawl_speed*settings.crawl_slope_multiplier(angle,true),settings.crawl_speed*settings.crawl_slope_multiplier(angle,false)] if angle <= settings.crawl_max_angle else "%.0f°: склон недоступен" % angle)
				readout.text = "По поверхности: " + "\n".join(speeds) + "\nСтупень ≤ %.0f px · ровный пол %.0f px/с" % [settings.crawl_step_height,settings.crawl_speed]
			"Бой": readout.text = "Удар: %.0f HP · одной рукой: %.2f HP\nЦикл атаки: %.2f с · дальность %.0f px\nПрочность конечностей — F4 → «Урон»." % [settings.attack_damage,settings.attack_damage*.65,settings.attack_windup+settings.attack_recovery,settings.attack_range]
			"Сбрасывание": readout.text = "Сброс через %.2f с на лежащем зомби\nТолчок: %.0f в сторону · %.0f вверх px/с\nУрон: %.0f HP · одной рукой: %.1f HP\nБез рук сброса нет. Прыжок/дэш — уклонение." % [settings.shove_delay,settings.shove_speed,settings.shove_lift,settings.shove_damage,settings.shove_damage*.65]
		for entry in CoreZombieSettings.SWITCHES:
			if entry[2] == tabs.get_tab_title(tabs.current_tab) and not settings.get(entry[0]):
				readout.text = "Механика выключена\n"+readout.text
		return
	if settings is CoreCameraSettings:
		if tabs.get_tab_title(tabs.current_tab) == "Визуал":
			readout.text = "Блюр: %.0f%% · радиус до %.0f px экрана\nРастёт со скоростью выше %.0f px/с.\n0× полностью выключает блюр. На паузе блюра нет.\nСглаживание — отдельное смягчение текстуры тела." % [settings.character_blur_strength*100,settings.character_blur_length,settings.character_blur_start_speed]
			return
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
	readout.text = "Прыжок ≈ %.0f px · Дэш ≈ %.0f px\nРазгон ≈ %.2f с · Тормозной путь ≈ %.0f px" % [height,distance,settings.acceleration_time(settings.run_speed,settings.acceleration),braking]
	if tabs.get_tab_title(tabs.current_tab) == "Дэш":
		readout.text = "Дэш в воздухе: %s · Дэш ≈ %.0f px\n%s\n20°: вверх ≈ %.0f · вниз ≈ %.0f px/с\n35°: вверх ≈ %.0f · вниз ≈ %.0f px/с\nДлительность общая: %.2f с; начатый дэш сохраняет её." % ["включён" if settings.air_dash_enabled else "выключен",distance,"Один дэш до приземления, с учётом восстановления." if settings.air_dash_enabled else "Начать дэш можно только с земли.",settings.dash_speed*settings.dash_slope_multiplier(20,true),settings.dash_speed*settings.dash_slope_multiplier(20,false),settings.dash_speed*settings.dash_slope_multiplier(35,true),settings.dash_speed*settings.dash_slope_multiplier(35,false),settings.dash_duration]
	if tabs.get_tab_title(tabs.current_tab) in ["Бег","Спринт"]:
		readout.text = "Бег: %.0f · спринт: %.0f px/с\nПолный прыжок по X: ≈ %.0f / %.0f px\nВысота прыжка общая: ≈ %.0f px\nДальность: полный разгон, без стрельбы и стен." % [settings.run_speed,settings.sprint_speed,settings.jump_range(false),settings.jump_range(true),height]
		if tabs.get_tab_title(tabs.current_tab) == "Спринт":
			readout.text += "\nЗапас %.1f с · полное восстановление %.1f с" % [settings.sprint_duration,settings.sprint_recovery_time]
	if tabs.get_tab_title(tabs.current_tab) == "Ходьба":
		readout.text = "Ctrl — ходьба стоя; C — присед; шум шагов %.0f%%\nРазгон ≈ %.2f с · тормозной путь ≈ %.0f px\nПрыжок по X ≈ %.0f px · высота ≈ %.0f px" % [settings.slow_walk_noise_multiplier*100,settings.acceleration_time(settings.slow_walk_speed,settings.slow_walk_acceleration),settings.slow_walk_speed*settings.slow_walk_speed/(2*settings.slow_walk_braking),settings.slow_walk_jump_range(),height]
	if tabs.get_tab_title(tabs.current_tab) == "Движение задом":
		readout.text = "На ровном полу задом, без стрельбы:\nБег %.0f · ходьба %.0f · присед %.1f px/с\nИтог: скорость × движение задом × стрельба × склон.\nСпринт: %.0f px/с, всегда лицом по движению." % [settings.run_speed*settings.run_backward_multiplier,settings.slow_walk_speed*settings.slow_walk_backward_multiplier,settings.run_speed*settings.crouch_speed_multiplier*settings.crouch_backward_multiplier,settings.sprint_speed]
	if tabs.get_tab_title(tabs.current_tab) == "Разгон":
		readout.text = "Разгон с места на ровном полу, без стрельбы:\nБег ≈ %.2f с · спринт ≈ %.2f с · ходьба ≈ %.2f с\nПлавность общая; темп у бега и ходьбы раздельный.\nГрафик: скорость по времени; серый — бег при 0 с." % [settings.acceleration_time(settings.run_speed,settings.acceleration),settings.acceleration_time(settings.sprint_speed,settings.acceleration),settings.acceleration_time(settings.slow_walk_speed,settings.slow_walk_acceleration)]
	if tabs.get_tab_title(tabs.current_tab) == "Здоровье":
		readout.text = "Возрождение: %.0f HP\nТекущее здоровье не сохраняется в профиле.\nБессмертие — временный инструмент тестирования." % settings.max_health
	if tabs.get_tab_title(tabs.current_tab) == "Приседание":
		readout.text = "C — удерживать приседание\nВысота: %.0f px · скорость: %.0f px/с\nШум шагов: %.0f%% · стрельба: ЛКМ / ПКМ\nПод низким потолком встать нельзя." % [settings.crouch_height,settings.run_speed*settings.crouch_speed_multiplier,settings.crouch_noise_multiplier*100]
	if tabs.get_tab_title(tabs.current_tab) == "Склоны":
		readout.text = "Скорость по поверхности, без стрельбы:\n20°: вверх ≈ %.0f · вниз ≈ %.0f px/с\n35°: вверх ≈ %.0f · вниз ≈ %.0f px/с\nЗамедление от стрельбы умножается на эти скорости." % [settings.run_speed*settings.slope_multiplier(20,true),settings.run_speed*settings.slope_multiplier(20,false),settings.run_speed*settings.slope_multiplier(35,true),settings.run_speed*settings.slope_multiplier(35,false)]
	if tabs.get_tab_title(tabs.current_tab) == "Подкат":
		var speed: float = settings.sprint_speed*settings.slide_speed_multiplier
		var time: float = minf(settings.slide_duration,speed/settings.slide_braking) if settings.slide_braking > 0 else settings.slide_duration
		readout.text = "С полного спринта: %.0f px/с · путь ≈ %.0f px\nДлительность %.2f с · восстановление %.2f с\nВысота %.0f px · урон %.0f HP от %.0f px/с\nСбивание: %s · шанс %.0f%% · от %.0f px/с\nЛежит: человек %.1f с · зомби %.1f с · толчок %.0f px/с" % [speed,speed*time-settings.slide_braking*time*time*.5,settings.slide_duration,settings.slide_cooldown,settings.slide_height,settings.slide_damage,settings.slide_damage_min_speed,"включено" if settings.slide_knockdown_enabled else "выключено",settings.slide_knockdown_chance*100,settings.slide_knockdown_min_speed,settings.slide_knockdown_duration,settings.slide_zombie_knockdown_duration,settings.slide_knockback_speed]

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
