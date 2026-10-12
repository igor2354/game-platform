class_name CoreMovementLab
extends Node2D

const SettingsFile := preload("res://scripts/core/settings_file.gd")
const SettingsFileDialog := preload("res://scripts/core/settings_file_dialog.gd")

@export var load_user_settings := true
@export var settings_path := CoreMovementSettings.SAVE_PATH
@export var shooting_settings_path := CoreShootingSettings.SAVE_PATH
@export var camera_settings_path := CoreCameraSettings.SAVE_PATH

@onready var level: CoreMovementLevel = $World/Level
@onready var player: CoreMovementPlayer = $World/Player
@onready var camera: Camera2D = $World/Camera
var hud: Label
var telemetry: Label
var notice: Label
var respawns := 0
var movement_overlay: CoreMovementOverlay
var shooting_overlay: CoreMovementOverlay
var camera_overlay: CoreMovementOverlay
var camera_settings: CoreCameraSettings
var camera_applied_values: Dictionary = {}
var camera_was_paused := false
var respawn_enemies_button: Button
var hud_pointer_position := Vector2.ZERO
var shooting_telemetry: Label
var suppress_mouse_until_release := false
var camera_kick := Vector2.ZERO
var camera_shake := 0.0
var camera_phase := 0.0
var settings_dialog: FileDialog
var settings_dialog_open := false
var settings_dialog_exporting := false
var settings_dialog_was_paused := false

func _ready() -> void:
	_setup_input()
	Engine.time_scale = 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.set_default_clear_color(Color("1c252d"))
	player.ladders = level.ladders
	# Keep the editor resource unchanged; overlays edit a runtime copy.
	var defaults := player.tuning.duplicate() as CoreMovementSettings
	defaults.apply_values(defaults.as_dictionary())
	player.tuning = defaults.duplicate() as CoreMovementSettings
	var shooting_defaults := load("res://resources/core/shooting.tres").duplicate() as CoreShootingSettings
	shooting_defaults.apply_values(shooting_defaults.as_dictionary())
	player.weapon.tuning = shooting_defaults.duplicate() as CoreShootingSettings
	for enemy in level.enemies:
		enemy.damage_tuning = player.weapon.tuning
		enemy.posture_changed.connect(player.allow_exit_overlapping_enemies)
	var camera_defaults := load("res://resources/core/camera.tres").duplicate() as CoreCameraSettings
	camera_defaults.apply_values(camera_defaults.as_dictionary())
	camera_settings = camera_defaults.duplicate() as CoreCameraSettings
	if load_user_settings: player.tuning.load_saved(settings_path)
	if load_user_settings: player.weapon.tuning.load_saved(shooting_settings_path)
	if load_user_settings: camera_settings.load_saved(camera_settings_path)
	player.fell.connect(_recover)
	player.weapon.camera_impulse.connect(_camera_impulse)
	player.reset_to(CoreMovementLevel.SPAWN)
	camera.make_current()
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_camera(true)
	_build_hud()
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)
	movement_overlay = CoreMovementOverlay.new()
	movement_overlay.settings = player.tuning
	movement_overlay.defaults = defaults
	movement_overlay.settings_path = settings_path
	overlay_layer.add_child(movement_overlay)
	shooting_overlay = CoreMovementOverlay.new()
	shooting_overlay.settings = player.weapon.tuning
	shooting_overlay.defaults = shooting_defaults
	shooting_overlay.settings_path = shooting_settings_path
	shooting_overlay.params = CoreShootingSettings.PARAMS
	shooting_overlay.groups = ["Оружие","От бедра","Прицел","Отдача","Звук","Урон"]
	shooting_overlay.heading_text = "НАСТРОЙКА СТРЕЛЬБЫ · F4"
	overlay_layer.add_child(shooting_overlay)
	camera_overlay = CoreMovementOverlay.new()
	camera_overlay.settings = camera_settings
	camera_overlay.defaults = camera_defaults
	camera_overlay.settings_path = camera_settings_path
	camera_overlay.params = CoreCameraSettings.PARAMS
	camera_overlay.groups = ["Камера"]
	camera_overlay.heading_text = "НАСТРОЙКА КАМЕРЫ · F5"
	camera_overlay.help_text = "Изменения видны сразу, в том числе на паузе."
	camera_overlay.current_values_text = "Текущие значения камеры"
	overlay_layer.add_child(camera_overlay)
	for overlay in _overlays():
		overlay.export_requested.connect(_open_settings_dialog.bind(true))
		overlay.import_requested.connect(_open_settings_dialog.bind(false))
	_build_settings_dialog(overlay_layer)
	player.input_blocker = _blocks_keyboard
	player.weapon.input_blocker = _blocks_shooting

