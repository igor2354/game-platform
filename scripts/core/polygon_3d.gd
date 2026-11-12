extends Node3D
signal return_to_menu_requested
@export var load_user_settings := true
@export var settings_path := CoreMovementSettings.SAVE_PATH
@export var shooting_settings_path := CoreShootingSettings.SAVE_PATH
@export var camera_settings_path := CoreCameraSettings.SAVE_PATH
@export var zombie_settings_path := CoreZombieSettings.SAVE_PATH
@export var ragdoll_settings_path := CoreRagdollSettings.SAVE_PATH
@onready var geometry = $Geometry
@onready var player = $Player
@onready var camera: Camera3D = $Camera
var ragdoll_settings: CoreRagdollSettings
var ragdoll_overlay: CoreMovementOverlay
var camera_settings: CoreCameraSettings
var movement_overlay: CoreMovementOverlay
var camera_overlay: CoreMovementOverlay
var hud: Label
var inspection := false
var paused := false
var respawns := 0
var look_direction := 1.0
var camera_kick := Vector2.ZERO
var camera_shake := 0.0
var camera_phase := 0.0
var camera_effect_offset := Vector3.ZERO
var map_panel: PanelContainer
var combat: Node3D

func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("1c252d"))
 for action in {"core_left":[KEY_A,KEY_LEFT],"core_right":[KEY_D,KEY_RIGHT],"core_up":[KEY_W,KEY_UP],"core_down":[KEY_S,KEY_DOWN],"core_jump":[KEY_SPACE],"core_walk":[KEY_CTRL],"core_sprint":[KEY_SHIFT],"core_crouch":[KEY_C],"core_dash":[KEY_ALT],"core_reset":[KEY_F8],"core_interact":[KEY_E]}:
  if not InputMap.has_action(action): InputMap.add_action(action)
  for key in {"core_left":[KEY_A,KEY_LEFT],"core_right":[KEY_D,KEY_RIGHT],"core_up":[KEY_W,KEY_UP],"core_down":[KEY_S,KEY_DOWN],"core_jump":[KEY_SPACE],"core_walk":[KEY_CTRL],"core_sprint":[KEY_SHIFT],"core_crouch":[KEY_C],"core_dash":[KEY_ALT],"core_reset":[KEY_F8],"core_interact":[KEY_E]}[action]:
   var event := InputEventKey.new()
   event.physical_keycode = key
   if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)
 player.geometry = geometry
 var defaults: CoreMovementSettings = player.tuning.duplicate(true)
 if load_user_settings: player.tuning.load_saved(settings_path)
 camera_settings = preload("res://resources/core/camera.tres").duplicate(true)
 var camera_defaults := camera_settings.duplicate(true)
 if load_user_settings: camera_settings.load_saved(camera_settings_path)
 var layer := CanvasLayer.new()
 layer.layer = 30
 add_child(layer)
 hud = Label.new()
 hud.position = Vector2(24,70)
 layer.add_child(hud)
 movement_overlay = CoreMovementOverlay.new()
 movement_overlay.groups.append("Частицы и эффекты")
 movement_overlay.settings = player.tuning
 movement_overlay.defaults = defaults
 movement_overlay.settings_path = settings_path
 layer.add_child(movement_overlay)
 camera_overlay = CoreMovementOverlay.new()
 camera_overlay.settings = camera_settings
 camera_overlay.defaults = camera_defaults
 camera_overlay.settings_path = camera_settings_path
 camera_overlay.params = CoreCameraSettings.PARAMS
 camera_overlay.groups = ["Камера"]
 camera_overlay.heading_text = "КАМЕРА 3D · F5"
 layer.add_child(camera_overlay)
 ragdoll_settings = CoreRagdollSettings.new()
 var ragdoll_defaults := ragdoll_settings.duplicate(true)
 if load_user_settings: ragdoll_settings.load_saved(ragdoll_settings_path)
 ragdoll_overlay = CoreMovementOverlay.new()
 ragdoll_overlay.settings = ragdoll_settings
 ragdoll_overlay.defaults = ragdoll_defaults
 ragdoll_overlay.params = CoreRagdollSettings.PARAMS.filter(func(entry): return entry[6]=="Манекен")
 ragdoll_overlay.groups = ["Манекен"]
 ragdoll_overlay.profile_keys = ["simulation_enabled","muscle_tension","muscle_stiffness","muscle_damping"]
 ragdoll_overlay.settings_path = ragdoll_settings_path
 ragdoll_overlay.heading_text = "РЭГДОЛЛ 3D · F10"
 layer.add_child(ragdoll_overlay)
 combat = preload("res://scripts/core/polygon_3d_combat.gd").new()
 add_child(combat)
 build_map(layer)
 player.reset()
 update_camera(1.0)

