extends SceneTree
var checks:=0
var failures:=0
var geometry:Array=[]
const MEDIA=preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame;await process_frame
func collect(node: Node) -> void:
	if node is StaticBody2D and node.collision_layer!=0:
		for child in node.get_children():
			var points:PackedVector2Array=[]
			if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
				var r:Vector2=child.shape.size*.5
				points=PackedVector2Array([Vector2(-r.x,-r.y),Vector2(r.x,-r.y),Vector2(r.x,r.y),Vector2(-r.x,r.y)])
			elif child is CollisionPolygon2D and not child.disabled: points=child.polygon
			if not points.is_empty():
				var world:Array=[]
				for p in points:
					var v:Vector2=child.global_transform*p;world.append([v.x,v.y])
				geometry.append(world)
	for child in node.get_children():collect(child)
func run() -> void:
	root.size=Vector2i(1440,900)
	var lab=load("res://scenes/main.tscn").instantiate();lab.load_user_settings=false
	lab.get_node("World/Player").character_id="sofia"
	var temp:=OS.get_environment("TEMP").path_join("polygon-laboratory-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	root.add_child(lab);await frames(10)
	var level=lab.level;var art=level.laboratory_art
	check(art!=null and art.get_child_count()==15,"fourteen connected source strips and canonical ladder drawing")
	check(art.z_index==-10 and art.position==Vector2(-6600,-200) and art.scale==Vector2(.5,.5),"registered origin, resolution and actor layering")
	check(is_equal_approx(lab.player.world_height(),182.4),"Sofia dimensions preserved")
	collect(level)
	var old=JSON.parse_string(FileAccess.get_file_as_string(MEDIA.path("docs/locations/polygon_laboratory_20261102/Исходники/Блокинг_из_игры.json")))
	check(geometry.size()==old.static_shapes.size(),"static shape count unchanged")
	for i in mini(geometry.size(),old.static_shapes.size()):
		var expected:Array=old.static_shapes[i].points;var same:bool=geometry[i].size()==expected.size()
		for j in mini(geometry[i].size(),expected.size()):
			same=same and Vector2(geometry[i][j][0],geometry[i][j][1]).distance_to(Vector2(expected[j][0],expected[j][1]))<.001
		check(same,"exact static vertices "+str(i))
	for i in level.ladders.size():
		var r:Rect2=level.ladders[i];var e:Array=old.ladders[i]
		check(r.position.distance_to(Vector2(e[0],e[1]))<.001 and r.size.distance_to(Vector2(e[2],e[3]))<.001,"ladder interaction rectangle "+str(i))
	check(level.indoor_lighting.textured_background and level.indoor_lighting.shade.z_index==20 and level.indoor_lighting.lamp.z_index==22,"live lamp and darkness preserved above new wall")
	for door in level.transition_doors:
		lab.player.reset_to(door.global_position);lab._begin_transition(door)
		lab._update_transition(.3);lab._update_transition(.3)
		check(not lab.transition_active and lab.player.global_position.distance_to(door.destination_position)<1,"fade door roundtrip endpoint "+door.name)
	lab.camera_settings.blocking_overlay_enabled=false;lab.blocking_overlay.apply_settings(lab.camera_settings)
	lab.developer_mode.debug_toggle.button_pressed=true;lab.developer_mode._apply_debug()
	check(lab.blocking_overlay.visible and art.visible,"F1 overlays live collision without replacing artwork")
	lab.developer_mode.debug_toggle.button_pressed=false;lab.developer_mode._apply_debug()
	check(not lab.blocking_overlay.visible and art.visible,"F1 off keeps artwork")
	for enemy in level.enemies:enemy.set_physics_process(false)
	for point in [Vector2(160,760),Vector2(600,630),Vector2(835,675),Vector2(1360,540),Vector2(1830,350),Vector2(3560,639.89),Vector2(4370,577.95),Vector2(6120,760)]:
		lab.player.reset_to(point-Vector2(0,20));await frames(30)
		check(absf(lab.player.global_position.y-point.y)<1 and lab.player.is_on_floor(),"physical foot contact "+str(point))
	if "--capture" in OS.get_cmdline_user_args():
		var folder:=MEDIA.path("docs/core/polygon_laboratory_adapted_20261103" if "--adapted" in OS.get_cmdline_user_args() else "docs/core/polygon_laboratory_20261103")
		lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
		lab.set_process(false);lab.camera.position_smoothing_enabled=false;lab.camera.zoom=Vector2.ONE
		for enemy in level.enemies:enemy.set_physics_process(false)
		var spots=[Vector2(-6300,760),Vector2(-4800,760),Vector2(-3300,610),Vector2(-2200,760),Vector2(-560,760),Vector2(160,760),Vector2(760,760),Vector2(1060,760),Vector2(1580,540),Vector2(2018,350),Vector2(2700,760),Vector2(3560,639.89),Vector2(4370,577.95),Vector2(5400,760),Vector2(6470,760)]
		lab.player.set_physics_process(false)
		for i in spots.size():
			lab.player.reset_to(spots[i]);lab.camera.position=spots[i]-Vector2(0,180);lab.camera.reset_smoothing()
			await frames(3);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("point_%02d.png"%i))
			if i in [2,7,9,11,14]:
				lab.blocking_overlay.set_debug_enabled(true);await frames(2);await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join("point_%02d_blocking.png"%i))
				lab.blocking_overlay.set_debug_enabled(false)
	print("POLYGON LABORATORY ",checks-failures,"/",checks)
	lab.queue_free();await process_frame;quit(1 if failures else 0)
