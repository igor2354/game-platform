extends SceneTree

const CASING = preload("res://scripts/core/weapon_casing.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const WEAPONS = ["stg44", "mp40", "svt", "m1911"]
const SHOTS := 24
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func cases(gun: Node) -> Array:
	return gun.effects.filter(func(effect): return effect.kind == "casing")

func run() -> void:
	await test_surfaces()
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_temp_dir().path_join("casing-series-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.launch(false)
	await frames(15)
	var lab = app.game
	var gun = lab.player.weapon
	for id in WEAPONS:
		CATALOG.equip(gun, id)
		gun.tuning.sound_enabled = false
		gun.tuning.damage_enabled = false
		gun.tuning.magazine_enabled = false
		gun.tuning.recoil_enabled = false
		var velocities := {}
		var spins := {}
		var angles := {}
		var before: int = gun.shots_fired
		for i in SHOTS:
			gun.aim_direction = Vector2.RIGHT
			gun._fire()
			var shell: Dictionary = cases(gun).back()
			velocities[shell.velocity] = true
			spins[shell.spin] = true
			angles[shell.rotation] = true
			await frames(2)
		check(gun.shots_fired - before == SHOTS and cases(gun).filter(func(shell): return shell.weapon_id == id).size() == SHOTS, id + " every actual shot creates one case")
		check(velocities.size() == SHOTS and spins.size() == SHOTS and angles.size() == SHOTS, id + " initial velocity, spin and angle vary")
	await frames(240)
	var settled_positions := PackedVector2Array()
	var first_counts := {}
	for shell in cases(gun):
		var key: String = shell.weapon_id + "/" + shell.state
		first_counts[key] = first_counts.get(key, 0) + 1
		settled_positions.append(shell.point)
	print("After 4s: ", first_counts)
	await frames(480)
	var remaining := cases(gun)
	var final_counts := {}
	for shell in remaining:
		var key: String = shell.weapon_id + "/" + shell.state
		final_counts[key] = final_counts.get(key, 0) + 1
	print("After 12s: ", final_counts)
	check(remaining.all(func(shell): return shell.state == "rest"), "all actual cases settle")
	check(remaining.size() == SHOTS * WEAPONS.size() and remaining.all(func(shell): return is_inf(shell.life)), "all 96 cases retained after twelve seconds")
	var unchanged := remaining.size() == settled_positions.size()
	if unchanged:
		for i in remaining.size():
			unchanged = unchanged and remaining[i].point == settled_positions[i] and is_inf(remaining[i].life)
	check(unchanged and remaining.size() == SHOTS * WEAPONS.size(), "all 96 cases remain stationary after eight additional seconds")
	lab._recover()
	check(cases(gun).is_empty(), "level reset clears spent cases")
	print("CASING SERIES %d/%d" % [checks - failures, checks])
	quit(1 if failures else 0)

func test_surfaces() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var motion = CASING.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1911
	for material in 6:
		var body := StaticBody2D.new()
		body.position = Vector2(700 * material, 150)
		body.set_meta("terra_material", material)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(500, 20)
		body.add_child(shape)
		world.add_child(body)
	await frames(3)
	for id in WEAPONS:
		var size: Vector2 = CATALOG.casing_mm(id) * CoreWorldUnits.units(0.001)
		var flight: Dictionary = motion.spawn(Vector2(0, -300), Vector2.RIGHT, size, id, rng)
		var expected_point: Vector2 = flight.point
		var expected_velocity: Vector2 = flight.velocity
		var expected_angle: float = flight.rotation
		var ballistic := true
		for i in 24:
			var dt := 1.0 / 60.0
			expected_velocity.y += 750.0 * dt
			expected_point += expected_velocity * dt
			expected_angle += flight.spin * dt
			ballistic = ballistic and motion.tick(world, flight, dt, rng).is_empty()
			ballistic = ballistic and flight.point.is_equal_approx(expected_point) and is_equal_approx(flight.rotation, expected_angle)
		check(ballistic and expected_velocity.y > 0, id + " rises, tumbles and descends under gravity")
		for material in 6:
			var rebounds := {}
			var settled_count := 0
			for i in 12:
				var shell: Dictionary = motion.spawn(Vector2(700 * material, 108), Vector2.RIGHT, size, id, rng)
				shell.velocity = Vector2(0, 210)
				shell.rotation = 0.75
				var first := false
				for step in 180:
					var hit: Dictionary = motion.tick(world, shell, 1.0 / 60.0, rng)
					if not first and not hit.is_empty():
						rebounds[shell.velocity.y] = true
						first = true
				if first and shell.state == "rest" and shell.point.y < 140.0 and is_inf(shell.life):
					settled_count += 1
			var response := rebounds.size() == 1 and rebounds.has(0.0) if material < 2 else rebounds.size() > 1
			check(response and settled_count == 12, "%s material %d: rebound variants=%d, settled=%d/12" % [id, material, rebounds.size(), settled_count])
	world.queue_free()
	await frames(2)
