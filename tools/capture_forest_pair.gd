extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	var temporary := "/private/tmp/forest-pair-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(temporary)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],temporary.path_join(entry[1]))
	root.add_child(lab)
	lab.camera_settings.look_ahead = 0
	lab.player.weapon.tuning.sound_enabled = false
	await frames(8)
	paused = true
	var directory := MEDIA.path("docs/forest_pair_preview")
	var phase := OS.get_environment("FOREST_PAIR_PHASE")
	if phase.is_empty(): phase = "after"
	for entry in [["spawn",160.0],["join",-500.0],["left",-1100.0]]:
		lab._teleport_player(Vector2(entry[1],760))
		lab.player.weapon.aim_override = lab.player.global_position+Vector2(300,-35)
		lab.moon_forest.elapsed = 0
		lab.moon_forest.update_effect(0)
		await frames(4)
		await RenderingServer.frame_post_draw
		var path := directory.path_join(phase+"_"+entry[0]+".png")
		var result := root.get_texture().get_image().save_png(path)
		if result != OK: push_error("Cannot save "+path); quit(1); return
	paused = false
	lab.queue_free()
	await frames(3)
	print("FOREST PAIR CAPTURE: ",directory)
	quit()
