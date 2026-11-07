extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func jump_right() -> void:
	Input.action_press("core_jump")
	await frames(5)
	Input.action_press("core_right")
	await frames(52)
	Input.action_release("core_jump")
	Input.action_release("core_right")
	await frames(20)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("shovel-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(12)
	var lab: CoreMovementLab = app.game
	var player := lab.player
	var ground = lab.level.ground
	var shovel = player.weapon.shovel
	var base: Vector2 = ground.global_position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_X
	key.pressed = true
	root.push_input(key, true)
	check(player.weapon.shovel_selected(), "X immediately equips the shovel before developer issuance")
	ground.reset_ground()
	await frames(8)
	await lab.level.prepare_shovel_crater()
	shovel.select_tool(false)
	player.tuning.parkour_enabled = false
	player.weapon.aim_cursor.focus_override = true
	player.weapon.aim_cursor.sync_context()
	await frames(14)
	var start_y := player.global_position.y
	await jump_right()
	check(player.global_position.y > start_y - 5, "ordinary jump cannot escape the original deep crater")
	shovel.issue()
	check(player.weapon.shovel_selected() and not player.weapon.request_reload(), "tool equips and blocks reload")
	check(lab.movement_overlay.rows.has("shovel_depth"), "developer depth control exists")
	var revision: int = ground.revision
	var target := player.global_position + Vector2(110, -56)
	player.weapon.aim_override = target
	await frames(3)
	check(shovel.preview.reason.is_empty() and ground.revision == revision, "preview is valid and leaves terrain untouched")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var folder := preload("res://tools/media_paths.gd").path("docs/core/shovel_rounded_20261104")
		check(root.get_texture().get_image().save_png(folder.path_join("shovel_preview.png")) == OK, "saved preview capture")
	var wall := StaticBody2D.new()
	wall.collision_layer = 32
	var wall_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 120)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	lab.level.add_child(wall)
	wall.global_position = shovel.origin() + Vector2(20, 0)
	await frames(4)
	check(not shovel.preview.reason.is_empty() and ground.revision == revision, "near blocker rejects the soil behind it")
	wall.queue_free()
	await frames(4)
	shovel.queue_cycle()
	await frames(5)
	shovel.select_tool(false)
	await frames(38)
	check(ground.revision == revision, "cancel before contact preserves the wall")
	shovel.select_tool(true)
	var noise_events: Array[float] = []
	player.noise_emitted.connect(func(_point: Vector2, loudness: float, kind: String):
		if kind == "shovel": noise_events.append(loudness))
	player.tuning.shovel_volume = -60.0
	player.tuning.shovel_noise = .85
	check(player.tuning.shovel_width <= 80.0 and player.tuning.shovel_depth <= 37.0, "shovel footprint is at most a third on each axis")
	var before: PackedFloat32Array = ground.health.duplicate()
	Input.action_press("core_fire")
	await frames(23)
	Input.action_release("core_fire")
	await frames(23)
	var changed := 0
	for i in ground.health.size():
		if ground.health[i] < before[i]: changed += 1
	check(changed > 0 and changed <= 24, "first real shovel cycle removes only a small patch")
	check(noise_events.size() == 1 and is_equal_approx(noise_events[0], .85) and not shovel.audio.playing, "muting player audio leaves independent zombie hearing signal")

	var narrow: PackedVector2Array = shovel.footprint(Vector2.ZERO, Vector2.DOWN, 1.0)
	player.tuning.shovel_area = 25.0
	var smaller: PackedVector2Array = shovel.footprint(Vector2.ZERO, Vector2.DOWN, 1.0)
	var materials := preload("res://scripts/core/terra_materials.gd")
	check(narrow.size() == 20 and is_equal_approx(materials.area(smaller) / materials.area(narrow), .25), "rounded area slider scales actual footprint")
	player.tuning.shovel_area = 100.0
	var edge: Vector2 = base + Vector2(1770, -4)
	player.weapon.aim_override = edge
	await frames(3)
	var edge_revision: int = ground.revision
	check(shovel.preview.reason.is_empty() and shovel.preview.anchor.distance_to(edge) < 3, "edge overlap works with cursor outside soil")
	shovel.queue_cycle()
	await frames(44)
	check(ground.revision > edge_revision, "edge-only overlap removes soil")
	var local_box := PackedVector2Array([Vector2(0,0),Vector2(72,0),Vector2(72,44),Vector2(0,44)])
	var material_color := Color("705c48")
	for baked in [false,true]:
		var body = load("res://scripts/core/terra_deposit.gd" if baked else "res://scripts/core/terra_fragment.gd").new()
		body.pieces = [[local_box,material_color,1]]
		if baked: body.tuning = player.tuning
		ground.add_child(body)
		body.global_position = player.global_position + Vector2(-125, -44 if baked else -105)
		if not baked:
			body.gravity_scale = 0.0
			body.linear_velocity = Vector2(-15,0)
		await frames(3)
		var aim: Vector2 = body.to_global(Vector2(68,20))
		player.weapon.aim_override = aim
		await frames(3)
		check(shovel.preview.get("owner") == body and shovel.preview.reason.is_empty(), "nearest rubble is a valid target, baked=%s" % baked)
		var old_mass: float = body.mass
		shovel.queue_cycle()
		await frames(24)
		check(is_instance_valid(body) and body.mass < old_mass, "rubble loses material during the contact cycle, baked=%s" % baked)
		if is_instance_valid(body): body.queue_free()
		await frames(22)
	var data := player.tuning.as_dictionary()
	var restored := CoreMovementSettings.new()
	restored.apply_values(data)
	check(is_equal_approx(restored.shovel_noise, .85) and restored.shovel_depth == player.tuning.shovel_depth, "developer settings round-trip through profile values")

	# A clay cut at the wood boundary should stop at the material seam.
	var x_wood: int = ceili(float(ground.W) * 3.0 / 5.0)
	var clay := Vector2i(x_wood-1, 0)
	var wood := clay + Vector2i.RIGHT
	var clay_before: float = ground.health[clay.x]
	var wood_before: float = ground.health[wood.x]
	var removed: int = ground.shovel_cut(clay, Vector2(clay.x*16+8, 0), Vector2.DOWN, 160, 112)
	check(removed > 0 and ground.health[clay.x] < clay_before and ground.health[wood.x] == wood_before, "mixed clay and wood cut removes only permitted ground")
	check(ground.shovel_cut(wood, Vector2(wood.x*16+8, 0), Vector2.DOWN, 160, 112) == 0, "wood refuses a direct cut")
	check(ground.shovel_cut(Vector2i(5,0), Vector2(88,0), Vector2.DOWN, 160, 112) == 0, "protected entrance refuses a cut")
	var tiny := Vector2i(50,0)
	var tiny_index: int = tiny.x
	var full_health: float = ground.health[tiny_index]
	var shaved: int = ground.shovel_cut(tiny, Vector2(808,-15.75), Vector2.DOWN, 16, 16)
	check(shaved > 0 and ground.health[tiny_index] > 0.0 and ground.health[tiny_index] < full_health, "sub-cell grazing cut shaves only the intersected strip")
	player.tuning.shovel_enabled = false
	check(ground.shovel_cut(Vector2i(40,20), Vector2(648,320), Vector2.DOWN, 160, 112) == 0, "disabled tool cannot mutate ground")
	await frames(20)
	var saved_health: PackedFloat32Array = ground.health.duplicate()
	await app.return_to_menu()
	app.launch(true)
	await frames(18)
	check(app.game.level.ground.health == saved_health, "excavation persists across re-entry in the current session")
	print("SHOVEL %d/%d" % [checks-failures,checks])
	await app.return_to_menu()
	quit(1 if failures else 0)
