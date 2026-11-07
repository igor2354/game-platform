extends SceneTree
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("shovel-wedge-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(12)
	var lab: CoreMovementLab = app.game
	var player := lab.player
	var ground = lab.level.ground
	var center: Vector2 = ground.global_position + Vector2(1650,0)
	var banks: Array[Node2D] = []
	for side in [-1,1]:
		var bank = preload("res://scripts/core/terra_deposit.gd").new()
		bank.tuning = player.tuning
		var poly := PackedVector2Array([Vector2(20,0),Vector2(73,-180),Vector2(200,-180),Vector2(200,3),Vector2(20,3)])
		for i in poly.size(): poly[i].x *= side
		bank.pieces = [[poly,Color("705c48"),1]]
		bank.position = ground.to_local(center)
		ground.add_child(bank)
		banks.append(bank)
	player.reset_to(center + Vector2(0,-208))
	var shovel = player.weapon.shovel
	shovel.issue()
	await frames(8)
	check(not shovel.can_work(), "free fall cannot use the shovel")
	await frames(155)
	check(not player.is_on_floor() and player.velocity.y > 100 and player.braced_in_terrain(),
		"opposing steep terrain contacts reproduce the stalled capsule")
	check(shovel.can_work(), "wedged player can use the shovel")
	var y := player.global_position.y
	var jumps := player.jumps
	Input.action_press("core_jump")
	await frames(9)
	Input.action_release("core_jump")
	check(player.jumps == jumps + 1 and player.global_position.y < y - 12.0,
		"ordinary jump moves the wedged capsule upward")
	await frames(115)
	player.weapon.aim_cursor.focus_override = true
	player.weapon.aim_cursor.sync_context()
	player.weapon.aim_override = center + Vector2(115, -105)
	await frames(4)
	var old_mass: float = banks[1].mass
	shovel.queue_cycle()
	await frames(45)
	check(banks[1].mass < old_mass, "shovel actually cuts the bank while the capsule is wedged")
	print("SHOVEL WEDGE %d/%d" % [checks-failures, checks])
	await app.return_to_menu()
	quit(1 if failures else 0)
