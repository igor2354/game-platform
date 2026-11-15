extends SceneTree
class Reference extends CoreShootingController:
 var point := Vector2(600,-80)
 func _ready() -> void: pass
 func _draw() -> void: pass
 func cursor_point() -> Vector2: return point
 func pivot() -> Vector2: return Vector2.ZERO
 func _shift_cursor(motion: Vector2) -> Vector2:
  point += motion
  return motion
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var reference := Reference.new()
 root.add_child(reference)
 var port = load("res://scripts/core/shooting_3d_recoil.gd").new()
 root.add_child(port)
 reference.tuning = CoreShootingSettings.new()
 port.tuning = reference.tuning.duplicate(true)
 reference.recoil_rng.seed = 1924
 port.recoil_rng.seed = 1924
 port.point = reference.point
 var failures := 0
 var rng := RandomNumberGenerator.new()
 rng.seed = 12
 for tick in 3000:
  reference.aiming = tick%140<70
  port.aiming = reference.aiming
  reference.firing = tick%50<30
  port.firing = reference.firing
  if tick%170==0:
   reference.tuning.recoil_continuous_enabled = not reference.tuning.recoil_continuous_enabled
   port.tuning.recoil_continuous_enabled = reference.tuning.recoil_continuous_enabled
  if tick%230==0:
   reference.tuning.recoil_auto_during_fire = not reference.tuning.recoil_auto_during_fire
   port.tuning.recoil_auto_during_fire = reference.tuning.recoil_auto_during_fire
  if tick%9==0:
   reference._apply_shot_recoil()
   port._apply_shot_recoil()
  if tick%5==0:
   var motion := Vector2(rng.randf_range(-12,12),rng.randf_range(-12,12))
   reference.point += motion
   port.point += motion
   reference.consume_manual_recoil(motion)
   port.consume_manual_recoil(motion)
  reference._tick_recoil(1.0/60)
  port._tick_recoil(1.0/60)
  for key in ["point","recoil_kick_offset","recoil_drift_offset","recoil_retarget_motion"]:
   if not reference.get(key).is_equal_approx(port.get(key)): failures += 1
  for key in ["recoil_angle","recoil_climb","recoil_horizontal","recoil_back","recoil_manual_grace"]:
   if not is_equal_approx(reference.get(key),port.get(key)): failures += 1
 print("RECOIL_2D_3D_PARITY failures=",failures," ticks=3000")
 reference.casing_pool.batch.free()
 reference.casing_pool.free()
 reference.queue_free()
 port.queue_free()
 await process_frame
 quit(int(failures>0))
