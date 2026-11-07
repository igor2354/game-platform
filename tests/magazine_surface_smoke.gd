extends SceneTree

const CATALOG = preload("res://scripts/campaign/catalog.gd")
const IDS = ["stg44", "mp40", "svt", "m1911", ""]
const MATERIALS = ["sand", "earth", "clay", "stone", "wood", "metal"]
const ANGLES = [0, -15, 15, -30, 30]

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func support_depth(node: Node2D, points: PackedVector2Array, origin: Vector2, inward: Vector2, offset := Vector2.ZERO) -> float:
	var depth := -INF
	for point in points:
		depth = maxf(depth, (node.to_global(point + offset) - origin).dot(inward))
	return depth

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_temp_dir().path_join("magazine-surface-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.launch(false)
	await frames(15)
	var gun: CoreShootingController = app.game.player.weapon
	gun.cosmetic_rng.seed = 3321
	var world: Node2D = app.game.get_node("World")
	var cases: Array[Dictionary] = []
	for id in IDS:
		if id.is_empty(): gun.equipped_weapon_id = ""
		else: CATALOG.equip(gun, id)
		for material in MATERIALS.size():
			for angle in ANGLES:
				var ramp := StaticBody2D.new()
				ramp.position = Vector2(18000 + cases.size() % 30 * 1300, -4400 + (cases.size() / 30) * 650)
				ramp.rotation = deg_to_rad(angle)
				ramp.collision_layer = 1 if material % 2 == 0 else 8
				ramp.set_meta("terra_material", material)
				var collider := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = Vector2(520, 24)
				collider.shape = box
				ramp.add_child(collider)
				world.add_child(ramp)
				var surface := ramp.to_global(Vector2(0, -12))
				var ends := PackedVector2Array()
				for side in [-1, 1]:
					var edge := ramp.to_global(Vector2(side * 260, -12))
					ends.append(edge)
					var catch_floor := StaticBody2D.new()
					catch_floor.collision_layer = ramp.collision_layer
					catch_floor.set_meta("terra_material", material)
					catch_floor.position = edge + Vector2(side * 162, 12)
					var catch_shape := CollisionShape2D.new()
					var catch_box := RectangleShape2D.new()
					catch_box.size = Vector2(326, 24)
					catch_shape.shape = catch_box
					catch_floor.add_child(catch_shape)
					world.add_child(catch_floor)
				gun._drop_magazine({"magazine_point": Vector2.ZERO, "direction": Vector2.RIGHT})
				var drop := gun.get_child(-1) as RigidBody2D
				drop.global_position = surface + Vector2(0, -95)
				cases.append({"drop": drop, "surface": surface, "ends": ends, "inward": Vector2.DOWN.rotated(ramp.rotation),
					"label": "%s %s %d" % ["ppsh" if id.is_empty() else id, MATERIALS[material], angle]})
	await frames(600)
	var failures := 0
	var visual_failures := 0
	var volume_views := 0
	for sample in cases:
		var drop: RigidBody2D = sample.drop
		var origin: Vector2 = sample.surface
		var inward: Vector2 = sample.inward
		var ends: PackedVector2Array = sample.ends
		if drop.global_position.x < ends[0].x or drop.global_position.x > ends[1].x:
			origin = ends[0] if drop.global_position.x < ends[0].x else ends[1]
			inward = Vector2.DOWN
		var hull: PackedVector2Array = drop.get_child(0).shape.points
		var physical := support_depth(drop, hull, origin, inward)
		if absf(physical) > 0.75 or drop.linear_velocity.length() > 12 or absf(drop.global_position.x - sample.surface.x) > 590:
			failures += 1
			print("FAIL physical ", sample.label, " depth=", physical, " velocity=", drop.linear_velocity)
		if drop.get_child_count() < 3: continue
		volume_views += 1
		var view := drop.get_child(2)
		var projection: Array = view.frames[view.frame]
		var offset: Vector2 = view.support_offset(projection, view.global_transform.basis_xform_inv(Vector2.DOWN).normalized())
		var visible := -INF
		for item in projection:
			visible = maxf(visible, support_depth(view, item.points, origin, inward, offset))
		if absf(visible - physical) > 0.75:
			visual_failures += 1
			print("FAIL visual ", sample.label, " gap=", visible - physical)
	print("SURFACES: ", cases.size(), " drops, ", volume_views, " volume views, physical failures=", failures, ", visual failures=", visual_failures)
	app.queue_free()
	await process_frame
	quit(int(failures + visual_failures > 0 or volume_views < 100))
