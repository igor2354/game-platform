class_name CoreShootingController
extends Node2D

signal shot_fired(origin: Vector2,direction: Vector2,aimed: bool,spread_degrees: float)
signal camera_impulse(direction: Vector2,kick: float,shake: float)
var tuning: CoreShootingSettings = CoreShootingSettings.new()
var equipped_weapon_id := ""
var camera_settings: CoreCameraSettings = CoreCameraSettings.new()
var player: CoreMovementPlayer
var input_blocker: Callable
var aiming := false
var firing := false
var movement_multiplier := 1.0
var burst_time := 0.0
var bloom := 0.0
var movement_spread := 0.0
var cooldown := 0.0
var sway_clock := 0.0
var aim_point := Vector2.ZERO
var raw_aim_point := Vector2.ZERO
var unrecoiled_aim_point := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var aim_facing := 1.0
var aim_override := Vector2.INF # Automated tests/capture only; normal play uses mouse.
var aim_cursor: Node
var override_cursor_point := Vector2.ZERO
var override_input_sample := Vector2.INF
var recoil_kick_offset := Vector2.ZERO
var recoil_drift_offset := Vector2.ZERO
var recoil_manual_grace := 0.0
var recoil_burst_age := 0.0
var recoil_retarget_motion := Vector2.ZERO
var shots_fired := 0
var hits := 0
var kills := 0
var last_shot_direction := Vector2.RIGHT
var last_shot_spread := 0.0
var rng := RandomNumberGenerator.new()
var flash_left := 0.0
var hit_marker_left := 0.0
var effects: Array[Dictionary] = []
var shot_audio: AudioStreamPlayer
var hit_audio: AudioStreamPlayer
var kill_audio: AudioStreamPlayer
var magazine_empty_audio: AudioStreamPlayer
var empty_sounds_played := 0
var last_shot_sound_profile := {"low":false,"pitch":1.0,"last":false}
var hit_sounds_played := 0
var kill_sounds_played := 0
var recoil_back := 0.0
var recoil_angle := 0.0
var recoil_climb := 0.0
var recoil_horizontal := 0.0
var recoil_idle_time := 1000.0
var recoil_rng := RandomNumberGenerator.new()
var kill_marker_left := 0.0
var cosmetic_rng := RandomNumberGenerator.new()
var trigger_held := false
var trigger_needs_release := false
var last_fire_mode := CoreShootingSettings.FireMode.AUTO
var queued_single_press := false
const HIP_PIVOT := Vector2(0,-36)
const ADS_RAISE_TIME := .12
var ads_blend := 0.0
var magazine_ammo := 71
var reserve_ammo := 213
var reloading := false
var reload_left := 0.0
var reload_duration_active := 2.4
var reload_facing := 1.0
var reload_start_direction := Vector2.RIGHT
var reload_cues := 0
var old_magazine_dropped := false
var reloads_completed := 0
var reload_audio: AudioStreamPlayer
var reload_sounds: Dictionary = {}
var dry_clicks := 0

func muzzle_distance() -> float:
	if equipped_weapon_id.is_empty(): return 34.0
	var catalog = preload("res://scripts/campaign/catalog.gd")
	var data: Dictionary = catalog.WEAPONS[catalog.index_for(equipped_weapon_id)]
	return data.length*(1.0-data.grip)

func _ready() -> void:
	player = get_parent() as CoreMovementPlayer
	rng.randomize()
	recoil_rng.randomize()
	z_index = 5
	cosmetic_rng.randomize()
	shot_audio = _audio_player("shot",6)
	hit_audio = _audio_player("hit",4)
	kill_audio = _audio_player("kill",2)
	magazine_empty_audio = _audio_player("magazine_empty",1)
	reload_audio = _audio_player("reload_out",1)
	for kind in ["reload_out","reload_in","reload_bolt","dry"]: reload_sounds[kind] = CoreCombatAudio.make_stream(kind)

func _audio_player(kind: String,polyphony: int) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = CoreCombatAudio.make_stream(kind)
	audio_player.max_polyphony = polyphony
	add_child(audio_player)
	return audio_player
