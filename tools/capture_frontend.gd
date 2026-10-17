extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
var app: Node
var directory := "res://docs/campaign"

func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func snapshot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))

func capture() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	app = FRONTEND.new()
	app.load_user_settings = false
	root.add_child(app)
	await snapshot("main")
	app.show_page("characters")
	await snapshot("characters_harry")
	app.select_character("sofia")
	await snapshot("characters_sofia")
	app.show_page("weapons")
	await snapshot("weapons_sofia")
	app.selected_character = "harry"
	app.select_weapon("mp40")
	await snapshot("weapons_harry")
	for id in ["harry","sofia"]:
		app.selected_character = id
		app.selected_weapon = "stg44" if id == "harry" else "m1911"
		app.launch(true)
		await frames(8)
		var lab: CoreMovementLab = app.game
		lab.player.weapon.tuning.sound_enabled = false
		lab.player.weapon.aim_override = lab.player.position+Vector2(300,-36)
		lab.camera_settings.apply_values({"zoom":3.0,"offset_x":0,"offset_y":-30,"look_ahead":0,"follow_speed":0})
		lab._update_camera(true)
		await snapshot("prologue_"+id)
		if id == "sofia":
			lab.developer_mode.toggle()
			await snapshot("developer_prologue")
		await app.return_to_menu()
	app.queue_free()
	await frames(4)
	print("FRONTEND CAPTURE complete")
	quit()
