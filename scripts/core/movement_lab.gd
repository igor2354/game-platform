class_name CoreMovementLab
extends Node2D

const SettingsFile := preload("res://scripts/core/settings_file.gd")
const SettingsFileDialog := preload("res://scripts/core/settings_file_dialog.gd")
const TRANSITION_FADE_DURATION := .28

@export var load_user_settings := true
@export var campaign_mode := false
@export var settings_path := CoreMovementSettings.SAVE_PATH
@export var shooting_settings_path := CoreShootingSettings.SAVE_PATH
@export var camera_settings_path := CoreCameraSettings.SAVE_PATH
@export var zombie_settings_path := CoreZombieSettings.SAVE_PATH
@export var ragdoll_settings_path := CoreRagdollSettings.SAVE_PATH

@onready var level: CoreMovementLevel = $World/Level
@onready var player: CoreMovementPlayer = $World/Player
@onready var camera: Camera2D = $World/Camera
var hud: Label
var telemetry: Label
var notice: Label
var respawns := 0
var movement_overlay: CoreMovementOverlay
var health_overlay: CoreMovementOverlay
var shooting_overlay: CoreMovementOverlay
var camera_overlay: CoreMovementOverlay
var camera_settings: CoreCameraSettings
var zombie_overlay: CoreMovementOverlay
var zombie_settings: CoreZombieSettings
var concept_zombie_teleport_button: Button
var ragdoll_overlay: CoreMovementOverlay
var ragdoll_settings: CoreRagdollSettings
var ragdoll_reset_button: Button
var ragdoll_activate_button: Button
var ragdoll_teleport_button: Button
var barrel_teleport_button: Button
var barrel_reset_button: Button
var hanging_teleport_button: Button
var hanging_reset_button: Button
var developer_mode: CoreDeveloperMode
var developer_button: Button
var camera_applied_values: Dictionary = {}
var camera_was_paused := false
var aim_cursor: CoreAimCursor
var camera_look_direction := 1.0
var camera_look_velocity := 0.0
var respawn_enemies_button: Button
var map_button: Button
var level_map: CoreLevelMap
var map_was_paused := false
var hud_pointer_position := Vector2.ZERO
var shooting_telemetry: Label
var explosion_telemetry: Label
var explosion_debug: Node2D
var ammo_label: Label
var ammo_progress: ProgressBar
var interaction_hint: Label
var transition_fade: ColorRect
var transition_active := false
var transition_phase := ""
var transition_elapsed := 0.0
var transition_door: CoreTransitionDoor
var suppress_mouse_until_release := false
var camera_kick := Vector2.ZERO
var camera_shake := 0.0
var explosion_camera_shake := 0.0
var camera_phase := 0.0
var settings_dialog: FileDialog
var settings_dialog_open := false
var settings_dialog_exporting := false
var settings_dialog_was_paused := false
var windowed_mode := Window.MODE_WINDOWED

