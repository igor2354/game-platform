extends SceneTree
## Read-only framing audit. Never loads or saves the user's five live profiles.
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,900)
	root.gui_embed_subwindows = true
	var directory := OS.get_environment("TEMP").path_join("world-scale-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/campaign/prologue.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],directory.path_join(entry[1]))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab)
	await frames(6)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--camera-copy="):
			var error := lab.camera_settings.load_saved(argument.trim_prefix("--camera-copy="))
			if error != OK:
				push_error("Camera copy could not be read: %s" % error)
				quit(1)
				return
	var original_camera := lab.camera_settings.as_dictionary()
	# Inspect geometry without pixelation, blur or noir hiding the silhouettes.
	lab.camera_settings.pixel_enabled = false
	lab.camera_settings.noir_enabled = false
	lab.camera_settings.character_blur_strength = 0
	lab.player.weapon.aim_override = lab.player.global_position+Vector2(500,-32)
	paused = true
	var result := {"date":"2026-10-23","viewport":Vector2(1600,900),"camera_copy":original_camera,
		"hero_collision_height":CoreMovementPlayer.HEIGHT,"forest_unit_H":lab.level.forest.H,
		"background_texture":lab.level.forest.BACKDROP.get_size(),"background_scale":lab.level.forest.BACKDROP_SCALE,
		"background_world_size":lab.level.forest.BACKDROP.get_size()*lab.level.forest.BACKDROP_SCALE,
		"forest_length":lab.level.forest.WIDTH,"forest_length_in_hero_heights":lab.level.forest.WIDTH/CoreMovementPlayer.HEIGHT,
		"frames":[]}
	for zoom in [.75,1.5,2.25]:
		lab.camera_settings.zoom = zoom
		lab._camera_settings_changed()
		lab._update_camera(true)
		await frames(3)
		await RenderingServer.frame_post_draw
		var transform := lab.player.get_global_transform_with_canvas()
		var height := (transform*Vector2.ZERO).distance_to(transform*Vector2(0,-CoreMovementPlayer.HEIGHT))
		var picture := root.get_texture().get_image()
		var path := MEDIA.path("docs/core/scale_audit_20261023/zoom_%03d.png" % roundi(zoom*100))
		if picture.save_png(path) != OK:
			push_error("Cannot save scale audit screenshot")
			quit(1)
			return
		result.frames.append({"zoom":zoom,"hero_capsule_screen_height":height,"screen_height_percent":height/900*100,
			"visible_world_width":1600/zoom,"visible_world_height":900/zoom,"image":path})
	var output := FileAccess.open(MEDIA.path("docs/core/scale_audit_20261023/measurements.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"))
	output.close()
	print("SCALE AUDIT: 3 native frames; world geometry and real profiles unchanged.")
	paused = false
	lab.queue_free()
	await frames(2)
	quit()
