extends SceneTree

var lab: CoreMovementLab
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
	for tick in count: await physics_frame
func settle(point: Vector2,lost_leg := "left_leg") -> void:
	zombie.set_physics_process(true)
	zombie.home = point
	zombie.reset_target()
	zombie.tuning.apply_values({"detection_range":32,"forget_range":32,"hearing_range":0,"patrol_radius":600,"crawl_speed":100,"crawl_max_angle":45,"crawl_uphill_multiplier":1,"crawl_downhill_multiplier":1,"crawl_step_height":12})
	zombie.take_projectile_hit(50,lost_leg)
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	await frames(30)
func move(direction: float) -> void:
	zombie.home = zombie.global_position+Vector2(direction*300,0)
	if zombie.is_prone():
		zombie.state = CoreZombie.State.INVESTIGATE
		zombie.last_heard_position = zombie.global_position+Vector2(direction*1200,0)
		zombie.noise_memory_left = 500
	else:
		zombie.state = CoreZombie.State.PATROL
		zombie.patrol_direction = direction
func measured_speed(direction: float) -> float:
	move(direction)
	await frames(8)
	var origin := zombie.global_position
	await frames(12)
	return zombie.global_position.distance_to(origin)/(12*zombie.get_physics_process_delta_time())
func investigate_right() -> void:
	zombie.state = CoreZombie.State.INVESTIGATE
	zombie.last_heard_position = zombie.global_position+Vector2(500,0)
	zombie.noise_memory_left = 500
