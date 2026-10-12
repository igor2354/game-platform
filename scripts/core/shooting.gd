class_name CoreShootingController
extends Node2D

signal shot_fired(origin: Vector2,direction: Vector2,aimed: bool,spread_degrees: float)
signal camera_impulse(direction: Vector2,kick: float,shake: float)
var tuning: CoreShootingSettings = CoreShootingSettings.new()
var player: CoreMovementPlayer
var input_blocker: Callable
var aiming := false
var firing := false
var movement_multiplier := 1.0
var burst_time := 0.0
var bloom := 0.0
var cooldown := 0.0
var sway_clock := 0.0
var aim_point := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var aim_override := Vector2.INF # Automated tests/capture only; normal play uses mouse.
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
var hit_sounds_played := 0
var kill_sounds_played := 0
var recoil_back := 0.0
var recoil_angle := 0.0
var kill_marker_left := 0.0
var cosmetic_rng := RandomNumberGenerator.new()
var trigger_held := false
var trigger_needs_release := false
var last_fire_mode := CoreShootingSettings.FireMode.AUTO
var queued_single_press := false
const HIP_PIVOT := Vector2(0,-36)
const ADS_RAISE_TIME := .12
var ads_blend := 0.0

func _ready() -> void:
	player = get_parent() as CoreMovementPlayer
	rng.randomize()
	z_index = 5
	cosmetic_rng.randomize()
	shot_audio = _audio_player("shot",6)
	hit_audio = _audio_player("hit",4)
	kill_audio = _audio_player("kill",2)

func _audio_player(kind: String,polyphony: int) -> AudioStreamPlayer:
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = CoreCombatAudio.make_stream(kind)
	audio_player.max_polyphony = polyphony
	add_child(audio_player)
	return audio_player
func reset_state() -> void:
	aiming = false
	ads_blend = 0
	firing = false
	trigger_held = Input.is_action_pressed("core_fire")
	trigger_needs_release = false
	last_fire_mode = tuning.fire_mode
	queued_single_press = false
	movement_multiplier = 1
	burst_time = 0
	bloom = 0
	cooldown = 0
	sway_clock = 0
	shots_fired = 0
	hits = 0
	kills = 0
	hit_sounds_played = 0
	kill_sounds_played = 0
	recoil_back = 0
	recoil_angle = 0
	kill_marker_left = 0
	flash_left = 0
	hit_marker_left = 0
	effects.clear()
	if shot_audio: shot_audio.stop()
	if hit_audio: hit_audio.stop()
	if kill_audio: kill_audio.stop()
	queue_redraw()
func spread_degrees() -> float:
	return 0.0 if aiming else minf(tuning.hip_max_spread,tuning.hip_spread+bloom)
func pivot() -> Vector2:
	return player.global_position+local_pivot()
func local_pivot() -> Vector2:
	if not player.body: return HIP_PIVOT
	# The barrel sits just below the sight line; stock rests beside the cheek.
	var eye := player.body.eye_anchor()
	var raised := eye+Vector2(player.body.facing*7,3)
	return HIP_PIVOT.lerp(raised,smoothstep(0,1,ads_blend))
func look_facing() -> float:
	# Use the body centre, not the offset muzzle, to avoid flipping repeatedly
	# when the mouse is directly above/below a raised weapon.
	var horizontal := aim_point.x-player.global_position.x
	return signf(horizontal) if absf(horizontal) > 1 else player.facing
