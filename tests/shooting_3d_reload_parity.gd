extends SceneTree
class Reference extends CoreShootingController:
 var dropped := 0
 func _drop_magazine(_pose: Dictionary) -> void: dropped += 1
 func _update_aim() -> void: pass
 func _draw() -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/main.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.process_mode = Node.PROCESS_MODE_DISABLED
 var ref := Reference.new()
 scene.player.add_child(ref)
 var gun = load("res://scripts/core/shooting_3d.gd").new()
 root.add_child(gun)
 gun.set_physics_process(false)
 gun.input_driven = true
 var drops := [0]
 gun.magazine_dropped.connect(func(): drops[0]+=1)
 var failures := 0
 var samples := 0
 Input.action_release("core_fire")
 for entry in preload("res://scripts/campaign/catalog.gd").WEAPONS:
  for empty in [true,false]:
   ref.tuning = CoreShootingSettings.new()
   ref.tuning.apply_values(entry.values)
   ref.tuning.sound_enabled = false
   ref.magazine_ammo = 0 if empty else 2
   ref.reserve_ammo = 80
   ref.reloading = false
   ref.dropped = 0
   gun.equip(entry.id)
   gun.tuning.sound_enabled = false
   gun.magazine = ref.magazine_ammo
   gun.reserve = ref.reserve_ammo
   drops[0] = 0
   if gun.begin_reload()!=ref.request_reload(): failures += 1
   for tick in 240:
    if tick==15:
     ref.tuning.reload_duration += .7
     gun.tuning.reload_duration += .7
    ref.update_state(1.0/60,true)
    gun._physics_process(1.0/60)
    gun.tick_trigger(1.0/60,false,false,Vector3.ZERO,Vector3.RIGHT)
    if gun.magazine!=ref.magazine_ammo or gun.reserve!=ref.reserve_ammo or absf(gun.reload_left-ref.reload_left)>.00001 or gun.reload_cues!=ref.reload_cues or drops[0]!=ref.dropped or not is_equal_approx(gun.movement_multiplier,ref.movement_multiplier): failures += 1
    samples += 1
   ref.magazine_ammo = 0
   gun.magazine = 0
   ref.request_reload()
   gun.begin_reload()
   ref._tick_reload(.2)
   gun._physics_process(.2)
   ref.cancel_reload()
   gun.cancel_reload()
   ref._tick_reload(10)
   gun._physics_process(10)
   if gun.magazine!=ref.magazine_ammo or gun.reserve!=ref.reserve_ammo or gun.audio.reload_audio.playing: failures += 1
 print("RELOAD_MOVEMENT_2D_3D failures=",failures," samples=",samples)
 gun.queue_free()
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
