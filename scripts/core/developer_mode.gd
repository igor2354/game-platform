class_name CoreDeveloperMode
extends Control
## One modeless workspace for all runtime balance settings and test tools.
var lab: Node
var enabled := false
var current_section := 0
var current_player_tab := 0
var player_tabs: TabContainer
var panel: PanelContainer
var pages: Control
var tools_page: VBoxContainer
var tools_scroll: ScrollContainer
var invulnerable_toggle: CheckButton
var health_number: SpinBox
var health_slider: HSlider
var heal_button: Button
var health_readout: Label
var syncing_health := false
var enemy_tools: CoreEnemyTools
var ammo_button: Button
var navigation: Array[Button] = []
var debug_toggle: CheckButton
var telemetry_toggle: CheckButton
var pause_button: Button
var reset_button: Button
var zombie_button: Button
var save_button: Button
var load_button: Button
var defaults_button: Button
var export_button: Button
var import_button: Button
var close_button: Button
var status: Label
enum Section { PLAYER, ZOMBIE, TESTING, PHYSICS }
const SECTIONS := ["Игрок","Зомби","Тестирование","Физика"]
const OVERLAY_SECTIONS := [Section.PLAYER,Section.PLAYER,Section.PLAYER,Section.ZOMBIE,Section.PHYSICS,Section.PLAYER]
const OVERLAY_NAMES := ["Движение","Стрельба и урон","Камера и визуал","Зомби","Физика","Здоровье"]
const PLAYER_OVERLAYS := [0,1,2,5]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = lab.movement_overlay.theme
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",lab.movement_overlay._style(Color(.065,.10,.13,.98),12))
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label("РЕЖИМ РАЗРАБОТЧИКА · F2",21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = _button("Закрыть",func(): set_enabled(false))
	heading.add_child(close_button)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	save_button = _button("Сохранить всё",save_all)
	load_button = _button("Загрузить всё",load_all)
	defaults_button = _button("Сбросить всё",reset_all)
	export_button = _button("Экспорт JSON",func(): lab._open_settings_dialog(true))
	import_button = _button("Импорт JSON",func(): lab._open_settings_dialog(false))
	for button in [save_button,load_button,defaults_button,export_button,import_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 172
	body.add_child(sidebar)
	for index in SECTIONS.size():
		var button := _button(SECTIONS[index],show_section.bind(index))
		button.toggle_mode = true
		sidebar.add_child(button)
		navigation.append(button)
	var hint := _label("F3 — движение\nF4 — стрельба\nF5 — камера\nF6 — зомби\nF1 — зоны\nF7 — возродить врагов\nF9 — к зомби\nF10 — к солдату\n\nПравки — сразу.\nПауза — в тестировании.\n\nЧисла: точный ввод.\nEnter: закончить ввод.",14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(hint)
	pages = MarginContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	player_tabs = TabContainer.new()
	player_tabs.set_tab_focus_mode(Control.FOCUS_NONE)
	pages.add_child(player_tabs)
	for index in lab._ui_overlays().size():
		var overlay: CoreMovementOverlay = lab._ui_overlays()[index]
		if OVERLAY_SECTIONS[index] == Section.PLAYER:
			# The container owns tab visibility; the original panels retain their
			# own visibility and input gating inside stable page wrappers.
			var page := MarginContainer.new()
			page.name = OVERLAY_NAMES[index]
			player_tabs.add_child(page)
			overlay.panel.reparent(page)
			# Reserve one row for Player navigation. The existing parameter
			# lists remain scrollable and all profile actions stay on screen.
			overlay.tabs.custom_minimum_size.y = 200
		else:
			overlay.panel.reparent(pages)
		overlay.panel.hide()
		overlay.toggle_requested.connect(toggle_overlay.bind(index))
	player_tabs.tab_changed.connect(_player_tab_changed)
	tools_scroll = ScrollContainer.new()
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(tools_scroll)
	tools_page = VBoxContainer.new()
	tools_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_page.add_theme_constant_override("separation",12)
	tools_scroll.add_child(tools_page)
	tools_page.add_child(_label("ИНСТРУМЕНТЫ ТЕСТИРОВАНИЯ",19))
	var description := _label("Управляйте тестовой площадкой без изменения баланса.\nF1 — зоны; F7 — возродить врагов; F9 — к зомби.",16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_page.add_child(description)
	var health_box: VBoxContainer = lab.health_overlay.tabs.get_tab_control(0).get_child(0)
	var health_tools := VBoxContainer.new()
	health_tools.add_theme_constant_override("separation",6)
	health_box.add_child(health_tools)
	invulnerable_toggle = CheckButton.new()
	invulnerable_toggle.text = "Бессмертие героя"
	invulnerable_toggle.tooltip_text = "Блокирует урон, сохраняя физические толчки. Не записывается в профили и JSON."
	invulnerable_toggle.focus_mode = Control.FOCUS_NONE
	invulnerable_toggle.toggled.connect(func(value: bool):
		_prepare_action()
		lab.player.set_invulnerable(value)
		_sync_health())
	health_tools.add_child(invulnerable_toggle)
	var health_row := HBoxContainer.new()
	health_tools.add_child(health_row)
	var health_label := _label("Текущие HP героя",16)
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_label)
	health_number = SpinBox.new()
	health_number.min_value = 0
	health_number.max_value = lab.player.maximum_health()
	health_number.step = .01
	health_number.suffix = "HP"
	health_number.custom_minimum_size.x = 150
	health_number.value_changed.connect(_change_health)
	health_number.get_line_edit().text_submitted.connect(func(_text: String): finish_health_edit())
	health_row.add_child(health_number)
	health_slider = HSlider.new()
	health_slider.min_value = 0
	health_slider.max_value = lab.player.maximum_health()
	health_slider.step = .01
	health_slider.focus_mode = Control.FOCUS_NONE
	health_slider.value_changed.connect(_change_health)
	health_tools.add_child(health_slider)
	health_readout = _label("",14)
	health_tools.add_child(health_readout)
	heal_button = _button("Полностью восстановить HP",func():
		_prepare_action()
		lab.player.set_current_health(lab.player.maximum_health())
		_sync_health())
	health_tools.add_child(heal_button)
	ammo_button = _button("Пополнить боеприпасы",func():
		_prepare_action()
		lab.player.weapon.refill_ammunition())
	tools_page.add_child(ammo_button)
	enemy_tools = CoreEnemyTools.new()
	enemy_tools.lab = lab
	tools_page.add_child(enemy_tools)
	pause_button = _button("Пауза",func():
		_prepare_action()
		get_tree().paused = not get_tree().paused)
	reset_button = _button("Вернуть героя на старт · F8",func():
		_prepare_action()
		lab._recover())
	zombie_button = _button("Перейти к зоне зомби · F9",func():
		_prepare_action()
		lab._teleport_zombie())
	for button in [pause_button,reset_button,zombie_button]: tools_page.add_child(button)
	tools_page.add_child(_button("К новому зомби-солдату · F10",func():
		_prepare_action()
		lab._teleport_player(CoreMovementLevel.CONCEPT_ZOMBIE_TEST_SPAWN)))
	lab.respawn_enemies_button.reparent(tools_page)
	lab.respawn_enemies_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	lab.respawn_enemies_button.custom_minimum_size.y = 38
	lab.respawn_enemies_button.show()
	debug_toggle = CheckButton.new()
	debug_toggle.text = "Зоны попаданий, коллизии, зрение и слух · F1"
	debug_toggle.focus_mode = Control.FOCUS_NONE
	debug_toggle.toggled.connect(func(_value: bool): _apply_debug())
	tools_page.add_child(debug_toggle)
	telemetry_toggle = CheckButton.new()
	telemetry_toggle.text = "Телеметрия движения и стрельбы"
	telemetry_toggle.focus_mode = Control.FOCUS_NONE
	telemetry_toggle.button_pressed = true
	telemetry_toggle.toggled.connect(func(_value: bool): _apply_debug())
	tools_page.add_child(telemetry_toggle)
	status = _label("Все разделы используют текущие настройки игры. Профили и JSON совместимы.",14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	resized.connect(_layout)
	_layout()
	# Initial construction is not a UI click: do not suppress the first shot.
	hide()
	_apply_debug()
	_sync_health()

func _label(text: String,font_size: int) -> Label:
	return lab.movement_overlay._label(text,font_size)
func _button(text: String,callback: Callable) -> Button:
	return lab.movement_overlay._button(text,callback)
func _layout() -> void:
	if not panel: return
	panel.position = Vector2(maxf(12,size.x-936),140)
	panel.size = Vector2(minf(924,size.x-24),maxf(540,size.y-156))
func _prepare_action() -> void:
	for overlay in lab._ui_overlays(): overlay._finish_editing("")
	finish_health_edit()
	lab.suppress_mouse_until_release = true
	lab.player.weapon.queued_single_press = false
	lab.player.jump_buffer = 0
	lab.player.dash_held = Input.is_action_pressed("core_dash")
func set_enabled(value: bool) -> void:
	_prepare_action()
	enabled = value
	visible = value
	for overlay in lab._ui_overlays():
		overlay.hide()
		overlay.panel.hide()
	if enabled: show_section(current_section)
	_apply_debug()
func toggle() -> void: set_enabled(not enabled)
func toggle_overlay(index: int) -> void:
	if enabled and current_section == OVERLAY_SECTIONS[index] and (current_section != Section.PLAYER or current_player_tab == PLAYER_OVERLAYS.find(index)):
		set_enabled(false)
	else:
		show_overlay(index)
		if not enabled: set_enabled(true)
func show_overlay(index: int) -> void:
	_prepare_action()
	if OVERLAY_SECTIONS[index] == Section.PLAYER:
		current_player_tab = PLAYER_OVERLAYS.find(index)
		player_tabs.set_current_tab(current_player_tab)
	show_section(OVERLAY_SECTIONS[index])
func _player_tab_changed(index: int) -> void:
	_prepare_action()
	current_player_tab = index
	_refresh_pages()
func toggle_section(index: int) -> void:
	if enabled and current_section == index:
		set_enabled(false)
	else:
		current_section = index
		set_enabled(true)
func show_section(index: int) -> void:
	_prepare_action()
	current_section = clampi(index,0,SECTIONS.size()-1)
	_refresh_pages()
func _refresh_pages() -> void:
	player_tabs.visible = enabled and current_section == Section.PLAYER
	for i in lab._ui_overlays().size():
		var overlay: CoreMovementOverlay = lab._ui_overlays()[i]
		overlay.visible = enabled and OVERLAY_SECTIONS[i] == current_section
		if current_section == Section.PLAYER: overlay.visible = overlay.visible and i == PLAYER_OVERLAYS[current_player_tab]
		overlay.panel.visible = overlay.visible
		if overlay.visible: overlay._sync()
	tools_page.visible = enabled and current_section == Section.TESTING
	tools_scroll.visible = tools_page.visible
	for i in navigation.size(): navigation[i].set_pressed_no_signal(i == current_section)
	_layout()
func toggle_debug() -> void:
	debug_toggle.button_pressed = not debug_toggle.button_pressed
func _apply_debug() -> void:
	# Debug geometry is an independent test overlay, not the settings window.
	lab.player.debug_shape = debug_toggle.button_pressed
	lab.player.queue_redraw()
	if lab.level.forest: lab.level.forest.set_debug_geometry(debug_toggle.button_pressed)
	for enemy in lab.level.enemies:
		enemy.debug_zones = lab.player.debug_shape
		enemy.queue_redraw()
	for load_fixture in lab.level.hanging_loads:
		load_fixture.debug_shapes = lab.player.debug_shape
		load_fixture.queue_redraw()
		load_fixture.body.queue_redraw()
	lab.telemetry.visible = telemetry_toggle.button_pressed
	lab.shooting_telemetry.visible = telemetry_toggle.button_pressed
func blocks_mouse_input(point: Vector2) -> bool:
	return enabled and panel.get_global_rect().has_point(point)
func blocks_keyboard_input() -> bool:
	return enabled and ((health_number != null and get_viewport().gui_get_focus_owner() == health_number.get_line_edit()) or (enemy_tools != null and enemy_tools.blocks_keyboard_input()))
func finish_health_edit() -> void:
	if enemy_tools: enemy_tools.finish_editing()
	if not health_number: return
	var field := health_number.get_line_edit()
	if get_viewport().gui_get_focus_owner() == field:
		health_number.apply()
		field.release_focus()
func _change_health(value: float) -> void:
	if syncing_health: return
	lab.suppress_mouse_until_release = true
	lab.player.set_current_health(value)
	_sync_health()
func _sync_health() -> void:
	if not health_number: return
	syncing_health = true
	invulnerable_toggle.set_pressed_no_signal(lab.player.invulnerable)
	health_slider.max_value = lab.player.maximum_health()
	health_slider.set_value_no_signal(lab.player.health)
	if not blocks_keyboard_input():
		health_number.max_value = lab.player.maximum_health()
		health_number.set_value_no_signal(lab.player.health)
	health_readout.text = "HP: %.2f / %.0f" % [lab.player.health,lab.player.maximum_health()]
	syncing_health = false
func _input(event: InputEvent) -> void:
	if blocks_keyboard_input() and event.is_action_pressed("core_pause"):
		finish_health_edit()
		get_viewport().set_input_as_handled()
func save_all() -> void:
	_prepare_action()
	var failures: Array[String] = []
	for i in lab._overlays().size():
		var overlay: CoreMovementOverlay = lab._overlays()[i]
		var result: int = overlay.settings.save_saved(overlay.settings_path)
		if result == OK:
			overlay.saved_values = overlay.settings.as_dictionary()
			overlay._flash("Профиль раздела сохранён.")
		else: failures.append(OVERLAY_NAMES[i])
	status.text = "Все профили сохранены для следующих запусков." if failures.is_empty() else "Не удалось сохранить: "+", ".join(failures)
func load_all() -> void:
	_prepare_action()
	var candidates: Array[Resource] = []
	var loaded_sections: Array[bool] = []
	var loaded := 0
	for i in lab._overlays().size():
		var overlay: CoreMovementOverlay = lab._overlays()[i]
		var candidate: Resource = overlay.settings.duplicate()
		var result: int = candidate.load_saved(overlay.settings_path)
		if result != OK and result != ERR_FILE_NOT_FOUND:
			status.text = "Ошибка загрузки раздела «%s» (%d). Настройки не изменены." % [OVERLAY_NAMES[i],result]
			return
		if result == OK: loaded += 1
		candidates.append(candidate)
		loaded_sections.append(result == OK)
	for i in candidates.size():
		var overlay: CoreMovementOverlay = lab._overlays()[i]
		overlay.settings.apply_values(candidates[i].as_dictionary())
		if loaded_sections[i]: overlay.saved_values = overlay.settings.as_dictionary()
		overlay._sync()
		overlay.settings_changed.emit()
	lab._update_camera(true)
	status.text = "Загружено профилей: %d из %d. Разделы без файла сохранены без изменений." % [loaded,lab._overlays().size()]
func reset_all() -> void:
	_prepare_action()
	for overlay in lab._overlays(): overlay.reset_profile()
	lab._update_camera(true)
	status.text = "Восстановлен базовый баланс всех разделов. Сохранённые файлы не перезаписаны."
func _process(_delta: float) -> void:
	if not enabled: return
	_sync_health()
	enemy_tools.sync()
	# Wrapped labels can temporarily grow a container before its width is
	# assigned. Reapply the viewport bounds after that layout has settled.
	_layout()
	pause_button.text = "Продолжить игру" if get_tree().paused else "Пауза"
