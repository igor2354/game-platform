extends SceneTree
var lab: CoreMovementLab
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func capture() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	var trap := lab.level.hanging_loads[1]
	lab.player.reset_to(Vector2(trap.position.x-200,760))
	lab.player.weapon.tuning.apply_values({"recoil_enabled":false,"sound_enabled":false,"hip_spread":0,"hip_max_spread":0,"sway_radius":0})
	lab.player.weapon.aim_override = trap.rope.global_position
	lab.camera_settings.apply_values({"zoom":2.0,"offset_x":180,"offset_y":-135,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	await frames(600)
	lab._update_camera(true)
	DirAccess.make_dir_recursive_absolute("/private/tmp/net-tear-frames")
	for filename in DirAccess.get_files_at("/private/tmp/net-tear-frames"):
		if filename.ends_with(".png") and filename.get_basename().is_valid_int(): DirAccess.remove_absolute("/private/tmp/net-tear-frames/"+filename)
	for index in 140:
		if index == 45: lab.player.weapon._fire()
		await frames(1)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/net-tear-frames/%03d.png" % index)
	print("CAPTURE ground tear: ",trap.ruptured and trap.physical_net.impact_breaks > 0)
	lab.queue_free()
	await process_frame
	quit()
