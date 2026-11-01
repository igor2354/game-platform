extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("PASS ",label)
	else: failures+=1;push_error("FAIL "+label)
func release() -> void:
	for action in ["core_left","core_right","core_up","core_down","core_jump"]: Input.action_release(action)
func travel(hero: Node, direction: String, vertical: String, end: Vector2) -> void:
	release();Input.action_press(direction);Input.action_press(vertical)
	for i in 260:
		await frames(1)
		if hero.position.distance_to(end)<.4 and (hero.stairs.flight==null or hero.stairs.progress==0 or hero.stairs.progress==1): break
	release();await frames(1)
	if hero.position.distance_to(end)>=1: print("DETAIL feet=",hero.position," target=",end," flight=",hero.stairs.flight," progress=",hero.stairs.progress," exceptions=",hero.stairs.ignored.size())
	check(hero.position.distance_to(end)<1,"flight reaches endpoint "+str(end))
	check(hero.collision_mask==hero.WORLD_MASK,"world collision remains enabled")
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("ordinary-stairs-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_character="sofia";app.selected_level="hub";app.launch(true)
	await frames(10)
	var hero: CoreMovementPlayer=app.game.player
	var routes:=get_nodes_in_group("ordinary_stairs")
	check(routes.size()==14,"all hub flights registered")
	for pair in 7:
		var first: PackedVector2Array=routes[pair*2].endpoints()
		var second: PackedVector2Array=routes[pair*2+1].endpoints()
		hero.reset_to(first[0]);await frames(6)
		Input.action_press("core_right");await frames(2);release()
		check(hero.stairs.flight==null,"walking past does not enter")
		hero.reset_to(first[0]);await frames(6)
		Input.action_press("core_right");Input.action_press("core_down");await frames(2);release()
		if pair==0 or pair==3: check(hero.stairs.flight==null,"wrong vertical direction does not enter at ground floor")
		hero.reset_to(first[0]);await frames(6)
		await travel(hero,"core_right","core_up",first[1])
		var stopped: Vector2=hero.position;await frames(8)
		check(hero.position.distance_to(stopped)<.1,"unsupported half-landing holds position")
		if pair==0 and "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var folder:=preload("res://tools/media_paths.gd").path("docs/core/ordinary_stairs_20261101")
			root.get_texture().get_image().save_png(folder.path_join("half_landing.png"))
		await travel(hero,"core_left","core_up",second[1])
		check(hero.stairs.flight==null and hero.stairs.ignored.is_empty(),"floor exit restores collision exceptions")
		await frames(6)
		await travel(hero,"core_right","core_down",second[0])
		await travel(hero,"core_left","core_down",first[0])
		check(hero.stairs.flight==null,"descent exits on original floor")
		await frames(6)
	hero.tuning.stairs_enabled=false;hero.reset_to(routes[0].endpoints()[0]);await frames(6)
	Input.action_press("core_right");Input.action_press("core_up");await frames(3);release()
	check(hero.stairs.flight==null,"independent toggle disables entry")
	hero.tuning.stairs_enabled=true;hero.reset_to(routes[0].endpoints()[0]);await frames(6)
	Input.action_press("core_right");Input.action_press("core_up");await frames(10)
	check(hero.stairs.flight!=null,"entered for interruption test")
	hero.tuning.stairs_enabled=false;await frames(2);release()
	check(hero.stairs.flight==null and hero.stairs.ignored.is_empty(),"disabling active route restores all exceptions")
	hero.tuning.stairs_enabled=true;hero.reset_to(routes[0].endpoints()[0]);await frames(6)
	Input.action_press("core_right");Input.action_press("core_up");Input.action_press("core_jump");await frames(3);release()
	check(hero.stairs.flight==null,"jump takes priority over entering stairs")
	hero.reset_to(routes[0].endpoints()[0]);await frames(6)
	Input.action_press("core_right");Input.action_press("core_up");await frames(10)
	var old_blocker=hero.input_blocker;hero.input_blocker=func(): return true
	var paused: Vector2=hero.position;await frames(4)
	check(hero.position.distance_to(paused)<.1,"blocked input stops on route")
	hero.input_blocker=old_blocker
	var wall:=StaticBody2D.new();var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new()
	var wall_x: float=hero.position.x+70
	box.size=Vector2(20,400);shape.shape=box;shape.position=Vector2(wall_x+10,hero.position.y-150)
	wall.add_child(shape);app.game.add_child(wall);await frames(65);release()
	check(hero.position.x<wall_x and hero.collision_mask==hero.WORLD_MASK,"wall on route remains solid")
	wall.queue_free();hero.reset_to(routes[0].endpoints()[0]);hero.tuning.stairs_enabled=false;await frames(3)
	check(app.game.export_settings_file(app.test_settings_directory.path_join("stairs.json")),"settings export with stair fields")
	check(app.game.import_settings_file(app.test_settings_directory.path_join("stairs.json")),"settings import retains stair fields")
	check(not hero.tuning.stairs_enabled and hero.tuning.stairs_speed==160,"JSON preserves stair toggle and speed")
	print("ORDINARY STAIRS: %d/%d"%[checks-failures,checks])
	app.queue_free();await frames(3);quit(1 if failures else 0)
