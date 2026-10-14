extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
const ACTIONS := ["core_left","core_right","core_up","core_down","core_jump","core_dash"]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release_inputs() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle(point: Vector2) -> void:
	release_inputs()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(2000,-36)
	await frames(8)
func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.weapon.aim_override = hero.position+Vector2(2000,-36)
	await frames(8)
	check(lab.level.enemies.size() == 4 and lab.level.zombie is CoreZombie and hero is CoreMovementPlayer,"main scene contains the core player, three stationary targets and a zombie arena")
	check(hero.is_on_floor() and absf(hero.position.y-760) < 2,"player starts standing on the test floor")
	if "--packed" in OS.get_cmdline_user_args():
		check(not ResourceLoader.exists("res://scenes/archive/station_demo.tscn") and not FileAccess.file_exists("res://assets/drawn_soldier/walk.png"),"movement pack excludes the archived scene and painted actors")
	var start := hero.position.x
	Input.action_press("core_right")
	await frames(35)
	check(absf(hero.velocity.x-hero.tuning.run_speed) < .1 and hero.position.x > start+140 and hero.mode == "run","A/D input accelerates to the configured running speed")
	var release_point := hero.position.x
	Input.action_release("core_right")
	await frames(14)
	check(absf(hero.velocity.x) < 1 and hero.position.x-release_point < 30,"running brakes promptly after releasing movement")
	await settle(Vector2(300,760))
	Input.action_press("core_jump")
	await frames(4)
	check(hero.velocity.y < 0 and hero.position.y < 740,"Space starts an upward jump from the floor")
	var highest := hero.position.y
	for i in 48:
		await physics_frame
		highest = minf(highest,hero.position.y)
	var full_height := 760-highest
	check(full_height > 120 and full_height < 150 and hero.is_on_floor(),"held jump reaches its designed height and lands on solid ground")
	await settle(Vector2(300,760))
	Input.action_press("core_jump")
	await frames(3)
	Input.action_release("core_jump")
	highest = hero.position.y
	for i in 32:
		await physics_frame
		highest = minf(highest,hero.position.y)
	check(760-highest < full_height*.6,"releasing Space early makes a shorter jump")
	await settle(Vector2(947,760))
	Input.action_press("core_right")
	for i in 25:
		await physics_frame
		if not hero.is_on_floor(): break
	check(not hero.is_on_floor() and hero.coyote > 0,"leaving an edge opens a short coyote window")
	Input.action_press("core_jump")
	await frames(3)
	check(hero.jumps == 1 and hero.velocity.y < -300,"a jump pressed just after the edge still executes")
	await settle(Vector2(320,650))
	for i in 35:
		await physics_frame
		if hero.position.y > 733: break
	Input.action_press("core_jump")
	await frames(10)
	check(hero.jumps == 1 and hero.velocity.y < 0,"jump pressed just before landing is buffered and executes on contact")
	await settle(Vector2(885,760))
	var recoveries := lab.respawns
	Input.action_press("core_right")
	await frames(16)
	Input.action_press("core_jump")
	await frames(55)
	check(hero.position.x > 1180 and hero.is_on_floor() and lab.respawns == recoveries,"the test gap can be crossed with a running full-height jump")
	await settle(Vector2(250,760))
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dash_left > 0 and hero.mode == "dash" and hero.velocity.x > 700,"Alt starts a fast horizontal ground dash")
	Input.action_release("core_dash")
	await frames(13)
	check(hero.dash_left == 0 and hero.last_dash_distance > 112 and hero.last_dash_distance < 140,"dash travels a finite distance and returns to normal movement")
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dashes == 1,"dash cannot restart during its cooldown")
	Input.action_release("core_dash")
	await frames(24)
	start = hero.position.x
	Input.action_press("core_left")
	Input.action_press("core_dash")
	await frames(4)
	check(hero.position.x < start-25 and hero.dash_direction == -1,"dash direction follows movement input")
	await settle(Vector2(600,760))
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(5)
	check(hero.position.x <= 627 and hero.dash_left == 0,"dash stops at a wall without tunnelling through solid geometry")
	await settle(Vector2(250,760))
	Input.action_press("core_jump")
	await frames(21)
	Input.action_press("core_dash")
	await frames(3)
	check(not hero.is_on_floor() and hero.dash_left > 0 and absf(hero.velocity.y) < 1,"an air dash briefly suspends vertical movement")
	Input.action_release("core_dash")
	Input.action_release("core_jump")
	await frames(26)
	check(hero.dash_cooldown <= 0 and not hero.is_on_floor() and not hero.dash_available(),"air dash is limited to one per airtime even after cooldown")
	Input.action_press("core_dash")
	await frames(2)
	check(hero.dashes == 1,"second air dash is rejected before landing")
	Input.action_release("core_dash")
	await frames(26)
	check(hero.is_on_floor() and hero.dash_available(),"landing restores the air dash budget")
	await settle(Vector2(2400,760))
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(8)
	check(hero.position.x > 2490 and lab.level.enemies[0].position == Vector2(2460,760),"dash passes through a stationary enemy without moving it")
	await settle(Vector2(1446,760))
	Input.action_press("core_up")
	await frames(12)
	check(hero.climbing and hero.position.y < 740,"W attaches to a nearby ladder and climbs")
	check(not hero.get_collision_mask_value(4) and hero.get_collision_mask_value(1),"climbing ignores one-way ledges while retaining solid wall collision")
	Input.action_release("core_up")
	var resting_y := hero.position.y
	await frames(12)
	check(absf(hero.position.y-resting_y) < .1 and hero.velocity.y == 0,"releasing W/S holds the player on the ladder")
	Input.action_press("core_up")
	Input.action_press("core_jump")
	Input.action_press("core_right")
	await frames(4)
	check(not hero.climbing and hero.velocity.y < 0 and hero.position.x > 1446 and hero.get_collision_mask_value(4),"Space jumps off the ladder and restores ledge collision without instant regrab")
	await settle(Vector2(1446,760))
	Input.action_press("core_up")
	await frames(90)
	check(not hero.climbing and hero.is_on_floor() and absf(hero.position.y-540) < 2,"climber exits onto the top platform")
	Input.action_release("core_up")
	Input.action_press("core_down")
	await frames(20)
	check(hero.climbing and hero.position.y > 560,"S descends from the upper platform into the ladder")
	await frames(80)
	check(not hero.climbing and hero.is_on_floor() and absf(hero.position.y-760) < 2,"climber exits onto solid ground at the bottom")
	await settle(Vector2(2018,760))
	Input.action_press("core_up")
	await frames(150)
	check(not hero.climbing and hero.is_on_floor() and absf(hero.position.y-350) < 2,"tall ladder passes the intermediate ledge and exits at its own top")
	await settle(Vector2(1060,950))
	await frames(30)
	check(lab.respawns > 0 and hero.position.x == CoreMovementLevel.SPAWN.x,"falling into the gap automatically returns to the start")
	await settle(Vector2(250,760))
	Input.action_press("core_dash")
	await frames(3)
	await dispatch("core_pause")
	var paused_position := hero.position
	var paused_dash := hero.dash_left
	await frames(8)
	check(paused and hero.position == paused_position and hero.dash_left == paused_dash,"Escape pauses player physics and dash timers")
	release_inputs()
	await dispatch("core_reset")
	await frames(8)
	check(not paused and hero.position.distance_to(CoreMovementLevel.SPAWN) < 2 and hero.dash_cooldown == 0 and hero.collision_mask == CoreMovementPlayer.WORLD_MASK,"R resets the lab from pause with collision and dash state restored")
	release_inputs()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
