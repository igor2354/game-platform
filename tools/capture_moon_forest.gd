extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
var app: Node
var directory: String
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	directory = MEDIA.path("docs/moon_forest_preview")
	if directory.is_empty(): quit(1); return
	root.size = Vector2i(1600,900)
	app = load("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("moon-forest-capture-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.begin_selection(false)
	app.select_character("harry")
	app.launch(false)
	await frames(10)
	var lab: CoreMovementLab = app.game
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.weapon.aim_override = lab.player.position+Vector2(300,-35)
	await frames(4)
	await shot("game")
	paused = true
	for index in 48:
		lab.moon_forest.elapsed = float(index)/8.0
		lab.moon_forest.update_effect(0)
		await shot("frame_%02d" % index)
	# Capture isolated effects with identical time and framing for comparison.
	for key in ["wind","clouds","smoke","fire","water"]:
		for other in ["wind","clouds","smoke","fire","water"]:
			lab.camera_settings.set("forest_"+other+"_enabled",other == key)
		for time in [0.0,1.5]:
			lab.moon_forest.elapsed = time
			lab.moon_forest.update_effect(0)
			await shot(key+("_a" if time == 0 else "_b"))
	paused = false
	await app.return_to_menu()
	app.queue_free()
	await frames(2)
	print("MOON FOREST CAPTURE: ",directory)
	quit()
