extends SceneTree

var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var noises: Array[Dictionary] = []
const ACTIONS := ["core_left","core_right","core_up","core_down","core_dash","core_jump","core_fire","core_aim"]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func reset_encounter(offset := 450.0) -> void:
	for action in ACTIONS: Input.action_release(action)
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.tuning.detection_range = 32
	zombie.tuning.forget_range = 32
	zombie.reset_target()
	hero.reset_to(zombie.home+Vector2(offset,0))
	noises.clear()
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	zombie = lab.level.zombie
	hero = lab.player
	hero.noise_emitted.connect(func(point: Vector2,loudness: float,kind: String): noises.append({"point":point,"loudness":loudness,"kind":kind}))
	await frames(8)
	reset_encounter(120)
	await frames(20)
	check(zombie.state == CoreZombie.State.PATROL and zombie.heard_noise_count == 0 and not zombie.sees_player(360),"a stationary player behind the zombie remains unnoticed and produces no noise")
	reset_encounter()
	var every_direction := true
	for index in 8:
		var point := zombie.eye_point()+Vector2.from_angle(index*TAU/8)*40
		every_direction = zombie.hear_noise(point,1,"step") and every_direction
	check(every_direction and zombie.heard_noise_count == 8,"hearing receives noise from all eight directions around the head")
	check(not zombie.hear_noise(zombie.eye_point()+Vector2(-181,0),1,"step"),"a sound outside its effective radius is not heard")
	reset_encounter()
	var source := zombie.eye_point()+Vector2(150,0)
	check(zombie.hear_noise(source,1,"step") and zombie.state == CoreZombie.State.INVESTIGATE and zombie.last_heard_position == source,"a noise behind the head starts investigation of that exact location")
	await frames(8)
	check(zombie.facing > 0 and zombie.position.x > zombie.home.x and is_equal_approx(zombie.velocity.x,zombie.tuning.patrol_speed),"the zombie turns and moves towards the sound rather than the unseen player's current position")
	hero.reset_to(Vector2(160,760))
	var remembered := zombie.last_heard_position
	await frames(8)
	check(zombie.last_heard_position == remembered and zombie.facing > 0,"moving the silent player does not move the remembered sound source")
	zombie.tuning.noise_memory_time = .1
	zombie.apply_tuning()
	await frames(8)
	check(zombie.state == CoreZombie.State.RETURN and zombie.noise_memory_left == 0,"expired noise memory returns the zombie towards its patrol")
	reset_encounter()
	zombie.hear_noise(zombie.eye_point()+Vector2(-100,0),1,"step")
	var second := zombie.eye_point()+Vector2(100,0)
	zombie.hear_noise(second,1,"step")
	await frames(4)
	check(zombie.last_heard_position == second and zombie.facing > 0,"a fresh noise updates the investigation location")
	reset_encounter()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20,120)
	shape.shape = rectangle
	wall.position = zombie.home+Vector2(80,-60)
	wall.add_child(shape)
	lab.get_node("World").add_child(wall)
	source = zombie.eye_point()+Vector2(150,0)
	await frames(2)
	check(not zombie.hear_noise(source,1,"step") and zombie.heard_noise_count == 0,"a wall attenuates quiet movement below the hearing threshold")
	check(zombie.hear_noise(source,1,"shot"),"a louder shot at the same location remains audible through the wall")
	zombie.tuning.noise_occlusion_multiplier = 0
	check(not zombie.hear_noise(source,1,"shot"),"zero occluded audibility makes the wall block even gunshots")
	zombie.tuning.noise_occlusion_multiplier = 1
	check(zombie.hear_noise(source,1,"step"),"full occluded audibility restores the base circular radius")
	wall.queue_free()
	await frames(2)
	reset_encounter()
	zombie.tuning.hearing_range = 0
	check(not zombie.hear_noise(zombie.eye_point(),1,"shot") and zombie.heard_noise_count == 0,"zero hearing range completely disables hearing")
	zombie.tuning.hearing_range = 180
	zombie.tuning.shot_noise_multiplier = 0
	check(not zombie.hear_noise(zombie.eye_point()+Vector2(50,0),1,"shot") and zombie.hear_noise(zombie.eye_point()+Vector2(50,0),1,"step"),"gunshot hearing can be disabled independently of movement")
	zombie.tuning.movement_noise_multiplier = 0
	check(not zombie.hear_noise(zombie.eye_point(),2,"dash"),"movement hearing can be disabled independently")
	reset_encounter()
	check(not zombie.hear_noise(Vector2(NAN,0),1,"step") and not zombie.hear_noise(zombie.eye_point(),INF,"shot") and not zombie.hear_noise(zombie.eye_point(),-1,"step"),"invalid sound coordinates and loudness are ignored")
	paused = true
	check(not zombie.hear_noise(zombie.eye_point(),1,"shot") and zombie.heard_noise_count == 0,"a paused world cannot receive noise events")
	paused = false
	zombie.take_damage(100)
	check(not zombie.hear_noise(zombie.eye_point(),1,"shot"),"a dead zombie does not react to noise")
	reset_encounter()
	zombie.hear_noise(zombie.eye_point()+Vector2(100,0),1,"step")
	paused = true
	var memory := zombie.noise_memory_left
	var position := zombie.position
	await frames(20)
	check(zombie.noise_memory_left == memory and zombie.position == position,"pause freezes an ongoing sound investigation and its memory timer")
	paused = false
	lab.respawn_enemies_button.pressed.emit()
	check(zombie.state == CoreZombie.State.PATROL and zombie.noise_memory_left == 0 and zombie.heard_noise_count == 0 and zombie.last_heard_kind == "","enemy respawn clears heard events and restores the original patrol")
	# Actual weapon and movement events go through the lab, not just direct calls.
	reset_encounter(220)
	hero.weapon.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	hero.weapon.aim_override = zombie.home+Vector2(1000,-36)
	await frames(8)
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	check(hero.weapon.shots_fired == 1 and zombie.heard_noise_count > 0 and zombie.last_heard_kind == "shot" and zombie.last_heard_position.x > zombie.home.x,"a real single shot is heard behind the zombie and records its muzzle position")
	reset_encounter(60)
	await frames(8)
	Input.action_press("core_right")
	await frames(30)
	Input.action_release("core_right")
	check(noises.any(func(noise: Dictionary): return noise.kind == "step") and zombie.heard_noise_count > 0,"actual running emits spaced footstep events audible behind the zombie")
	await frames(12)
	var count := noises.size()
	await frames(20)
	check(noises.size() == count,"a stationary player does not produce continuous footstep noise")
	reset_encounter(100)
	await frames(8)
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(3)
	Input.action_release("core_dash")
	Input.action_release("core_right")
	check(noises.size() == 1 and noises[0].kind == "dash" and zombie.last_heard_kind == "dash" and hero.health == 100,"a dash emits one loud event and remains invulnerable while alerting the enemy")
	reset_encounter()
	hero.reset_to(Vector2(1446,760))
	await frames(8)
	Input.action_press("core_up")
	await frames(25)
	Input.action_release("core_up")
	check(noises.any(func(noise: Dictionary): return noise.kind == "ladder"),"climbing a ladder emits noise based on actual distance climbed")
	reset_encounter()
	hero.reset_to(Vector2(300,650))
	await frames(35)
	check(noises.any(func(noise: Dictionary): return noise.kind == "land"),"a substantial landing emits an impact noise")
	reset_encounter(-48)
	zombie.tuning.detection_range = 360
	await frames(4)
	var phase_time := zombie.state_left
	var look := zombie.facing
	zombie.hear_noise(zombie.eye_point()+Vector2(120,0),1,"shot")
	check(zombie.state == CoreZombie.State.WINDUP and zombie.facing == look and zombie.state_left == phase_time,"noise cannot rotate or cancel an already committed melee windup")
	hero.reset_to(zombie.home+Vector2(450,0))
	await frames(80)
	check(zombie.state == CoreZombie.State.INVESTIGATE and zombie.facing > 0,"after attack recovery a remembered noise can resume investigation")
	# Cone displacement affects both mirrored directions and actual detection.
	reset_encounter()
	zombie.set_physics_process(false)
	hero.set_physics_process(false)
	var overlay := lab.zombie_overlay
	overlay.toggle()
	for look_direction in [-1.0,1.0]:
		zombie.facing = look_direction
		zombie.tuning.detection_range = 100
		overlay.rows.vision_offset_x.slider.value = 0
		hero.global_position = zombie.eye_point()+Vector2(look_direction*130,32)
		check(not zombie.sees_player(100),"an unshifted cone cannot reach the test player when facing %.0f" % look_direction)
		overlay.rows.vision_offset_x.slider.value = 40
		check(zombie.sees_player(100) and zombie.vision_origin().is_equal_approx(zombie.eye_point()+Vector2(look_direction*40,0)),"positive X shifts the real cone forward with facing %.0f" % look_direction)
		overlay.rows.vision_offset_x.number.value = -40
		check(not zombie.sees_player(100) and overlay.rows.vision_offset_x.slider.value == -40,"negative X shifts the real cone back with facing %.0f" % look_direction)
	overlay.rows.hearing_range.slider.value = 300
	overlay.tabs.current_tab = 1
	check(zombie.tuning.hearing_range == 300 and overlay.readout.text.contains("1200"),"F6 hearing controls update the listener and calculated gunshot radius")
	wall = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	shape = CollisionShape2D.new()
	rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(16,120)
	shape.shape = rectangle
	wall.position = zombie.home+Vector2(40,-60)
	wall.add_child(shape)
	lab.get_node("World").add_child(wall)
	overlay.rows.vision_offset_x.slider.value = 80
	await frames(2)
	check(not zombie.sees_player(100),"shifting the cone past a wall cannot bypass occlusion at the physical head")
	wall.queue_free()
	await frames(2)
	hero.set_physics_process(true)
	zombie.set_physics_process(true)
	reset_encounter()
	hero.weapon.shot_audio.stop()
	hero.weapon.hit_audio.stop()
	hero.weapon.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
