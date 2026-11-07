extends SceneTree
const FRONT = preload("res://scripts/campaign/frontend.gd")
var checks := 0
var failures := 0
var directory := OS.get_environment("TEMP").path_join("fog-smoke-%d" % OS.get_process_id())
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func solid(parent: Node,rect: Rect2,one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 8 if one_way else 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.get_center()
	collision.one_way_collision = one_way
	body.add_child(collision)
	parent.add_child(body)
	return body
func dummy(parent: Node,point: Vector2) -> CoreEnemyDummy:
	var actor := CoreEnemyDummy.new()
	actor.position = point
	parent.add_child(actor)
	return actor
func keys_in(fog: Node,rect: Rect2,remembered := false) -> int:
	var count := 0
	for key in fog.cells:
		if rect.has_point(fog.cells[key].get_center()) and (not remembered or fog.explored.has(key)): count += 1
	return count
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	for mode in ["polygon","prologue","prologue_v2","hub"]:
		var app := FRONT.new()
		app.load_user_settings = false
		app.test_settings_directory = directory.path_join(mode)
		DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
		app.selected_level = mode
		root.add_child(app)
		app.launch(mode != "polygon")
		await frames(6)
		var lab: CoreMovementLab = app.game
		var fog = lab.fog_of_war
		var hero := lab.player
		var tuning := lab.camera_settings
		var label: String = mode
		check(tuning.fog_enabled and fog.targets.size() == lab.level.enemies.size(),"automatic target registration: "+label)
		check(fog.cells.size() > 0,"existing interiors derive from blocking: "+label)
		check(lab.developer_mode.SECTIONS.has("Туман войны") and lab.fog_overlay.rows.size() == 11 and lab.fog_overlay.feature_toggles.size() == 4,"dedicated complete developer category: "+label)
		solid(lab.level,Rect2(7500,760,3100,80))
		hero.reset_to(Vector2(8200,760))
		hero.set_physics_process(false)
		hero.weapon.aim_override = Vector2(10000,620)
		hero.weapon._update_aim()
		hero.body.advance(0)
		var target := dummy(lab.level,Vector2(8600,760))
		var rear := dummy(lab.level,Vector2(7500,760))
		await frames(4)
		fog.update_visibility()
		check(target.visible and not rear.visible,"independent forward/rear range: "+label)
		check(fog.eye.is_equal_approx(hero.body.to_global(hero.body.weapon_mount_points()[0])),"eye follows actual character anatomy: "+label)
		var obstacle := solid(lab.level,Rect2(8490,0,30,760))
		await frames(3)
		fog.update_visibility()
		check(not target.visible and not fog.point_visible(target.aim_point_for_part("head")),"opaque wall blocks enemy and labels: "+label)
		var clock := target.idle_clock
		await frames(10)
		check(target.idle_clock > clock and target.is_physics_processing(),"hidden actor keeps simulation: "+label)
		target.take_damage(10)
		check(target.health == 90,"hidden actor still receives damage: "+label)
		obstacle.set_meta("fog_blocks_vision",false)
		fog.update_visibility()
		check(target.visible,"transparent collision blocks movement but not sight: "+label)
		obstacle.set_meta("fog_blocks_vision",true)
		(obstacle.get_child(0) as CollisionShape2D).disabled = true
		await frames(2)
		fog.update_visibility()
		check(target.visible,"opening disables physical vision obstruction: "+label)
		obstacle.queue_free()
		await frames(2)
		# Place the slit between actual head/foot rays for each character's anatomy.
		var fraction: float = (8505-fog.eye.x)/(target.global_position.x-fog.eye.x)
		var head_line := lerpf(fog.eye.y,target.aim_point_for_part("head").y,fraction)
		var foot_line := lerpf(fog.eye.y,target.to_global(Vector2(0,-4)).y,fraction)
		var sill_y := (head_line+foot_line)*.5
		var top := solid(lab.level,Rect2(8490,0,30,head_line-32))
		var sill := solid(lab.level,Rect2(8490,sill_y,30,760-sill_y))
		await frames(2)
		fog.update_visibility()
		check(target.visible and fog.point_visible(target.aim_point_for_part("head")) and not fog.point_visible(target.to_global(Vector2(0,-4))),"window exposes only actual lines through opening: "+label)
		check(target.material == fog.actor_material,"visible portions share world-space clipping material: "+label)
		top.queue_free(); sill.queue_free()
		await frames(2)
		var roof := solid(lab.level,Rect2(8800,300,800,24),true)
		solid(lab.level,Rect2(8800,324,20,180))
		solid(lab.level,Rect2(9580,324,20,436))
		await frames(3)
		fog.rebuild_geometry()
		fog.clear_memory()
		fog.update_visibility()
		var room := Rect2(8820,326,760,430)
		var count := keys_in(fog,room)
		var remembered := keys_in(fog,room,true)
		check(count > 100 and remembered > 0 and remembered < count,"arbitrary new room auto-detected; doorway reveals only cells: "+label)
		var floor_target := dummy(lab.level,Vector2(9000,300))
		await frames(2)
		fog.update_visibility()
		check(not floor_target.visible,"one-way gameplay floor is still opaque to sight: "+label)
		hero.weapon.aim_override = Vector2(6000,620)
		hero.weapon._update_aim()
		fog.update_visibility()
		check(keys_in(fog,room,true) == remembered,"turning away preserves clear remembered environment: "+label)
		hero.weapon.aim_override = Vector2(10000,620)
		hero.weapon._update_aim()
		hero.weapon.tuning.aim_beam_enabled = false
		fog.update_visibility()
		var state := [fog.eye,fog.gaze,fog.distances.duplicate()]
		hero.weapon.tuning.aim_beam_enabled = true
		hero.weapon.tuning.hip_max_spread = 35
		hero.weapon.bloom = 25
		fog.update_visibility()
		check(state == [fog.eye,fog.gaze,fog.distances],"beam display and spread do not change field of view: "+label)
		var explored_before: Dictionary = fog.explored.duplicate()
		lab._set_pause(true)
		var paused_eye: Vector2 = fog.eye
		await frames(8)
		check(fog.eye == paused_eye and fog.explored == explored_before,"pause freezes sight and memory: "+label)
		tuning.fog_enabled = false
		fog.apply_settings()
		check(target.visible and rear.visible and floor_target.visible and fog.explored == explored_before,"disable restores actors without erasing memory: "+label)
		tuning.fog_enabled = true
		fog.apply_settings()
		check(not floor_target.visible,"paused developer edits update sight immediately: "+label)
		lab._set_pause(false)
		roof.set_meta("fog_interior",false)
		fog.rebuild_geometry()
		check(keys_in(fog,room) == 0,"explicit outdoor override avoids guessing a room: "+label)
		roof.set_meta("fog_interior",true)
		tuning.fog_auto_interiors = false
		fog.rebuild_geometry()
		check(keys_in(fog,room) > 0,"explicit interior works without automatic enclosure guesses: "+label)
		tuning.fog_front_range = 13.5
		tuning.zoom = 1.7
		lab.fog_overlay.save_profile()
		tuning.fog_front_range = 3
		tuning.zoom = 1.3
		lab.fog_overlay.load_profile()
		check(tuning.fog_front_range == 13.5 and tuning.zoom == 1.3,"fog-only load preserves camera framing: "+label)
		lab.fog_overlay.reset_profile()
		check(tuning.fog_front_range == 18 and tuning.zoom == 1.3,"fog-only reset preserves camera framing: "+label)
		check(lab.export_settings_file(app.test_settings_directory.path_join("fog.json")),"fog exports in compatible JSON: "+label)
		tuning.fog_front_range = 4
		check(lab.import_settings_file(app.test_settings_directory.path_join("fog.json")) and tuning.fog_front_range == 18,"fog JSON round trip and persisted settings: "+label)
		var legacy := JSON.parse_string(FileAccess.get_file_as_string(app.test_settings_directory.path_join("fog.json"))) as Dictionary
		for key in tuning.as_dictionary():
			if key.begins_with("fog_"): legacy.camera.erase(key)
		var file := FileAccess.open(app.test_settings_directory.path_join("old.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy)); file.close()
		check(lab.import_settings_file(app.test_settings_directory.path_join("old.json")) and tuning.fog_enabled and tuning.fog_ray_count == 192 and not tuning.fog_debug,"legacy JSON receives safe defaults: "+label)
		target.blast_ragdoll.start(Vector2.ZERO,10,.2)
		target.blast_ragdoll.rig.set_simulation_enabled(false)
		await frames(3)
		fog.update_visibility()
		check(target.visible and target.blast_ragdoll.rig.visible and target.blast_ragdoll.rig.material == fog.actor_material,"ragdoll keeps independent physics and shares visual clipping: "+label)
		hero.blast_ragdoll.start(Vector2.ZERO,10,.2)
		hero.blast_ragdoll.rig.set_simulation_enabled(false)
		await frames(3)
		fog.update_visibility()
		check(fog.eye == hero.blast_ragdoll.rig.parts.head.global_position and fog.point_visible(target.blast_ragdoll.rig.parts.head.global_position),"fallen player's own physical head never blocks its sight: "+label)
		var transient := CoreEnemyDummy.new()
		lab.level.add_child(transient)
		transient.free()
		await frames(2)
		check(fog.targets.all(func(actor): return is_instance_valid(actor)),"same-frame spawn/removal leaves no stale target: "+label)
		var visual := Node2D.new()
		target.add_child(visual)
		await frames(2)
		check(visual.material == fog.actor_material,"late visual children inherit sight clipping: "+label)
		var id := visual.get_instance_id()
		target.remove_child(visual)
		check(visual.material == null and not fog.materials.has(id),"removed visuals release material tracking and authored ownership: "+label)
		visual.free()
		app.queue_free()
		await frames(3)
	print("FOG OF WAR: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
