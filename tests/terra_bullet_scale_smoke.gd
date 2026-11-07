extends SceneTree
const GRID=preload("res://scripts/core/terra_grid.gd")
const CATALOG=preload("res://scripts/campaign/catalog.gd")
class Labels extends Node2D:
	var grid: Node2D
	func _draw() -> void:
		for list in grid.surfaces.values():
			for item in list:draw_colored_polygon(item[0],grid.COLORS[item[1]])
		var names:=["MP-40","STG-44","1911","СВТ"]
		for i in 4:
			draw_string(ThemeDB.fallback_font,Vector2(115+i*100,-25),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
			draw_line(Vector2(140+i*100,-19),Vector2(140+i*100,-3),Color.WHITE,1)
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func width(grid: Node) -> float:
	var lo:=INF;var hi:=-INF
	for p in grid.bullet_erased:lo=minf(lo,p.x);hi=maxf(hi,p.x+1)
	return maxf(0,hi-lo)
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-small-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_character="sofia";app.selected_level="terra";app.launch(true);await frames(10)
	var lab=app.game;var ground=lab.level.ground
	var grid:=GRID.new();grid.W=32;grid.H=16;grid.custom_polygon=PackedVector2Array([Vector2.ZERO,Vector2(512,0),Vector2(512,256),Vector2(0,256)])
	grid.restored=true;grid.material_override=4;grid.tuning=lab.player.tuning;grid.position=Vector2(80000,0)
	grid.tuning.terra_collapse_enabled=false;grid.tuning.terra_variation=0;lab.add_child(grid)
	var point:=grid.position+Vector2(200.3,.2)
	var counts: Dictionary={}
	for id in ["mp40","stg44","m1911","svt"]:
		grid.reset_ground();await frames(3)
		var data: Dictionary=CATALOG.WEAPONS[CATALOG.index_for(id)]
		grid.bullet_hit(point,Vector2.DOWN,data.values.damage,CATALOG.terrain_ballistics(id));await frames(4)
		counts[id]=grid.bullet_erased.size()
		print("HOLE ",id," removed_cm2=",counts[id]," width_cm=",width(grid)," refined_cells=",grid.bullet_cells.size())
		check(counts[id]>0 and width(grid)<=8,"small physical hole "+id)
		check(grid.bullet_cells.size()<=4,"refinement stays local "+id)
	check(counts.svt>counts.stg44 and counts.stg44>counts.mp40,"weapon penetration power changes removed volume")
	grid.reset_ground();await frames(2);grid.bullet_hit(point,Vector2.DOWN,35,{"caliber_mm":7.62,"power":1.0});await frames(2)
	var narrow:=width(grid);var small_volume:=grid.bullet_erased.size()
	grid.reset_ground();await frames(2);grid.bullet_hit(point,Vector2.DOWN,35,{"caliber_mm":11.43,"power":1.0});await frames(2)
	check(width(grid)>narrow and grid.bullet_erased.size()>small_volume,"caliber changes width at equal damage and power")
	grid.reset_ground();await frames(2);grid.bullet_hit(point,Vector2.DOWN,70,{"caliber_mm":7.62,"power":1.0});await frames(2)
	check(grid.bullet_erased.size()>small_volume,"damage affects excavation independently of caliber")
	grid.reset_ground();await frames(2);grid.tuning.terra_bullet_power=3
	grid.bullet_hit(point,Vector2.DOWN,35,CATALOG.terrain_ballistics("stg44"));await frames(2)
	check(grid.bullet_erased.size()>small_volume,"extended terrain damage control affects actual geometry")
	var maximum_volume:=grid.bullet_erased.size()
	grid.reset_ground();await frames(2);grid.tuning.terra_bullet_power=1
	grid.bullet_hit(point,Vector2.DOWN,35,CATALOG.terrain_ballistics("stg44"));await frames(2)
	check(maximum_volume>grid.bullet_erased.size(),"range from one to three remains effective")
	grid.tuning.terra_bullet_power=.12
	grid.reset_ground();await frames(2)
	var health:=grid.health.duplicate();grid.tuning.terra_bullets_enabled=false
	grid.bullet_hit(point,Vector2.DOWN,65,CATALOG.terrain_ballistics("svt"));await frames(2)
	check(grid.health==health and grid.bullet_erased.is_empty(),"bullet toggle suppresses all fine damage")
	grid.tuning.terra_bullets_enabled=true
	var bullet:=CoreProjectile.new();bullet.position=point-Vector2(0,30);bullet.direction=Vector2.DOWN;bullet.damage=65;bullet.speed=2400
	bullet.shooter=lab.player.get_rid();bullet.terrain_ballistics=CATALOG.terrain_ballistics("svt")
	lab.add_child(bullet);await frames(4)
	check(grid.bullet_erased.size()>counts.mp40,"flying projectile carries its own weapon ballistics")
	var maximum:=0.0
	for row in grid.tuning.PARAMS:
		if row[0]=="terra_bullet_power":maximum=row[3]
	check(maximum>=3,"terrain damage slider maximum tripled")
	if "--capture" in OS.get_cmdline_user_args():
		grid.reset_ground();await frames(3)
		var ids:=["mp40","stg44","m1911","svt"]
		for i in 4:
			var data: Dictionary=CATALOG.WEAPONS[CATALOG.index_for(ids[i])]
			grid.bullet_hit(grid.position+Vector2(140+i*100,.2),Vector2.DOWN,data.values.damage,CATALOG.terrain_ballistics(ids[i]))
		var labels:=Labels.new();labels.grid=grid;grid.add_child(labels)
		lab.player.reset_to(grid.position+Vector2(28,0));lab.camera_settings.fog_enabled=false;lab.fog_of_war.apply_settings()
		lab.set_process(false);lab.set_physics_process(false)
		lab.camera.position=grid.position+Vector2(256,20);lab.camera.zoom=Vector2(1.3,1.3);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await frames(12);await RenderingServer.frame_post_draw
		var folder:=preload("res://tools/media_paths.gd").path("docs/core/terra_bullet_size_20261102")
		root.get_texture().get_image().save_png(folder.path_join("weapon_holes.png"))
	grid.tuning.terra_bullet_size=.6;grid.tuning.terra_bullet_power=2.7
	var path:=app.test_settings_directory.path_join("ballistics.json")
	check(lab.export_settings_file(path),"isolated settings export")
	grid.tuning.terra_bullet_power=.12;grid.tuning.terra_bullet_size=1
	check(lab.import_settings_file(path) and is_equal_approx(grid.tuning.terra_bullet_power,2.7) and is_equal_approx(grid.tuning.terra_bullet_size,.6),"extended settings round trip")
	grid.tuning.terra_bullet_power=.12;grid.tuning.terra_bullet_size=1;grid.reset_ground();await frames(3)
	var peak_hit:=0.0;var peak_rebuild:=0.0;var fired:=0
	for i in 100:
		var query:=PhysicsRayQueryParameters2D.create(grid.position+Vector2(200.3,-40),grid.position+Vector2(200.3,255),1)
		var hit:=grid.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():break
		var began:=Time.get_ticks_usec()
		CoreProjectile.resolve_impact(hit,35,Vector2.DOWN,Callable(),Vector2.INF,true,null,CATALOG.terrain_ballistics("stg44"))
		peak_hit=maxf(peak_hit,(Time.get_ticks_usec()-began)/1000.0);fired+=1
		await frames(2);peak_rebuild=maxf(peak_rebuild,grid.last_rebuild_ms)
	print("FINE BURST shots=",fired," cells=",grid.bullet_cells.size()," peak_hit_ms=",peak_hit," peak_rebuild_ms=",peak_rebuild)
	check(fired>=50 and grid.bullet_cells.size()<64,"long burst refines only its narrow channel")
	ground.tuning.terra_bullet_power=.12;ground.tuning.terra_bullet_size=1;ground.reset_ground();await frames(3)
	ground.bullet_hit(ground.global_position+Vector2(1100,.2),Vector2.DOWN,65,CATALOG.terrain_ballistics("svt"));await frames(5)
	var saved: Dictionary=ground.bullet_erased.duplicate()
	await app.return_to_menu();app.launch(true);await frames(8)
	check(not saved.is_empty() and app.game.level.ground.bullet_erased==saved,"fine holes survive return to Terra")
	print("TERRA BULLET SCALE: %d/%d"%[checks-failures,checks]);app.queue_free();await frames(3);quit(1 if failures else 0)