func reset_state() -> void:
	refill_ammunition()
	reloads_completed = 0
	dry_clicks = 0
	empty_sounds_played = 0
	last_shot_sound_profile = {"low":false,"pitch":1.0,"last":false}
	if magazine_empty_audio: magazine_empty_audio.stop()
	aiming = false
	aim_facing = 1
	ads_blend = 0
	firing = false
	trigger_held = Input.is_action_pressed("core_fire")
	trigger_needs_release = false
	last_fire_mode = tuning.fire_mode
	queued_single_press = false
	movement_multiplier = 1
	burst_time = 0
	bloom = 0
	movement_spread = 0
	cooldown = 0
	sway_clock = 0
	shots_fired = 0
	hits = 0
	kills = 0
	hit_sounds_played = 0
	kill_sounds_played = 0
	recoil_back = 0
	recoil_angle = 0
	recoil_climb = 0
	recoil_horizontal = 0
	recoil_idle_time = 1000
	recoil_kick_offset = Vector2.ZERO
	recoil_drift_offset = Vector2.ZERO
	recoil_manual_grace = 0
	recoil_burst_age = 0
	recoil_retarget_motion = Vector2.ZERO
	override_input_sample = Vector2.INF
	kill_marker_left = 0
	flash_left = 0
	hit_marker_left = 0
	effects.clear()
	if shot_audio: shot_audio.stop()
	if hit_audio: hit_audio.stop()
	if kill_audio: kill_audio.stop()
	queue_redraw()

func capacity() -> int: return clampi(tuning.magazine_capacity,1,150)
func apply_tuning() -> void:
	if not tuning.movement_spread_enabled: movement_spread = 0
	else: movement_spread = minf(movement_spread,maxf(tuning.movement_spread_forward,tuning.movement_spread_backward))
	if not tuning.weapon_enabled or not tuning.magazine_enabled:
		if reloading: cancel_reload()
	if not tuning.ads_enabled or not tuning.weapon_enabled:
		aiming = false
		ads_blend = 0
	if not tuning.recoil_enabled:
		recoil_back = 0
		recoil_angle = 0
		recoil_climb = 0
		recoil_horizontal = 0
		recoil_idle_time = 1000
		recoil_kick_offset = Vector2.ZERO
		recoil_drift_offset = Vector2.ZERO
	_clamp_aim_recoil()
	if not tuning.sound_enabled:
		for audio in [shot_audio,hit_audio,kill_audio,reload_audio,magazine_empty_audio]:
			if is_instance_valid(audio): audio.stop()
	# Changing capacity never creates or discards rounds mid-test.
	if magazine_ammo > capacity():
		reserve_ammo += magazine_ammo-capacity()
		magazine_ammo = capacity()
	# Developer controls also work while paused, without advancing recoil time.
	if is_node_ready():
		_update_aim()
		if get_tree().paused and player.body: player.body.update_arms()
		queue_redraw()

func refill_ammunition() -> void:
	cancel_reload()
	magazine_ammo = capacity()
	reserve_ammo = clampi(tuning.starting_reserve,0,1000)
	queue_redraw()

func request_reload() -> bool:
	apply_tuning()
	if not tuning.weapon_enabled or not tuning.magazine_enabled: return false
	if (player.grenades and player.grenades.busy()) or (player.blast_ragdoll and player.blast_ragdoll.active) or reloading or player.pushing or player.barrel_knockdown_left > 0 or get_tree().paused or player.health <= 0 or player.climbing or player.dash_left > 0 or player.slide_left > 0 or magazine_ammo >= capacity() or reserve_ammo <= 0: return false
	var pose := visual_pose()
	reload_facing = player.body.facing
	reload_start_direction = pose.direction
	reloading = true
	reload_duration_active = clampf(tuning.reload_duration,.5,6)
	reload_left = reload_duration_active
	reload_cues = 0
	old_magazine_dropped = false
	firing = false
	aiming = false
	queued_single_press = false
	burst_time = 0
	return true

func cancel_reload() -> void:
	var was_reloading := reloading
	reloading = false
	reload_left = 0
	queued_single_press = false
	if reload_audio: reload_audio.stop()
	if was_reloading and player.body and player.body.sprite:
		player.body._show_frame()
		player.body.update_arms()

func reload_progress() -> float:
	return clampf(1-reload_left/reload_duration_active,0,1) if reloading else 0.0

