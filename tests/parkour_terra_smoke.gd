extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("parkour-terra-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(12)
	var lab: CoreMovementLab = app.game
	var player := lab.player
	var ground = lab.level.ground
	var origin: Vector2 = ground.global_position
	player.tuning.sprint_auto_parkour_enabled = false
	player.tuning.terra_bullet_power = 3.0
	for scenario in [[-1.0, false], [1.0, false], [-1.0, true], [1.0, true]]:
		var side: float = scenario[0]
		player.tuning.terra_collapse_enabled = scenario[1]
		ground.reset_ground()
		await frames(8)
		for y in 12:
			for x in range(86, 112):
				ground.health[y * ground.W + x] = 0.0
				ground.dirty_at(Vector2i(x,y))
		await frames(24)
		var edge := 1792.0 if side > 0 else 1376.0
		var before: int = ground.revision
		for i in 22:
			var local := Vector2(edge + side * (4 + (i % 6) * 5), i / 6 * 5)
			ground.bullet_hit(origin + local, Vector2(side,1).normalized(), 38.0, {"caliber_mm": 7.92, "power":1.0})
			await frames(1)
		var shovel_pixels: int = ground.shovel_cut(Vector2i(int((edge + 12*side)/16), 1), Vector2(edge+10*side,20), Vector2(side,0), 55, 32)
		var removed: int = ground.deform(Vector2(edge+side*24,15), 66, 80, false)
		await frames(28)
		check(removed > 0 and shovel_pixels > 0 and ground.revision > before and not ground.bullet_erased.is_empty(), "bullets, shovel and blast modify the collision grid")
		player.reset_to(origin + Vector2(edge-side*95, 188))
		await frames(12)
		var action := "core_right" if side > 0 else "core_left"
		Input.action_press(action)
		Input.action_press("core_jump")
		var climbs := 0
		var active := false
		for i in 200:
			await frames(1)
			if player.parkour_active() and not active: climbs += 1
			active = player.parkour_active()
			if player.is_on_floor() and player.global_position.y < origin.y + 5: break
		Input.action_release(action)
		Input.action_release("core_jump")
		print("TERRA EDGE ", side, " climbs=", climbs, " pos=", player.global_position-origin)
		check(climbs > 0 and player.is_on_floor() and player.global_position.y < origin.y+5, "held parkour exits the damaged bank, side %s, collapse=%s" % [side, scenario[1]])
		await frames(8)
	var pile = preload("res://scripts/core/terra_deposit.gd").new()
	pile.tuning = player.tuning
	pile.position = Vector2(2250, 0)
	pile.pieces = [[PackedVector2Array([Vector2(0,1), Vector2(12,-112), Vector2(245,-107), Vector2(245,1)]), Color("705c48"), 1]]
	ground.add_child(pile)
	player.reset_to(origin + Vector2(2198,-1))
	await frames(10)
	player.tuning.set_parameter("parkour_mantle_time", 2.5)
	player.tuning.set_parameter("parkour_vault_time", 2.0)
	check(is_equal_approx(player.tuning.parkour_mantle_time, 2.5) and is_equal_approx(player.tuning.parkour_vault_time, 2.0),
		"developer sliders allow both longer durations")
	Input.action_press("core_right")
	Input.action_press("core_jump")
	var on_pile := false
	for i in 250:
		await frames(1)
		if player.global_position.y < origin.y - 100 and player.is_on_floor():
			on_pile = true
			break
	Input.action_release("core_right")
	Input.action_release("core_jump")
	check(on_pile, "held parkour reaches the top of a baked deposit")
	print("TERRA PARKOUR %d/%d" % [checks-failures,checks])
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit(1 if failures else 0)
