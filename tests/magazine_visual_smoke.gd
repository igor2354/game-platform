extends SceneTree

const CATALOG = preload("res://scripts/campaign/catalog.gd")
const TURN = preload("res://scripts/core/magazine_turn_visual.gd")
const IDS = ["stg44", "mp40", "svt", "m1911"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func touches_sand(view: Node2D, silhouette: PackedVector2Array, offset: Vector2) -> bool:
	var hull := Geometry2D.convex_hull(silhouette)
	var space := view.get_world_2d().direct_space_state
	for i in hull.size() - 1:
		var a := view.to_global(hull[i] + offset)
		var b := view.to_global(hull[i + 1] + offset)
		for sample in maxi(1, ceili(a.distance_to(b))) + 1:
			var point := a.lerp(b, float(sample) / maxi(1, ceili(a.distance_to(b))))
			var ray := PhysicsRayQueryParameters2D.create(point - Vector2(0, 0.8), point + Vector2(0, 0.8), 1)
			var hit := space.intersect_ray(ray)
			if not hit.is_empty() and hit.normal.y < -0.4:
				return true
	return false

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_temp_dir().path_join("magazine-visual-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app)
	app.selected_level = "terra"
	app.launch(true)
	await frames(15)
	var gun = app.game.player.weapon
	gun.cosmetic_rng.seed = 5411
	var spawn: Vector2 = app.game.level.player_spawn()
	var ground = app.game.level.ground
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
		var camera := Camera2D.new()
		app.game.get_node("World").add_child(camera)
		camera.global_position = spawn + Vector2(360, -90)
		camera.make_current()
	var chips := 0
	for i in range(3, 12, 2):
		var crater := spawn + Vector2(70 * i - 22, 0)
		if ground.bullet_hit(crater, Vector2.DOWN, 55.0):
			chips += 1
	await frames(12)
	check(chips == 5, "real bullet chips prepared on the sand")
	var classic_count := 0
	for id in IDS:
		CATALOG.equip(gun, id)
		var spins := {}
		var rebounds := {}
		var drops: Array[RigidBody2D] = []
		var transforms: Array[Transform2D] = []
		for i in 12:
			gun._drop_magazine({"magazine_point": Vector2.ZERO, "direction": Vector2.RIGHT})
			var drop: RigidBody2D = gun.get_child(-1)
			drop.global_position = spawn + Vector2(70 * i, -110)
			drops.append(drop)
			transforms.append(drop.get_child(1).transform)
			spins[signf(drop.angular_velocity)] = true
			rebounds[drop.physics_material_override.bounce] = true
		check(spins.size() == 2 and rebounds.size() == 12, id + " spin direction and bounce vary")
		var rebounded := false
		var steady_pivot := true
		var late_positions := {}
		var steady_rest := true
		for frame in 360:
			await frames(1)
			for drop in drops:
				if drop.linear_velocity.y < -8.0: rebounded = true
				if frame > 330:
					steady_rest = steady_rest and drop.global_position.distance_to(late_positions[drop]) < 0.75
				if frame >= 330:
					late_positions[drop] = drop.global_position
				if drop.get_child_count() < 3: continue
				var view := drop.get_child(2)
				var down: Vector2 = view.global_transform.basis_xform_inv(Vector2.DOWN).normalized()
				var offset: Vector2 = view.support_offset(view.frames[view.frame], down)
				steady_pivot = steady_pivot and absf(view.global_transform.basis_xform(offset).x) < 0.01
			if frame >= 180 and drops.all(func(drop): return drop.sleeping):
				await frames(2)
				break
		check(rebounded, id + " shows a real rebound")
		check(steady_pivot, id + " view never jumps sideways relative to body")
		var rigid := true
		var contacts := true
		var volume_count := 0
		for i in drops.size():
			var drop := drops[i]
			if not drop.sleeping:
				print("Contact solver still active for ", id, " at ", drop.global_position)
			rigid = rigid and drop.get_child(1).transform.is_equal_approx(transforms[i])
			if drop.get_child_count() == 2:
				classic_count += 1
				rigid = rigid and drop.get_child(1).visible
				contacts = contacts and touches_sand(drop.get_child(1), CATALOG.magazine_shell(id).points, Vector2.ZERO)
				continue
			volume_count += 1
			var view := drop.get_child(2)
			rigid = rigid and view.get_script() == TURN and view.frame == TURN.FRAME_COUNT - 1
			if drop.sleeping:
				rigid = rigid and not view.is_physics_processing()
			var down: Vector2 = view.global_transform.basis_xform_inv(Vector2.DOWN).normalized()
			var current: Array = view.frames[view.frame]
			var offset: Vector2 = view.support_offset(current, down)
			var projected := PackedVector2Array()
			for item in current:
				projected.append_array(item.points)
			var visible_y := -INF
			for point in projected:
				visible_y = maxf(visible_y, view.to_global(point + offset).y)
			var hull: PackedVector2Array = drop.get_child(0).shape.points
			var collider_y := -INF
			for point in hull:
				collider_y = maxf(collider_y, drop.to_global(point).y)
			var collider_gap := absf(visible_y - collider_y)
			if not touches_sand(view, projected, offset) or collider_gap >= 0.05:
				print("Support gap ", id, " at ", view.global_position, ", collider=", collider_gap)
				contacts = false
		check(rigid and steady_rest and volume_count > 0, id + " final views without late jumps")
		check(contacts and volume_count > 0, id + " visible support matches collider and floor")
		if capture:
			await RenderingServer.frame_post_draw
			var folder := preload("res://tools/media_paths.gd").path("docs/core/magazine_contact_20261104")
			check(root.get_texture().get_image().save_png(folder.path_join(id + ".png")) == OK, id + " sand capture saved")
		gun.clear_dropped_magazines()
		await frames(2)
	app.queue_free()
	check(classic_count > 0 and classic_count < 12, "rare original side view, count %d/48" % classic_count)
	await process_frame
	quit(1 if failures else 0)
