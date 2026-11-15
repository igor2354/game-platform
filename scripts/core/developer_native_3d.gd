extends Node
## Adapter: the existing F2 workspace owns the same live resources and panels.
var stage: Node3D
var player: CharacterBody3D
var movement_overlay: CoreMovementOverlay
var shooting_overlay: CoreMovementOverlay
var camera_overlay: CoreMovementOverlay
var zombie_overlay: CoreMovementOverlay
var ragdoll_overlay: CoreMovementOverlay
var health_overlay: CoreMovementOverlay
var fog_overlay: CoreMovementOverlay
var particle_overlay: CoreMovementOverlay
var developer_mode: CoreDeveloperMode
var respawn_enemies_button: Button
var fog_of_war: Node
var fog_readout: Label
var dialog: FileDialog
var settings_dialog_open := false
var dialog_exporting := false
var dialog_was_paused := false
var suppress_mouse_until_release := true
var debug_view: Node3D
var paused: bool:
 get: return stage.paused

func _ready() -> void:
 stage = get_parent()
 player = stage.player
 movement_overlay = stage.movement_overlay
 shooting_overlay = stage.combat.overlay
 camera_overlay = stage.camera_overlay
 zombie_overlay = stage.combat.zombie_overlay
 ragdoll_overlay = stage.ragdoll_overlay
 var layer := CanvasLayer.new()
 layer.layer = 40
 add_child(layer)
 health_overlay = _view(player.tuning,movement_overlay,["Здоровье"],CoreMovementSettings.PARAMS,layer)
 particle_overlay = _view(player.tuning,movement_overlay,["Частицы и эффекты"],CoreMovementSettings.PARAMS,layer)
 fog_overlay = _view(stage.camera_settings,camera_overlay,CoreCameraSettings.FOG.GROUPS.duplicate(),CoreCameraSettings.FOG.PARAMS,layer)
 for overlay in _ui_overlays():
  overlay.hosted = true
  overlay.export_requested.connect(_open_settings_dialog.bind(true))
  overlay.import_requested.connect(_open_settings_dialog.bind(false))
  overlay.settings_changed.connect(_settings_changed)
 respawn_enemies_button = Button.new()
 respawn_enemies_button.text = "Возродить всех врагов · F7"
 respawn_enemies_button.pressed.connect(_respawn_enemies)
 layer.add_child(respawn_enemies_button)
 debug_view = preload("res://scripts/core/developer_debug_3d.gd").new()
 debug_view.stage = stage
 stage.add_child(debug_view)
 developer_mode = CoreDeveloperMode.new()
 developer_mode.lab = self
 layer.add_child(developer_mode)
 get_viewport().size_changed.connect(func(): developer_mode.size = get_viewport().get_visible_rect().size)
 var workspace_content := developer_mode.panel.get_child(0)
 var workspace_scroll := ScrollContainer.new()
 workspace_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 developer_mode.panel.add_child(workspace_scroll)
 workspace_content.reparent(workspace_scroll)
 workspace_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 developer_mode.enemy_tools.invulnerable_toggle.tooltip_text = "Урон не уменьшает HP. Включение оживляет погибших на месте. В профили не записывается."
 _mark_capabilities()
 var grenade_refill=Button.new()
 grenade_refill.text="Пополнить запас гранат"
 grenade_refill.pressed.connect(func(): developer_prepare(); player.grenades.refill())
 ragdoll_overlay.tabs.get_tab_control(ragdoll_overlay.groups.find("Гранаты")).get_child(0).add_child(grenade_refill)
 dialog = FileDialog.new()
 dialog.access = FileDialog.ACCESS_FILESYSTEM
 dialog.filters = PackedStringArray(["*.json ; Настройки UBERSHRIKE"])
 dialog.process_mode = Node.PROCESS_MODE_ALWAYS
 dialog.file_selected.connect(_file_selected)
 dialog.canceled.connect(_close_settings_dialog)
 layer.add_child(dialog)
 var button := Button.new()
 button.text = "Разработчик · F2"
 button.position = Vector2(24,24)
 button.pressed.connect(developer_mode.toggle)
 layer.add_child(button)

