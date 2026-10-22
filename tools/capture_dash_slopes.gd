extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hill := lab.level.slopes[1]
	lab.player.reset_to(hill[0].lerp(hill[1],.6)-Vector2(0,10))
	lab.player.weapon.aim_override = Vector2(4800,520)
	lab.camera_settings.look_ahead = 0
	lab.player.tuning.apply_values({"dash_uphill_multiplier":.75,"dash_downhill_multiplier":1.25})
	for tick in 20: await physics_frame
	lab.player.facing = 1
	Input.action_press("core_dash")
	for tick in 3: await physics_frame
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Дэш")
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var scroll := lab.movement_overlay.tabs.get_current_tab_control() as ScrollContainer
	for child in scroll.get_child(0).get_children():
		if child is Label and child.text == "Наклонные поверхности": scroll.scroll_vertical = int(child.position.y)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/dash_slope_settings.png"))
	var defaults := {"movement":lab.movement_overlay.defaults,"shooting":lab.shooting_overlay.defaults,"camera":lab.camera_overlay.defaults,"zombie":lab.zombie_overlay.defaults}
	lab.SettingsFile.write_file(MEDIA.path("docs/core/settings-defaults.json"),defaults)
	Input.action_release("core_dash")
	lab.queue_free()
	await process_frame
	quit()