func _play_reload_sound(kind: String) -> void:
	if not tuning.sound_enabled: return
	reload_audio.stream = reload_sounds[kind]
	reload_audio.volume_db = tuning.reload_volume
	reload_audio.play()

func _tick_reload(delta: float) -> void:
	if not reloading: return
	if player.health <= 0 or player.climbing or player.dash_left > 0 or player.slide_left > 0:
		cancel_reload()
		return
	reload_left = maxf(0,reload_left-delta)
	var progress := reload_progress()
	for index in 3:
		if progress >= [.17,.70,.84][index] and reload_cues <= index:
			_play_reload_sound(["reload_out","reload_in","reload_bolt"][index])
			reload_cues = index+1
	if progress >= .42 and not old_magazine_dropped:
		old_magazine_dropped = true
		var pose := _reload_pose(.40)
		effects.append({"kind":"magazine","point":player.global_position+pose.magazine_point,"target":false,"velocity":Vector2(-reload_facing*55,35),"rotation":0.0,"life":2.0})
	if reload_left <= 0:
		# Commit exactly once, only after the weapon is ready. Partial reloads
		# retain remaining rounds; interruptions cannot duplicate ammunition.
		var transferred := mini(capacity()-magazine_ammo,reserve_ammo)
		magazine_ammo += transferred
		reserve_ammo -= transferred
		reloading = false
		reloads_completed += 1
func spread_degrees() -> float:
	var moving := movement_spread if tuning.movement_spread_enabled else 0.0
	return moving*tuning.movement_spread_ads_multiplier if aiming else minf(tuning.hip_max_spread,tuning.hip_spread+bloom)+moving

func movement_spread_target() -> float:
	if not tuning.movement_spread_enabled or not tuning.weapon_enabled or player.health <= 0 or not player.is_on_floor() or player.climbing or player.dash_left > 0 or player.slide_left > 0 or is_zero_approx(player.velocity.x): return 0.0
	# Actual ground speed already includes backward, firing and slope modifiers.
	# Use its tangent length so climbing a hill does not artificially improve aim.
	var speed := player.velocity.length()
	var weight := clampf((speed-tuning.movement_spread_start_speed)/maxf(1,tuning.movement_spread_full_speed-tuning.movement_spread_start_speed),0,1)
	var amount := tuning.movement_spread_backward if player.velocity.x*look_facing() < 0 else tuning.movement_spread_forward
	return amount*weight

func _tick_movement_spread(delta: float) -> void:
	if not tuning.movement_spread_enabled:
		movement_spread = 0
		return
	var target := movement_spread_target()
	var response := tuning.movement_spread_rise_time if target > movement_spread else tuning.movement_spread_recovery_time
	movement_spread = target if response <= 0 else lerpf(movement_spread,target,1-exp(-delta/response))
	if absf(movement_spread-target) < .001: movement_spread = target
func pivot() -> Vector2:
	return player.global_position+local_pivot()
func local_pivot() -> Vector2:
	if not player.body: return HIP_PIVOT
	var hip := Vector2(0,-player.collision_height()/3.0) if player.crouching else HIP_PIVOT
	# Mount the stock at the shoulder; the baked head leans down to the sights.
	var raised := player.body.ads_anchor()
	return hip.lerp(raised,smoothstep(0,1,ads_blend))
func look_facing() -> float:
	# Gaze is independent of movement facing, including dash and vertical aim.
	# All consumers use the same sample from _update_aim in this physics tick.
	return aim_facing