func _view(resource: Resource,owner_overlay: CoreMovementOverlay,groups: Array,params: Array,layer: CanvasLayer) -> CoreMovementOverlay:
 var overlay := CoreMovementOverlay.new()
 overlay.hosted = true
 overlay.settings = resource
 overlay.defaults = owner_overlay.defaults
 overlay.profile_owner = owner_overlay
 overlay.settings_path = owner_overlay.settings_path
 overlay.groups.assign(groups)
 overlay.params = params.filter(func(p): return p[6] in groups)
 for p in overlay.params: overlay.profile_keys.append(p[0])
 var switches: Array = CoreMovementSettings.SWITCHES if resource is CoreMovementSettings else CoreCameraSettings.FOG.SWITCHES
 for p in switches:
  if p[2] in groups: overlay.profile_keys.append(p[0])
 layer.add_child(overlay)
 return overlay

func _overlays() -> Array[CoreMovementOverlay]:
 return [movement_overlay,shooting_overlay,camera_overlay,zombie_overlay,ragdoll_overlay]
func _ui_overlays() -> Array[CoreMovementOverlay]:
 return [movement_overlay,shooting_overlay,camera_overlay,zombie_overlay,ragdoll_overlay,health_overlay,fog_overlay,particle_overlay]
func developer_enemies() -> Array:
 return stage.combat.targets+stage.combat.enemies
func developer_prepare() -> void:
 suppress_mouse_until_release = true
 stage.combat.gun.queued_single_press = false
 stage.combat.gun.trigger_needs_release = true
 if player.grenades: player.grenades.cancel_charge()
 player.buffer = 0
 player.dash_held = Input.is_action_pressed("core_dash")
func developer_refill() -> void:
 var gun = stage.combat.gun
 gun.cancel_reload()
 gun.magazine = int(gun.tuning.magazine_capacity)
 gun.reserve = int(gun.tuning.starting_reserve)
 if player.grenades: player.grenades.refill()
func developer_pause() -> void:
 stage.paused = not stage.paused
func developer_debug(zones: bool,telemetry: bool) -> void:
 if is_instance_valid(debug_view): debug_view.visible = zones
 stage.hud.visible = telemetry
 stage.combat.readout.visible = telemetry
func _recover() -> void:
 developer_prepare()
 stage.combat.reset_test_world()
 player.reset()
 stage.camera_kick = Vector2.ZERO
 stage.camera_shake = 0
func _respawn_enemies() -> void:
 developer_prepare()
 stage.combat.gun.projectiles.clear()
 for enemy in developer_enemies(): enemy.reset()
func _teleport_zombie() -> void:
 developer_prepare()
 player.position = stage.geometry.point(Vector2(4980,760))+Vector3.UP*.02
 player.velocity = Vector3.ZERO
func _teleport_player(_point: Vector2) -> void:
 developer_prepare()
 player.position = stage.geometry.point(Vector2(2460,760))+Vector3.UP*.02
 player.velocity = Vector3.ZERO
func _update_camera(_instant := false) -> void:
 _settings_changed()
 stage.update_camera(1.0)
func _settings_changed() -> void:
 player.apply_health_limit()
 player.apply_feature_settings()
 stage.combat.gun.apply_tuning()

func handle_key(event: InputEventKey) -> bool:
 if not event.pressed or event.echo: return false
 var focus := get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit:
  if event.physical_keycode == KEY_ESCAPE:
   for overlay in _ui_overlays(): overlay._finish_editing("")
   developer_mode.finish_health_edit()
  return true
 if settings_dialog_open: return true
 match event.physical_keycode:
  KEY_F2: developer_mode.toggle()
  KEY_F3: developer_mode.toggle_overlay(0)
  KEY_F4: developer_mode.toggle_overlay(1)
  KEY_F5: developer_mode.toggle_overlay(2)
  KEY_F6: developer_mode.toggle_overlay(3)
  KEY_F10: developer_mode.toggle_overlay(4)
  KEY_F1: developer_mode.toggle_debug()
  KEY_F7: _respawn_enemies()
  KEY_F8: _recover()
  KEY_F9: _teleport_zombie()
  _: return false
 return true
func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and developer_mode.blocks_mouse_input(event.position): developer_prepare()

func blocks_mouse() -> bool:
 var focus := get_viewport().gui_get_focus_owner()
 return (is_instance_valid(stage.game_hud) and stage.game_hud.blocks_mouse_input(get_viewport().get_mouse_position())) or settings_dialog_open or suppress_mouse_until_release or focus is LineEdit or focus is TextEdit or developer_mode.blocks_mouse_input(get_viewport().get_mouse_position())
func _process(_dt: float) -> void:
 if suppress_mouse_until_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): suppress_mouse_until_release = false

