extends Node
var host: Node
var tuning: CoreShootingSettings
var aiming := false
var firing := false
var screen_scale := 1.0
var screen_projection := Transform2D.IDENTITY
var point := Vector2(600,0)
var pivot_point := Vector2.ZERO
var shift_callback: Callable
var recoil_rng := RandomNumberGenerator.new()
var recoil_kick_offset := Vector2.ZERO
var recoil_drift_offset := Vector2.ZERO
var recoil_manual_grace := 0.0
var recoil_burst_age := 0.0
var recoil_retarget_motion := Vector2.ZERO
var recoil_back := 0.0
var recoil_angle := 0.0
var recoil_climb := 0.0
var recoil_horizontal := 0.0
var recoil_idle_time := 1000.0
func cursor_point() -> Vector2: return point
func pivot() -> Vector2: return pivot_point
func _shift_cursor(motion: Vector2) -> Vector2:
 var actual: Vector2 = shift_callback.call(motion) if shift_callback.is_valid() else motion
 point += actual
 return actual
func consume_manual_recoil(motion: Vector2,manual := true) -> void:
 # Input always moves the same aiming point by its full distance. Opposing
 # motion also pays down recoil debt, so auto return cannot subtract it twice.
 var debt := recoil_kick_offset+recoil_drift_offset
 var remaining := Vector2.ONE
 for axis in 2:
  if debt[axis]*motion[axis] < 0:
   remaining[axis] = maxf(0,1-absf(motion[axis])/absf(debt[axis]))
 recoil_kick_offset *= remaining
 recoil_drift_offset *= remaining
 recoil_angle *= remaining.y
 recoil_climb *= remaining.y
 recoil_horizontal *= remaining.x
 if manual and debt.length_squared() > .000001 and motion.length_squared() > .000001:
  recoil_manual_grace = tuning.recoil_auto_input_grace
  # Motion left after paying recoil is an intentional change of aim.
  # A deliberate retarget rebases the return point at the player's cursor,
  # without moving it or querying any enemy/target positions.
  recoil_retarget_motion += motion+debt*(Vector2.ONE-remaining)
  var screen_motion := screen_projection.basis_xform(recoil_retarget_motion)
  if screen_motion.length() >= tuning.recoil_auto_retarget_threshold and screen_motion.length_squared() > .000001:
   recoil_kick_offset = Vector2.ZERO
   recoil_drift_offset = Vector2.ZERO
   recoil_angle = 0
   recoil_climb = 0
   recoil_horizontal = 0
   recoil_retarget_motion = Vector2.ZERO
 if (recoil_kick_offset+recoil_drift_offset).length_squared() < .000001: recoil_retarget_motion = Vector2.ZERO

func _clamp_aim_recoil() -> void:
 if not tuning.recoil_continuous_enabled:
  var limit := deg_to_rad(tuning.ads_recoil_max_angle if aiming else tuning.hip_recoil_max_angle)
  recoil_climb = clampf(recoil_climb,0,limit)
  recoil_angle = clampf(recoil_angle,0,maxf(0,limit-recoil_climb))
 var lateral_limit := deg_to_rad(tuning.ads_recoil_horizontal_limit if aiming else tuning.hip_recoil_horizontal_limit)
 recoil_horizontal = clampf(recoil_horizontal,-lateral_limit,lateral_limit)

func _shift_shot_cursor(motion: Vector2) -> Vector2:
 var offset := cursor_point()-pivot()
 # At exactly 90 degrees down an upward impulse must not push the cursor
 # through the gun pivot and suddenly reverse the weapon by 180 degrees.
 # Deliberate mouse motion across the pivot is unrestricted.
 if offset.y > 0 and absf(offset.x) < 2 and motion.y < 0:
  motion.y = maxf(motion.y,minf(0,2-offset.y))
 return _shift_cursor(motion)

