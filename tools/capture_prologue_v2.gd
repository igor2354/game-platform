extends SceneTree
## Native previews, Sofia only, all five user profile destinations isolated.
const MEDIA = preload("res://tools/media_paths.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue_v2.gd")
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
var app
var lab: CoreMovementLab
var directory := ""
func _initialize() -> void:call_deferred("capture")
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func save_frame(file:String) -> void:
	await frames(3);await RenderingServer.frame_post_draw
	var error=root.get_texture().get_image().save_png(directory.path_join(file+".png"))
	assert(error==OK);print("CAPTURE ",file)
func capture() -> void:
	directory=MEDIA.path("docs/locations/mvp_village/Проверки/prologue_ver2_runtime_2026-10-25")
	root.size=Vector2i(1600,900)
	app=FRONTEND.new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("prologue-v2-capture-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);await frames(3)
	app.buttons.campaign.pressed.emit();await save_frame("menu_two_prologues")
	app.buttons.prologue_v2.pressed.emit();app.buttons.sofia.pressed.emit();app.buttons.choose.pressed.emit();app.buttons.apply.pressed.emit()
	lab=app.game;await frames(10)
	lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"zoom":2.25,"offset_x":0,"offset_y":-130,"look_ahead":0,"follow_speed":0,"limit_to_level":false,"noir_enabled":false,"pixel_enabled":false,"stable_pixel_enabled":false,"world_pixel_enabled":false})
	lab._camera_settings_changed();lab.aim_cursor.hide()
	lab._update_camera(true);await save_frame("start_sofia_285")
	lab.set_process(false)
	# Geometry overview uses the actual instantiated level; only capture framing differs.
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	for n in FOREST.DATA.PLAN.nodes:
		lab.player.reset_to(FOREST.point(n.start_m+2,12));lab.player.set_physics_process(false)
		lab.player.hide()
		lab.camera.zoom=Vector2.ONE*minf(.46,1450.0/(n.length_m*FOREST.UPM))
		lab.camera.position=FOREST.point(n.start_m+n.length_m*.5,1.4)
		lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await save_frame("section_"+n.id)
	lab.player.show()
	for record in [["root_passage",78,1.3,true],["house",315,.6,false],["bunker",405,.3,false],["fatal_chasm",243,2.6,false]]:
		lab.player.reset_to(FOREST.point(record[1],record[2]));lab.player.set_physics_process(true)
		lab.player.weapon.aim_override=lab.player.position+Vector2(700,-100)
		if record[3]:Input.action_press("core_crouch")
		await frames(8);lab.player.set_physics_process(false)
		lab.camera.zoom=Vector2.ONE*.95
		lab.camera.position=lab.player.position+Vector2(240,-190)
		lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await save_frame(record[0]);Input.action_release("core_crouch")
	app.queue_free();await frames(3)
	print("NATIVE V2: 18 frames; ",directory);quit()
