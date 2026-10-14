extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func place_target(point: Vector2) -> void:
	hero.global_position = point+Vector2(0,hero.collision_height()*.5)
func settle(point: Vector2,prone: bool) -> void:
	zombie.set_physics_process(true)
	hero.reset_to(CoreMovementLevel.SPAWN)
	zombie.home = point
	zombie.reset_target()
	if prone: zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	zombie.tuning.vision_angle = 30
	zombie.tuning.vision_offset_x = 0
	await frames(20)
	zombie.set_physics_process(false)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	hero.set_physics_process(false)
	for hill in lab.level.slopes:
		for side in [0,2]:
			var tangent: Vector2 = (hill[side+1]-hill[side]).normalized()
			var normal := Vector2(tangent.y,-tangent.x)
			for prone in [false,true]:
				await settle(hill[side].lerp(hill[side+1],.5)-Vector2(0,12),prone)
				for look in [1.0,-1.0]:
					zombie.facing = look
					zombie._sync_zones()
					var forward: Vector2 = tangent*float(look)
					var label := "slope %.0f side %d prone %s look %.0f" % [absf(rad_to_deg(tangent.angle())),side,prone,look]
					check(zombie.is_on_floor() and zombie.vision_direction().distance_to(forward) < .001,"world gaze follows the actual slope once: "+label)
					var point := zombie.vision_origin()+forward*120+normal*24
					place_target(point)
					check(zombie._clear_sight(zombie.eye_point(),point) and zombie.sees_player(360),"a target along the slope is visible through the narrow cone: "+label)
					point = zombie.vision_origin()+forward.rotated(-look*deg_to_rad(20))*120
					place_target(point)
					check(zombie._clear_sight(zombie.eye_point(),point) and not zombie.sees_player(360),"a clear target outside the tilted cone is rejected: "+label)
					place_target(zombie.vision_origin()-forward*60)
					check(not zombie.sees_player(360),"a target behind the slope gaze remains unseen: "+label)
					for offset in [-30.0,30.0]:
						zombie.tuning.vision_offset_x = offset
						check(zombie.vision_origin().distance_to(zombie.eye_point()+forward*offset) < .001,"cone X offset follows tilted gaze: "+label+" offset "+str(offset))
					zombie.tuning.vision_offset_x = 0
	# The same observer updates from hill to level ground and to free fall.
	await settle(Vector2(5000,760),false)
	zombie.facing = -1
	check(zombie.vision_direction() == Vector2.LEFT,"flat ground restores horizontal gaze")
	zombie.set_physics_process(true)
	zombie.global_position = Vector2(5000,500)
	await frames(3)
	zombie.set_physics_process(false)
	check(not zombie.is_on_floor() and zombie.vision_direction() == Vector2.LEFT,"airborne gaze does not retain a stale floor tilt")
	# Check dynamic updates on one uninterrupted ascent, crest and descent.
	var transition_hill := lab.level.slopes[1]
	for prone in [false,true]:
		await settle(transition_hill[0].lerp(transition_hill[1],.85)-Vector2(0,12),prone)
		zombie.tuning.apply_values({"detection_range":32,"forget_range":32,"patrol_speed":100,"crawl_speed":100})
		zombie.state = CoreZombie.State.INVESTIGATE
		zombie.last_heard_position = zombie.global_position+Vector2(600,0)
		zombie.noise_memory_left = 15
		zombie.set_physics_process(true)
		var ascent := false
		var crest := false
		var descent := false
		for i in 200:
			await frames(1)
			var gaze := zombie.vision_direction()
			if zombie.is_on_floor():
				if zombie.position.x < transition_hill[1].x-20: ascent = ascent or gaze.y < -.4
				if zombie.position.x > transition_hill[1].x+20 and zombie.position.x < transition_hill[2].x-20: crest = crest or absf(gaze.y) < .03
				if zombie.position.x > transition_hill[2].x+20: descent = descent or gaze.y > .4
			if ascent and crest and descent: break
		check(ascent and crest and descent,"moving gaze updates uphill, across the flat crest and downhill: prone "+str(prone))
		zombie.set_physics_process(false)
	# Displacing the virtual cone must still respect the ray from the head.
	var hill := lab.level.slopes[1]
	await settle(hill[0].lerp(hill[1],.5)-Vector2(0,12),false)
	zombie.facing = 1
	var forward := zombie.vision_direction()
	var eye := zombie.eye_point()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,100)
	collision.shape = rectangle
	wall.add_child(collision)
	wall.position = eye+forward*40
	lab.level.add_child(wall)
	await frames(2)
	zombie.tuning.vision_offset_x = 80
	place_target(eye+forward*110)
	check(not zombie.sees_player(360),"offsetting a slope cone past a wall cannot grant head wall vision")
	wall.queue_free()
	await frames(2)
	check(zombie.sees_player(360),"removing the wall restores visibility along the slope")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
