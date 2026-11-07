extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(15)
	var player: CoreMovementPlayer = app.game.player
	var origin: Vector2 = app.game.level.player_spawn()
	var effects = player.sole_effects
	player.reset_to(origin + Vector2(0, -90))
	await frames(29)
	check(player.is_on_floor() and not effects.parts.is_empty(), "actual landing on sand emits dust")
	check(effects.parts.all(func(part): return not part.mark and absf(part.point.y - origin.y) < 1.0), "dust starts at the surface")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var path := preload("res://tools/media_paths.gd").path("docs/core/sole_effects_20261105/sand_landing.png")
		check(root.get_texture().get_image().save_png(path) == OK, "saved sand landing frame")
	await frames(34)
	check(effects.parts.is_empty() and not effects.is_physics_processing(), "dust expires and the emitter rests")
	effects.contact_tick(player.global_position, Vector2(260, 0), true, false, 1.0/60.0)
	check(not effects.parts.is_empty(), "hard braking emits dust")
	player.tuning.sole_effects_enabled = false
	await frames(3)
	check(effects.parts.is_empty(), "independent toggle clears visible particles")
	player.tuning.sole_effects_enabled = true
	var floor := StaticBody2D.new()
	floor.position = origin + Vector2(0, -180)
	floor.set_meta("terra_material", 3)
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(260, 12)
	collider.position.y = 6
	collider.shape = box
	floor.add_child(collider)
	app.game.get_node("World").add_child(floor)
	player.reset_to(floor.position + Vector2(0, -90))
	await frames(30)
	check(player.is_on_floor() and effects.parts.is_empty(), "dry stone produces no dust")
	floor.set_meta("foot_surface", "wet")
	effects.contact_tick(player.global_position, Vector2(260, 0), true, false, 1.0/60.0)
	floor.remove_meta("foot_surface")
	for i in 3:
		effects.contact_tick(player.global_position - Vector2(60, 0), Vector2.ZERO, true, false, 1.0/60.0)
	check(effects.parts.size() == 4 and effects.parts[-1].color.a < effects.parts[0].color.a, "wet floor leaves three fading transferred prints")
	floor.set_meta("foot_surface", "mud")
	effects.contact_tick(player.global_position - Vector2(60, 0), Vector2.ZERO, true, false, 1.0/60.0)
	check(effects.parts.size() == 5 and effects.parts[-1].duration == 7.0, "mud leaves a longer footprint")
	app.queue_free()
	await process_frame
	quit(int(failures > 0))