func update_state(delta: float,input_allowed: bool) -> void:
	sway_clock += delta
	cooldown = cooldown-delta if firing else maxf(0,cooldown-delta)
	flash_left = maxf(0,flash_left-delta)
	hit_marker_left = maxf(0,hit_marker_left-delta)
	kill_marker_left = maxf(0,kill_marker_left-delta)
	recoil_back *= exp(-tuning.recoil_return*delta)
	recoil_angle *= exp(-tuning.recoil_return*delta)
	for effect in effects:
		effect.life -= delta
		if effect.get("kind","") == "casing": _tick_casing(effect,delta)
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	var blocked := not input_allowed or (input_blocker.is_valid() and bool(input_blocker.call())) or player.climbing or player.dash_left > 0
	var trigger := Input.is_action_pressed("core_fire")
	if tuning.fire_mode != last_fire_mode:
		trigger_needs_release = trigger and trigger_held
		last_fire_mode = tuning.fire_mode
	if not trigger: trigger_needs_release = false
	var new_press := trigger and not trigger_held
	trigger_held = trigger
	var single_press := new_press or queued_single_press
	queued_single_press = false
	aiming = not blocked and Input.is_action_pressed("core_aim")
	ads_blend = move_toward(ads_blend,1.0 if aiming else 0.0,delta/ADS_RAISE_TIME)
	firing = not blocked and not trigger_needs_release and (trigger if tuning.fire_mode == CoreShootingSettings.FireMode.AUTO else single_press)
	burst_time = burst_time+delta if firing and not aiming else 0.0
	if not firing:
		bloom = maxf(0,bloom-tuning.spread_recovery*delta)
		# Releasing the trigger restores movement immediately and won't bank shots.
		cooldown = clampf(cooldown,0,60.0/tuning.rounds_per_minute)
	movement_multiplier = tuning.ads_move_multiplier if aiming else lerpf(1,tuning.hip_move_multiplier,minf(1,burst_time/tuning.hip_slow_ramp))
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
func _update_aim() -> void:
	var target := get_global_mouse_position() if aim_override == Vector2.INF else aim_override
	if aiming:
		var phase := sway_clock*TAU*tuning.sway_frequency
		target += Vector2(sin(phase),sin(phase*.73+.8)*.7)*tuning.sway_radius
	aim_point = target
	var offset := target-pivot()
	aim_direction = offset.normalized() if offset.length_squared() > 1 else Vector2(player.facing,0)
	if aiming or firing: player.facing = look_facing()
func finish_tick() -> void:
	# Dash and ladder entry take priority over shooting in the same frame.
	if player.climbing or player.dash_left > 0:
		aiming = false
		ads_blend = 0
		firing = false
		burst_time = 0
		movement_multiplier = 1
		return
	_update_aim()
	if firing and cooldown <= 0:
		_fire()
		# Retain fractional timing for automatic fire; single fire keeps the same
		# minimum interval and requires a fresh press after releasing the trigger.
		cooldown += 60.0/tuning.rounds_per_minute
		# A small remainder is carried by update_state while held below.
	queue_redraw()