func step_at(x: float,height: float,width := 80.0) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width,height)
	shape.shape = rectangle
	shape.position = Vector2(x+width*.5,760-height*.5)
	body.add_child(shape)
	lab.level.add_child(body)
	return body
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	zombie = lab.level.zombie
	lab.player.reset_to(Vector2(160,760))
	await frames(8)
	for index in 2:
		var points := lab.level.slopes[index]
		var angle := 20 if index == 0 else 35
		for direction in [1.0,-1.0]:
			var start := Vector2(points[0].x-40 if direction > 0 else points[3].x+40,760)
			var finish := points[3].x+30 if direction > 0 else points[0].x-30
			await settle(start,"left_leg" if direction > 0 else "right_leg")
			move(direction)
			var airborne := 0
			var top := zombie.global_position.y
			var reached := false
			for tick in 1600:
				await physics_frame
				if not zombie.is_on_floor(): airborne += 1
				top = minf(top,zombie.global_position.y)
				if (zombie.global_position.x-finish)*direction >= 0:
					reached = true
					break
			check(reached and top < points[1].y+5,"crawler traverses %d° ascent, crest and descent in direction %.0f (x %.1f, top %.1f)" % [angle,direction,zombie.global_position.x,top])
			check(airborne <= 2,"crawler keeps ground contact over %d° transitions (air frames %d)" % [angle,airborne])
		for side in [0,2]:
			var middle := points[side].lerp(points[side+1],.5)-Vector2(0,12)
			await settle(middle)
			check(zombie.is_on_floor() and absf(rad_to_deg(zombie.rotation)) > angle-1,"prone body and anatomical areas follow %d° ramp %d" % [angle,side])
			var rest := zombie.global_position
			await frames(30)
			check(zombie.global_position.distance_to(rest) < .2,"stopped crawler does not slide on %d° ramp %d" % [angle,side])
			for direction in [1.0,-1.0]:
				await settle(middle)
				zombie.tuning.apply_values({"crawl_uphill_multiplier":.5,"crawl_downhill_multiplier":1.5})
				var uphill: bool = (side == 0 and direction > 0) or (side == 2 and direction < 0)
				var expected := 100*(1+(-.5 if uphill else .5)*angle/45.0)
				var speed := await measured_speed(direction)
				check(absf(speed-expected) < 4,"surface crawl speed on %d° ramp %d direction %.0f: %.1f expected %.1f" % [angle,side,direction,speed,expected])
				zombie.tuning.apply_values({"crawl_uphill_multiplier":1,"crawl_downhill_multiplier":1})
				var origin := zombie.global_position
				await frames(12)
				speed = zombie.global_position.distance_to(origin)/(12*zombie.get_physics_process_delta_time())
				check(absf(speed-100) < 4 and zombie.is_on_floor(),"live 1× settings restore surface speed without resetting the wounded enemy")
			if index == 1:
				zombie.set_physics_process(false)
				await frames(2)
				var head := zombie.aim_point_for_part("head")
				var bullet := CoreProjectile.new()
				bullet.position = zombie.to_global(zombie.part_rect("head").get_center()-Vector2(0,80))
				bullet.direction = (head-bullet.position).normalized()
				bullet.speed = 4000
				bullet.damage = 10
				bullet.shooter = lab.player.get_rid()
				lab.get_node("World").add_child(bullet)
				await frames(4)
				check(zombie.health == 62.5 and zombie.last_hit_part == "head","rotated head hitbox matches the prone silhouette on ramp %d" % side)
		# Standing zombies retain their ordinary terrain traversal.
		zombie.set_physics_process(true)
		zombie.home = Vector2(points[0].x-40,760)
		zombie.reset_target()
		zombie.tuning.patrol_speed = 100
		zombie.state = CoreZombie.State.RECOVERY
		zombie.state_left = 100
		await frames(20)
		move(1)
		var standing_reached := false
		for tick in 1200:
			await physics_frame
			if zombie.global_position.x > points[3].x+30:
				standing_reached = true
				break
		check(standing_reached and zombie.rotation == 0 and not zombie.is_prone(),"standing zombie still traverses the %d° hill without tilting its upright body" % angle)
	# The limit stops traversal, then changing it releases the same crawler.
	await settle(Vector2(4020,760))
	zombie.tuning.crawl_max_angle = 25
	investigate_right()
	await frames(180)
	check(zombie.global_position.x < 4070 and zombie.global_position.y > 745,"a 25° crawl limit rejects the 35° hill (%.1f, %.1f)" % [zombie.global_position.x,zombie.global_position.y])
	zombie.tuning.crawl_max_angle = 40
	investigate_right()
	await frames(150)
	check(zombie.global_position.x > 4100 and zombie.global_position.y < 740,"raising the angle immediately enables the blocked hill (%.1f, %.1f)" % [zombie.global_position.x,zombie.global_position.y])
	zombie.tuning.crawl_max_angle = 10
	var stopped := zombie.global_position
	await frames(20)
	check(zombie.global_position.distance_to(stopped) < 1,"lowering the angle while on a hill holds position rather than dropping the enemy")
	# Actual vertical steps use pixels independently of the slope angle.
	var step := step_at(5120,8)
	await settle(Vector2(5050,760))
	zombie.tuning.crawl_step_height = 10
	move(1)
	await frames(125)
	check(zombie.global_position.x > 5220 and zombie.is_on_floor(),"crawler climbs and descends an allowed 8 px step (x %.1f y %.1f)" % [zombie.global_position.x,zombie.global_position.y])
	await settle(Vector2(5260,760))
	zombie.tuning.crawl_step_height = 10
	move(-1)
	await frames(125)
	check(zombie.global_position.x < 5100 and zombie.is_on_floor(),"step traversal also works when the crawler faces left")
	await settle(Vector2(5050,760))
	zombie.tuning.crawl_step_height = 0
	investigate_right()
	await frames(90)
	check(zombie.global_position.x < 5120 and zombie.global_position.y > 758,"zero step height disables climbing a vertical step")
	step.queue_free()
	await frames(2)
	step = step_at(5120,20)
	await settle(Vector2(5050,760))
	zombie.tuning.crawl_step_height = 8
	investigate_right()
	await frames(100)
	check(zombie.global_position.x < 5120 and zombie.global_position.y > 755,"an excessive vertical step is not bypassed despite its flat top")
	zombie.tuning.crawl_step_height = 24
	investigate_right()
	await frames(130)
	check(zombie.global_position.x > 5220 and zombie.is_on_floor(),"raising step height allows the same 20 px obstacle")
	var ceiling := step_at(5090,20,150)
	ceiling.position.y -= 40
	await settle(Vector2(5050,760))
	zombie.tuning.crawl_step_height = 24
	investigate_right()
	await frames(100)
	check(zombie.global_position.x < 5120 and zombie.global_position.y > 755,"step helper respects a low ceiling rather than moving through it")
	ceiling.queue_free()
	step.queue_free()
	await frames(2)
	await settle(Vector2(3140,760))
	zombie.tuning.crawl_max_angle = 0
	investigate_right()
	await frames(90)
	check(zombie.global_position.x < 3180 and zombie.global_position.y > 758,"zero-degree setting allows flat ground but blocks even the 20° ramp")
	# A higher configured limit must support terrain beyond the old 46° limit.
	var steep := StaticBody2D.new()
	steep.collision_layer = 1
	steep.collision_mask = 0
	var polygon := CollisionPolygon2D.new()
	var rise := 120*tan(deg_to_rad(50))
	polygon.polygon = PackedVector2Array([Vector2(5100,760),Vector2(5220,760-rise),Vector2(5300,760-rise),Vector2(5420,760),Vector2(5420,860),Vector2(5100,860)])
	steep.add_child(polygon)
	lab.level.add_child(steep)
	await settle(Vector2(5050,760))
	zombie.tuning.crawl_max_angle = 45
	investigate_right()
	await frames(90)
	check(zombie.global_position.x < 5110 and zombie.global_position.y > 749,"default limit rejects a real 50° ramp")
	zombie.tuning.crawl_max_angle = 60
	investigate_right()
	var reached := false
	for tick in 700:
		await physics_frame
		if zombie.global_position.x > 5450:
			reached = true
			break
	check(reached and zombie.is_on_floor(),"60° setting enables traversal of the 50° ascent, crest and descent (%.1f, %.1f)" % [zombie.global_position.x,zombie.global_position.y])
	steep.queue_free()
	await frames(2)
	await settle(Vector2(925,760))
	move(1)
	await frames(80)
	check(zombie.global_position.x > 960 and zombie.global_position.y > 800,"alerted crawler enters the jump-test pit instead of avoiding the drop or stepping over it")
	await settle(Vector2(5100,760))
	for part in ["left_arm","right_arm"]: zombie.take_projectile_hit(50,part)
	move(1)
	var no_arms := zombie.global_position
	await frames(20)
	check(zombie.global_position.distance_to(no_arms) < .2 and zombie.health > 0,"terrain helpers cannot move a living crawler without arms")
	paused = true
	var frozen := zombie.global_position
	lab.zombie_overlay.rows.crawl_max_angle.slider.value = 50
	await frames(3)
	check(zombie.global_position == frozen and zombie.tuning.crawl_max_angle == 50,"crawl settings are editable during pause without moving the body")
	paused = false
	zombie.reset_target()
	check(zombie.rotation == 0 and zombie.body_shape.shape is RectangleShape2D and zombie.health == 100,"respawn restores the upright collider, pose and anatomy")
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
