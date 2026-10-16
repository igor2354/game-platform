extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/camera-turn-%d" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func step(delta := 1.0/60.0) -> void:
	lab._process(delta)
	lab.camera.force_update_scroll()

func face(side: float) -> void:
	lab.player.weapon.aim_override = lab.player.position+Vector2(side*700,-32)
	lab.player.weapon._update_aim()

func prepare(side: float,zoom: float,follow: float,turn := .35) -> void:
	lab.player.reset_to(Vector2(2200,760))
	lab.camera_settings.apply_values({"zoom":zoom,"offset_x":180,"offset_y":-100,"look_ahead":200,"follow_speed":follow,"look_turn_duration":turn,"limit_to_level":false})
	face(side)
	lab._update_camera(true)
	lab.camera.force_update_scroll()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	root.add_child(lab)
	var isolated := lab._overlays().all(func(overlay): return overlay.settings_path.begins_with(directory+"/"))
	check(isolated,"all five test profiles are isolated from the real player settings")
	if not isolated:
		lab.queue_free()
		quit(1)
		return
	await process_frame
	lab.set_process(false)
	lab.player.set_physics_process(false)
	lab.player.weapon.tuning.recoil_enabled = false
	for side in [-1.0,1.0]:
		for zoom in [.5,2.0,3.0]:
			prepare(side,zoom,0)
			var previous := lab.camera.get_screen_center_position()
			face(-side)
			var max_step := 0.0
			var monotonic := true
			for frame in 90:
				step()
				var current := lab.camera.get_screen_center_position()
				max_step = maxf(max_step,absf(current.x-previous.x)*zoom)
				monotonic = monotonic and (current.x-previous.x)*-side >= -.001
				previous = current
			check(max_step < 36,"side change is smooth with zero follow speed: side %s zoom %s, max %.2f screen px/frame" % [side,zoom,max_step])
			check(monotonic and previous.distance_to(lab.camera_target())*zoom < .1,"turn settles at exact desired framing without rebound")
	# Smooth direction must not add movement latency when follow is disabled.
	prepare(1,2,0)
	lab.player.position.x += 120
	step()
	check(absf(lab.camera.position.x-lab.camera_target().x) < .01,"zero follow still tracks player movement immediately")
	# Rapid retargets preserve position and velocity instead of snapping to an endpoint.
	prepare(1,2,0)
	var previous := lab.camera.get_screen_center_position()
	var max_step := 0.0
	for frame in 120:
		face(-1 if frame%12 < 6 else 1)
		step()
		var current := lab.camera.get_screen_center_position()
		max_step = maxf(max_step,absf(current.x-previous.x)*2)
		previous = current
	check(max_step < 36,"rapid alternating aim never teleports the camera")
	face(-1)
	for frame in 90: step()
	check(lab.camera.position.distance_to(lab.camera_target()) < .1,"interrupted turn converges to final side")
	# Frame-rate independence and a useful adjustable turn duration.
	var samples := []
	for fps in [30,60,120]:
		prepare(1,2,0,.6)
		face(-1)
		for frame in fps/5: step(1.0/fps)
		samples.append(lab.camera.position.x)
	check(absf(samples.max()-samples.min()) < .01,"same turn trajectory at 30, 60 and 120 FPS")
	prepare(1,2,0,.2)
	face(-1)
	for frame in 12: step()
	var fast_remaining := lab.camera.position.distance_to(lab.camera_target())
	prepare(1,2,0,.8)
	face(-1)
	for frame in 12: step()
	check(lab.camera.position.distance_to(lab.camera_target()) > fast_remaining*3,"duration changes the complete transition, not only its start")
	var before_pause := lab.camera.get_screen_center_position()
	paused = true
	for frame in 30: step()
	check(lab.camera.get_screen_center_position().distance_to(before_pause) < .01,"pause freezes an unfinished turn")
	paused = false
	for frame in 180: step()
	check(lab.camera.position.distance_to(lab.camera_target()) < .1,"turn resumes after pause")
	prepare(1,2,0,0)
	face(-1)
	step()
	check(lab.camera.position.distance_to(lab.camera_target()) < .01,"zero turn duration explicitly restores an instant side change")
	prepare(1,2,0)
	face(-1)
	step()
	lab.player.position.x = -1800
	lab._update_camera(true)
	lab.camera.force_update_scroll()
	check(lab.camera.get_screen_center_position().distance_to(lab.camera_target()) < .01,"teleport resets turn state without dragging the old framing")
	var overlay := lab.camera_overlay
	check(overlay.rows.has("look_turn_duration"),"camera panel exposes a separate turn-duration slider")
	if overlay.rows.has("look_turn_duration"):
		overlay.rows.look_turn_duration.slider.value = .65
		check(lab.camera_settings.get("look_turn_duration") == .65 and overlay.rows.look_turn_duration.number.value == .65,"turn slider and exact input stay synchronized")
		overlay.save_profile()
		var loaded := CoreCameraSettings.new()
		check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.get("look_turn_duration") == .65,"turn duration survives CFG save/load")
		var path := directory+"/balance.json"
		check(lab.export_settings_file(path),"new camera setting exports in the balance file")
		overlay.rows.look_turn_duration.number.value = .1
		check(lab.import_settings_file(path) and lab.camera_settings.get("look_turn_duration") == .65,"JSON import restores turn duration")
		var legacy := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
		legacy.camera.erase("look_turn_duration")
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy))
		file.close()
		check(lab.import_settings_file(path) and lab.camera_settings.get("look_turn_duration") == .35,"old JSON profiles get a smooth default turn")
		var config := ConfigFile.new()
		config.set_value("camera","follow_speed",0)
		config.set_value("camera","look_ahead",200)
		config.save(lab.camera_settings_path)
		loaded = CoreCameraSettings.new()
		check(loaded.load_saved(lab.camera_settings_path) == OK and loaded.get("look_turn_duration") == .35 and loaded.follow_speed == 0,"legacy CFG preserves user framing and gets smooth direction changes")
	lab.queue_free()
	await process_frame
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+name)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
