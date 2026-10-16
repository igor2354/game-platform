extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func tick() -> void:
	await physics_frame
	await process_frame
	# Inspect the completed movement tick, without relying on idle/physics order.
	lab._update_camera()
	lab.camera.force_update_scroll()

func release() -> void:
	for action in ["core_left","core_right","core_fire","core_aim"]: Input.action_release(action)

func retreat(direction: float,mode: int,taps: bool,ads: bool,zoom: float,follow: float) -> void:
	release()
	var hero := lab.player
	var gun := hero.weapon
	hero.reset_to(Vector2(1800,760))
	gun.tuning.fire_mode = mode
	gun.aim_override = hero.position+Vector2(direction*700,-36)
	lab.camera_settings.apply_values({"zoom":zoom,"offset_x":250,"offset_y":-200,"look_ahead":200,"follow_speed":follow,"limit_to_level":true})
	for i in 4: await tick()
	lab._update_camera(true)
	var origin := hero.position.x
	Input.action_press("core_left" if direction > 0 else "core_right")
	if ads: Input.action_press("core_aim")
	var stable := true
	var min_offset := INF
	var max_offset := -INF
	for i in 32:
		if i == 0 or (taps and i % 8 == 0): Input.action_press("core_fire")
		if taps and i % 8 == 4: Input.action_release("core_fire")
		await tick()
		var offset := (lab.camera.position.x-hero.position.x)*zoom
		min_offset = minf(min_offset,offset)
		max_offset = maxf(max_offset,offset)
		stable = stable and absf(offset-(250+direction*200)) < .1
	var label := "%s %s %s zoom %.1f follow %.0f" % ["right" if direction > 0 else "left","auto" if mode == 0 else "single","ADS" if ads else "taps" if taps else "held",zoom,follow]
	check(stable and max_offset-min_offset < .2,"retreat preserves framing: "+label)
	check((hero.position.x-origin)*direction < -5 and gun.shots_fired > 0 and hero.body.facing == direction,"retreat moves backwards while shooting forwards: "+label)
	release()

func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	for i in 8: await tick()
	# Isolate follow motion from intentional recoil; combat_feel_smoke checks recoil.
	lab.player.weapon.tuning.camera_kick = 0
	lab.player.weapon.tuning.camera_shake = 0
	lab.player.weapon.tuning.kill_camera_boost = 0
	for direction in [1.0,-1.0]:
		for profile in [Vector2(.5,0),Vector2(2.5,8)]:
			await retreat(direction,0,false,false,profile.x,profile.y)
			await retreat(direction,0,true,false,profile.x,profile.y)
			await retreat(direction,1,false,false,profile.x,profile.y)
			await retreat(direction,1,true,true,profile.x,profile.y)
	# Turning the visible character must still turn look-ahead.
	lab.player.weapon.aim_override = lab.player.position+Vector2(700,-36)
	for i in 90: await tick()
	var right_offset := lab.camera.position.x-lab.player.position.x
	lab.player.weapon.aim_override = lab.player.position+Vector2(-700,-36)
	for i in 90: await tick()
	check(absf((right_offset-(lab.camera.position.x-lab.player.position.x))*lab.camera_settings.zoom-400) < .1,"deliberate weapon/body turn still changes camera look-ahead")
	release()
	lab.player.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	for i in 20: await tick()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
