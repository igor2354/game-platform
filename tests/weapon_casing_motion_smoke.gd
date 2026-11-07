extends SceneTree

const CASING := preload("res://scripts/core/weapon_casing.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var motion := CASING.new()
	var random := RandomNumberGenerator.new()
	random.seed = 8301
	motion.visual_rng.seed = 4621
	var smoke_variants := {}
	var rest_variants := {}
	for i in 64:
		var visual := motion.spawn(Vector2.ZERO, Vector2.RIGHT, Vector2(3, 1), "stg44", random)
		smoke_variants[visual.smoke_variant] = true
		rest_variants[visual.rest_variant] = true
	check(smoke_variants.size() == 6 and rest_variants.size() == 4, "all smoke and rest variants are reachable")
	var trail := motion.spawn(Vector2.ZERO, Vector2.RIGHT, Vector2(3, 1), "stg44", random)
	for i in 5: motion.tick_smoke(trail, 1.0 / 60.0, true)
	check(trail.smoke_points.size() == 2, "short trail records airborne positions")
	for i in 20: motion.tick_smoke(trail, 1.0 / 60.0, true)
	check(not trail.has("smoke_points"), "smoke expires independently of casing")
	random.seed = 8301
	for kind in [1, 3, 4]:
		var floor := StaticBody2D.new()
		floor.position = Vector2(kind * 500, 150)
		floor.set_meta("terra_material", kind)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(340, 20)
		floor.add_child(shape)
		world.add_child(floor)
		await physics_frame
		await physics_frame
		var shell := motion.spawn(floor.position + Vector2(0, -30), Vector2.RIGHT, Vector2(3, 1), "stg44", random)
		shell.velocity = Vector2(0, 180)
		var rebound := false
		for i in 180:
			motion.tick(world, shell, 1.0 / 60.0, random)
			if shell.velocity.y < -15.0: rebound = true
		check(rebound == (kind != 1), "material response %d" % kind)
		check(shell.state == "rest" and is_inf(shell.life) and shell.point.y < 140, "case remains above floor %d" % kind)
		if kind == 4:
			shape.disabled = true
			await physics_frame
			motion.tick(world, shell, 1.0 / 60.0, random)
			check(shell.state == "air", "case wakes when support is removed")

	var ramp := StaticBody2D.new()
	ramp.position = Vector2(3000, 200)
	ramp.rotation = 0.45
	ramp.set_meta("terra_material", 4)
	var ramp_shape := CollisionShape2D.new()
	ramp_shape.shape = RectangleShape2D.new()
	ramp_shape.shape.size = Vector2(400, 20)
	ramp.add_child(ramp_shape)
	world.add_child(ramp)
	await physics_frame
	await physics_frame
	var shell := motion.spawn(Vector2(2980, 174), Vector2.RIGHT, Vector2(3, 1), "stg44", random)
	shell.velocity = Vector2.ZERO
	for i in 45: motion.tick(world, shell, 1.0 / 60.0, random)
	check(shell.point.x > 3010.0 and shell.state == "roll", "wooden slope rolls case downhill")
	quit(1 if failures else 0)
