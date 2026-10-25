extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var crate: RigidBody2D
var checks := 0
var failures := 0
var directory := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("pushing-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_grab","core_left","core_right","core_sprint","core_walk","core_crouch","core_jump","core_dash","core_fire","core_aim"]: Input.action_release(action)
func setup(side := 1.0) -> void:
	release()
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	crate.mass = 8
	crate.freeze = false
	crate.home_transform = Transform2D(0,Vector2(-800,728))
	hero.reset_to(Vector2(-800-side*90,760))
	crate.reset_crate()
	hero.weapon.aim_override = hero.position-Vector2(side*900,36)
	await frames(12)
func toggle_grab() -> void:
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(1)
func approach(side := 1.0) -> bool:
	Input.action_press("core_right" if side > 0 else "core_left")
	for tick in 100:
		await frames(1)
		if hero.is_on_wall(): break
	await toggle_grab()
	await frames(8)
	return hero.pushing
func palms_on_box() -> bool:
	for arm in [hero.body.near_arm,hero.body.far_arm]:
		var point: Vector2 = crate.to_local(hero.global_position+arm.hand)
		if absf(point.x) > 32.8 or absf(point.y) > 32.8: return false
		if minf(absf(absf(point.x)-32),absf(absf(point.y)-32)) > .8: return false
	return true
