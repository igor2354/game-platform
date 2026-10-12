extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var gun: CoreShootingController
var records: Array[Dictionary] = []
var checks := 0
var failures := 0
var profile := "/private/tmp/shooting-test-%d.cfg" % OS.get_process_id()
const ACTIONS := ["core_left","core_right","core_up","core_down","core_jump","core_dash","core_fire","core_aim"]
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
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	hero.reset_to(point)
	records.clear()
	await frames(8)
func dispatch(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func record(origin: Vector2,direction: Vector2,aimed: bool,spread: float) -> void:
	records.append({"origin":origin,"direction":direction,"aimed":aimed,"spread":spread,"point":gun.aim_point})
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.shooting_settings_path = profile
	root.add_child(lab)
	hero = lab.player
	gun = hero.weapon
	gun.rng.seed = 2354
	gun.aim_override = Vector2(1000,400)
	gun.shot_fired.connect(record)
	await frames(8)
	check(InputMap.action_get_events("core_fire")[0].button_index == MOUSE_BUTTON_LEFT and InputMap.action_get_events("core_aim")[0].button_index == MOUSE_BUTTON_RIGHT,"LMB fires and RMB aims")
	check(gun.shots_fired == 0 and gun.movement_multiplier == 1,"idle weapon does not affect movement")
	Input.action_press("core_fire")
	await frames(45)
	check(gun.shots_fired >= 12 and gun.shots_fired <= 13,"held LMB fires automatic bursts at the configured cadence")
	check(records[0].spread == gun.tuning.hip_spread and records[-1].spread > records[0].spread,"hip spread grows over an uninterrupted burst")
	check(records[-1].spread == gun.tuning.hip_max_spread,"hip spread has a maximum")
	var random_offsets := []
	var inside_cone := true
	for shot in records:
		var center: Vector2 = (shot.point-shot.origin).normalized()
		var offset: float = center.angle_to(shot.direction)
		random_offsets.append(offset)
		inside_cone = inside_cone and absf(rad_to_deg(offset)) <= shot.spread+.01
	check(inside_cone and absf(random_offsets[0]-random_offsets[1]) > .001,"hip bullets have varied random directions within the displayed cone")
	Input.action_release("core_fire")
	await frames(55)
	check(absf(gun.spread_degrees()-gun.tuning.hip_spread) < .01,"spread recovers after releasing fire")
	check(gun.movement_multiplier == 1 and gun.burst_time == 0,"ending a burst restores the movement multiplier")
	await settle(Vector2(160,760))
	Input.action_press("core_right")
	Input.action_press("core_fire")
	await frames(32)
	check(absf(hero.velocity.x-hero.tuning.run_speed*.65) < 1,"continuous hip firing reduces running speed to 65 percent")
	Input.action_release("core_fire")
	await frames(14)
	check(absf(hero.velocity.x-hero.tuning.run_speed) < 1,"running recovers when firing stops")
	await settle(Vector2(160,760))
	Input.action_press("core_right")
	Input.action_press("core_aim")
	await frames(20)
	check(gun.aiming and gun.shots_fired == 0 and absf(hero.velocity.x-96) < 1,"RMB alone aims and slows movement strongly to 30 percent")
	var first_point := gun.aim_point
	Input.action_press("core_fire")
	await frames(40)
	var exact := true
	var bounded := true
	for shot in records:
		exact = exact and shot.aimed and shot.spread == 0 and absf((shot.point-shot.origin).normalized().cross(shot.direction)) < .00001
		bounded = bounded and shot.point.distance_to(gun.aim_override) <= gun.tuning.sway_radius*1.23
	check(exact and records.size() > 8,"aimed bullets pass through the visible swaying aim point without random spread")
	check(bounded and first_point.distance_to(gun.aim_point) > 1,"aim point sways smoothly around the mouse within the configured amplitude")
	check(absf(gun.movement_multiplier-.3) < .001,"aim slowdown takes priority over hip burst slowdown")
	Input.action_release("core_aim")
	Input.action_release("core_fire")
	await frames(15)
	check(not gun.aiming and absf(hero.velocity.x-320) < 1,"releasing RMB restores ordinary movement")
	await settle(Vector2(160,760))
	Input.action_press("core_fire")
	await frames(121)
	check(gun.shots_fired >= 33 and gun.shots_fired <= 35,"fractional cadence preserves about 1000 RPM over two seconds")
	var hill := lab.level.slopes[1]
	for side in [0,2]:
		for aimed in [false,true]:
			await settle(hill[side].lerp(hill[side+1],.3)-Vector2(0,10))
			Input.action_press("core_right")
			Input.action_press("core_aim" if aimed else "core_fire")
			await frames(30)
			var origin := hero.position
			await frames(6)
			var measured := hero.position.distance_to(origin)/(6*hero.get_physics_process_delta_time())
			var expected := (224.0 if side == 0 else 368.0)*(gun.tuning.ads_move_multiplier if aimed else gun.tuning.hip_move_multiplier)
			# Allow the capsule's 0.08 px contact correction per physics tick;
			# also allow small variations of the capsule's contact normal.
			check(hero.is_on_floor() and absf(measured-expected) < 5 and absf(hero.ground_speed-expected) < 2,"weapon slowdown combines with ascent/descent (side %d, aimed %s, %.1f px/s)" % [side,aimed,measured])
	await settle(Vector2(2250,760))
	var target := lab.level.enemies[0]
	for dummy in lab.level.enemies: dummy.reset_target()
	gun.tuning.sway_radius = 0
	gun.aim_override = target.aim_point_for_part("torso")
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	await frames(8)
	check(target.health == 75 and target.received_hits == 1 and gun.hits == 1,"a projectile damages a target and registers an impact")
	Input.action_press("core_fire")
	await frames(22)
	check(target.health == 0 and target.collision_layer == 0,"lethal hits disable the defeated target collision")
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	lab._recover()
	await frames(8)
	check(target.health == 100 and target.collision_layer == 4 and gun.shots_fired == 0 and get_nodes_in_group("core_projectiles").is_empty(),"R resets targets, weapon state and outstanding bullets")
	await settle(Vector2(620,760))
	gun.aim_override = Vector2(900,724)
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(3)
	var wall_hit := false
	for effect in gun.effects:
		if not effect.target and absf(effect.point.x-640) < 1: wall_hit = true
	check(wall_hit and gun.hits == 0 and target.health == 100,"a muzzle overlapping a wall cannot fire through it")
	await settle(Vector2(160,760))
	var thin_wall := StaticBody2D.new()
	thin_wall.collision_layer = 1
	thin_wall.collision_mask = 0
	thin_wall.position = Vector2(500,600)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2,80)
	shape.shape = rect
	thin_wall.add_child(shape)
	lab.get_node("World").add_child(thin_wall)
	var bullet := CoreProjectile.new()
	bullet.speed = 4000
	bullet.shooter = hero.get_rid()
	bullet.position = Vector2(450,600)
	lab.get_node("World").add_child(bullet)
	await frames(3)
	check(not is_instance_valid(bullet),"swept projectile collision catches a two-pixel wall at maximum bullet speed")
	thin_wall.queue_free()
	await settle(Vector2(160,760))
	Input.action_press("core_fire")
	Input.action_press("core_dash")
	await frames(4)
	check(hero.dash_left > 0 and gun.shots_fired == 0,"dash has priority over firing in the same frame (dash %.3f, shots %d, dash count %d)" % [hero.dash_left,gun.shots_fired,hero.dashes])
	await settle(Vector2(1446,760))
	Input.action_press("core_up")
	Input.action_press("core_fire")
	await frames(6)
	check(hero.climbing and gun.shots_fired == 0,"ladder climbing blocks firing")
	await settle(Vector2(160,760))
	gun.aim_override = Vector2(1000,400)
	Input.action_press("core_fire")
	await frames(4)
	paused = true
	var state := [gun.cooldown,gun.bloom,gun.shots_fired]
	var flying: Node2D = get_nodes_in_group("core_projectiles")[0]
	var bullet_position := flying.position
	await frames(8)
	check(state == [gun.cooldown,gun.bloom,gun.shots_fired] and flying.position == bullet_position,"pause freezes weapon timing, spread and bullets")
	release_inputs()
	await dispatch("core_weapon_tuner")
	var overlay := lab.shooting_overlay
	check(overlay.visible and overlay.rows.size() == CoreShootingSettings.PARAMS.size() and overlay.tabs.get_tab_count() == 6,"F4 exposes shooting, recoil, sound and zonal damage in six tabs, also on pause")
	overlay.tabs.current_tab = 2
	overlay.rows.ads_move_multiplier.slider.value = .25
	check(gun.tuning.ads_move_multiplier == .25 and overlay.rows.ads_move_multiplier.number.value == .25,"weapon sliders update the runtime settings live")
	overlay.save_profile()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(profile) == OK and loaded.ads_move_multiplier == .25,"shooting settings save to a separate profile")
	check((load("res://resources/core/shooting.tres") as CoreShootingSettings).ads_move_multiplier == .3,"runtime settings do not mutate the source resource")
	overlay.reset_profile()
	check(gun.tuning.ads_move_multiplier == .3 and gun.tuning.sway_radius == 10,"shooting Reset restores the base resource")
	overlay.load_profile()
	check(gun.tuning.ads_move_multiplier == .25,"shooting Load restores the saved profile")
	await dispatch("core_tuner")
	check(lab.movement_overlay.visible and not overlay.visible,"F3 and F4 open one settings panel at a time")
	await dispatch("core_weapon_tuner")
	paused = false
	var line: LineEdit = overlay.rows.ads_move_multiplier.number.get_line_edit()
	line.grab_focus()
	await process_frame
	Input.action_press("core_fire")
	Input.action_press("core_aim")
	var count := gun.shots_fired
	await frames(6)
	check(gun.shots_fired == count and not gun.aiming,"editing parameters blocks fire and aiming")
	release_inputs()
	line.release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = overlay.panel.get_global_rect().get_center()
	root.push_input(motion,true)
	await process_frame
	Input.action_press("core_fire")
	await frames(6)
	check(gun.shots_fired == count,"clicks over a settings panel do not shoot into the level")
	release_inputs()
	var click := InputEventMouseButton.new()
	click.position = overlay.panel.position+Vector2(20,20)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	overlay.toggle()
	Input.action_press("core_fire")
	await frames(5)
	check(gun.shots_fired == count,"closing the panel or dragging away does not reuse the held UI click as fire")
	release_inputs()
	click.pressed = false
	root.push_input(click,true)
	await frames(2)
	Input.action_press("core_fire")
	await frames(4)
	check(gun.shots_fired > count,"a fresh trigger press works after releasing the UI click")
	release_inputs()
	loaded.apply_values({"hip_spread":15,"hip_max_spread":2,"rounds_per_minute":0,"sway_radius":100})
	check(loaded.hip_max_spread >= loaded.hip_spread and loaded.rounds_per_minute >= 120 and loaded.sway_radius <= 40,"invalid shooting profiles are bounded and normalised")
	lab.queue_free()
	await process_frame
	lab = load("res://scenes/main.tscn").instantiate()
	lab.settings_path = "/private/tmp/no-saved-movement-%d.cfg" % OS.get_process_id()
	lab.shooting_settings_path = profile
	root.add_child(lab)
	await frames(8)
	check(lab.player.weapon.tuning.ads_move_multiplier == .25,"a new session automatically loads the shooting profile")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(profile)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
