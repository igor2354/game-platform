extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL "+label)
	else: print("PASS ",label)
func block(parent: Node, rect: Rect2, thin := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8 if thin else 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new(); box.size = rect.size
	shape.shape = box; shape.position = rect.get_center(); shape.one_way_collision = thin
	body.add_child(shape); parent.add_child(body)
func run() -> void:
	var app := preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("polygon-scale-%d"%OS.get_process_id())
	root.add_child(app); app.selected_character="sofia"; app.launch(false)
	await frames(6)
	var lab: CoreMovementLab = app.game
	var hero: CoreMovementPlayer = lab.player
	check(is_equal_approx(hero.world_height(),182.4),"Sofia physical size unchanged")
	for ladder in lab.level.ladders:
		check(is_equal_approx(ladder.size.x,51.3),"polygon ladder human width")
	check(is_equal_approx(lab.level.obstacles[0].size.y,130),"chest-high course obstacle")
	check(is_equal_approx(lab.level.ragdoll_mannequin.body_scale*94,CoreWorldUnits.REFERENCE_HEIGHT),"standalone mannequin human height")
	check(lab.level.enemies[0].body_size.y>150,"polygon target scaled to human size")
	check(lab.level.transition_doors[0].frame_height==202,"door frame clears standing Sofia")
	check(CoreIndoorLighting.SOLIDS[1].end.y==560,"lighting room has 200-unit entrance")
	hero.tuning.jump_enabled=false
	for obstacle in [lab.level.obstacles[0],lab.level.obstacles[1]]:
		hero.reset_to(Vector2(obstacle.position.x-hero.world_radius()-6,760))
		hero.weapon.aim_override=hero.position+Vector2(500,-80)
		await frames(6); Input.action_press("core_jump"); await frames(3)
		check(hero.parkour_active() and hero.parkour.kind=="vault","real course obstacle starts vault")
		Input.action_release("core_jump"); await frames(70)
		check(not hero.parkour_active() and hero.is_on_floor() and hero.position.x>obstacle.end.x,"real course vault completes on safe ground")
	hero.reset_to(Vector2(5930,760));Input.action_press("core_right")
	await frames(55);Input.action_release("core_right")
	check(hero.position.x>6050 and hero.is_on_floor(),"standing Sofia walks through lighting room entrance")
	var fixtures := Node2D.new(); lab.add_child(fixtures)
	block(fixtures,Rect2(7700,760,1000,80))
	block(fixtures,Rect2(8000,560.7,250,.5),true)
	await frames(3)
	hero.tuning.jump_enabled=false
	for face in [1.0,-1.0]:
		Input.action_release("core_jump"); Input.action_release("core_crouch")
		hero.reset_to(Vector2(8000-hero.world_radius()-24 if face>0 else 8250+hero.world_radius()+24,760))
		hero.weapon.aim_override=hero.position+Vector2(face*500,-80)
		await frames(6)
		Input.action_press("core_jump"); await frames(4)
		check(hero.mode=="ledge_hang","fractional thin deck captured facing "+str(face))
		Input.action_release("core_jump"); await frames(4)
		check(hero.mode=="ledge_hang","release preserves grip")
		Input.action_press("core_crouch"); await frames(2)
		check(not hero.parkour_active(),"crouch cancels grip")
		Input.action_release("core_crouch"); await frames(20)
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(1280,720));root.size=Vector2i(1280,720)
		var folder := preload("res://tools/media_paths.gd").path("docs/core/polygon_scale_20261031")
		lab.set_process(false)
		for entry in [["course",Vector2(460,760)],["ladders",Vector2(1380,760)],["targets",Vector2(2400,760)],["room",Vector2(5900,760)]]:
			hero.reset_to(entry[1]);await frames(2);hero.set_physics_process(false)
			lab.camera.position=entry[1]+Vector2(220,-180);lab.camera.zoom=Vector2.ONE
			lab.camera.reset_smoothing();lab.camera.force_update_scroll();await frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join(entry[0]+".png"))
	print("POLYGON SCALE PARKOUR: %d/%d"%[checks-failures,checks])
	app.queue_free(); await frames(2); quit(1 if failures else 0)
