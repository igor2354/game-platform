extends SceneTree
class Reference extends CoreShootingController:
 func _fire() -> void:
  if tuning.magazine_enabled: magazine_ammo -= 1
  shots_fired += 1
 func _update_aim() -> void: pass
 func _tick_recoil(_dt: float) -> void: pass
 func apply_tuning(_aim := true) -> void: pass
var failures := 0
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
 var rng := RandomNumberGenerator.new()
 rng.seed = 43129
 var samples := 0
 for fps in [30,60,144]:
  for rpm in [180.0,480.0,1000.0]:
   ref.tuning = CoreShootingSettings.new()
   ref.tuning.sound_enabled = false
   ref.tuning.rounds_per_minute = rpm
   ref.tuning.magazine_enabled = true
   ref.tuning.fire_mode = 0
   ref.magazine_ammo = 11
   ref.cooldown = 0
   ref.firing = false
   ref.trigger_held = false
   ref.trigger_needs_release = false
   ref.last_fire_mode = 0
   ref.queued_single_press = false
   ref.shots_fired = 0
   ref.dry_clicks = 0
   gun.equip("stg44")
   gun.tuning = ref.tuning.duplicate(true)
   gun.magazine = 11
   gun.trigger_held = false
   gun.shots_fired = 0
   gun.dry_clicks = 0
   for tick in 900:
    var pressed := tick%170<140
    var blocked := tick%131<7
    if tick%83==0:
     ref.tuning.fire_mode = 1-ref.tuning.fire_mode
     gun.tuning.fire_mode = ref.tuning.fire_mode
    if tick%199==0:
     ref.magazine_ammo = 11
     gun.magazine = 11
    if tick%157==0:
     ref.tuning.weapon_enabled = not ref.tuning.weapon_enabled
     gun.tuning.weapon_enabled = ref.tuning.weapon_enabled
    if tick%251==0:
     ref.tuning.magazine_enabled = not ref.tuning.magazine_enabled
     gun.tuning.magazine_enabled = ref.tuning.magazine_enabled
    # A completed fast click between physics ticks.
    var queued := tick%47==0
    ref.queued_single_press = queued
    gun.queued_single_press = queued
    if pressed: Input.action_press("core_fire")
    else: Input.action_release("core_fire")
    var dt: float = (1.0/fps)*rng.randf_range(.8,1.2)
    if tick%100<50: Input.action_press("core_aim")
    else: Input.action_release("core_aim")
    ref.update_state(dt,not blocked)
    gun.aiming = ref.aiming
    if not blocked: ref.finish_tick()
    gun.tick_trigger(dt,pressed,blocked,Vector3.ZERO,Vector3.RIGHT)
    if gun.shots_fired!=ref.shots_fired or gun.magazine!=ref.magazine_ammo or gun.dry_clicks!=ref.dry_clicks or absf(gun.cooldown-ref.cooldown)>.00001 or gun.trigger_needs_release!=ref.trigger_needs_release or not is_equal_approx(gun.movement_multiplier,ref.movement_multiplier):
     failures += 1
     if failures<4: print("MISMATCH fps=",fps," rpm=",rpm," tick=",tick," shots=",gun.shots_fired,"/",ref.shots_fired," dry=",gun.dry_clicks,"/",ref.dry_clicks)
    samples += 1
 Input.action_release("core_fire")
 Input.action_release("core_aim")
 print("FIRE_2D_3D_PARITY failures=",failures," samples=",samples)
 gun.queue_free()
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
