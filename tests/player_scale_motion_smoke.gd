extends SceneTree
var checks := 0
var failures := 0
var app: Node
var lab: CoreMovementLab
var hero: CoreMovementPlayer
const ACTIONS := ["core_right","core_left","core_walk","core_sprint","core_crouch","core_jump","core_dash","core_up","core_down","core_aim","core_fire"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func place() -> void:
	release()
	hero.reset_to(Vector2(8000,760))
	hero.weapon.aim_override = Vector2(10000,650)
	await frames(5)
func run() -> void:
	var temp := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("scaled-motion-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp)
	app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = temp
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("sofia")
	app.launch(false)
	await frames(7)
	lab = app.game
	hero = lab.player
	hero.weapon.tuning.sound_enabled = false
	hero.weapon.tuning.recoil_enabled = false
	hero.tuning.apply_values({"run_speed":180,"sprint_speed":250,"slow_walk_speed":60,"jump_speed":540,"gravity":1800,"fall_speed":1150,"dash_speed":350,"climb_speed":60,"acceleration":800,"braking":900})
	var base := hero.tuning.as_dictionary().duplicate()
	var original_camera := lab.camera_settings.as_dictionary().duplicate()
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(6000,100)
	shape.position = Vector2(9500,810)
	shape.shape = rectangle
	floor_body.add_child(shape)
	lab.add_child(floor_body)
	await frames(3)
	var baseline_jump_height := 0.0
	var baseline_jump_ticks := 0
	for factor in [1.0,2.85,4.0,.5]:
		await place()
		hero.request_body_scale(factor)
		await frames(3)
		check(is_equal_approx(hero.body_scale,factor),"requested size applied "+str(factor))
		var motion_values := true
		for key in CoreMovementSettings.SCALED_MOTION_KEYS: motion_values = motion_values and is_equal_approx(hero.motion_value(key),float(base[key])*factor)
		check(motion_values,"all movement coefficients multiply once "+str(factor))
		Input.action_press("core_right")
		await frames(60)
		check(absf(hero.velocity.x-180*factor) < .1,"actual run speed "+str(factor))
		Input.action_press("core_walk")
		await frames(45)
		check(absf(hero.velocity.x-60*factor) < .1,"actual slow walk speed "+str(factor))
		Input.action_release("core_walk")
		Input.action_press("core_sprint")
		await frames(60)
		check(hero.sprinting and absf(hero.velocity.x-250*factor) < .1,"actual sprint speed "+str(factor))
		await place()
		Input.action_press("core_right")
		Input.action_press("core_crouch")
		await frames(60)
		check(hero.crouching and absf(hero.velocity.x-180*factor*hero.tuning.crouch_speed_multiplier) < .1,"actual crouch speed "+str(factor))
		await place()
		var lowest := hero.position.y
		var ticks := 0
		Input.action_press("core_jump")
		for i in 60:
			await frames(1)
			ticks += 1
			lowest = minf(lowest,hero.position.y)
			if ticks > 2 and hero.is_on_floor(): break
		var height := 760-lowest
		if factor == 1:
			baseline_jump_height = height
			baseline_jump_ticks = ticks
		check(absf(height/factor-baseline_jump_height) < .15,"jump height scales linearly "+str(factor))
		check(absi(ticks-baseline_jump_ticks) <= 1,"jump duration is preserved "+str(factor))
		await place()
		hero._start_dash(1)
		await frames(3)
		check(absf(hero.velocity.x-350*factor) < .1,"actual dash speed "+str(factor))
		await place()
		hero.global_position = Vector2(8000,500)
		hero._enter_ladder(Rect2(7991,0,18,760))
		Input.action_press("core_up")
		await frames(3)
		check(hero.climbing and absf(hero.velocity.y+60*factor) < .1,"actual ladder speed "+str(factor))
		hero._leave_ladder()
		await place()
		hero.sprinting = true
		hero.ground_speed = 250*factor
		hero.velocity = Vector2(250*factor,0)
		hero._start_slide()
		await frames(3)
		check(hero.slide_speed > 0 and absf(hero.slide_speed/factor-(250*hero.tuning.slide_speed_multiplier-hero.tuning.slide_braking*3/60.0)) < .2,"slide acceleration/deceleration scales "+str(factor))
		check(hero.tuning.as_dictionary() == base,"base profile unchanged "+str(factor))
		check(lab.camera_settings.as_dictionary() == original_camera,"camera profile unchanged "+str(factor))
	# Refreshing or reapplying the same size must never compound the multiplier.
	await place()
	hero.request_body_scale(2.85)
	for i in 5: hero.request_body_scale(2.85)
	check(is_equal_approx(hero.motion_value("run_speed"),513),"2.85x selected run remains 513 without compounding")
	check(is_equal_approx(hero.motion_value("slow_walk_speed"),171) and is_equal_approx(hero.motion_value("sprint_speed"),712.5),"selected walk and sprint are 171 and 712.5")
	hero.request_body_scale(1)
	check(hero.motion_value("run_speed") == 180 and hero.tuning.as_dictionary() == base,"1x restores original effective speed and all profile values")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(0)
	hero.request_body_scale(2.85)
	await frames(3)
	check(lab.movement_overlay.rows.run_speed.metric.text.contains("2.85") and lab.movement_overlay.rows.run_speed.number.value == 180,"UI shows derived speed without changing the base number")
	release()
	app.queue_free()
	await frames(3)
	print("PLAYER SCALE MOTION: %d/%d" % [checks-failures,checks])
	quit(1 if failures else 0)
