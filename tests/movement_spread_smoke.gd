extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var gun: CoreShootingController
var checks := 0
var failures := 0
var shots: Array[Dictionary] = []
var directory := "/private/tmp/movement-spread-%d" % OS.get_process_id()
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
	for action in ["core_left","core_right","core_fire","core_aim","core_jump","core_walk","core_crouch"]: Input.action_release(action)
func record(_origin: Vector2,direction: Vector2,ads: bool,spread: float) -> void:
	shots.append({"direction":direction,"ads":ads,"spread":spread,"center":gun.aim_direction})
func same_values(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key): return false
		if expected[key] is bool:
			if actual[key] != expected[key]: return false
		elif not is_equal_approx(float(actual[key]),float(expected[key])): return false
	return true
func setup(look := 1.0) -> void:
	release()
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.tuning.run_backward_multiplier = 1
	hero.reset_to(Vector2(1800,760))
	gun.tuning.apply_values(lab.shooting_overlay.defaults.as_dictionary())
	gun.tuning.apply_values({"hip_spread":2,"hip_max_spread":8,"hip_move_multiplier":1,"ads_move_multiplier":1,"sway_radius":0,"magazine_enabled":false,"sound_enabled":false,"damage_enabled":false,"recoil_enabled":false,"movement_spread_forward":4,"movement_spread_backward":10,"movement_spread_start_speed":0,"movement_spread_full_speed":200,"movement_spread_rise_time":0,"movement_spread_recovery_time":0})
	gun.aim_override = hero.position+Vector2(look*1000,-36)
	gun.rng.seed = 2354
	shots.clear()
	await frames(5)
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
	gun = hero.weapon
	gun.shot_fired.connect(record)
	await frames(8)
	var panel := lab.shooting_overlay
	check(panel.groups.has("Разброс в движении") and panel.feature_toggles.has("movement_spread_enabled") and panel.rows.has("movement_spread_backward"),"F4 contains a dedicated page, master switch and directional sliders")
	for look in [-1.0,1.0]:
		for move in [-1.0,1.0]:
			for mode in [0,1]:
				await setup(look)
				gun.tuning.fire_mode = mode
				Input.action_press("core_left" if move < 0 else "core_right")
				await frames(30)
				var extra := 4.0 if move == look else 10.0
				check(absf(hero.velocity.x) > 200 and is_equal_approx(gun.movement_spread,extra),"actual running chooses forward/backward spread relative to gaze: %s / %s / %s" % [look,move,mode])
				Input.action_press("core_fire")
				await frames(18)
				check(not shots.is_empty() and is_equal_approx(shots[0].spread,2+extra),"the first real shot contains baseline plus movement spread")
				var bounded := shots.all(func(shot: Dictionary): return absf(rad_to_deg(shot.center.angle_to(shot.direction))) <= shot.spread+.001)
				check(bounded and (gun.shots_fired > 2 if mode == 0 else gun.shots_fired == 1),"automatic and single shots obey the displayed cone and trigger rules")
				if mode == 0:
					await frames(30)
					check(is_equal_approx(gun.bloom,6) and is_equal_approx(gun.spread_degrees(),8+extra),"burst cap remains independent and movement spread adds above it")
	await setup()
	hero.tuning.run_speed = 200
	gun.tuning.movement_spread_full_speed = 400
	Input.action_press("core_right")
	await frames(30)
	check(is_equal_approx(gun.movement_spread,2),"half of full movement speed produces half of the forward penalty")
	gun.tuning.movement_spread_start_speed = 250
	await frames(2)
	check(gun.movement_spread == 0,"movement below the configured starting threshold has no penalty")
	await setup()
	Input.action_press("core_right")
	await frames(30)
	Input.action_release("core_right")
	Input.action_press("core_left")
	await frames(1)
	check(hero.velocity.x > 0 and gun.movement_spread_target() <= 4,"direction changes follow actual momentum rather than the newly pressed key")
	await frames(30)
	check(hero.velocity.x < -200 and gun.movement_spread == 10,"backward penalty applies after the player actually reverses")
	await setup()
	gun.tuning.movement_spread_rise_time = .2
	gun.tuning.movement_spread_recovery_time = .3
	Input.action_press("core_right")
	await frames(12)
	check(gun.movement_spread > 0 and gun.movement_spread < gun.movement_spread_target(),"nonzero smoothing builds the movement penalty gradually")
	await frames(70)
	var moving := gun.movement_spread
	Input.action_release("core_right")
	await frames(15)
	check(absf(hero.velocity.x) < .1 and gun.movement_spread > 0 and gun.movement_spread < moving,"the penalty settles gradually after the character stops")
	paused = true
	var frozen := gun.movement_spread
	await frames(12)
	check(gun.movement_spread == frozen,"pause freezes movement-spread smoothing")
	paused = false
	await frames(150)
	check(gun.movement_spread == 0 and gun.spread_degrees() == 2,"settling fully restores the original stationary spread")
	await setup()
	Input.action_press("core_right")
	Input.action_press("core_aim")
	Input.action_press("core_fire")
	await frames(35)
	check(gun.movement_spread > 0 and gun.spread_degrees() == 0 and shots.all(func(shot: Dictionary): return shot.ads and shot.spread == 0 and shot.direction.is_equal_approx(shot.center)),"default ADS coefficient preserves exact aimed shots while running")
	shots.clear()
	gun.tuning.movement_spread_ads_multiplier = .5
	await frames(30)
	check(shots.size() > 4 and shots.all(func(shot: Dictionary): return is_equal_approx(shot.spread,2) and absf(shot.center.angle_to(shot.direction)) <= deg_to_rad(2.001)),"optional ADS coefficient scales real aimed-bullet dispersion")
	check(shots.any(func(shot: Dictionary): return absf(shot.center.angle_to(shot.direction)) > .001),"ADS movement spread actually changes bullet directions when enabled")
	await setup()
	Input.action_press("core_left")
	Input.action_press("core_fire")
	await frames(35)
	panel._sync()
	var bloom := gun.bloom
	panel.feature_toggles.movement_spread_enabled.button_pressed = false
	check(gun.movement_spread == 0 and is_equal_approx(gun.spread_degrees(),minf(8,2+bloom)) and gun.tuning.movement_spread_backward == 10,"switch removes only movement spread immediately without clearing burst or settings")
	var fired := gun.shots_fired
	await frames(10)
	check(gun.shots_fired > fired and hero.velocity.x < 0,"disabling the movement penalty leaves shooting and locomotion active")
	panel.feature_toggles.movement_spread_enabled.button_pressed = true
	await frames(2)
	check(gun.movement_spread == 10,"re-enabling applies the preserved backward setting")
	Input.action_press("core_jump")
	await frames(5)
	check(not hero.is_on_floor() and gun.movement_spread_target() == 0,"airborne travel does not generate a new running penalty")
	await setup()
	hero.reset_to(Vector2(610,760))
	gun.aim_override = Vector2(1500,724)
	Input.action_press("core_right")
	await frames(30)
	check(absf(hero.velocity.x) < .1 and gun.movement_spread == 0,"holding movement against a wall does not count as running")
	await setup()
	panel._sync()
	panel.rows.movement_spread_forward.slider.value = 7
	panel.rows.movement_spread_backward.number.value = 12
	panel.rows.movement_spread_start_speed.slider.value = 20
	panel.rows.movement_spread_full_speed.number.value = 500
	panel.rows.movement_spread_rise_time.slider.value = .4
	panel.rows.movement_spread_recovery_time.number.value = .7
	panel.rows.movement_spread_ads_multiplier.slider.value = .25
	panel.feature_toggles.movement_spread_enabled.button_pressed = false
	check(gun.tuning.movement_spread_forward == 7 and gun.tuning.movement_spread_backward == 12 and panel.rows.movement_spread_forward.number.value == 7 and panel.rows.movement_spread_backward.slider.value == 12,"directional sliders and exact numbers edit the same live settings")
	panel.save_profile()
	var expected := gun.tuning.as_dictionary()
	var loaded := CoreShootingSettings.new()
	check(loaded.load_saved(lab.shooting_settings_path) == OK and same_values(loaded.as_dictionary(),expected),"CFG persists every movement-spread value and master switch")
	var path := directory+"/settings.json"
	check(lab.export_settings_file(path),"JSON export includes movement-spread settings")
	panel.reset_profile()
	check(gun.tuning.movement_spread_enabled and gun.tuning.movement_spread_forward == 3 and gun.tuning.movement_spread_backward == 6 and gun.tuning.movement_spread_ads_multiplier == 0,"Reset restores the default movement penalty and precise ADS")
	check(lab.import_settings_file(path) and same_values(gun.tuning.as_dictionary(),expected) and not panel.feature_toggles.movement_spread_enabled.button_pressed and panel.rows.movement_spread_backward.number.value == 12,"JSON import restores all values and visible controls")
	var legacy := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	for key in expected:
		if str(key).begins_with("movement_spread_"): legacy.shooting.erase(key)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	check(lab.import_settings_file(path) and gun.tuning.movement_spread_enabled and gun.tuning.movement_spread_forward == 3 and gun.tuning.movement_spread_backward == 6 and gun.tuning.movement_spread_ads_multiplier == 0,"older JSON profiles receive movement defaults independently of current edits")
	var cfg := ConfigFile.new()
	cfg.set_value("shooting","hip_spread",5)
	cfg.save(lab.shooting_settings_path)
	loaded = CoreShootingSettings.new()
	check(loaded.load_saved(lab.shooting_settings_path) == OK and loaded.hip_spread == 5 and loaded.movement_spread_enabled and loaded.movement_spread_backward == 6,"older CFG profiles retain existing values and receive compatible defaults")
	loaded.apply_values({"movement_spread_start_speed":100,"movement_spread_full_speed":20,"movement_spread_forward":-5,"movement_spread_ads_multiplier":5})
	check(loaded.movement_spread_full_speed > loaded.movement_spread_start_speed and loaded.movement_spread_forward == 0 and loaded.movement_spread_ads_multiplier == 2,"invalid values and speed thresholds are normalised")
	release()
	hero.reset_to(Vector2(1800,760))
	check(gun.movement_spread == 0,"player reset clears pending movement spread")
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
