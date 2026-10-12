extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.reset_to(Vector2(2250,760))
	lab.player.weapon.aim_override = Vector2(2460,728)
	lab.player.weapon.rng.seed = 2354
	lab.set_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/core/combat_frames")
	DirAccess.make_dir_recursive_absolute("res://docs/core/audio")
	var saved_kill := false
	for i in 60:
		if i == 10: Input.action_press("core_fire")
		if i == 43: Input.action_release("core_fire")
		await create_timer(1.0/30).timeout
		lab._process(1.0/30)
		lab.camera.position = Vector2(2800,450)
		lab.camera.reset_smoothing()
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		frame.save_png("res://docs/core/combat_frames/%03d.png" % i)
		if lab.player.weapon.kill_marker_left > 0 and not saved_kill:
			frame.save_png("res://docs/core/combat_feel_kill.png")
			saved_kill = true
	lab.shooting_overlay.toggle()
	lab.shooting_overlay.tabs.current_tab = 3
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/combat_feel_settings.png")
	lab.shooting_overlay.tabs.current_tab = 4
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/core/combat_feel_sound.png")
	for kind in ["shot","hit","kill"]:
		var stream := CoreCombatAudio.make_stream(kind)
		var result := stream.save_to_wav("res://docs/core/audio/"+kind+".wav")
		print("AUDIO ",kind," ",result)
	print("DEMO KILLS ",lab.player.weapon.kills," KILL FRAME ",saved_kill)
	quit()