func _blocks_keyboard() -> bool:
	if settings_dialog_open: return true
	for overlay in _overlays():
		if overlay.blocks_gameplay_input(): return true
	return false

func _overlays() -> Array[CoreMovementOverlay]:
	return [movement_overlay,shooting_overlay,camera_overlay]

func _blocks_shooting() -> bool:
	if suppress_mouse_until_release:
		if Input.is_action_pressed("core_fire") or Input.is_action_pressed("core_aim"): return true
		suppress_mouse_until_release = false
	if _blocks_keyboard(): return true
	if respawn_enemies_button.get_global_rect().has_point(hud_pointer_position): return true
	for overlay in _overlays():
		if overlay.blocks_mouse_input(): return true
	return false

func _setup_input() -> void:
	var bindings := {"core_left":[KEY_A,KEY_LEFT],"core_right":[KEY_D,KEY_RIGHT],"core_up":[KEY_W,KEY_UP],"core_down":[KEY_S,KEY_DOWN],"core_jump":[KEY_SPACE],"core_dash":[KEY_SHIFT],"core_reset":[KEY_R],"core_pause":[KEY_ESCAPE],"core_debug":[KEY_F1],"core_tuner":[KEY_F3],"core_weapon_tuner":[KEY_F4],"core_camera_tuner":[KEY_F5],"core_fire_mode":[KEY_B]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	for action in {"core_fire":MOUSE_BUTTON_LEFT,"core_aim":MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "core_fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,event)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color("16212a")
	panel.size = Vector2(1440,132)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	hud = _label(layer,Vector2(30,15),"КОР ГЕЙМПЛЕЯ · ПЕРЕДВИЖЕНИЕ И СТРЕЛЬБА",27)
	_label(layer,Vector2(30,57),"A/D — бег     Пробел — прыжок     Shift — дэш     W/S — лестница     R — на старт     Esc — пауза",20)
	telemetry = _label(layer,Vector2(30,94),"",18)
	respawn_enemies_button = Button.new()
	respawn_enemies_button.text = "Возродить врагов"
	respawn_enemies_button.tooltip_text = "Восстановить всех врагов, не возвращая героя на старт"
	respawn_enemies_button.focus_mode = Control.FOCUS_NONE
	respawn_enemies_button.add_theme_font_size_override("font_size",18)
	layer.add_child(respawn_enemies_button)
	respawn_enemies_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	respawn_enemies_button.offset_left = -259
	respawn_enemies_button.offset_right = -24
	respawn_enemies_button.offset_top = 16
	respawn_enemies_button.offset_bottom = 58
	respawn_enemies_button.pressed.connect(_respawn_enemies)
	hud_pointer_position = get_viewport().get_mouse_position()
	shooting_telemetry = _label(layer,Vector2(30,813),"",18)
	notice = _label(layer,Vector2(30,850),"ЛКМ — огонь · ПКМ — прицел · B — режим · F3 — движение · F4 — стрельба · F5 — камера · F1 — тело · R — сброс",18)

func _label(parent: Node,point: Vector2,text: String,size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("d3dfe3"))
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if _blocks_keyboard(): return
	if event.is_action_pressed("core_fire") and not get_tree().paused and not _blocks_shooting():
		# Keep short clicks that begin and end between two physics ticks.
		if player.weapon.tuning.fire_mode == CoreShootingSettings.FireMode.SINGLE and player.weapon.cooldown <= 0:
			player.weapon.queued_single_press = true
	if event.is_action_pressed("core_fire_mode") and not event.is_echo():
		player.weapon.tuning.set_fire_mode(1-player.weapon.tuning.fire_mode)
		shooting_overlay._sync()
	if event.is_action_pressed("core_pause"):
		get_tree().paused = not get_tree().paused
	if event.is_action_pressed("core_reset"):
		get_tree().paused = false
		_recover()
	if event.is_action_pressed("core_debug"):
		player.debug_shape = not player.debug_shape
		for enemy in level.enemies:
			enemy.debug_zones = player.debug_shape
			enemy.queue_redraw()
		player.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		hud_pointer_position = event.position
	if settings_dialog_open: return
	if event is InputEventMouseButton and event.pressed:
		if respawn_enemies_button.get_global_rect().has_point(event.position): suppress_mouse_until_release = true
		for overlay in _overlays():
			if overlay.visible and overlay.panel.get_global_rect().has_point(event.position):
				# Closing or dragging off the panel must not turn that click into fire.
				suppress_mouse_until_release = true
	var overlay_actions := {"core_tuner":movement_overlay,"core_weapon_tuner":shooting_overlay,"core_camera_tuner":camera_overlay}
	for action in overlay_actions:
		if event.is_action_pressed(action) and not event.is_echo():
			var selected: CoreMovementOverlay = overlay_actions[action]
			for overlay in _overlays():
				if overlay != selected and overlay.visible: overlay.toggle()
			selected.toggle()
			get_viewport().set_input_as_handled()
			return

func _build_settings_dialog(parent: Node) -> void:
	settings_dialog = SettingsFileDialog.new()
	settings_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_dialog.access = FileDialog.ACCESS_FILESYSTEM
	settings_dialog.filters = PackedStringArray(["*.json ; Настройки игры (JSON)"])
	settings_dialog.min_size = Vector2i(680,420)
	settings_dialog.unresizable = false
	settings_dialog.exclusive = true
	settings_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	parent.add_child(settings_dialog)
	settings_dialog.file_selected.connect(_settings_file_selected)
	settings_dialog.canceled.connect(_close_settings_dialog)
	settings_dialog.close_requested.connect(_close_settings_dialog)

func _open_settings_dialog(exporting: bool) -> void:
	if settings_dialog_open: return
	for overlay in _overlays(): overlay._finish_editing("")
	settings_dialog_was_paused = get_tree().paused
	settings_dialog_exporting = exporting
	settings_dialog_open = true
	get_tree().paused = true
	suppress_mouse_until_release = true
	player.weapon.queued_single_press = false
	settings_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
	settings_dialog.get_ok_button().text = "Сохранить" if exporting else "Открыть"
	settings_dialog.get_cancel_button().text = "Отмена"
	settings_dialog.title = "Экспорт всех настроек" if exporting else "Импорт всех настроек"
	settings_dialog.current_file = "dead-platform-settings.json" if exporting else ""
	settings_dialog.popup_centered_clamped(Vector2i(860,560))
	settings_dialog.get_ok_button().text = "Сохранить" if exporting else "Открыть"

func _close_settings_dialog() -> void:
	if not settings_dialog_open: return
	settings_dialog.hide()
	settings_dialog_open = false
	get_tree().paused = settings_dialog_was_paused
	suppress_mouse_until_release = true
	player.weapon.queued_single_press = false
	player.jump_buffer = 0
	player.dash_held = Input.is_action_pressed("core_dash")

func _settings_file_selected(path: String) -> void:
	if settings_dialog_exporting: export_settings_file(path)
	else: import_settings_file(path)
	settings_dialog.current_dir = path.get_base_dir()
	_close_settings_dialog()

func _settings_resources() -> Dictionary:
	return {"movement":player.tuning,"shooting":player.weapon.tuning,"camera":camera_settings}

func _settings_file_message(message: String) -> void:
	for overlay in _overlays():
		overlay._flash(message)
		overlay.flash_left = 8

func export_settings_file(path: String) -> bool:
	for overlay in _overlays(): overlay._finish_editing("")
	var result := SettingsFile.write_file(path,_settings_resources())
	if result != OK:
		_settings_file_message("Не удалось экспортировать файл (%d)." % result)
		return false
	_settings_file_message("Все настройки экспортированы: %s" % path.get_file())
	return true

func import_settings_file(path: String) -> bool:
	var defaults := {"movement":movement_overlay.defaults,"shooting":shooting_overlay.defaults,"camera":camera_overlay.defaults}
	var result := SettingsFile.read_file(path,defaults)
	if result.has("error"):
		_settings_file_message(result.error)
		return false
	var resources := _settings_resources()
	for section in resources: resources[section].apply_values(result.values[section])
	var saved := true
	for overlay in _overlays():
		var save_result: int = overlay.settings.save_saved(overlay.settings_path)
		if save_result == OK: overlay.saved_values = overlay.settings.as_dictionary()
		else: saved = false
		overlay._sync()
	_update_camera(true)
	suppress_mouse_until_release = true
	player.weapon.queued_single_press = false
	var message := "Все настройки импортированы и сохранены для следующих запусков."
	if not saved: message = "Импорт применён. Не удалось сохранить часть профилей — нажмите «Сохранить» в нужном окне."
	elif result.adjusted: message = "Все настройки импортированы и сохранены. Значения ограничены допустимыми диапазонами."
	_settings_file_message(message)
	return true

func _clear_projectiles() -> void:
	for bullet in get_tree().get_nodes_in_group("core_projectiles"):
		bullet.set_physics_process(false)
		bullet.queue_free()

func _respawn_enemies() -> void:
	for overlay in _overlays():
		if overlay.visible: overlay._finish_editing("")
	suppress_mouse_until_release = true
	player.weapon.queued_single_press = false
	_clear_projectiles()
	for target in level.enemies: target.reset_target()
	# Resurrecting a body around the hero must not push or trap the hero.
	player.allow_exit_overlapping_enemies()

func _recover() -> void:
	respawns += 1
	player.reset_to(CoreMovementLevel.SPAWN)
	_clear_projectiles()
	for target in level.enemies: target.reset_target()
	camera_kick = Vector2.ZERO
	camera_shake = 0
	camera_phase = 0
	camera.offset = Vector2.ZERO
	_update_camera(true)

func _camera_impulse(direction: Vector2,kick: float,shake: float) -> void:
	var impulse := Vector2(direction.x*.5,direction.y*.5-absf(direction.x)*.75)*kick
	camera_kick = (camera_kick+impulse).limit_length(12)
	camera_shake = minf(5,camera_shake+shake)

func camera_target() -> Vector2:
	var anchor := player.global_position-Vector2(0,CoreMovementPlayer.HEIGHT*.5)
	var target := anchor+Vector2(camera_settings.offset_x+player.facing*camera_settings.look_ahead,camera_settings.offset_y)/camera_settings.zoom
	if camera_settings.limit_to_level:
		var half_width := get_viewport_rect().size.x*.5/camera_settings.zoom
		var minimum := minf(half_width,CoreMovementLevel.WIDTH*.5)
		target.x = clampf(target.x,minimum,CoreMovementLevel.WIDTH-minimum)
	return target

func _update_camera(force_snap := false) -> void:
	var values := camera_settings.as_dictionary()
	var changed := values != camera_applied_values
	var is_paused := get_tree().paused
	if is_paused and not camera_was_paused and not changed and not force_snap:
		# Freeze the current rendered centre rather than snapping to its target.
		camera.position = camera.get_screen_center_position()-camera.offset
		camera.reset_smoothing()
	camera.zoom = Vector2.ONE*camera_settings.zoom
	camera.position_smoothing_enabled = camera_settings.follow_speed > 0
	camera.position_smoothing_speed = maxf(.1,camera_settings.follow_speed)
	if not is_paused or changed or force_snap: camera.position = camera_target()
	if changed or force_snap: camera.reset_smoothing()
	if is_paused: camera.force_update_scroll()
	camera_applied_values = values
	camera_was_paused = is_paused

func _process(delta: float) -> void:
	_update_camera()
	if not get_tree().paused:
		var decay := exp(-player.weapon.tuning.camera_return*delta)
		camera_kick *= decay
		camera_shake *= decay
		camera_phase += delta
		camera.offset = camera_kick+Vector2(sin(camera_phase*83)*.65,sin(camera_phase*127+1.2))*camera_shake
	var names := {"idle":"стойка","run":"бег","jump":"прыжок","fall":"падение","dash":"дэш","climb":"лестница"}
	hud.text = "КОР ГЕЙМПЛЕЯ · ПЕРЕДВИЖЕНИЕ И СТРЕЛЬБА"+(" · ПАУЗА" if get_tree().paused else "")
	var dash_status := "готов" if player.dash_available() else ("на лестнице" if player.climbing else "%.2f с" % player.dash_cooldown if player.dash_cooldown > 0 else "после приземления")
	telemetry.text = "Состояние: %s    Скорость: %.0f / %.0f    Дэш: %s    Последний дэш: %.0f px    Возвраты: %d" % [names[player.mode],player.velocity.x,player.velocity.y,dash_status,player.last_dash_distance,respawns]
	var weapon := player.weapon
	shooting_telemetry.text = "%s · %s · Разброс: ±%.1f° · Скорость: %.0f%% · Выстрелы: %d · Попадания: %d · Убийства: %d" % ["ОДИНОЧНЫЙ" if weapon.tuning.fire_mode == CoreShootingSettings.FireMode.SINGLE else "АВТО","ПРИЦЕЛ" if weapon.aiming else "ОТ БЕДРА",weapon.spread_degrees(),weapon.movement_multiplier*100,weapon.shots_fired,weapon.hits,weapon.kills]
