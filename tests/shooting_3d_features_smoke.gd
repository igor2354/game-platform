extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var gun = load("res://scripts/core/shooting_3d.gd").new()
 world.add_child(gun)
 gun.set_physics_process(false)
 var failures := 0
 for id in ["stg44","mp40","m1911","svt"]:
  gun.equip(id)
  gun.tuning.sound_enabled = false
  gun.aiming = false
  gun.magazine = 1
  gun.fire(Vector3.ZERO,Vector3.RIGHT)
  if not gun.audio.last_shot_sound_profile.last: failures += 1
  if gun.bloom<=0 or gun.recoil_angle<=0: failures += 1
  gun._physics_process(5)
  if gun.bloom>0 or gun.recoil_angle>0: failures += 1
  gun.begin_reload()
  gun._physics_process(gun.tuning.reload_duration)
  if gun.reload_cues!=3 or gun.magazine!=gun.tuning.magazine_capacity: failures += 1
  gun.aiming = true
  gun.cooldown = 0
  gun.fire(Vector3.ZERO,Vector3.RIGHT)
  if gun.ads_bloom<=0: failures += 1
 print("SHOOTING_3D_AUDIO_SPREAD_RELOAD failures=",failures)
 world.queue_free()
 await process_frame
 quit(int(failures>0))
