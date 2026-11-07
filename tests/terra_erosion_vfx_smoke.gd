extends SceneTree

const GRID = preload("res://scripts/core/terra_grid.gd")
var failures := 0

class SurfacePreview extends Node2D:
	var grid: Node2D
	var label: String

	func _draw() -> void:
		for list in grid.surfaces.values():
			for item in list:
				draw_colored_polygon(item[0], grid.COLORS[item[1]].darkened(0.28))
		draw_string(ThemeDB.fallback_font, Vector2(0, 105), label)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func run() -> void:
	root.size = Vector2i(960, 520)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("22252b"))
	var tuning := CoreMovementSettings.new()
	tuning.terra_variation = 0.0
	tuning.terra_collapse_enabled = false
	var grids: Array[Node2D] = []
	for kind in 6:
		var grid := GRID.new()
		grid.W = 16
		grid.H = 5
		grid.custom_polygon = PackedVector2Array([Vector2.ZERO, Vector2(256, 0), Vector2(256, 80), Vector2(0, 80)])
		grid.restored = true
		grid.material_override = kind
		grid.tuning = tuning
		grid.position = Vector2(40 + kind % 3 * 300, 160 + floori(kind / 3.0) * 225)
		root.add_child(grid)
		grid.reset_ground()
		grids.append(grid)
		grid.bullet_hit(grid.to_global(Vector2(32, 0)), Vector2.DOWN, 50.0)
		check(not grid.bullet_erased.is_empty() and is_instance_valid(grid.chips) and grid.chips.chips.size() == 6, "bullet erosion %d" % kind)
		var removed := grid.deform(Vector2(155, 0), 80.0, 100.0)
		check(removed > 0 and grid.chips.chips.size() == 24, "blast erosion %d" % kind)

	for i in 9:
		await physics_frame
		await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		var names := ["Песок", "Земля", "Глина", "Камень / бетон", "Дерево", "Сталь"]
		for kind in 6:
			var surface := SurfacePreview.new()
			surface.grid = grids[kind]
			surface.label = names[kind]
			grids[kind].add_child(surface)
		await RenderingServer.frame_post_draw
		var folder := preload("res://tools/media_paths.gd").path("docs/core/impact_collision_20261104")
		check(root.get_texture().get_image().save_png(folder.path_join("six_materials_soft_impacts.png")) == OK, "saved capture")
		for grid in grids:
			grid.reset_ground()
			for x in [65, 128, 191]:
				grid.bullet_hit(grid.to_global(Vector2(x, 0)), Vector2.DOWN, 50.0)
		for i in 3:
			await physics_frame
			await process_frame
		for grid in grids:
			for child in grid.get_children():
				if child is SurfacePreview: child.queue_redraw()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder.path_join("bullet_only_soft_impacts.png")) == OK, "saved bullet impact comparison")

	var sample := grids[0]
	sample.reset_ground()
	check(sample.chips.chips.is_empty() and not sample.chips.is_physics_processing(), "reset clears effect")
	tuning.terra_visuals_enabled = false
	var removed: int = sample.deform(Vector2(155, 0), 80.0, 100.0)
	check(removed > 0 and sample.chips.chips.is_empty(), "visual toggle preserves erosion")
	tuning.terra_visuals_enabled = true
	sample.reset_ground()
	removed = sample.deform(Vector2(155, 0), 80.0, 100.0, false)
	check(removed > 0 and sample.chips.chips.is_empty(), "blast visual toggle preserves erosion")
	check(sample.deform(Vector2(155, -500), 80.0, 100.0) == 0 and sample.chips.chips.is_empty(), "no particles away from terrain")
	for i in 20: sample.emit_erosion(Vector2.ZERO, Vector2.UP, 0, 1.0, true)
	check(sample.chips.chips.size() == 64, "particles stay bounded under repeated blasts")
	for i in 70: await process_frame
	check(grids[1].chips.chips.is_empty() and not grids[1].chips.is_physics_processing(), "effect expires and sleeps")
	await check_surface_fallback()
	quit(1 if failures else 0)