func update_state(delta: float,input_allowed: bool) -> void:
	apply_tuning()
	_tick_reload(delta)
	sway_clock += delta
	cooldown = cooldown-delta if firing else maxf(0,cooldown-delta)
	flash_left = maxf(0,flash_left-delta)
	hit_marker_left = maxf(0,hit_marker_left-delta)
	kill_marker_left = maxf(0,kill_marker_left-delta)
	for effect in effects:
		effect.life -= delta
		if effect.get("kind","") in ["casing","magazine"]: _tick_casing(effect,delta)
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	var blocked := (player.grenades and player.grenades.busy()) or (player.blast_ragdoll and player.blast_ragdoll.active) or not tuning.weapon_enabled or not input_allowed or (input_blocker.is_valid() and bool(input_blocker.call())) or player.pushing or player.climbing or player.dash_left > 0 or player.slide_left > 0
	var trigger := tuning.weapon_enabled and Input.is_action_pressed("core_fire")
	if tuning.fire_mode != last_fire_mode:
		trigger_needs_release = trigger and trigger_held
		last_fire_mode = tuning.fire_mode
	if not trigger: trigger_needs_release = false
	var new_press := trigger and not trigger_held
	trigger_held = trigger
	var single_press := new_press or queued_single_press
	queued_single_press = false
	aiming = tuning.ads_enabled and not blocked and not reloading and Input.is_action_pressed("core_aim")
	_tick_recoil(delta)
	ads_blend = move_toward(ads_blend,1.0 if aiming else 0.0,delta/ADS_RAISE_TIME)
	if tuning.magazine_enabled and not blocked and not reloading and magazine_ammo <= 0 and single_press:
		_play_reload_sound("dry")
		dry_clicks += 1
	firing = not blocked and (aiming or tuning.hip_enabled) and not reloading and (magazine_ammo > 0 or not tuning.magazine_enabled) and not trigger_needs_release and (trigger if tuning.fire_mode == CoreShootingSettings.FireMode.AUTO else single_press)
	burst_time = burst_time+delta if firing and not aiming else 0.0
	if not firing:
		bloom = maxf(0,bloom-tuning.spread_recovery*delta)
		# Releasing the trigger restores movement immediately and won't bank shots.
		cooldown = clampf(cooldown,0,60.0/tuning.rounds_per_minute)
	movement_multiplier = player.grenades.tuning.grenade_move_multiplier if player.grenades and player.grenades.busy() and player.grenades.tuning else tuning.reload_move_multiplier if reloading else tuning.ads_move_multiplier if aiming else lerpf(1,tuning.hip_move_multiplier,minf(1,burst_time/tuning.hip_slow_ramp))
	_update_aim()
	queue_redraw()

func _tick_casing(effect: Dictionary,delta: float) -> void:
	var before: Vector2 = effect.point
	effect.velocity += Vector2(0,750*delta)
	var after: Vector2 = before+effect.velocity*delta
	var query := PhysicsRayQueryParameters2D.create(before,after,1|8)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): effect.point = after
	else:
		effect.point = hit.position+hit.normal*2
		effect.velocity = (effect.velocity as Vector2).bounce(hit.normal)*.30
	effect.rotation += delta*10
func cursor_point() -> Vector2:
	if aim_override != Vector2.INF:
		if override_input_sample == Vector2.INF:
			override_cursor_point = aim_override
		elif not aim_override.is_equal_approx(override_input_sample):
			var motion := aim_override-override_input_sample
			override_cursor_point += motion
			consume_manual_recoil(motion)
		override_input_sample = aim_override
		return override_cursor_point
	return aim_cursor.world_point() if is_instance_valid(aim_cursor) else get_global_mouse_position()

func _shift_cursor(motion: Vector2) -> Vector2:
	if aim_override != Vector2.INF:
		override_cursor_point += motion
		return motion
	return aim_cursor.shift_world(motion) if is_instance_valid(aim_cursor) else Vector2.ZERO

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
		var screen_motion := get_viewport().get_canvas_transform().basis_xform(recoil_retarget_motion)
		if screen_motion.length() >= tuning.recoil_auto_retarget_threshold and screen_motion.length_squared() > .000001:
			recoil_kick_offset = Vector2.ZERO
			recoil_drift_offset = Vector2.ZERO
			recoil_angle = 0
			recoil_climb = 0
			recoil_horizontal = 0
			recoil_retarget_motion = Vector2.ZERO
	if (recoil_kick_offset+recoil_drift_offset).length_squared() < .000001: recoil_retarget_motion = Vector2.ZERO

func _update_aim() -> void:
	var target := cursor_point()
	raw_aim_point = target
	# Hysteresis around both vertical axes preserves the last deliberate side.
	# Use the raw cursor and a neutral body anchor, not sway or a mirrored gun
	# mount: neither animation nor camera recoil may choose the opposite side.
	var bearing := target-recoil_kick_offset-recoil_drift_offset-(player.global_position-Vector2(0,player.collision_height()*.5))
	var turn_threshold := maxf(1,absf(bearing.y)*tan(deg_to_rad(camera_settings.vertical_aim_deadzone)))
	if absf(bearing.x) > turn_threshold: aim_facing = signf(bearing.x)
	if aiming:
		var phase := sway_clock*TAU*tuning.sway_frequency
		target += Vector2(sin(phase),sin(phase*.73+.8)*.7)*tuning.sway_radius
	unrecoiled_aim_point = target-recoil_kick_offset-recoil_drift_offset
	if aim_override == Vector2.INF and is_instance_valid(aim_cursor) and aim_cursor.active:
		target = aim_cursor._bounded_point(target)
	aim_point = target
	var offset := target-pivot()
	aim_direction = offset.normalized() if offset.length_squared() > 1 else Vector2(player.facing,0)
	if aiming or firing: player.facing = look_facing()
