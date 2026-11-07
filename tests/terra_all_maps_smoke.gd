extends SceneTree

var failures := 0
var checks := 0

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

func run() -> void:
	for map_id in ["polygon", "prologue", "prologue_v2", "hub"]:
		var app = preload("res://scripts/campaign/frontend.gd").new()
		app.load_user_settings = false
		app.test_settings_directory = OS.get_environment("TEMP").path_join("terra-all-%d-%s" % [OS.get_process_id(), map_id])
		DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
		root.add_child(app)
		app.selected_level = map_id
		app.launch(map_id != "polygon")
		await frames(10)
		var lab = app.game
		var shovel = lab.player.weapon.shovel
		check(is_instance_valid(shovel), map_id + " gets the shared shovel")
		var manager = lab.level.get_node("Terraforming")
		check(not manager.owners.is_empty() and not manager.bullet_sources.is_empty(), map_id + " registers physics and art")
		var spawn: Vector2 = lab.level.player_spawn()
		var hit: Dictionary = lab.get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(spawn - Vector2(0, 10), spawn + Vector2(0, 260), 1))
		var patch = null if hit.is_empty() else hit.collider.get_meta("terra_owner", null)
		check(patch != null, map_id + " ray hits registered ground")
		if patch != null:
			var point: Vector2 = hit.position
			lab.player.tuning.terra_enabled = false
			patch.bullet_hit(point, Vector2.DOWN, 120)
			check(patch.grid == null, map_id + " existing switch prevents activation")
			lab.player.tuning.terra_enabled = true
			lab.player.tuning.terra_bullets_enabled = true
			patch.bullet_hit(point, Vector2.DOWN, 120)
			await frames(12)
			check(is_instance_valid(patch.grid) and not patch.grid.bullet_erased.is_empty(), map_id + " bullet removes matter")
			check(not manager.bullet_patches.is_empty(), map_id + " bullet builds local visual mask")
			check(patch.grid.chunks.size() <= 4 and patch.original.collision_layer == 1, map_id + " damage keeps distant simple collision")
			var profile := CoreExplosionSettings.new()
			profile.explosion_radius = 120
			profile.explosion_damage = 500
			lab.player.tuning.terra_explosions_enabled = true
			var health_before: PackedFloat32Array = patch.grid.health.duplicate()
			CoreExplosion.spawn(lab.level, point + Vector2(90, 0), profile)
			await frames(60)
			check(patch.grid.health != health_before, map_id + " explosion updates terrain")
			if "--capture" in OS.get_cmdline_user_args():
				lab.camera.position_smoothing_enabled = false
				lab.set_process(false)
				lab.camera.global_position = point - Vector2(0, 100)
				lab.camera.reset_smoothing()
				await frames(3)
				await RenderingServer.frame_post_draw
				var folder := preload("res://tools/media_paths.gd").path("docs/core/terra_all_maps_20261103")
				root.get_texture().get_image().save_png(folder.path_join(map_id + ".png"))
			var id: String = patch.id
			var saved_damage: int = patch.grid.bullet_erased.size()
			app.game.queue_free()
			await frames(3)
			app.launch(map_id != "polygon")
			await frames(12)
			var restored = app.game.level.get_node("Terraforming").owners.filter(func(owner): return owner.id == id)
			check(restored.size() == 1 and is_instance_valid(restored[0].grid) and restored[0].grid.bullet_erased.size() >= saved_damage,
				map_id + " damage survives re-entry")
		manager = app.game.level.get_node("Terraforming")
		var eligible: Array = manager.owners.filter(func(owner): return owner.kind <= 2 and owner.grid == null and owner.box.size.x > 120)
		if not eligible.is_empty():
			var surface: Dictionary = {}
			var space: PhysicsDirectSpaceState2D = app.game.player.get_world_2d().direct_space_state
			for candidate in eligible:
				for fraction in [.5, .25, .75]:
					var x: float = lerpf(candidate.box.position.x, candidate.box.end.x, fraction)
					var ray := PhysicsRayQueryParameters2D.create(Vector2(x, candidate.box.position.y - 16), Vector2(x, candidate.box.end.y), 1)
					var surface_hit: Dictionary = space.intersect_ray(ray)
					if not surface_hit.is_empty() and surface_hit.collider.has_meta("terra_owner") and surface_hit.collider.get_meta("terra_owner") == candidate and surface_hit.normal.y < -.7:
						surface = {"owner": candidate, "point": surface_hit.position, "inward": -surface_hit.normal}
						break
				if not surface.is_empty(): break
			check(not surface.is_empty(), map_id + " has exposed diggable ground")
			if not surface.is_empty():
				var fresh = surface.owner
				var contact: Dictionary = fresh.shovel_target(surface.point, surface.inward)
				check(contact.material == fresh.kind and fresh.grid == null, map_id + " shovel preview leaves untouched ground simple")
				var removed: int = fresh.shovel_apply(surface.point, surface.inward, 80, 37, contact)
				await frames(10)
				print("SHOVEL LOCAL ", map_id, " cells=", removed, " chunks=", fresh.grid.chunks.size())
				check(removed > 0 and fresh.grid.chunks.size() <= 6, map_id + " shovel activates only local ground collision")
		else:
			check(manager.owners.all(func(owner): return owner.kind >= 3 or is_instance_valid(owner.grid) or owner.box.size.x <= 120),
				map_id + " construction stays outside shovel material profile")
		app.queue_free()
		await frames(3)
	print("TERRA ALL MAPS %d/%d" % [checks - failures, checks])
	quit(1 if failures else 0)