func check_surface_fallback() -> void:
	var host := Node2D.new()
	root.add_child(host)
	var steel := StaticBody2D.new()
	steel.position = Vector2(2000, 100)
	steel.set_meta("terra_material", 5)
	var box := RectangleShape2D.new()
	box.size = Vector2(160, 20)
	var shape := CollisionShape2D.new()
	shape.shape = box
	steel.add_child(shape)
	host.add_child(steel)
	await physics_frame
	await physics_frame
	var start := Vector2(2000, 40)
	var query := PhysicsRayQueryParameters2D.create(start, start + Vector2.DOWN * 100, 1)
	var hit := host.get_world_2d().direct_space_state.intersect_ray(query)
	check(hit.get("collider") == steel, "ray reaches ordinary steel surface")
	var probe := preload("res://scripts/core/terra_chips.gd").new()
	host.add_child(probe)
	probe.random.seed = 7341
	probe.emit_erosion(start, Vector2.DOWN, 4, 1.0, false)
	var shapes := {}
	for i in 9:
		probe.emit_erosion(start, Vector2.DOWN, 4, 1.0, false)
	for chip in probe.chips:
		if not chip.dust: shapes[chip.variant] = true
	check(shapes.size() == 3, "successive hits sample all wood outlines")
	var shard: Dictionary = probe.chips.back()
	probe.chips = [shard]
	shard.velocity = Vector2(0, 5000)
	shard.life = 0.2
	await physics_frame
	await physics_frame
	check(shard.settled and shard.point.y < hit.position.y and shard.life > 0.0, "fast shard settles above the real floor")
	var floor_point: Vector2 = shard.point
	await physics_frame
	check(shard.point == floor_point, "settled shard does not sink on the next tick")
	probe.queue_free()
	CoreProjectile.resolve_impact(hit, 25.0, Vector2.DOWN, Callable(), start, false)
	var chips := host.get_node_or_null("SurfaceImpactParticles")
	check(chips != null and chips.chips.size() == 6 and chips.chips[2].color == Color("eeb982"), "ordinary steel bullet hit creates one material effect")
	var profile := CoreExplosionSettings.new()
	profile.explosion_audio_enabled = false
	var blast := CoreExplosion.spawn(host, start, profile)
	var blast_chips := blast.get_node_or_null("SurfaceImpactParticles")
	check(blast_chips != null and blast_chips.chips.size() == 18, "blast samples ordinary surface once")
	if "--capture" in OS.get_cmdline_user_args():
		var plate := Polygon2D.new()
		plate.polygon = PackedVector2Array([Vector2(-80, -10), Vector2(80, -10), Vector2(80, 10), Vector2(-80, 10)])
		plate.color = Color("4c5963")
		steel.add_child(plate)
		var camera := Camera2D.new()
		camera.position = steel.position - Vector2(0, 45)
		camera.zoom = Vector2(3, 3)
		host.add_child(camera)
		for i in 9:
			await physics_frame
			await process_frame
		await RenderingServer.frame_post_draw
		var folder := preload("res://tools/media_paths.gd").path("docs/core/impact_collision_20261104")
		check(root.get_texture().get_image().save_png(folder.path_join("ordinary_steel_soft_impacts.png")) == OK, "saved ordinary surface capture")
		camera.queue_free()
	profile.explosion_visuals_enabled = false
	blast = CoreExplosion.spawn(host, start, profile)
	check(not blast.has_node("SurfaceImpactParticles"), "blast visual toggle suppresses ordinary surface particles")

	var grid := GRID.new()
	grid.W = 10
	grid.H = 5
	grid.restored = true
	grid.material_override = 4
	grid.custom_polygon = PackedVector2Array([Vector2.ZERO, Vector2(160, 0), Vector2(160, 80), Vector2(0, 80)])
	grid.position = Vector2(2400, 100)
	grid.tuning = CoreMovementSettings.new()
	grid.tuning.terra_collapse_enabled = false
	host.add_child(grid)
	grid.reset_ground()
	await physics_frame
	await physics_frame
	var contact := Vector2(2480, 100)
	query.from = contact - Vector2.DOWN * 20
	query.to = contact + Vector2.DOWN * 30
	hit = host.get_world_2d().direct_space_state.intersect_ray(query)
	var before: int = chips.chips.size()
	CoreProjectile.resolve_impact(hit, 25.0, Vector2.DOWN, Callable(), query.from)
	check(grid.chips != null and grid.chips.chips.size() == 6 and chips.chips.size() == before, "terrain bullet does not duplicate the local effect")
	grid.tuning.terra_bullets_enabled = false
	CoreProjectile.resolve_impact(hit, 25.0, Vector2.DOWN, Callable(), query.from)
	check(chips.chips.size() == before + 6, "surface response continues with terrain bullet erosion disabled")
	profile.explosion_visuals_enabled = true
	profile.explosion_damage = 1000.0
	blast = CoreExplosion.spawn(host, contact, profile)
	check(grid.chips.chips.size() > 6 and not blast.has_node("SurfaceImpactParticles"), "terrain blast does not duplicate the local effect")