func finish_tick() -> void:
	# Dash and ladder entry take priority over shooting in the same frame.
	if (player.grenades and player.grenades.busy()) or (player.blast_ragdoll and player.blast_ragdoll.active) or player.pushing or player.climbing or player.dash_left > 0 or player.slide_left > 0:
		_tick_movement_spread(player.get_physics_process_delta_time())
		cancel_reload()
		aiming = false
		ads_blend = 0
		firing = false
		burst_time = 0
		movement_multiplier = player.grenades.tuning.grenade_move_multiplier if player.grenades and player.grenades.busy() and player.grenades.tuning else 1.0
		return
	_update_aim()
	_tick_movement_spread(player.get_physics_process_delta_time())
	if firing and cooldown <= 0:
		_fire()
		# Retain fractional timing for automatic fire; single fire keeps the same
		# minimum interval and requires a fresh press after releasing the trigger.
		cooldown += 60.0/tuning.rounds_per_minute
		# A small remainder is carried by update_state while held below.
	queue_redraw()
func _fire() -> void:
	if (player.grenades and player.grenades.busy()) or (player.blast_ragdoll and player.blast_ragdoll.active): return
	if player.pushing or player.barrel_knockdown_left > 0 or not tuning.weapon_enabled or (not aiming and not tuning.hip_enabled) or reloading or (tuning.magazine_enabled and magazine_ammo <= 0) or player.health <= 0: return
	var rounds_before := magazine_ammo
	if tuning.magazine_enabled: magazine_ammo -= 1
	last_shot_spread = spread_degrees()
	last_shot_direction = aim_direction.rotated(deg_to_rad(rng.randf_range(-last_shot_spread,last_shot_spread))) if last_shot_spread > 0 else aim_direction
	var muzzle := pivot()+aim_direction*muzzle_distance()
	var query := PhysicsRayQueryParameters2D.create(pivot(),muzzle,CoreProjectile.BULLET_MASK,[player.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if tuning.damage_enabled:
		for field in get_tree().get_nodes_in_group("fuel_fields"):
			field.ignite_segment(pivot(),hit.position if not hit.is_empty() else muzzle,player)
	if not hit.is_empty():
		CoreProjectile.resolve_impact(hit,tuning.damage,last_shot_direction,_on_impact,pivot(),tuning.damage_enabled,player)
	else:
		var bullet := CoreProjectile.new()
		bullet.direction = last_shot_direction
		bullet.speed = tuning.bullet_speed
		bullet.damage = tuning.damage
		bullet.damage_settings = tuning
		bullet.shooter = player.get_rid()
		bullet.instigator = player
		# Remember where the shot started, rather than tracking a hidden shooter.
		bullet.attack_origin = pivot()
		bullet.impact_callback = _on_impact
		player.get_parent().add_child(bullet)
		bullet.global_position = muzzle
		bullet.add_to_group("core_projectiles")
	shots_fired += 1
	flash_left = .045
	if tuning.recoil_enabled:
		_apply_shot_recoil()
		var camera_scale := tuning.ads_recoil_camera_multiplier if aiming else 1.0
		camera_impulse.emit(aim_direction,tuning.camera_kick*camera_scale,tuning.camera_shake*camera_scale)
	effects.append({"kind":"casing","point":pivot()-aim_direction*3,"target":false,"velocity":Vector2(-player.facing*cosmetic_rng.randf_range(45,95),-cosmetic_rng.randf_range(80,140)),"rotation":0.0,"life":.65})
	if not aiming: bloom = minf(tuning.hip_max_spread-tuning.hip_spread,bloom+tuning.spread_per_shot)
	_play_shot_sound(rounds_before)
	shot_fired.emit(muzzle,last_shot_direction,aiming,last_shot_spread)
	# The shot exits along the pre-kick aiming line. Its physical kick then
	# raises the crosshair and the complete weapon for the next shot.
	_update_aim()
	queue_redraw()

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

func shot_sound_profile(rounds_before: int) -> Dictionary:
	if not tuning.magazine_enabled: return {"low":false,"pitch":1.0,"last":false}
	var threshold := tuning.low_ammo_threshold
	var fraction := float(rounds_before)/capacity()
	var low := rounds_before > 0 and threshold > 0 and fraction <= threshold
	var pitch := 1.0
	if low:
		# A noticeable change at the threshold, rising to its target on the
		# last round. Reserve ammunition never affects this magazine warning.
		var progress := clampf((threshold-fraction)/maxf(.0001,threshold-1.0/capacity()),0,1)
		pitch = lerpf(1,tuning.low_ammo_pitch,.25+.75*progress)
	return {"low":low,"pitch":pitch,"last":rounds_before == 1}

func _play_shot_sound(rounds_before: int) -> void:
	last_shot_sound_profile = shot_sound_profile(rounds_before)
	if not tuning.sound_enabled: return
	shot_audio.volume_db = tuning.shot_volume
	shot_audio.pitch_scale = last_shot_sound_profile.pitch*cosmetic_rng.randf_range(.98 if last_shot_sound_profile.low else .96,1.02 if last_shot_sound_profile.low else 1.04)
	shot_audio.play()
	if last_shot_sound_profile.last and tuning.last_shot_accent > 0:
		magazine_empty_audio.volume_db = tuning.shot_volume+linear_to_db(tuning.last_shot_accent)
		magazine_empty_audio.play()
		empty_sounds_played += 1
func _on_impact(point: Vector2,target_hit: bool,killed := false,direction := Vector2.RIGHT) -> void:
	effects.append({"kind":"impact","point":point,"life":.30 if killed else .15,"duration":.30 if killed else .15,"target":target_hit,"killed":killed})
	if target_hit:
		hits += 1
		hit_marker_left = .14
		if killed:
			kills += 1
			kill_marker_left = .32
			kill_audio.volume_db = tuning.kill_volume
			kill_audio.pitch_scale = cosmetic_rng.randf_range(.97,1.03)
			if tuning.sound_enabled:
				kill_audio.play()
				kill_sounds_played += 1
			if tuning.recoil_enabled: camera_impulse.emit(direction,tuning.camera_kick*tuning.kill_camera_boost,tuning.camera_shake*tuning.kill_camera_boost)
		else:
			hit_audio.volume_db = tuning.hit_volume
			hit_audio.pitch_scale = cosmetic_rng.randf_range(.92,1.08)
			if tuning.sound_enabled:
				hit_audio.play()
				hit_sounds_played += 1
	queue_redraw()
func visual_pose() -> Dictionary:
	if reloading: return _reload_pose(reload_progress())
	var base := local_pivot()
	# Carry the gun with the body during sprint, sprint dash and slide. A
	# cursor behind the slide must not twist the gripping arms backwards.
	# Reticle and camera gaze remain independent throughout these actions.
	var carrying := player.sprint_pose_active() or player.sprint_dash_pose_active() or player.slide_left > 0 or player.barrel_knockdown_left > 0
	var visual_direction := Vector2(player.body.facing,.25).normalized() if carrying else aim_direction
	var normal := Vector2(-visual_direction.y,visual_direction.x)*player.body.facing if player.body else Vector2(-visual_direction.y,visual_direction.x)*player.facing
	var recoil := -visual_direction*recoil_back
	var breech := base+recoil
	var result := {"breech":breech,"direction":visual_direction,"normal":normal,"rear_grip":breech+visual_direction*3+normal*5,"front_grip":breech+visual_direction*20+normal*3}
	if not equipped_weapon_id.is_empty():
		var catalog = preload("res://scripts/campaign/catalog.gd")
		var data: Dictionary = catalog.WEAPONS[catalog.index_for(equipped_weapon_id)]
		result.rear_grip = breech+normal*3
		result.front_grip = breech+visual_direction*data.length*(data.front-data.grip)+normal*2
	return result

func _reload_pose(progress: float) -> Dictionary:
	# Lift the muzzle clear of the manipulating hand, with the stock held
	# low against the body. This direction mirrors correctly to either side.
	var raised := Vector2(reload_facing,0).rotated(-reload_facing*deg_to_rad(38))
	var direction := reload_start_direction.lerp(raised,smoothstep(0,.16,progress)).normalized()
	if progress > .90:
		var ready_direction := aim_direction if aim_direction.x*reload_facing >= 0 else reload_start_direction
		direction = direction.lerp(ready_direction,smoothstep(.90,1,progress)).normalized()
	var normal := Vector2(-direction.y,direction.x)*reload_facing
	var base := player.body.shoulder("near")+Vector2(reload_facing*8,10)
	var breech := local_pivot().lerp(base,smoothstep(0,.16,progress))
	if progress > .90: breech = breech.lerp(local_pivot(),smoothstep(.90,1,progress))
	if progress >= .70 and progress < .78: breech -= normal*.8*sin(smoothstep(.70,.78,progress)*PI)
	var magazine_point := breech+direction*10+normal*5
	var front := breech+direction*20+normal*3
	var pouch := Vector2(-reload_facing*4,-player.collision_height()*.45)
	var support := front
	var magazine_visible := true
	var bolt_offset := 0.0
	if progress < .17: support = front.lerp(magazine_point+normal*2,smoothstep(0,.17,progress))
	elif progress < .42:
		magazine_point += (normal*13-direction*3)*smoothstep(.24,.42,progress)
		support = magazine_point+normal*2
	elif progress < .52:
		magazine_visible = false
		support = (breech+direction*7+normal*20).lerp(pouch,smoothstep(.42,.52,progress))
	elif progress < .70:
		magazine_point = (pouch-normal*2).lerp(magazine_point,smoothstep(.52,.70,progress))
		support = magazine_point+normal*2
	elif progress < .80:
		support = (magazine_point+normal*2).lerp(breech+direction*7-normal*4,smoothstep(.73,.80,progress))
	elif progress < .90:
		bolt_offset = -5*sin(smoothstep(.80,.90,progress)*PI)
		support = breech+direction*(7+bolt_offset)-normal*4
	else: support = (breech+direction*7-normal*4).lerp(front,smoothstep(.90,1,progress))
	return {"breech":breech,"direction":direction,"normal":normal,"rear_grip":breech+direction*3+normal*5,"front_grip":support,"magazine_point":magazine_point,"magazine_visible":magazine_visible,"bolt_offset":bolt_offset}

func _draw_magazine(canvas: Node2D,point: Vector2,normal: Vector2,color := Color("485961")) -> void:
	canvas.draw_circle(point,4.6,Color("25323b",color.a))
	canvas.draw_circle(point,3.9,color)
	canvas.draw_arc(point,2.8,-PI,PI,18,Color("819596",color.a),.7,true)
	canvas.draw_line(point-normal*5,point-normal*2,Color("64746e",color.a),3,true)
	canvas.draw_circle(point,.9,Color("b4bdaf",color.a))

func draw_reload_magazine(canvas: Node2D) -> void:
	if not reloading: return
	if not equipped_weapon_id.is_empty(): return
	var pose := visual_pose()
	if pose.magazine_visible:
		_draw_magazine(canvas,pose.magazine_point,pose.normal)

func draw_weapon(canvas: Node2D) -> void:
	var pose := visual_pose()
	var breech: Vector2 = pose.breech
	var visual_direction: Vector2 = pose.direction
	var normal: Vector2 = pose.normal
	if player.grenades and player.grenades.busy():
		var gaze := player.body.facing
		breech = Vector2(-gaze*9,-34)
		visual_direction = Vector2(-gaze*.3,-.95).normalized()
		normal = Vector2(-visual_direction.y,visual_direction.x)*gaze
		canvas.draw_line(Vector2(-gaze*12,-52),Vector2(gaze*2,-26),Color("34434d"),2,true)
	elif player.pushing:
		breech = Vector2(-player.push_direction*10,-34)
		visual_direction = Vector2(-player.push_direction*.25,-.97).normalized()
		normal = Vector2(-visual_direction.y,visual_direction.x)*player.push_direction
		canvas.draw_line(Vector2(-player.push_direction*12,-52),Vector2(player.push_direction*2,-26),Color("34434d"),2,true)
	elif player.climbing:
		breech = Vector2(-2,-32)
		visual_direction = Vector2(.5,-.866)
		normal = Vector2(-visual_direction.y,visual_direction.x)
		canvas.draw_line(Vector2(-6,-48),Vector2(5,-27),Color("34434d"),2,true)
	# During reload the drum has its own background layer. A fitted drum also
	# sits behind the receiver, so insertion/completion never draws it on top.
	draw_rifle(canvas,breech,visual_direction,normal,pose.get("bolt_offset",0.0),not reloading)
	if flash_left > 0 and not player.climbing:
		var muzzle := breech+visual_direction*(muzzle_distance()+3)
		canvas.draw_colored_polygon(PackedVector2Array([muzzle-normal*5,muzzle+visual_direction*14,muzzle+normal*5]),Color("ffe5a0"))

func draw_rifle(canvas: Node2D,breech: Vector2,visual_direction: Vector2,normal: Vector2,bolt := 0.0,magazine := true) -> void:
	if not equipped_weapon_id.is_empty():
		preload("res://scripts/campaign/catalog.gd").draw_weapon(canvas,equipped_weapon_id,breech,visual_direction,normal)
		return
	# Shared silhouette for the equipped gun and the gun slung on a fallen hero.
	if magazine:
		_draw_magazine(canvas,breech+visual_direction*10+normal*5,normal)
	# A simple stock, receiver and barrel silhouette; arms are separate.
	canvas.draw_line(breech-visual_direction*11,breech,Color("64746e"),5,true)
	canvas.draw_line(breech,breech+visual_direction*16,Color("34434d"),6,true)
	canvas.draw_line(breech+visual_direction*13,breech+visual_direction*34,Color("a9b6b6"),3,true)
	canvas.draw_line(breech+visual_direction*(4+bolt)-normal*3,breech+visual_direction*(8+bolt)-normal*3,Color("a9b6b6"),1.5,true)
	canvas.draw_line(breech+visual_direction*3,breech+visual_direction*3+normal*5,Color("34434d"),3,true)

func _draw() -> void:
	var center := to_local(aim_point)
	var color := Color("81c6a7") if aiming else Color("f0c96a")
	if aiming:
		draw_circle(center,2,color)
		draw_arc(center,9,0,TAU,24,color,1.5)
		if spread_degrees() > 0:
			var radius := clampf(pivot().distance_to(aim_point)*tan(deg_to_rad(spread_degrees())),9,95)
			draw_arc(center,radius,0,TAU,32,Color(color,.45),1)
	else:
		var radius := clampf(pivot().distance_to(aim_point)*tan(deg_to_rad(spread_degrees())),7,95)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(center+direction*radius,center+direction*(radius+6),color,2)
		draw_circle(center,1.5,color)
	if kill_marker_left > 0:
		var kill_color := Color("ff997d")
		for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			draw_line(center+direction*5,center+direction*13,kill_color,3)
		draw_arc(center,19+(1-kill_marker_left/.32)*10,0,TAU,32,kill_color,1.5)
		draw_string(ThemeDB.fallback_font,center+Vector2(21,-19),"УБИТ",HORIZONTAL_ALIGNMENT_LEFT,-1,16,kill_color)
	elif hit_marker_left > 0:
		for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			draw_line(center+direction*4,center+direction*8,Color("fff0bd"),2)
	for effect in effects:
		var point := to_local(effect.point)
		if effect.get("kind","") == "magazine":
			_draw_magazine(self,point,Vector2.DOWN.rotated(effect.rotation),Color(.28,.35,.38,minf(1,effect.life/.3)))
			continue
		if effect.get("kind","") == "casing":
			var casing_direction := Vector2.RIGHT.rotated(effect.rotation)
			draw_line(point-casing_direction*2,point+casing_direction*2,Color(1,.78,.38,minf(1,effect.life/.2)),2)
			continue
		var impact_color := Color("ed8e88") if effect.target else Color("f0c96a")
		var particles := 11 if effect.killed else 7 if effect.target else 5
		for i in particles:
			var direction := Vector2.RIGHT.rotated(i*TAU/particles)
			draw_line(point+direction*3,point+direction*(4+(1-effect.life/effect.duration)*(25 if effect.killed else 12)),impact_color,2)