func _ready() -> void:
	_setup_input()
	add_to_group("explosion_observers")
	Engine.time_scale = 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.set_default_clear_color(Color("1c252d"))
	player.ladders = level.ladders
	player.side_ladders = level.side_ladders
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
	level.zombie.target = player
	var zombie_defaults := level.zombie.tuning.duplicate() as CoreZombieSettings
	zombie_defaults.apply_values(zombie_defaults.as_dictionary())
	zombie_settings = zombie_defaults.duplicate() as CoreZombieSettings
	for enemy in level.enemies:
		if enemy is CoreZombie:
			enemy.tuning = zombie_settings
			enemy.target = player
	var camera_defaults := load("res://resources/core/camera.tres").duplicate() as CoreCameraSettings
	camera_defaults.apply_values(camera_defaults.as_dictionary())
	camera_settings = camera_defaults.duplicate() as CoreCameraSettings
	player.visuals.settings = camera_settings
	player.weapon.camera_settings = camera_settings
	var ragdoll_defaults := CoreRagdollSettings.new()
	for param in CoreRagdollSettings.PARAMS:
		if param[6] == "Манекен": ragdoll_defaults.set(param[0],level.ragdoll_mannequin.get(param[0]))
	ragdoll_settings = ragdoll_defaults.duplicate() as CoreRagdollSettings
	if load_user_settings: player.tuning.load_saved(settings_path)
	if load_user_settings: player.weapon.tuning.load_saved(shooting_settings_path)
	if load_user_settings: camera_settings.load_saved(camera_settings_path)
	if load_user_settings: zombie_settings.load_saved(zombie_settings_path)
	if load_user_settings: ragdoll_settings.load_saved(ragdoll_settings_path)
	_ragdoll_settings_changed()
	for barrel in level.explosive_barrels: barrel.reset_barrel()
	for load_fixture in level.hanging_loads: load_fixture.reset_load()
	_zombie_settings_changed()
	player.fell.connect(_recover)
	player.weapon.camera_impulse.connect(_camera_impulse)
	player.weapon.shot_fired.connect(_shot_noise)
	player.noise_emitted.connect(_broadcast_noise)
	player.reset_to(level.player_spawn())
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
	movement_overlay.params = CoreMovementSettings.PARAMS.filter(func(param): return param[6] != "Здоровье")
	movement_overlay.groups = movement_overlay.groups.duplicate()
	movement_overlay.groups.erase("Здоровье")
	movement_overlay.hosted = true
	movement_overlay.settings_changed.connect(_player_settings_changed)
	overlay_layer.add_child(movement_overlay)
	health_overlay = CoreMovementOverlay.new()
	health_overlay.settings = player.tuning
	health_overlay.defaults = defaults
	health_overlay.settings_path = settings_path
	health_overlay.profile_owner = movement_overlay
	health_overlay.params = CoreMovementSettings.PARAMS.filter(func(param): return param[6] == "Здоровье")
	health_overlay.groups = ["Здоровье"]
	health_overlay.heading_text = "НАСТРОЙКА ЗДОРОВЬЯ"
	health_overlay.help_text = "Изменения применяются сразу, в том числе на паузе."
	health_overlay.hosted = true
	health_overlay.settings_changed.connect(_player_settings_changed)
	overlay_layer.add_child(health_overlay)
	health_overlay.tabs.tabs_visible = false
	shooting_overlay = CoreMovementOverlay.new()
	shooting_overlay.settings = player.weapon.tuning
	shooting_overlay.defaults = shooting_defaults
	shooting_overlay.settings_path = shooting_settings_path
	shooting_overlay.params = CoreShootingSettings.PARAMS
	shooting_overlay.groups = ["Оружие","От бедра","Прицел","Отдача","Звук","Урон","Магазин","Разброс в движении"]
	shooting_overlay.heading_text = "НАСТРОЙКА СТРЕЛЬБЫ · F4"
	shooting_overlay.hosted = true
	overlay_layer.add_child(shooting_overlay)
	shooting_overlay.settings_changed.connect(player.weapon.apply_tuning)
	camera_overlay = CoreMovementOverlay.new()
	camera_overlay.settings = camera_settings
	camera_overlay.defaults = camera_defaults
	camera_overlay.settings_path = camera_settings_path
	camera_overlay.params = CoreCameraSettings.PARAMS
	camera_overlay.groups = ["Камера","Визуал"]
	camera_overlay.heading_text = "НАСТРОЙКА КАМЕРЫ · F5"
	camera_overlay.help_text = "Изменения видны сразу, в том числе на паузе."
	camera_overlay.current_values_text = "Текущие значения камеры"
	camera_overlay.hosted = true
	camera_overlay.settings_changed.connect(_camera_settings_changed)
	overlay_layer.add_child(camera_overlay)
	zombie_overlay = CoreMovementOverlay.new()
	zombie_overlay.settings = zombie_settings
	zombie_overlay.defaults = zombie_defaults
	zombie_overlay.settings_path = zombie_settings_path
	zombie_overlay.params = CoreZombieSettings.PARAMS
	zombie_overlay.groups = ["Зрение","Слух","Движение","Бой","Ползание","Сбрасывание","Попадания","Ошеломление"]
	zombie_overlay.heading_text = "НАСТРОЙКА ЗОМБИ · F6"
	zombie_overlay.help_text = "Обзор и скорость — сразу. Тайминги — с нового действия."
	zombie_overlay.current_values_text = "Текущие настройки зомби · F1 — сектор и слух"
	zombie_overlay.settings_changed.connect(_zombie_settings_changed)
	zombie_overlay.hosted = true
	overlay_layer.add_child(zombie_overlay)
	var zombie_box: VBoxContainer = zombie_overlay.tabs.get_child(0).get_child(0)
	concept_zombie_teleport_button = zombie_overlay._button("К новому зомби-солдату · F10",func():
		developer_mode._prepare_action()
		_teleport_player(CoreMovementLevel.CONCEPT_ZOMBIE_TEST_SPAWN))
	concept_zombie_teleport_button.tooltip_text = "Отдельная зона слева от подвесных грузов. Общие настройки F6 применяются к обоим зомби."
	zombie_box.add_child(concept_zombie_teleport_button)
	ragdoll_overlay = CoreMovementOverlay.new()
	ragdoll_overlay.settings = ragdoll_settings
	ragdoll_overlay.defaults = ragdoll_defaults
	ragdoll_overlay.settings_path = ragdoll_settings_path
	ragdoll_overlay.params = CoreRagdollSettings.PARAMS
	ragdoll_overlay.groups = ["Манекен","Взрывы","Бочки","Подвесные грузы","Гранаты","Ударная волна"]
	ragdoll_overlay.heading_text = "ФИЗИКА · ОБЪЕКТЫ И ЛОВУШКИ"
	ragdoll_overlay.help_text = "Манекен — сразу; взрыв сохраняет параметры на момент детонации."
	ragdoll_overlay.current_values_text = "Напряжение манекена"
	ragdoll_overlay.hosted = true
	ragdoll_overlay.settings_changed.connect(_ragdoll_settings_changed)
	overlay_layer.add_child(ragdoll_overlay)
	var ragdoll_box: VBoxContainer = ragdoll_overlay.tabs.get_child(0).get_child(0)
	var hint := ragdoll_overlay._label("Повторное натяжение удерживает текущую позу.\nДля исходной стойки нажмите «Восстановить манекен».",14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ragdoll_box.add_child(hint)
	ragdoll_reset_button = ragdoll_overlay._button("Восстановить манекен",func():
		developer_mode._prepare_action()
		level.ragdoll_mannequin.reset_mannequin())
	ragdoll_activate_button = ragdoll_overlay._button("Включить ragdoll",func():
		developer_mode._prepare_action()
		level.ragdoll_mannequin.activate())
	ragdoll_teleport_button = ragdoll_overlay._button("К манекену",func():
		developer_mode._prepare_action()
		_teleport_player(Vector2(-190,CoreMovementLevel.FLOOR)))
	ragdoll_teleport_button.tooltip_text = "Перейти к ящику и манекену"
	var ragdoll_actions := HBoxContainer.new()
	ragdoll_box.add_child(ragdoll_actions)
	for button in [ragdoll_reset_button,ragdoll_activate_button,ragdoll_teleport_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ragdoll_actions.add_child(button)
	var barrel_box: VBoxContainer = ragdoll_overlay.tabs.get_child(2).get_child(0)
	barrel_teleport_button = ragdoll_overlay._button("К бочкам и топливу",func():
		developer_mode._prepare_action()
		_teleport_player(CoreMovementLevel.EXPLOSION_TEST_SPAWN))
	barrel_reset_button = ragdoll_overlay._button("Восстановить бочки",func():
		developer_mode._prepare_action()
		_reset_explosives())
	for button in [barrel_teleport_button,barrel_reset_button]: barrel_box.add_child(button)
	barrel_box.add_child(ragdoll_overlay._button("К склону с бочками",func():
		developer_mode._prepare_action()
		_teleport_player(CoreMovementLevel.BARREL_RAMP_SPAWN)))
	var hanging_box: VBoxContainer = ragdoll_overlay.tabs.get_child(3).get_child(0)
	hanging_teleport_button = ragdoll_overlay._button("К подвесным грузам",func():
		developer_mode._prepare_action()
		_teleport_player(CoreMovementLevel.HANGING_TEST_SPAWN))
	hanging_reset_button = ragdoll_overlay._button("Восстановить подвесы",func():
		developer_mode._prepare_action()
		_reset_hanging_loads())
	for button in [hanging_teleport_button,hanging_reset_button]: hanging_box.add_child(button)
	var grenade_box: VBoxContainer = ragdoll_overlay.tabs.get_child(4).get_child(0)
	grenade_box.add_child(ragdoll_overlay._button("Пополнить гранаты",func():
		developer_mode._prepare_action()
		player.grenades.refill()))
	for overlay in _ui_overlays():
		overlay.export_requested.connect(_open_settings_dialog.bind(true))
		overlay.import_requested.connect(_open_settings_dialog.bind(false))
	developer_mode = CoreDeveloperMode.new()
	developer_mode.lab = self
	overlay_layer.add_child(developer_mode)
	developer_button.pressed.connect(developer_mode.toggle)
	_build_settings_dialog(overlay_layer)
	player.input_blocker = _blocks_keyboard
	player.weapon.input_blocker = _blocks_shooting
	var cursor_layer := CanvasLayer.new()
	cursor_layer.layer = 30
	add_child(cursor_layer)
	aim_cursor = CoreAimCursor.new()
	aim_cursor.host = self
	aim_cursor.weapon = player.weapon
	player.weapon.aim_cursor = aim_cursor
	cursor_layer.add_child(aim_cursor)
	_build_level_map()
	_camera_settings_changed()

func _blocks_keyboard() -> bool:
	if level_map and level_map.visible: return true
	if settings_dialog_open: return true
	if developer_mode and developer_mode.blocks_keyboard_input(): return true
	for overlay in _ui_overlays():
		if overlay.blocks_gameplay_input(): return true
	return false

func _overlays() -> Array[CoreMovementOverlay]:
	return [movement_overlay,shooting_overlay,camera_overlay,zombie_overlay,ragdoll_overlay]

func _ui_overlays() -> Array[CoreMovementOverlay]:
	# Health is a separate view of the existing movement profile.
	return [movement_overlay,shooting_overlay,camera_overlay,zombie_overlay,ragdoll_overlay,health_overlay]

func _ragdoll_settings_changed() -> void:
	player.grenades.tuning = ragdoll_settings
	for grenade in get_tree().get_nodes_in_group("core_grenades"):
		if is_ancestor_of(grenade): grenade.apply_tuning()
	level.ragdoll_mannequin.apply_muscle_settings(ragdoll_settings.as_dictionary())
	level.fuel_field.tuning = ragdoll_settings
	for barrel in level.explosive_barrels:
		barrel.tuning = ragdoll_settings
		barrel.apply_tuning()
	for load_fixture in level.hanging_loads:
		load_fixture.tuning = ragdoll_settings
		load_fixture.apply_tuning()

func _reset_hanging_loads() -> void:
	if player.push_target is CoreHangingLoadBody or (is_instance_valid(player.push_target) and player.push_target.is_in_group("hanging_fragments")): player.stop_pushing()
	for load_fixture in level.hanging_loads: load_fixture.reset_load()

func on_explosion(point: Vector2,profile: CoreExplosionSettings,blast: CoreExplosion = null) -> void:
	explosion_debug.record(point,profile,blast)
	_broadcast_noise(point,maxf(2,profile.explosion_radius/60),"explosion")
	if not profile.explosion_camera_enabled: return
	var distance := point.distance_to(player.global_position-Vector2(0,32))
	var strength := clampf(1-distance/maxf(1,profile.explosion_radius*3),0,1)
	if strength > 0 and camera_settings.camera_enabled:
		explosion_camera_shake = minf(30,explosion_camera_shake+profile.explosion_camera_strength*strength)

func _reset_explosives() -> void:
	explosion_debug.clear()
	player.stop_pushing()
	level.fuel_field.clear_fuel()
	for blast in get_tree().get_nodes_in_group("core_explosions"):
		if not is_ancestor_of(blast): continue
		blast.set_process(false)
		blast.queue_free()
	for barrel in level.explosive_barrels: barrel.reset_barrel()

func _zombie_settings_changed() -> void:
	for enemy in level.enemies:
		if enemy is CoreZombie: enemy.apply_tuning()
	level.queue_redraw()

func _player_settings_changed() -> void:
	player.apply_health_limit()
	player.apply_feature_settings()
	if health_overlay: health_overlay._sync()
	if developer_mode: developer_mode._sync_health()

func _shot_noise(origin: Vector2,_direction: Vector2,_aimed: bool,_spread: float) -> void:
	_broadcast_noise(origin,1.0,"shot")

func _broadcast_noise(point: Vector2,loudness: float,kind: String) -> void:
	for enemy in level.enemies:
		if enemy is CoreZombie: enemy.hear_noise(point,loudness,kind)

func _blocks_shooting() -> bool:
	if suppress_mouse_until_release:
		if Input.is_action_pressed("core_fire") or Input.is_action_pressed("core_aim"): return true
		suppress_mouse_until_release = false
	if _blocks_keyboard(): return true
	if developer_button.get_global_rect().has_point(hud_pointer_position): return true
	if map_button and map_button.is_visible_in_tree() and map_button.get_global_rect().has_point(hud_pointer_position): return true
	if developer_mode.blocks_mouse_input(hud_pointer_position): return true
	if respawn_enemies_button.is_visible_in_tree() and respawn_enemies_button.get_global_rect().has_point(hud_pointer_position): return true
	for overlay in _ui_overlays():
		if overlay.blocks_mouse_input(): return true
	return false

func _setup_input() -> void:
	var bindings := {"core_left":[KEY_A,KEY_LEFT],"core_right":[KEY_D,KEY_RIGHT],"core_up":[KEY_W,KEY_UP],"core_down":[KEY_S,KEY_DOWN],"core_jump":[KEY_SPACE],"core_crouch":[KEY_C],"core_walk":[KEY_CTRL],"core_sprint":[KEY_SHIFT],"core_dash":[KEY_ALT],"core_grab":[KEY_G],"core_interact":[KEY_E],"core_reload":[KEY_R],"core_reset":[KEY_F8],"core_pause":[KEY_ESCAPE],"core_map":[KEY_M],"core_debug":[KEY_F1],"core_respawn_enemies":[KEY_F7],"core_developer":[KEY_F2],"core_tuner":[KEY_F3],"core_weapon_tuner":[KEY_F4],"core_camera_tuner":[KEY_F5],"core_zombie_tuner":[KEY_F6],"core_fire_mode":[KEY_B],"core_grenade":[KEY_T],"core_zombie_test":[KEY_F9],"core_concept_zombie_test":[KEY_F10],"core_fullscreen":[KEY_F11]}
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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 132
	hud = _label(layer,Vector2(30,15),"КОР ГЕЙМПЛЕЯ · ПЕРЕДВИЖЕНИЕ И СТРЕЛЬБА",27)
	_label(layer,Vector2(30,57),"A/D — бег   Ctrl — ходьба   Shift — спринт   Alt — дэш   Пробел — прыжок   W/S — лестница   C — присед/подкат   M — карта   Esc — пауза",18)
	ammo_label = _label(layer,Vector2(30,94),"",18)
	ammo_progress = ProgressBar.new()
	ammo_progress.position = Vector2(680,100)
	ammo_progress.size = Vector2(180,14)
	ammo_progress.max_value = 1
	ammo_progress.show_percentage = false
	ammo_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ammo_progress)
	telemetry = _label(layer,Vector2(30,780),"",18)
	explosion_telemetry = _label(layer,Vector2(30,750),"",15)
	explosion_telemetry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	explosion_telemetry.hide()
	explosion_debug = preload("res://scripts/core/explosion_telemetry.gd").new()
	explosion_debug.lab = self
	explosion_debug.caption = explosion_telemetry
	explosion_debug.hide()
	add_child(explosion_debug)
	developer_button = Button.new()
	developer_button.text = "Разработчик · F2"
	developer_button.focus_mode = Control.FOCUS_NONE
	developer_button.add_theme_font_size_override("font_size",18)
	layer.add_child(developer_button)
	developer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	developer_button.offset_left = -259
	developer_button.offset_right = -24
	developer_button.offset_top = 16
	developer_button.offset_bottom = 58
	respawn_enemies_button = Button.new()
	respawn_enemies_button.text = "Возродить врагов · F7"
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
	map_button = Button.new()
	map_button.text = "Карта уровня · M"
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.add_theme_font_size_override("font_size",18)
	layer.add_child(map_button)
	map_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_button.offset_left = -259
	map_button.offset_right = -24
	map_button.offset_top = 68
	map_button.offset_bottom = 110
	map_button.pressed.connect(_toggle_level_map)
	hud_pointer_position = get_viewport().get_mouse_position()
	shooting_telemetry = _label(layer,Vector2(30,813),"",18)
	var interaction_control := "E — дверь · " if not campaign_mode else ""
	notice = _label(layer,Vector2(30,850),"ЛКМ — огонь · ПКМ — прицел · " + interaction_control + "R — перезарядка · B — режим огня · T — граната · G — взять/отпустить · F2 — разработчик · F11 — полный экран",18)
	interaction_hint = Label.new()
	interaction_hint.position = Vector2(0,712)
	interaction_hint.size = Vector2(1600,44)
	interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_hint.add_theme_font_size_override("font_size",24)
	interaction_hint.add_theme_color_override("font_color",Color("f3e7c7"))
	interaction_hint.add_theme_color_override("font_shadow_color",Color("10171c"))
	interaction_hint.add_theme_constant_override("shadow_offset_x",2)
	interaction_hint.add_theme_constant_override("shadow_offset_y",2)
	interaction_hint.visible = false
	layer.add_child(interaction_hint)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	transition_fade = ColorRect.new()
	transition_fade.color = Color(0,0,0,0)
	transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_fade.visible = false
	fade_layer.add_child(transition_fade)

func _teleport_zombie() -> void:
	_teleport_player(CoreMovementLevel.ZOMBIE_TEST_SPAWN)

func _teleport_player(point: Vector2) -> void:
	if player.grenades.preparing(): player.grenades.throw_held(true)
	player.reset_to(point)
	_clear_projectiles()
	camera_kick = Vector2.ZERO
	camera_shake = 0
	explosion_camera_shake = 0
	camera.offset = Vector2.ZERO
	_update_camera(true)

func _label(parent: Node,point: Vector2,text: String,size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("d3dfe3"))
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if transition_active:
		get_viewport().set_input_as_handled()
		return
	if level_map and level_map.visible:
		get_viewport().set_input_as_handled()
		return
	if _blocks_keyboard(): return
	if event.is_action_pressed("core_map") and not event.is_echo():
		_toggle_level_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("core_interact") and not event.is_echo() and not get_tree().paused:
		var door := _nearby_transition_door()
		if door:
			_begin_transition(door)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("core_grenade") and not event.is_echo() and not get_tree().paused:
		player.grenades.toggle_preparation()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("core_fire") and player.grenades.preparing():
		if not get_tree().paused and not _blocks_shooting(): player.grenades.input_trigger(event.is_pressed())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("core_grab") and not event.is_echo() and not get_tree().paused: player.queued_grab_press = true
	if event.is_action_pressed("core_reload") and not event.is_echo(): player.weapon.request_reload()
	if event.is_action_pressed("core_concept_zombie_test") and not event.is_echo():
		_teleport_player(CoreMovementLevel.CONCEPT_ZOMBIE_TEST_SPAWN)
	if event.is_action_pressed("core_zombie_test") and not event.is_echo():
		_teleport_zombie()
	if event.is_action_pressed("core_respawn_enemies") and not event.is_echo():
		_respawn_enemies()
	if event.is_action_pressed("core_fire") and not get_tree().paused and not _blocks_shooting():
		# Keep short clicks that begin and end between two physics ticks.
		if player.weapon.tuning.fire_mode == CoreShootingSettings.FireMode.SINGLE and player.weapon.cooldown <= 0:
			player.weapon.queued_single_press = true
	if event.is_action_pressed("core_fire_mode") and not event.is_echo():
		player.weapon.tuning.set_fire_mode(1-player.weapon.tuning.fire_mode)
		shooting_overlay._sync()
	if event.is_action_pressed("core_pause"):
		if player.grenades.preparing(): player.grenades.cancel_charge()
		get_tree().paused = not get_tree().paused
	if event.is_action_pressed("core_reset"):
		get_tree().paused = false
		_recover()
	if event.is_action_pressed("core_debug") and not event.is_echo():
		developer_mode.toggle_debug()

func _input(event: InputEvent) -> void:
	if transition_active: return
	if get_tree().paused and event.is_action("core_fire") and player.grenades.preparing():
		player.grenades.cancel_charge()
		player.grenades.trigger_held = event.is_pressed()
		player.grenades.needs_release = event.is_pressed()
	if is_instance_valid(aim_cursor): aim_cursor.handle_input(event)
	if get_tree().paused and event.is_action("core_grab"):
		# A G held through unpausing is not a new gameplay press.
		player.grab_held = event.is_pressed()
		player.queued_grab_press = false
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		hud_pointer_position = event.position
	if settings_dialog_open: return
	if event.is_action_pressed("core_fullscreen") and not event.is_echo():
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if level_map and level_map.visible:
		if event.is_action_pressed("core_map") and not event.is_echo():
			_close_level_map()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("core_pause") and not event.is_echo():
			_close_level_map()
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed: suppress_mouse_until_release = true
	if event is InputEventMouseButton and event.pressed:
		if level_map and level_map.visible: suppress_mouse_until_release = true
		if developer_button.get_global_rect().has_point(event.position) or developer_mode.blocks_mouse_input(event.position): suppress_mouse_until_release = true
		if respawn_enemies_button.is_visible_in_tree() and respawn_enemies_button.get_global_rect().has_point(event.position): suppress_mouse_until_release = true
		if map_button and map_button.is_visible_in_tree() and map_button.get_global_rect().has_point(event.position): suppress_mouse_until_release = true
		for overlay in _ui_overlays():
			if overlay.visible and overlay.panel.get_global_rect().has_point(event.position):
				# Closing or dragging off the panel must not turn that click into fire.
				suppress_mouse_until_release = true
	if event.is_action_pressed("core_developer") and not event.is_echo():
		developer_mode.toggle()
		get_viewport().set_input_as_handled()
		return
	var overlay_actions := {"core_tuner":0,"core_weapon_tuner":1,"core_camera_tuner":2,"core_zombie_tuner":3}
	for action in overlay_actions:
		if event.is_action_pressed(action) and not event.is_echo():
			developer_mode.toggle_overlay(overlay_actions[action])
			get_viewport().set_input_as_handled()
			return

func _toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		window.mode = windowed_mode
	else:
		windowed_mode = Window.MODE_MAXIMIZED if window.mode == Window.MODE_MAXIMIZED else Window.MODE_WINDOWED
		window.mode = Window.MODE_FULLSCREEN

func _build_level_map() -> void:
	var map_layer := CanvasLayer.new()
	map_layer.layer = 35
	add_child(map_layer)
	level_map = CoreLevelMap.new()
	level_map.level = level
	level_map.player = player
	level_map.camera = camera
	level_map.close_requested.connect(_close_level_map)
	map_layer.add_child(level_map)

func _toggle_level_map() -> void:
	if not level_map: return
	if level_map.visible:
		_close_level_map()
		return
	if not camera_settings.map_enabled or transition_active or settings_dialog_open: return
	if developer_mode and developer_mode.enabled: return
	for overlay in _ui_overlays():
		if overlay.visible: return
	if player.grenades.preparing(): player.grenades.cancel_charge()
	map_was_paused = get_tree().paused
	level_map.show()
	get_tree().paused = true

func _close_level_map() -> void:
	if not level_map or not level_map.visible: return
	level_map.hide()
	get_tree().paused = map_was_paused

func _camera_settings_changed() -> void:
	if map_button:
		map_button.disabled = not camera_settings.map_enabled
		map_button.text = "Карта отключена · F5" if not camera_settings.map_enabled else "Карта уровня · M"
		map_button.tooltip_text = "Отключить или включить карту: F5 → Визуал → Карта уровня"
	if not camera_settings.map_enabled: _close_level_map()

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
	for overlay in _ui_overlays(): overlay._finish_editing("")
	developer_mode.finish_health_edit()
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
	settings_dialog.current_file = "ubershrike-settings.json" if exporting else ""
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
	return {"movement":player.tuning,"shooting":player.weapon.tuning,"camera":camera_settings,"zombie":zombie_settings,"ragdoll":ragdoll_settings}

func _settings_file_message(message: String) -> void:
	developer_mode.status.text = message
	for overlay in _ui_overlays():
		overlay._flash(message)
		overlay.flash_left = 8

func export_settings_file(path: String) -> bool:
	for overlay in _ui_overlays(): overlay._finish_editing("")
	var result := SettingsFile.write_file(path,_settings_resources())
	if result != OK:
		_settings_file_message("Не удалось экспортировать файл (%d)." % result)
		return false
	_settings_file_message("Все настройки экспортированы: %s" % path.get_file())
	return true

func import_settings_file(path: String) -> bool:
	var defaults := {"movement":movement_overlay.defaults,"shooting":shooting_overlay.defaults,"camera":camera_overlay.defaults,"zombie":zombie_overlay.defaults,"ragdoll":ragdoll_overlay.defaults}
	var result := SettingsFile.read_file(path,defaults)
	if result.has("error"):
		_settings_file_message(result.error)
		return false
	var resources := _settings_resources()
	for section in resources: resources[section].apply_values(result.values[section])
	player.weapon.apply_tuning()
	_camera_settings_changed()
	_player_settings_changed()
	_zombie_settings_changed()
	var saved := true
	_ragdoll_settings_changed()
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
	for overlay in _ui_overlays():
		if overlay.visible: overlay._finish_editing("")
	suppress_mouse_until_release = true
	player.weapon.queued_single_press = false
	_clear_projectiles()
	for target in level.enemies: target.reset_target()
	if is_instance_valid(level.hanging_target):
		level.hanging_target.position = Vector2(level.hanging_loads[0].position.x,CoreMovementLevel.FLOOR)
	# Resurrecting a body around the hero must not push or trap the hero.
	player.allow_exit_overlapping_enemies()

func _recover() -> void:
	for grenade in get_tree().get_nodes_in_group("core_grenades"):
		grenade.set_physics_process(false)
		grenade.queue_free()
	respawns += 1
	player.reset_to(level.player_spawn())
	level.physics_crate.reset_crate()
	level.ragdoll_mannequin.reset_mannequin()
	_reset_explosives()
	_reset_hanging_loads()
	_clear_projectiles()
	for target in level.enemies: target.reset_target()
	if is_instance_valid(level.hanging_target):
		level.hanging_target.position = Vector2(level.hanging_loads[0].position.x,CoreMovementLevel.FLOOR)
	camera_kick = Vector2.ZERO
	camera_shake = 0
	explosion_camera_shake = 0
	camera_phase = 0
	camera.offset = Vector2.ZERO
	_update_camera(true)

func _camera_impulse(direction: Vector2,kick: float,shake: float) -> void:
	var impulse := Vector2(direction.x*.5,direction.y*.5-absf(direction.x)*.75)*kick
	camera_kick = (camera_kick+impulse).limit_length(12)
	camera_shake = minf(5,camera_shake+shake)

func camera_target(look_direction := NAN) -> Vector2:
	var anchor := player.global_position-Vector2(0,CoreMovementPlayer.HEIGHT*.5)
	# Temporary dash/slide/ladder poses must not reverse the camera's look-ahead.
	# The weapon owns a stable gaze sample, independent of movement direction.
	var look := player.weapon.look_facing() if is_nan(look_direction) else look_direction
	var target := anchor+Vector2(camera_settings.offset_x+look*camera_settings.look_ahead,camera_settings.offset_y)/camera_settings.zoom
	if camera_settings.limit_to_level:
		var half_width := get_viewport_rect().size.x*.5/camera_settings.zoom
		var minimum := minf(half_width,(level.right_bound()-CoreMovementLevel.LEFT_BOUND)*.5)
		target.x = clampf(target.x,CoreMovementLevel.LEFT_BOUND+minimum,level.right_bound()-minimum)
	return target

func _advance_camera_look(delta: float,snap: bool) -> void:
	var target := player.weapon.look_facing()
	if snap or camera_settings.look_turn_duration <= 0:
		camera_look_direction = target
		camera_look_velocity = 0
		return
	if delta <= 0: return
	# Analytic critically damped spring: continuous position AND velocity when
	# aim reverses mid-turn. About 95% of the travel takes the chosen duration.
	# Normalised screen framing keeps this independent of zoom and movement.
	var omega := 4.75/camera_settings.look_turn_duration
	var error := camera_look_direction-target
	var coefficient := camera_look_velocity+omega*error
	var decay := exp(-omega*delta)
	camera_look_direction = clampf(target+(error+coefficient*delta)*decay,-1,1)
	camera_look_velocity = (camera_look_velocity-omega*coefficient*delta)*decay
	if absf(camera_look_direction-target) < .00001 and absf(camera_look_velocity) < .0001:
		camera_look_direction = target
		camera_look_velocity = 0

func _update_camera(force_snap := false,delta := 0.0) -> void:
	if not camera_settings.camera_enabled:
		camera.position = camera.get_screen_center_position()-camera.offset
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
		return
	var values := camera_settings.framing_values()
	var changed := values != camera_applied_values
	var is_paused := get_tree().paused
	if is_paused and not camera_was_paused and not changed and not force_snap:
		# Freeze the current rendered centre rather than snapping to its target.
		camera.position = camera.get_screen_center_position()-camera.offset
		camera.reset_smoothing()
	camera.zoom = Vector2.ONE*camera_settings.zoom
	camera.position_smoothing_enabled = camera_settings.follow_speed > 0
	camera.position_smoothing_speed = maxf(.1,camera_settings.follow_speed)
	if not is_paused or changed or force_snap:
		_advance_camera_look(delta,changed or force_snap)
		camera.position = camera_target(camera_look_direction)
	if changed or force_snap: camera.reset_smoothing()
	if is_paused: camera.force_update_scroll()
	camera_applied_values = values
	camera_was_paused = is_paused

func _process(delta: float) -> void:
	_update_transition(delta)
	_update_interaction_hint()
	if not player.weapon.tuning.recoil_enabled:
		camera_kick = Vector2.ZERO
		camera_shake = 0
		if camera_settings.camera_enabled: camera.offset = Vector2.ZERO
	_update_camera(false,delta)
	if not get_tree().paused:
		var decay := exp(-player.weapon.tuning.camera_return*delta)
		camera_kick *= decay
		camera_shake *= decay
		explosion_camera_shake *= exp(-8*delta)
		camera_phase += delta
		if camera_settings.camera_enabled: camera.offset = camera_kick+Vector2(sin(camera_phase*83)*.65,sin(camera_phase*127+1.2))*(camera_shake+explosion_camera_shake)
	var names := {"ledge_hang":"захват уступа","mantle":"подъём на уступ","vault":"через препятствие","ragdoll":"рэгдолл","knocked_down":"сбит с ног","idle":"стойка","run":"бег","walk":"ходьба","sprint":"спринт","slide":"подкат","crouch":"присед","crouch_walk":"ходьба в приседе","jump":"прыжок","fall":"падение","dash":"дэш","climb":"лестница","push":"предмет: G — отпустить"}
	hud.text = ("ПОГИБ · F8 — ВОЗРОДИТЬСЯ" if player.health <= 0 else "КОР ГЕЙМПЛЕЯ · HP %.0f/%.0f" % [player.health,player.maximum_health()])+(" · БЕССМЕРТИЕ" if player.invulnerable else "")+(" · ПАУЗА" if get_tree().paused else "")
	var dash_status := "граната в руке" if player.grenades.busy() else "готов" if player.dash_available() else ("в подкате" if player.slide_left > 0 else "на лестнице" if player.climbing else "%.2f с" % player.dash_cooldown if player.dash_cooldown > 0 else "после приземления")
	var sprint_status := "восст. %.1f с" % player.sprint_recovery_left() if player.sprint_exhausted else "%.1f / %.1f с" % [player.sprint_seconds_left(),player.tuning.sprint_duration]
	telemetry.text = "Состояние: %s · Скорость: %.0f / %.0f · Спринт: %s · Дэш: %s (%.0f px) · Возвраты: %d" % [names[player.mode],player.velocity.x,player.velocity.y,sprint_status,dash_status,player.last_dash_distance,respawns]
	var weapon := player.weapon
	ammo_label.text = "Патроны: %d/%d · Запас: %d%s" % [weapon.magazine_ammo,weapon.capacity(),weapon.reserve_ammo," · ПЕРЕЗАРЯДКА %.0f%%" % (weapon.reload_progress()*100) if weapon.reloading else " · ПУСТО — R" if weapon.magazine_ammo == 0 and weapon.reserve_ammo > 0 else " · НЕТ ПАТРОНОВ" if weapon.magazine_ammo == 0 else ""]
	ammo_label.text += " · Гранаты: %d · T" % player.grenades.count
	if player.grenades.preparing():
		ammo_label.text += " · ЗАПАЛ %.1f с · БРОСОК %d%%" % [maxf(0,player.grenades.held_grenade.fuse_left),roundi(player.grenades.power()*100)]
	ammo_progress.visible = weapon.reloading
	ammo_progress.value = weapon.reload_progress()
	shooting_telemetry.text = "%s · %s · Разброс: ±%.1f° · Скорость: %.0f%% · Выстрелы: %d · Попадания: %d · Убийства: %d" % ["ОДИНОЧНЫЙ" if weapon.tuning.fire_mode == CoreShootingSettings.FireMode.SINGLE else "АВТО","ГРАНАТА" if player.grenades.busy() else "ПРИЦЕЛ" if weapon.aiming else "ОТ БЕДРА",weapon.spread_degrees(),weapon.movement_multiplier*100,weapon.shots_fired,weapon.hits,weapon.kills]

func _nearby_transition_door() -> CoreTransitionDoor:
	if player.health <= 0 or player.blast_ragdoll.active or player.barrel_knockdown_left > 0 or player.shove_left > 0:
		return null
	if not player.is_on_floor() or player.parkour_active() or player.climbing or player.dash_left > 0 or player.slide_left > 0 or player.pushing or player.grenades.busy():
		return null
	var nearest: CoreTransitionDoor
	var nearest_distance := INF
	for door in level.transition_doors:
		if not door.player_nearby: continue
		var distance := player.global_position.distance_to(door.global_position)
		if distance < nearest_distance:
			nearest = door
			nearest_distance = distance
	return nearest

func _update_interaction_hint() -> void:
	if not interaction_hint: return
	var door := _nearby_transition_door() if not get_tree().paused and not transition_active and not _blocks_keyboard() else null
	interaction_hint.visible = door != null
	if door: interaction_hint.text = "[ E ]  " + door.destination_label

func _begin_transition(door: CoreTransitionDoor) -> void:
	transition_door = door
	transition_active = true
	transition_phase = "out"
	transition_elapsed = 0
	transition_fade.show()
	_set_transition_alpha(0)
	player.weapon.queued_single_press = false
	suppress_mouse_until_release = true
	get_tree().paused = true

func _update_transition(delta: float) -> void:
	if not transition_active: return
	transition_elapsed += delta
	var progress := clampf(transition_elapsed/TRANSITION_FADE_DURATION,0,1)
	var eased := progress*progress*(3-2*progress)
	if transition_phase == "out":
		_set_transition_alpha(eased)
		if progress >= 1:
			player.transition_to(transition_door.destination_position)
			_clear_projectiles()
			camera_kick = Vector2.ZERO
			camera_shake = 0
			explosion_camera_shake = 0
			camera.offset = Vector2.ZERO
			_update_camera(true)
			transition_phase = "in"
			transition_elapsed = 0
	else:
		_set_transition_alpha(1-eased)
		if progress >= 1:
			_set_transition_alpha(0)
			transition_fade.hide()
			transition_active = false
			transition_phase = ""
			transition_door = null
			get_tree().paused = false

func _set_transition_alpha(alpha: float) -> void:
	var shade := transition_fade.color
	shade.a = alpha
	transition_fade.color = shade
