extends SceneTree
var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
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
func settle(point: Vector2,move: float,prone: bool,target_point: Vector2) -> void:
	hero.reset_to(target_point)
	zombie.home = point
	zombie.reset_target()
	zombie.tuning.apply_values({"detection_range":360,"forget_range":540,"lose_sight_delay":5,"damage_memory_time":5,"hearing_range":180,"patrol_radius":600,"chase_speed":105,"patrol_speed":100,"crawl_speed":100,"crawl_max_angle":0,"crawl_step_height":0})
	if prone: zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	zombie.facing = move
	await frames(10)
func pit(move: float,prone: bool,source: String) -> void:
	var start := Vector2(925 if move > 0 else 1195,760)
	var target_point := Vector2(1240 if move > 0 else 880,760)
	await settle(start,move,prone,target_point)
	var label := "direction %.0f prone %s source %s" % [move,prone,source]
	zombie.state = CoreZombie.State.WAIT if prone else CoreZombie.State.PATROL
	zombie.state_left = 0
	if source != "vision":
		zombie.tuning.apply_values({"detection_range":32,"forget_range":32})
		if source == "noise":
			check(zombie.hear_noise(target_point-Vector2(0,32),1,"shot"),"shot noise activates a search across the pit: "+label)
		else:
			zombie.take_projectile_hit(1,"torso",Vector2(move,0),target_point)
	var fell := false
	var pursuit_alive := false
	for i in 150:
		await frames(1)
		if zombie.global_position.y > 810:
			fell = zombie.global_position.x > 960 and zombie.global_position.x < 1160 and not zombie.is_on_floor()
			pursuit_alive = zombie.health > 0 and zombie.velocity.y > 0 and zombie.velocity.x*move > 0 and zombie.state in [CoreZombie.State.CHASE,CoreZombie.State.INVESTIGATE]
			break
	check(fell and pursuit_alive,"alerted zombie leaves the edge and falls while pursuing: "+label)
	await frames(75)
	check(zombie.health == 0 and zombie.state == CoreZombie.State.DEAD and zombie.collision_layer == 0 and zombie.global_position.y > CoreMovementLevel.FALL_LIMIT,"a bottomless pit retires the zombie beyond the level: "+label)
	var stopped := zombie.global_position
	await frames(5)
	check(zombie.global_position == stopped and zombie.velocity == Vector2.ZERO,"a retired zombie does not keep falling forever: "+label)
	lab._respawn_enemies()
	check(zombie.health == 100 and zombie.state == CoreZombie.State.PATROL and zombie.global_position == start and not zombie.is_prone(),"arena respawn restores a fallen zombie: "+label)
func drop_to_floor(move: float,prone: bool) -> void:
	await settle(Vector2(5170,600),move,prone,Vector2(5170+move*220,760))
	zombie.state = CoreZombie.State.PATROL
	# The upper platform occludes a prone head's view of the player below.
	# A gunshot can legitimately start the descent without granting wall sight.
	check(zombie.hear_noise(hero.global_position-Vector2(0,32),1,"shot"),"a lower-platform shot starts the search: direction %.0f prone %s" % [move,prone])
	var expected_health := zombie.health
	var falling := false
	var landed := false
	for i in 160:
		await frames(1)
		if not zombie.is_on_floor() and zombie.global_position.y > 605: falling = true
		if falling and zombie.is_on_floor() and zombie.global_position.y > 750:
			landed = true
			break
	check(falling and landed and zombie.health == expected_health,"pursuit drops from an upper platform and survives a lower landing: direction %.0f prone %s" % [move,prone])
	var landed_x := zombie.global_position.x
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE and (zombie.global_position.x-landed_x)*move > 5,"pursuit continues after landing: direction %.0f prone %s" % [move,prone])
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	zombie = lab.level.zombie
	hero = lab.player
	hero.set_physics_process(false)
	for move in [1.0,-1.0]:
		for prone in [false,true]:
			for source in ["vision","noise","damage"]: await pit(move,prone,source)
	var upper := StaticBody2D.new()
	upper.collision_layer = 1
	upper.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(100,20)
	shape.shape = rectangle
	upper.position = Vector2(5170,610)
	upper.add_child(shape)
	lab.level.add_child(upper)
	for move in [1.0,-1.0]:
		for prone in [false,true]: await drop_to_floor(move,prone)
	upper.queue_free()
	await settle(Vector2(925,760),1,false,Vector2(5000,760))
	zombie.state = CoreZombie.State.PATROL
	zombie.patrol_direction = 1
	await frames(60)
	check(zombie.global_position.y < 762 and zombie.global_position.x < 960,"unaware patrol still turns at an edge")
	await settle(Vector2(940,760),1,true,Vector2(5000,760))
	zombie.state = CoreZombie.State.PATROL
	await frames(20)
	check(zombie.state == CoreZombie.State.WAIT and zombie.global_position.y < 762,"an unaware crawler waits instead of patrolling into the pit")
	await settle(Vector2(925,760),1,false,Vector2(1240,760))
	zombie.state = CoreZombie.State.PATROL
	await frames(3)
	paused = true
	var frozen := zombie.global_position
	await frames(6)
	check(zombie.global_position == frozen,"pause freezes pursuit at an edge")
	paused = false
	hero.health = 0
	await frames(5)
	check(zombie.state != CoreZombie.State.CHASE and zombie.global_position.y < 762,"a defeated target ends the pursuit before the drop")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
