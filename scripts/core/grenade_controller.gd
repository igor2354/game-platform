class_name CoreGrenadeController
extends Node2D
## T readies/holsters an unarmed grenade. LMB starts its fuse and charges;
## release throws it. A burning fuse cannot be holstered or restarted.
var player: CoreMovementPlayer
var tuning: CoreRagdollSettings
var held_grenade: CoreGrenade
var charging := false
var charge := 0.0
var throw_progress := 0.0
var throw_direction := Vector2.RIGHT
var count := 5
var throws := 0
var last_launch := {}
var trajectory := PackedVector2Array()
var trajectory_hit := false
var trigger_held := false
var needs_release := false
func _ready() -> void:
	z_index = 6
func preparing() -> bool:
	return is_instance_valid(held_grenade) and not held_grenade.detonated
func busy() -> bool: return preparing() or throw_progress > 0
func refill() -> void:
	count = roundi(tuning.grenade_starting_count) if tuning else 5
func reset_state() -> void:
	if preparing():
		held_grenade.set_physics_process(false)
		held_grenade.queue_free()
	held_grenade = null
	charging = false
	charge = 0
	throw_progress = 0
	throws = 0
	last_launch.clear()
	trajectory.clear()
	trigger_held = Input.is_action_pressed("core_fire")
	needs_release = trigger_held
	refill()
func prepare() -> bool:
	if not tuning or not tuning.grenades_enabled or preparing() or count <= 0 or get_tree().paused or player.health <= 0 or player.pushing or player.climbing or player.parkour_active() or player.dash_left > 0 or player.slide_left > 0 or player.barrel_knockdown_left > 0 or (is_instance_valid(player.blast_ragdoll) and player.blast_ragdoll.active): return false
	player.weapon.cancel_reload()
	player.weapon.firing = false
	player.weapon.aiming = false
	player.weapon.ads_blend = 0
	player.weapon.queued_single_press = false
	player.weapon.recoil_kick_offset = Vector2.ZERO
	player.weapon.recoil_drift_offset = Vector2.ZERO
	player.weapon.recoil_back = 0
	player.weapon.recoil_angle = 0
	player.weapon.recoil_climb = 0
	player.weapon.recoil_horizontal = 0
	player.weapon.flash_left = 0
	var grenade: CoreGrenade = load("res://scenes/core/grenade.tscn").instantiate()
	grenade.tuning = tuning
	grenade.instigator = player
	grenade.controller = self
	player.get_parent().add_child(grenade)
	held_grenade = grenade
	charge = 0
	charging = false
	count -= 1
	needs_release = Input.is_action_pressed("core_fire")
	trigger_held = needs_release
	grenade.global_position = launch_origin()
	player.body.update_arms()
	_refresh_trajectory()
	return true
func toggle_preparation() -> bool:
	return holster() if preparing() else prepare()
func holster() -> bool:
	if not preparing() or held_grenade.fuse_started or get_tree().paused: return false
	held_grenade.set_physics_process(false)
	held_grenade.hide()
	held_grenade.queue_free()
	held_grenade = null
	count += 1
	charging = false
	charge = 0
	throw_progress = 0
	trajectory.clear()
	trajectory_hit = false
	trigger_held = Input.is_action_pressed("core_fire")
	needs_release = trigger_held
	# Returning to the gun must not turn a held grenade input into a shot.
	player.weapon.trigger_needs_release = trigger_held
	player.weapon.queued_single_press = false
	player.body.update_arms()
	queue_redraw()
	return true
func input_trigger(pressed: bool) -> void:
	if not preparing() or not tuning.grenades_enabled: return
	if pressed:
		if not needs_release:
			held_grenade.start_fuse()
			charging = true
			charge = 0
	elif charging:
		charging = false
		throw_held()
	if not pressed: needs_release = false
	trigger_held = pressed
func cancel_charge() -> void:
	charging = false
	charge = 0
	needs_release = Input.is_action_pressed("core_fire")
	trigger_held = needs_release
func power() -> float:
	return clampf(charge/maxf(.01,tuning.grenade_charge_time),0,1) if tuning else 0
func launch_velocity() -> Vector2:
	var raw := player.weapon.cursor_point()-(player.global_position-Vector2(0,player.collision_height()*.65))
	var direction := raw.normalized() if raw.length_squared() > 1 else Vector2(player.weapon.look_facing(),0)
	direction = direction.rotated(-signf(direction.x)*deg_to_rad(tuning.grenade_lob_angle)*absf(direction.x))
	var low := minf(tuning.grenade_min_speed,tuning.grenade_max_speed)
	var high := maxf(tuning.grenade_min_speed,tuning.grenade_max_speed)
	return direction*lerpf(low,high,power())
func hand_point(side := "near") -> Vector2:
	var gaze := player.weapon.look_facing()
	var upper := player.collision_height()*.74
	var local := Vector2(gaze*(15-10*power()),-upper-7*power())
	if throw_progress > 0:
		local = Vector2(gaze*12,-upper).lerp(throw_direction*31+Vector2(0,-upper+6),sin(throw_progress*PI))
	if side == "far": local += Vector2(gaze*4,5)
	return local
