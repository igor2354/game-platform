extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")

func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func save_frame(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	var crate: RigidBody2D = lab.level.physics_crate
	hero.reset_to(Vector2(-970,760))
	crate.home_transform = Transform2D(0,Vector2(-800,728))
	crate.reset_crate()
	hero.weapon.tuning.hip_spread = 0
	hero.weapon.tuning.hip_max_spread = 0
	hero.weapon.tuning.recoil_enabled = false
	lab.camera_settings.apply_values({"zoom":2.3,"offset_x":80,"offset_y":-80,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	await frames(20)
	for i in 4:
		hero.weapon.aim_override = crate.global_position
		await frames(2)
		hero.weapon._fire()
		await frames(14)
		if i == 2: await save_frame(MEDIA.path("docs/core/crate_damaged.png"))
	await frames(120)
	await save_frame(MEDIA.path("docs/core/crate_destroyed.png"))
	lab.queue_free()
	await process_frame
	quit()
