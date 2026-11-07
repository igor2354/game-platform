extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func surface(parent: Node, origin: Vector2, side: float, points: Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = origin
	var shape := CollisionPolygon2D.new()
	var polygon := PackedVector2Array()
	for point: Vector2 in points:
		polygon.append(Vector2(point.x * side, point.y))
	shape.polygon = polygon
	body.add_child(shape)
	parent.add_child(body)
	return body

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("parkour-held-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(14)
	var lab: CoreMovementLab = app.game
	var hero := lab.player
	hero.tuning.sprint_auto_parkour_enabled = false
	for side in [-1.0, 1.0]:
		var origin := Vector2(33500, 460)
		var course := Node2D.new()
		lab.level.add_child(course)
		surface(course, origin, side, [Vector2(-260,0), Vector2(920,0), Vector2(920,42), Vector2(-260,42)])
		surface(course, origin, side, [Vector2(0,0), Vector2(17,-80), Vector2(26,-100), Vector2(160,-114), Vector2(160,4), Vector2(0,4)])
		surface(course, origin, side, [Vector2(153,0), Vector2(175,-159), Vector2(196,-201), Vector2(332,-193), Vector2(332,4), Vector2(153,4)])
		surface(course, origin, side, [Vector2(326,0), Vector2(345,-245), Vector2(365,-292), Vector2(720,-300), Vector2(720,4), Vector2(326,4)])
		await frames(3)
		hero.reset_to(origin + Vector2(-100 * side,-2))
		hero.weapon.aim_override = origin + Vector2(-700 * side,-100)
		await frames(10)
		var action := "core_right" if side > 0 else "core_left"
		Input.action_press(action)
		Input.action_press("core_jump")
		var climbs := 0
		var hung := false
		var previous := false
		for i in 240:
			await frames(1)
			var active := hero.parkour_active()
			if active and not previous: climbs += 1
			hung = hung or hero.parkour.stage == "ledge_hang"
			previous = active
			if (hero.global_position.x - origin.x) * side > 440: break
		Input.action_release(action)
		Input.action_release("core_jump")
		await frames(14)
		print("COURSE ", side, " climbs=", climbs, " pos=", hero.global_position-origin)
		check(climbs >= 3 and not hung and hero.is_on_floor() and hero.global_position.y < origin.y-280,
			"hold Space and movement climbs three uneven faces, side %s" % side)
		course.queue_free()
		await frames(2)
	var ceiling_course := Node2D.new()
	lab.level.add_child(ceiling_course)
	var start := Vector2(33500, 460)
	surface(ceiling_course, start, 1, [Vector2(-250,0),Vector2(400,0),Vector2(400,50),Vector2(-250,50)])
	surface(ceiling_course, start, 1, [Vector2(0,0),Vector2(0,-125),Vector2(250,-125),Vector2(250,5)])
	var ceiling := surface(ceiling_course, start, 1, [Vector2(-130,-210),Vector2(280,-210),Vector2(280,-200),Vector2(-130,-200)])
	hero.reset_to(start + Vector2(-52,-1))
	hero.weapon.aim_override = start + Vector2(500,-120)
	await frames(8)
	check(not hero.parkour.try_start(1.0, true), "low ceiling blocks the full standing capsule")
	ceiling.queue_free()
	await frames(3)
	hero.tuning.parkour_hold_move_enabled = false
	hero.weapon.aim_override = start + Vector2(-500,-120)
	await frames(3)
	check(not hero.parkour.try_start(1.0, true), "disabled held traversal retains the gaze rule")
	check(lab.movement_overlay.feature_toggles.has("parkour_hold_move_enabled"), "developer settings expose a separate switch")
	ceiling_course.queue_free()
	await frames(3)
	print("PARKOUR HELD %d/%d" % [checks-failures,checks])
	await app.return_to_menu()
	app.queue_free()
	await frames(3)
	quit(1 if failures else 0)