func _unhandled_key_input(event: InputEvent) -> void:
 if not event.is_pressed() or event.is_echo(): return
 if event.physical_keycode == KEY_M and camera_settings.map_enabled: map_panel.visible = not map_panel.visible
 if event.physical_keycode == KEY_F2: movement_overlay.visible = not movement_overlay.visible
 if event.physical_keycode == KEY_F3: movement_overlay.visible = not movement_overlay.visible
 if event.physical_keycode == KEY_F10: ragdoll_overlay.visible = not ragdoll_overlay.visible
 if event.physical_keycode == KEY_F5: camera_overlay.visible = not camera_overlay.visible
 if event.physical_keycode == KEY_TAB: inspection = not inspection
 if event.physical_keycode == KEY_ESCAPE:
  paused = not paused
  player.set_physics_process(not paused)
 if event.physical_keycode == KEY_E:
  var pairs := [[-80.0,-6320.0],[400.0,5720.0],[-6320.0,-80.0],[5720.0,400.0]]
  for pair in pairs:
   if absf(player.position.x-pair[0]/geometry.U)<.9:
    player.position = geometry.point(Vector2(pair[1],760))+Vector3.UP*.015
    player.velocity = Vector3.ZERO
    break

func _process(dt: float) -> void:
 var focus := get_viewport().gui_get_focus_owner()
 player.set_physics_process(not paused and not (focus is LineEdit or focus is TextEdit))
 update_camera(dt)
 hud.text = "ПОЛИГОН 3D · %s · %.2f м/с · Спринт %.1f / %.1f\nA/D · Ctrl ходьба · Shift спринт · C присед/подкат · Alt дэш · W/S лестница\nSpace прыжок/подъём · F3 движение · F5 камера · F10 рэгдолл · Tab ракурс · E переход · F8 старт%s" % [player.mode,absf(player.velocity.x),player.reserve*player.tuning.sprint_duration,player.tuning.sprint_duration," · ПАУЗА" if paused else ""]

func update_camera(dt: float) -> void:
 camera.position -= camera_effect_offset
 camera_effect_offset = Vector3.ZERO
 if not camera_settings.camera_enabled: return
 look_direction = move_toward(look_direction,player.facing,2*dt/maxf(.001,camera_settings.look_turn_duration))
 var zoom := maxf(.1,camera_settings.zoom)
 var center: Vector3 = player.position + Vector3((camera_settings.offset_x+look_direction*camera_settings.look_ahead)/geometry.U/zoom,-camera_settings.offset_y/geometry.U/zoom,0)
 if camera_settings.limit_to_level:
  var half_width: float = get_viewport().get_visible_rect().size.x*.5/geometry.U/zoom
  var left: float = -6500/geometry.U+half_width
  var right: float = 7100/geometry.U-half_width
  center.x = clampf(center.x,left,right) if left<=right else 300.0/geometry.U
 var offset := Vector3(2.8,3.8,24) if inspection else Vector3(0,0,24)
 var target := center+offset
 camera.position = camera.position.lerp(target,1-exp(-camera_settings.follow_speed*dt)) if camera_settings.follow_speed>0 else target
 if camera_settings.limit_to_level:
  var half_width: float = get_viewport().get_visible_rect().size.x*.5/geometry.U/zoom
  var left: float = -6500/geometry.U+half_width
  var right: float = 7100/geometry.U-half_width
  camera.position.x = (clampf(camera.position.x-offset.x,left,right) if left<=right else 300.0/geometry.U)+offset.x
 camera.look_at(camera.position-offset)
 camera.size = get_viewport().get_visible_rect().size.y/geometry.U/maxf(.1,camera_settings.zoom)
 if is_instance_valid(combat) and not paused:
  if not combat.gun.tuning.recoil_enabled:
   camera_kick = Vector2.ZERO
   camera_shake = 0
  var decay := exp(-combat.gun.tuning.camera_return*dt)
  camera_kick *= decay
  camera_shake *= decay
  camera_phase += dt
  var effect := camera_kick+Vector2(sin(camera_phase*83)*.65,sin(camera_phase*127+1.2))*camera_shake
  camera_effect_offset = Vector3(effect.x,-effect.y,0)/geometry.U
  camera.position += camera_effect_offset

func build_map(layer: CanvasLayer) -> void:
 map_panel = PanelContainer.new()
 map_panel.position = Vector2(80,200)
 var column := VBoxContainer.new()
 map_panel.add_child(column)
 var title := Label.new()
 title.text = "ПОЛИГОН · участки слева направо · M закрыть"
 column.add_child(title)
 var source = preload("res://scripts/core/level.gd").new()
 var entries: Array = source.map_landmarks()
 entries.sort_custom(func(a,b): return a.position.x<b.position.x)
 for entry in entries:
  var label := Label.new()
  label.text = "%s · %s · %.1f м" % [entry.id,entry.label,entry.position.x/geometry.U]
  column.add_child(label)
 source.free()
 layer.add_child(map_panel)
 map_panel.hide()


func weapon_camera_impulse(direction: Vector3,kick: float,shake: float) -> void:
 var d := Vector2(direction.x,-direction.y)
 var impulse := Vector2(d.x*.5,d.y*.5-absf(d.x)*.75)*kick
 camera_kick = (camera_kick+impulse).limit_length(12)
 camera_shake = minf(5,camera_shake+shake)