func _resources() -> Dictionary:
 return {"movement":player.tuning,"shooting":stage.combat.gun.tuning,"camera":stage.camera_settings,"zombie":stage.combat.zombie_settings,"ragdoll":stage.ragdoll_settings}
func _open_settings_dialog(exporting: bool) -> void:
 if settings_dialog_open: return
 developer_mode._prepare_action()
 dialog_was_paused = stage.paused
 dialog_exporting = exporting
 settings_dialog_open = true
 stage.paused = true
 dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE
 dialog.title = "Экспорт всех настроек" if exporting else "Импорт всех настроек"
 dialog.current_file = "ubershrike-settings.json" if exporting else ""
 dialog.popup_centered_clamped(Vector2i(860,560))
func _close_settings_dialog() -> void:
 dialog.hide()
 if not settings_dialog_open: return
 settings_dialog_open = false
 stage.paused = dialog_was_paused
 developer_prepare()
func _file_selected(path: String) -> void:
 if dialog_exporting: export_settings_file(path)
 else: import_settings_file(path)
 _close_settings_dialog()
func export_settings_file(path: String) -> bool:
 developer_mode._prepare_action()
 var result := preload("res://scripts/core/settings_file.gd").write_file(path,_resources())
 developer_mode.status.text = "Все пять разделов экспортированы." if result==OK else "Ошибка экспорта: %d" % result
 return result==OK
func import_settings_file(path: String) -> bool:
 developer_mode._prepare_action()
 var defaults := {}
 var names := ["movement","shooting","camera","zombie","ragdoll"]
 for i in 5: defaults[names[i]] = _overlays()[i].defaults
 var result := preload("res://scripts/core/settings_file.gd").read_file(path,defaults)
 if result.has("error"):
  developer_mode.status.text = result.error
  return false
 var resources := _resources()
 for key in resources: resources[key].apply_values(result.values[key])
 _settings_changed()
 developer_mode.save_all()
 for overlay in _ui_overlays(): overlay._sync()
 return true

func _disable_tree(node: Node) -> void:
 if node is BaseButton: node.disabled = true
 if node is SpinBox or node is Slider: node.editable = false
 for child in node.get_children(): _disable_tree(child)
func _mark_capabilities() -> void:
 # Keep the entire compatible profile; unsupported world systems are explicit.
 var absent := {movement_overlay:["Маршевые лестницы","Терраформинг","Лопата","Толкание"],camera_overlay:["Визуал","Нуар","Окружение","Пиксельный мир","Сетка уровня","Размер героя"],zombie_overlay:["Ползание","Сбрасывание","Освещение"],ragdoll_overlay:["Бочки","Подвесные грузы"],fog_overlay:fog_overlay.groups}
 for overlay in absent:
  for i in overlay.tabs.get_tab_count():
   if overlay.tabs.get_tab_title(i) not in absent[overlay]: continue
   var page = overlay.tabs.get_tab_control(i)
   _disable_tree(page)
   var box = page.get_child(0)
   var note := Label.new()
   note.text = "В 3D ещё не подключено. Значения сохранены в общем профиле."
   note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   box.add_child(note)
   box.move_child(note,0)
 _disable_keys(ragdoll_overlay,["explosion_sever_chance","explosion_sever_min_damage"])
 for key in ["explosion_sever_enabled","explosion_chain_enabled"]:
  if ragdoll_overlay.feature_toggles.has(key):
   ragdoll_overlay.feature_toggles[key].disabled=true
   ragdoll_overlay.feature_toggles[key].tooltip_text="В 3D ещё не подключено; значение профиля сохранено."
 _disable_keys(shooting_overlay,["head_damage_multiplier","torso_damage_multiplier","arm_damage_multiplier","leg_damage_multiplier","arm_durability","leg_durability"])
 _disable_keys(camera_overlay,["vertical_aim_deadzone"])
 camera_overlay.feature_toggles.map_enabled.disabled = false
 developer_mode.status.text = "Общие профили 2D/3D. Серые страницы ещё не действуют в 3D; их значения сохраняются."

func _disable_keys(overlay: CoreMovementOverlay,keys: Array) -> void:
 for key in keys:
  if not overlay.rows.has(key): continue
  var row: Dictionary = overlay.rows[key]
  row.number.editable = false
  row.slider.editable = false
  row.number.tooltip_text = "В 3D ещё не подключено. Значение сохранено для совместимости профиля."