func launch_origin() -> Vector2:
	var origin := player.global_position+hand_point()
	var chest := player.global_position-Vector2(0,player.collision_height()*.6)
	var shape := CircleShape2D.new()
	shape.radius = tuning.grenade_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,chest)
	query.motion = origin-chest
	query.collision_mask = 1|8
	query.exclude = [player.get_rid()]
	var fractions := get_world_2d().direct_space_state.cast_motion(query)
	if fractions[0] < 1: origin = chest+query.motion*maxf(0,fractions[0]-.02)
	return origin
func throw_held(drop := false) -> bool:
	if not preparing() or not tuning.grenades_enabled or get_tree().paused: return false
	var grenade := held_grenade
	var point := launch_origin()
	var velocity := Vector2.ZERO if drop else launch_velocity()
	last_launch = {"point":point,"velocity":velocity,"fuse":grenade.fuse_left,"gravity":tuning.grenade_gravity}
	throw_direction = velocity.normalized() if velocity.length() > 0 else Vector2(player.facing,0)
	throw_progress = .001 if not drop else 0.0
	grenade.launch(point,velocity)
	held_grenade = null
	charge = 0
	charging = false
	throws += 1
	trajectory.clear()
	player.weapon.trigger_needs_release = Input.is_action_pressed("core_fire")
	player.weapon.queued_single_press = false
	queue_redraw()
	return true
func on_grenade_finished(grenade: CoreGrenade) -> void:
	if grenade == held_grenade:
		held_grenade = null
		charging = false
		charge = 0
		trajectory.clear()
		player.weapon.trigger_needs_release = Input.is_action_pressed("core_fire")
		player.weapon.queued_single_press = false
	queue_redraw()
func predict_path(point: Vector2,velocity: Vector2,seconds: float) -> PackedVector2Array:
	var points := PackedVector2Array([point])
	trajectory_hit = false
	var step := 1.0/Engine.physics_ticks_per_second
	var shape := CircleShape2D.new()
	shape.radius = tuning.grenade_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 1|2|4|8|128
	var excluded: Array[RID] = [player.get_rid()]
	if preparing(): excluded.append(held_grenade.get_rid())
	query.exclude = excluded
	for index in mini(900,ceili(seconds/step)):
		query.transform = Transform2D(0,point)
		query.motion = velocity*step
		var fractions := get_world_2d().direct_space_state.cast_motion(query)
		point += query.motion*fractions[0]
		points.append(point)
		velocity += Vector2(0,tuning.grenade_gravity*step)
		if fractions[0] < 1:
			trajectory_hit = true
			break
	return points
func _refresh_trajectory() -> void:
	trajectory.clear()
	if preparing() and tuning.grenade_trajectory_enabled:
		trajectory = predict_path(launch_origin(),launch_velocity(),maxf(0,held_grenade.fuse_left))
	queue_redraw()
func _physics_process(delta: float) -> void:
	if throw_progress > 0:
		throw_progress += delta/.32
		if throw_progress >= 1: throw_progress = 0
	if not preparing():
		queue_redraw()
		return
	if player.health <= 0:
		throw_held(true)
		return
	var blocked := (player.weapon.input_blocker.is_valid() and bool(player.weapon.input_blocker.call())) or not tuning.grenades_enabled
	var pressed := Input.is_action_pressed("core_fire")
	if blocked: cancel_charge()
	else:
		if pressed != trigger_held: input_trigger(pressed)
		if charging: charge = minf(charge+delta,tuning.grenade_charge_time)
	if preparing(): held_grenade.global_position = launch_origin()
	_refresh_trajectory()
func _process(_delta: float) -> void:
	# Aim may update on render frames faster than the physics clock.
	if preparing() and not get_tree().paused: _refresh_trajectory()
func _draw() -> void:
	if not preparing(): return
	var point := to_local(launch_origin())
	var color := Color("ff7d62") if held_grenade.fuse_started and held_grenade.fuse_left <= 1 else Color("f0c96a")
	var status := "%.1f с · %d%%" % [maxf(0,held_grenade.fuse_left),roundi(power()*100)] if held_grenade.fuse_started else "ЛКМ — бросок"
	draw_string(ThemeDB.fallback_font,point+Vector2(-28,-27),status,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
	if trajectory.size() < 2: return
	for index in range(1,trajectory.size()):
		if index%5 < 3: draw_line(to_local(trajectory[index-1]),to_local(trajectory[index]),Color(color,.8),1.6,true)
	var end := to_local(trajectory[-1])
	draw_arc(end,7,0,TAU,24,color,1.5,true)
	draw_line(end-Vector2(10,0),end+Vector2(10,0),color,1,true)
	if not trajectory_hit: draw_circle(end,3,Color("ff7d62"))