func _tick_recoil(delta: float) -> void:
 _clamp_aim_recoil()
 var response := tuning.ads_recoil_return if aiming else tuning.recoil_return
 recoil_back *= exp(-response*delta)
 recoil_burst_age += delta
 var grace_delta := maxf(0,delta-recoil_manual_grace)
 recoil_manual_grace = maxf(0,recoil_manual_grace-delta)
 var delay := tuning.ads_recoil_return_delay if aiming else tuning.hip_recoil_return_delay
 var recovery := deg_to_rad(tuning.ads_recoil_climb_recovery if aiming else tuning.hip_recoil_climb_recovery)
 var elapsed := recoil_burst_age-delta if firing and tuning.recoil_auto_during_fire else recoil_idle_time
 var recovery_delta := minf(grace_delta,clampf(elapsed+delta-delay,0,delta))
 recoil_idle_time += delta
 if not tuning.recoil_enabled or not tuning.recoil_auto_enabled: return
 var strength := tuning.ads_recoil_auto_strength if aiming else tuning.hip_recoil_auto_strength
 if strength <= 0 or grace_delta <= 0: return
 var kick_fraction := 1-exp(-response*strength*grace_delta)
 var returned := _shift_cursor(-recoil_kick_offset*kick_fraction)
 var previous := recoil_kick_offset
 recoil_kick_offset += returned
 if absf(previous.y) > .000001: recoil_angle *= clampf(absf(recoil_kick_offset.y/previous.y),0,1)
 if recovery_delta > 0:
  var fraction := Vector2(1,1)
  if recoil_climb > .000001: fraction.y = minf(1,recovery*strength*recovery_delta/recoil_climb)
  if absf(recoil_horizontal) > .000001: fraction.x = minf(1,recovery*strength*recovery_delta/absf(recoil_horizontal))
  previous = recoil_drift_offset
  returned = _shift_cursor(-recoil_drift_offset*fraction)
  recoil_drift_offset += returned
  if absf(previous.y) > .000001: recoil_climb *= clampf(absf(recoil_drift_offset.y/previous.y),0,1)
  if absf(previous.x) > .000001: recoil_horizontal *= clampf(absf(recoil_drift_offset.x/previous.x),0,1)
 if recoil_kick_offset.length_squared() < .00000001:
  recoil_kick_offset = Vector2.ZERO
  recoil_angle = 0
 if recoil_drift_offset.length_squared() < .00000001:
  recoil_drift_offset = Vector2.ZERO
  recoil_climb = 0
  recoil_horizontal = 0
 _clamp_aim_recoil()

func _apply_shot_recoil() -> void:
 var delay := tuning.ads_recoil_return_delay if aiming else tuning.hip_recoil_return_delay
 var fresh := recoil_idle_time >= maxf(.12,delay)
 if fresh: recoil_burst_age = 0
 var previous_kick := recoil_angle
 var previous_climb := recoil_climb
 var previous_horizontal := recoil_horizontal
 var first_multiplier := tuning.ads_recoil_first_shot_multiplier if aiming else tuning.hip_recoil_first_shot_multiplier
 var kick := tuning.ads_recoil_angle if aiming else tuning.recoil_angle
 var kick_step := deg_to_rad(kick)*(first_multiplier if fresh else 1.0)
 var climb_step := deg_to_rad(tuning.ads_recoil_climb if aiming else tuning.hip_recoil_climb)
 if not tuning.recoil_continuous_enabled:
  var limit := deg_to_rad(tuning.ads_recoil_max_angle if aiming else tuning.hip_recoil_max_angle)
  var room := maxf(0,limit-recoil_angle-recoil_climb)
  kick_step = minf(kick_step,room)
  climb_step = minf(climb_step,maxf(0,room-kick_step))
 recoil_angle += kick_step
 recoil_climb += climb_step
 var horizontal := tuning.ads_recoil_horizontal if aiming else tuning.hip_recoil_horizontal
 var bias := tuning.ads_recoil_horizontal_bias if aiming else tuning.hip_recoil_horizontal_bias
 recoil_horizontal += deg_to_rad(recoil_rng.randf_range(-horizontal,horizontal)+bias)
 recoil_back = minf(12,recoil_back+tuning.recoil_back*(tuning.ads_recoil_back_multiplier if aiming else 1.0))
 recoil_idle_time = 0
 _clamp_aim_recoil()
 # Integrate each impulse into the actual cursor, never into a hidden
 # additive angle on top of the hardware cursor. Debt records only travel
 # that was possible within the viewport, so the edge cannot bank recoil.
 var radius := maxf(40,cursor_point().distance_to(pivot()))
 var kick_motion := Vector2(0,-radius*tan(maxf(0,recoil_angle-previous_kick)))
 var drift_motion := Vector2(radius*tan(recoil_horizontal-previous_horizontal),-radius*tan(maxf(0,recoil_climb-previous_climb)))
 var actual := _shift_shot_cursor(kick_motion)
 recoil_kick_offset += actual
 if absf(kick_motion.y) > .000001: recoil_angle = previous_kick+(recoil_angle-previous_kick)*clampf(absf(actual.y/kick_motion.y),0,1)
 actual = _shift_shot_cursor(drift_motion)
 recoil_drift_offset += actual
 if absf(drift_motion.y) > .000001: recoil_climb = previous_climb+(recoil_climb-previous_climb)*clampf(absf(actual.y/drift_motion.y),0,1)
 if absf(drift_motion.x) > .000001: recoil_horizontal = previous_horizontal+(recoil_horizontal-previous_horizontal)*clampf(absf(actual.x/drift_motion.x),0,1)
