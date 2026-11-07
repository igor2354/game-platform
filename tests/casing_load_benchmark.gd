extends SceneTree
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await physics_frame
	await process_frame
func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("casing-load-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app); app.selected_level = "polygon"; app.launch(false)
	for i in 30: await frame()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lab = app.game
	var weapon = lab.player.weapon
	var query := PhysicsRayQueryParameters2D.create(lab.player.global_position-Vector2(0,100),lab.player.global_position+Vector2(0,200),1)
	var hit: Dictionary = weapon.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): push_error("benchmark floor missing"); quit(1); return
	if "--offscreen" in OS.get_cmdline_user_args():
		lab.player.reset_to(lab.player.global_position+Vector2(3000,0))
	lab.player.invulnerable = true
	var rng := RandomNumberGenerator.new(); rng.seed = 149
	var size: Vector2 = preload("res://scripts/campaign/catalog.gd").casing_mm("stg44")*CoreWorldUnits.units(.001)*lab.player.character_scale()
	for count in [0,1000,5000,10000]:
		weapon.effects.clear()
		for i in count:
			var point: Vector2 = hit.position+Vector2((i%100)*2-100,-.5)
			var effect: Dictionary = weapon.casing_motion.spawn(point,Vector2.RIGHT,size,"stg44",rng)
			weapon.casing_motion._settle(effect,hit)
			effect.smoke_age = 10.0; effect.contact_audio_played = true
			weapon.effects.append(effect)
		for i in 15: await frame()
		var update_samples: Array[float] = []
		for i in 9:
			var began := Time.get_ticks_usec()
			weapon.update_state(1.0/60.0,false)
			update_samples.append((Time.get_ticks_usec()-began)/1000.0)
		update_samples.sort()
		var memory := OS.get_static_memory_usage()
		var samples: Array[float] = []
		var started := Time.get_ticks_usec()
		var start_frames := Engine.get_process_frames()
		for i in 120:
			var began := Time.get_ticks_usec()
			await frame()
			samples.append((Time.get_ticks_usec()-began)/1000.0)
		var fps := (Engine.get_process_frames()-start_frames)*1000000.0/(Time.get_ticks_usec()-started)
		samples.sort()
		print("CASING LOAD ",JSON.stringify({"count":count,"update_ms":update_samples[4],"median_ms":samples[60],"p95_ms":samples[114],"fps":fps,"static_bytes":memory,"retained":weapon.effects.size()}))
	app.queue_free()
	for i in 3: await frame()
	quit()
