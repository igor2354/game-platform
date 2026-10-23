extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func shot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	if result != OK: push_error("Capture failed: "+path)
func run() -> void:
	root.size = Vector2i(1600,900)
	var directory := MEDIA.path("docs/indoor_lighting_preview")
	var temporary := "/private/tmp/indoor-capture-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(temporary)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	for entry in [["settings_path","movement.cfg"],["shooting_settings_path","shooting.cfg"],["camera_settings_path","camera.cfg"],["zombie_settings_path","zombie.cfg"],["ragdoll_settings_path","ragdoll.cfg"]]:
		lab.set(entry[0],temporary.path_join(entry[1]))
	root.add_child(lab)
	await frames(6)
	lab._teleport_player(Vector2(6350,760))
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.weapon.aim_override = lab.level.indoor_lighting.lamp.global_position
	await frames(5)
	for enemy in lab.level.enemies: enemy.set_test_frozen(true)
	var room := lab.level.indoor_lighting
	lab.level.indoor_zombie.facing = -1
	for debug in [false,true]:
		lab.player.debug_shape = debug
		for enemy in lab.level.enemies: enemy.debug_zones = debug; enemy.queue_redraw()
		room.lamp.reset_lamp()
		await frames(3)
		await shot(directory.path_join("lit"+("_f1" if debug else "")+".png"))
		room.lamp.take_projectile_damage(100)
		await frames(20)
		await shot(directory.path_join("dark"+("_f1" if debug else "")+".png"))
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_overlay(3)
	lab.zombie_overlay.tabs.current_tab = 8
	await frames(4)
	await shot(directory.path_join("settings.png"))
	lab.queue_free()
	await frames(3)
	print("INDOOR CAPTURE: ",directory)
	quit()