func _fire() -> void:
	last_shot_spread = spread_degrees()
	last_shot_direction = aim_direction.rotated(deg_to_rad(rng.randf_range(-last_shot_spread,last_shot_spread))) if not aiming else aim_direction
	var muzzle := pivot()+aim_direction*34
	var query := PhysicsRayQueryParameters2D.create(pivot(),muzzle,CoreProjectile.BULLET_MASK,[player.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		CoreProjectile.resolve_impact(hit,tuning.damage,last_shot_direction,_on_impact)
	else:
		var bullet := CoreProjectile.new()
		bullet.direction = last_shot_direction
		bullet.speed = tuning.bullet_speed
		bullet.damage = tuning.damage
		bullet.shooter = player.get_rid()
		bullet.impact_callback = _on_impact
		player.get_parent().add_child(bullet)
		bullet.global_position = muzzle
		bullet.add_to_group("core_projectiles")
	shots_fired += 1
	flash_left = .045
	var recoil_scale := .55 if aiming else 1.0
	recoil_back = minf(12,recoil_back+tuning.recoil_back*recoil_scale)
	recoil_angle = minf(deg_to_rad(12),recoil_angle+deg_to_rad(tuning.recoil_angle)*recoil_scale)
	camera_impulse.emit(aim_direction,tuning.camera_kick*recoil_scale,tuning.camera_shake*recoil_scale)
	effects.append({"kind":"casing","point":pivot()-aim_direction*3,"target":false,"velocity":Vector2(-player.facing*cosmetic_rng.randf_range(45,95),-cosmetic_rng.randf_range(80,140)),"rotation":0.0,"life":.65})
	if not aiming: bloom = minf(tuning.hip_max_spread-tuning.hip_spread,bloom+tuning.spread_per_shot)
	shot_fired.emit(muzzle,last_shot_direction,aiming,last_shot_spread)
	shot_audio.volume_db = tuning.shot_volume
	shot_audio.pitch_scale = cosmetic_rng.randf_range(.96,1.04)
	shot_audio.play()
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
			kill_audio.play()
			kill_sounds_played += 1
			camera_impulse.emit(direction,tuning.camera_kick*tuning.kill_camera_boost,tuning.camera_shake*tuning.kill_camera_boost)
		else:
			hit_audio.volume_db = tuning.hit_volume
			hit_audio.pitch_scale = cosmetic_rng.randf_range(.92,1.08)
			hit_audio.play()
			hit_sounds_played += 1
	queue_redraw()
func visual_pose() -> Dictionary:
	var base := local_pivot()
	var visual_direction := aim_direction.rotated(-player.facing*recoil_angle)
	var normal := Vector2(-visual_direction.y,visual_direction.x)*player.body.facing if player.body else Vector2(-visual_direction.y,visual_direction.x)*player.facing
	var recoil := -aim_direction*recoil_back
	var breech := base+recoil
	return {"breech":breech,"direction":visual_direction,"normal":normal,"rear_grip":breech+visual_direction*3+normal*5,"front_grip":breech+visual_direction*20+normal*3}

func _draw() -> void:
	var pose := visual_pose()
	var breech: Vector2 = pose.breech
	var visual_direction: Vector2 = pose.direction
	var normal: Vector2 = pose.normal
	if player.climbing:
		breech = Vector2(-2,-32)
		visual_direction = Vector2(.5,-.866)
		normal = Vector2(-visual_direction.y,visual_direction.x)
		draw_line(Vector2(-6,-48),Vector2(5,-27),Color("34434d"),2,true)
	# A simple stock, receiver, barrel and drum silhouette; arms are separate.
	draw_line(breech-visual_direction*11,breech,Color("64746e"),5,true)
	draw_line(breech,breech+visual_direction*16,Color("34434d"),6,true)
	draw_line(breech+visual_direction*13,breech+visual_direction*34,Color("a9b6b6"),3,true)
	draw_circle(breech+visual_direction*10+normal*5,4,Color("485961"))
	draw_line(breech+visual_direction*3,breech+visual_direction*3+normal*5,Color("34434d"),3,true)
	if flash_left > 0 and not player.climbing:
		var muzzle := breech+visual_direction*37
		draw_colored_polygon(PackedVector2Array([muzzle-normal*5,muzzle+visual_direction*14,muzzle+normal*5]),Color("ffe5a0"))
	var center := to_local(aim_point)
	var color := Color("81c6a7") if aiming else Color("f0c96a")
	if aiming:
		draw_circle(center,2,color)
		draw_arc(center,9,0,TAU,24,color,1.5)
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
		if effect.get("kind","") == "casing":
			var casing_direction := Vector2.RIGHT.rotated(effect.rotation)
			draw_line(point-casing_direction*2,point+casing_direction*2,Color(1,.78,.38,minf(1,effect.life/.2)),2)
			continue
		var impact_color := Color("ed8e88") if effect.target else Color("f0c96a")
		var particles := 11 if effect.killed else 7 if effect.target else 5
		for i in particles:
			var direction := Vector2.RIGHT.rotated(i*TAU/particles)
			draw_line(point+direction*3,point+direction*(4+(1-effect.life/effect.duration)*(25 if effect.killed else 12)),impact_color,2)