func same_values(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if expected[key] is bool:
			if actual[key] != expected[key]: return false
		elif not is_equal_approx(float(actual[key]),float(expected[key])): return false
	return true
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	hero = lab.player
	crate = lab.level.physics_crate
	await frames(8)
	var panel := lab.movement_overlay
	check(panel.groups.has("Толкание") and panel.feature_toggles.has("push_enabled") and panel.rows.has("push_force") and panel.rows.has("push_hand_height"),"F3 exposes push settings and an independent switch")
	var texture := CoreHybridBody.TEXTURES.push as Texture2D
	check(texture.get_width() == 3072 and texture.get_height() == 384 and CoreHybridBody.POSES.DATA.push.size() == 8,"pushing has eight baked body frames with shoulder anchors")
	for side in [-1.0,1.0]:
		await setup(side)
		check(await approach(side),"G takes the adjacent crate from side "+str(side))
		var origin := crate.position
		var seen := {}
		var grips := true
		var speed_cap := true
		var facing := true
		var previous_position := hero.global_position
		for tick in 135:
			await frames(1)
			var measured_speed := absf(hero.global_position.x-previous_position.x)/hero.get_physics_process_delta_time()
			previous_position = hero.global_position
			if hero.pushing:
				seen[hero.body.frame] = true
				grips = grips and palms_on_box()
				speed_cap = speed_cap and measured_speed <= hero.tuning.push_speed+8
				facing = facing and hero.body.facing == side and hero.weapon.look_facing() == -side
		check(seen.size() == 8 and hero.body.state == "push","real contact plays the complete eight-frame pushing cycle")
		check((crate.position.x-origin.x)*side > 60 and (crate.position.x-hero.position.x)*side > 0,"real force moves the crate without phasing through it")
		check(grips and palms_on_box(),"both palms remain on the moving physical box surface")
		check(speed_cap and facing,"push speed is capped and body faces the crate without reversing camera gaze")
		check(hero.visuals.gun.get_index() < hero.body.get_index() and not hero.weapon.aiming and not hero.weapon.firing,"slung gun stays behind the body and both hands are free")
		check(hero.collision_height() == 64,"pushing preserves the standing collider")
		release()
		await frames(20)
		check(hero.pushing and palms_on_box(),"stopping keeps both hands on the crate")
		var pull_origin := crate.position.x
		Input.action_press("core_left" if side > 0 else "core_right")
		var pull_frames := {}
		var pull_grips := true
		for tick in 110:
			await frames(1)
			pull_frames[hero.body.frame] = true
			pull_grips = pull_grips and palms_on_box()
		check(pull_frames.size() == 8 and pull_grips,"pulling plays all eight frames with both palms on the surface")
		check(hero.pushing and hero.body.state == "pull" and hero.body.facing == side and palms_on_box(),"pulling keeps the gaze and both hands towards the object")
		check((crate.position.x-pull_origin)*side < -35,"backward movement physically pulls the crate")
		release()
		await toggle_grab()
		check(not hero.pushing and hero.body.state not in ["push","pull"] and hero.visuals.gun.get_index() > hero.body.get_index(),"second G releases the crate and restores weapon layers")
	for gait in ["run","sprint","dash","slide"]:
		await setup()
		var stationary := crate.position
		Input.action_press("core_right")
		if gait in ["sprint","slide"]: Input.action_press("core_sprint")
		if gait == "dash": Input.action_press("core_dash")
		if gait == "slide":
			await frames(5)
			Input.action_press("core_crouch")
		await frames(85)
		check(not hero.pushing and crate.position.distance_to(stationary) < 1,"without G, collision cannot move the crate: "+gait)
	await setup()
	hero.reset_to(Vector2(-800,650))
	await frames(50)
	Input.action_press("core_right")
	await frames(2)
	check(not hero.pushing,"standing on top of a crate never starts a pushing pose")
	await setup()
	Input.action_press("core_crouch")
	Input.action_press("core_right")
	await frames(90)
	check(hero.crouching and not hero.pushing,"crouching does not claim the standing two-hand pose")
	await setup()
	hero.tuning.push_activation_delay = .3
	Input.action_press("core_right")
	await frames(80)
	check(not hero.pushing and hero.push_contact_time == 0,"body contact alone never acquires a prop")
	var unmoved := crate.position
	await frames(40)
	check(crate.position.distance_to(unmoved) < 1,"running into an ungrabbed crate cannot move it")
	await toggle_grab()
	check(hero.pushing and hero.push_contact_time < .3,"G acquires the object before the effort delay")
	await frames(8)
	check(hero.pushing and crate.position.distance_to(unmoved) < 1,"effort waits for the configured delay")
	await frames(20)
	check(hero.pushing and crate.position.x > unmoved.x,"force starts after the delay")
	paused = true
	var state := [hero.push_contact_time,hero.body.frame,hero.body.phase,hero.position,crate.global_transform]
	await frames(15)
	check(state == [hero.push_contact_time,hero.body.frame,hero.body.phase,hero.position,crate.global_transform],"pause freezes contact, body animation and rigid-body motion")
	paused = false
	Input.action_release("core_right")
	Input.action_press("core_left")
	await frames(4)
	check(hero.pushing and hero.body.state == "pull","moving away changes to pulling without releasing")
	for action in ["core_fire","core_aim","core_jump","core_dash"]:
		await setup()
		await approach()
		var shots := hero.weapon.shots_fired
		Input.action_press(action)
		await frames(3)
		check(hero.pushing and hero.weapon.shots_fired == shots and not hero.weapon.aiming and hero.jumps == 0 and hero.dashes == 0,"hands stay occupied until G, action blocked: "+action)
	await setup()
	await approach()
	release()
	var held_phase := hero.body.phase
	await frames(25)
	check(hero.pushing and is_equal_approx(held_phase,hero.body.phase),"idle holding does not keep stepping")
	hero.input_blocker = func() -> bool: return true
	await toggle_grab()
	check(hero.pushing,"G while editing a setting cannot release the object")
	hero.input_blocker = lab._blocks_keyboard
	await toggle_grab()
	check(not hero.pushing,"G works again after leaving text editing")
	await setup()
	await approach()
	hero.weapon.magazine_ammo = 30
	check(not hero.weapon.request_reload() and hero.pushing,"reload waits until the player explicitly releases with G")
	await frames(10)
	check(not hero.weapon.reloading and hero.pushing,"R cannot silently release the grab")
	await setup()
	hero.tuning.push_force = 0
	await approach()
	var anchor := crate.position
	var seen := {}
	for tick in 180:
		await frames(1)
		if hero.pushing: seen[hero.body.frame] = true
	check(hero.pushing and seen.size() == 8 and crate.position.distance_to(anchor) < 2,"zero force leaves a visible bracing effort without moving the crate")
	hero.tuning.push_animation_rate = .5
	var phase := hero.body.phase
	await frames(30)
	var slow_cycle := fposmod(hero.body.phase-phase,1)
	hero.tuning.push_animation_rate = 1.5
	phase = hero.body.phase
	await frames(30)
	var fast_cycle := fposmod(hero.body.phase-phase,1)
	check(absf(fast_cycle-slow_cycle*3) < .01,"animation rate changes the real cycle speed independently of physical force")
	panel._sync()
	panel.feature_toggles.push_enabled.button_pressed = false
	check(not hero.pushing and hero.tuning.push_speed == 100,"turning off pushing releases the pose immediately without clearing values")
	await frames(40)
	check(not hero.pushing and crate.position.distance_to(anchor) < 2,"disabled pushing applies no ordinary movement force to the box")
	panel.feature_toggles.push_enabled.button_pressed = true
	hero.tuning.push_force = 16000
	await frames(2)
	check(not hero.pushing,"re-enabling requires a new explicit G")
	await toggle_grab()
	await frames(50)
	check(hero.pushing and crate.position.x > anchor.x+20,"G resumes physical pushing after re-enabling")
	panel.rows.push_speed.slider.value = 50
	await frames(30)
	var speed_origin := hero.global_position
	await frames(6)
	check(absf(hero.position.x-speed_origin.x)/(6*hero.get_physics_process_delta_time()) <= 55,"speed slider caps actual pushing movement live")
	panel.rows.push_hand_height.number.value = 48
	panel.rows.push_hand_spacing.slider.value = 10
	await frames(3)
	check(palms_on_box() and absf(hero.body.near_arm.hand.y-hero.body.far_arm.hand.y) > 5,"hand-height controls reposition both palms on the box")
	hero.reset_to(CoreMovementLevel.SPAWN)
	await frames(2)
	check(not hero.pushing and hero.push_target == null,"player reset clears push contact and target")
	await setup()
	crate.mass = 800
	await approach()
	anchor = crate.position
	await frames(50)
	check(hero.pushing and crate.position.distance_to(anchor) < 2,"a heavy rigid body resists the same force instead of being teleported")
	await setup()
	await approach()
	hero.set_current_health(0)
	await frames(2)
	check(not hero.pushing,"defeated players cannot keep pushing")
	await setup()
	await toggle_grab()
	check(not hero.pushing,"G cannot acquire a distant object")
	# Short real key taps must survive the gap between physics ticks.
	Input.action_press("core_right")
	await frames(60)
	Input.action_release("core_right")
	await process_frame
	var event := InputEventAction.new()
	event.action = "core_grab"
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventAction.new()
	event.action = "core_grab"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(3)
	check(hero.pushing,"a tap shorter than a physics tick still grabs once")
	await toggle_grab()
	Input.action_press("core_grab")
	await frames(20)
	check(hero.pushing,"holding G does not repeatedly toggle the grip")
	Input.action_release("core_grab")
	await frames(2)
	paused = true
	await process_frame
	var paused_event := InputEventAction.new()
	paused_event.action = "core_grab"
	paused_event.pressed = true
	Input.parse_input_event(paused_event)
	await process_frame
	paused = false
	await frames(3)
	check(hero.pushing,"G held through unpausing does not release the object")
	Input.action_release("core_grab")
	await frames(2)
	# Pull backwards into a real wall; the box must stop outside the capsule.
	await setup()
	await approach()
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16,100)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	wall.position = hero.position+Vector2(-45,-50)
	lab.add_child(wall)
	release()
	Input.action_press("core_left")
	await frames(120)
	check(hero.pushing and hero.position.x >= wall.position.x+21,"a wall behind the player blocks pulling")
	check(crate.position.x-hero.position.x >= 44,"a blocked pull cannot drag the crate through the player")
	wall.queue_free()
	await setup()
	var mannequin = lab.level.ragdoll_mannequin
	mannequin.reset_mannequin()
	hero.reset_to(mannequin.global_position+Vector2(-45,0))
	hero.weapon.aim_override = mannequin.global_position
	await frames(8)
	Input.action_press("core_right")
	await frames(20)
	check(not mannequin.active and not hero.pushing,"walking into the held ragdoll does not activate it")
	await toggle_grab()
	check(hero.pushing and mannequin.active and hero.push_target.get("mannequin") == mannequin,"G activates and grabs a native ragdoll segment")
	release()
	Input.action_press("core_left")
	await frames(10)
	check(hero.pushing and hero.body.state == "pull","the same two-hand interaction can pull a ragdoll")
	mannequin.set_simulation_enabled(false)
	await frames(2)
	check(not hero.pushing,"disabling ragdoll simulation safely releases its grip")
	mannequin.set_simulation_enabled(true)
	await setup()
	var small_prop := RigidBody2D.new()
	var small_collider := CollisionShape2D.new()
	var small_shape := RectangleShape2D.new()
	small_shape.size = Vector2(32,24)
	small_collider.shape = small_shape
	small_prop.add_child(small_collider)
	small_prop.position = Vector2(-1000,748)
	small_prop.mass = 2
	lab.add_child(small_prop)
	hero.reset_to(Vector2(-1050,760))
	hero.weapon.aim_override = small_prop.position
	Input.action_press("core_right")
	await frames(30)
	await toggle_grab()
	check(hero.pushing and hero.push_target == small_prop,"low generic rigid bodies with generated collider names can be grabbed")
	release()
	Input.action_press("core_left")
	var small_origin := small_prop.position.x
	await frames(30)
	check(hero.pushing and small_prop.position.x < small_origin-10,"low physical objects can be pulled with the same interaction")
	small_prop.queue_free()
	await frames(2)
	check(not hero.pushing,"removing a generic held object clears the grip")
	await setup()
	await approach()
	crate.queue_free()
	await frames(3)
	check(not hero.pushing and hero.push_target == null,"removing a contacted crate safely releases its target reference")
	# UI/profile operations below do not require a world-space crate.
	release()
	panel._sync()
	panel.rows.push_speed.slider.value = 80
	panel.rows.push_force.number.value = 20000
	panel.rows.push_response.slider.value = 300
	panel.rows.push_activation_delay.number.value = .15
	panel.rows.push_contact_distance.slider.value = 6
	panel.rows.push_animation_rate.number.value = 1.4
	panel.rows.push_hand_height.slider.value = 45
	panel.rows.push_hand_spacing.number.value = 12
	panel.feature_toggles.push_enabled.button_pressed = false
	check(hero.tuning.push_speed == 80 and hero.tuning.push_force == 20000 and panel.rows.push_speed.number.value == 80 and panel.rows.push_force.slider.value == 20000,"push sliders and exact numeric input edit the same live resource")
	panel.save_profile()
	var expected := hero.tuning.as_dictionary()
	var loaded := CoreMovementSettings.new()
	check(loaded.load_saved(lab.settings_path) == OK and same_values(loaded.as_dictionary(),expected),"movement CFG persists all push values and the switch")
	var path := directory+"/settings.json"
	check(lab.export_settings_file(path),"full JSON exports pushing settings")
	panel.reset_profile()
	check(hero.tuning.push_enabled and hero.tuning.push_speed == 100 and hero.tuning.push_force == 16000,"Reset restores default pushing settings")
	check(lab.import_settings_file(path) and same_values(hero.tuning.as_dictionary(),expected) and not panel.feature_toggles.push_enabled.button_pressed and panel.rows.push_force.number.value == 20000,"JSON import restores push values and visible controls")
	var legacy := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	for key in expected:
		if str(key).begins_with("push_"): legacy.movement.erase(key)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(lab.import_settings_file(path) and hero.tuning.push_enabled and hero.tuning.push_speed == 100,"older JSON presets receive enabled push defaults")
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
