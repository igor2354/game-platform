extends SceneTree
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame;await physics_frame
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-perf-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="prologue_v2";app.selected_character="sofia";app.launch(true);await frames(15)
	var manager=app.game.level.get_node("Terraforming");var patch
	for p in manager.owners:
		if "house_roof" in p.id:patch=p
	app.game.camera_settings.fog_enabled=false;app.game.fog_of_war.apply_settings()
	app.game.player.reset_to(Vector2(patch.box.get_center().x,patch.box.end.y+270))
	for size in [1.0,6.0]:
		var grid=patch.activate();grid.tuning.terra_bullet_size=size;grid.reset_ground();await frames(10)
		var times: Array[float]=[];var peak:=0.0;var visual:=0.0;var upload:=0.0;var bytes:=0
		for i in 40:
			var point:=Vector2(patch.box.position.x+100+i*25,patch.box.position.y+.2)
			var began:=Time.get_ticks_usec()
			grid.bullet_hit(point,Vector2.DOWN,65,preload("res://scripts/campaign/catalog.gd").terrain_ballistics("svt"))
			times.append((Time.get_ticks_usec()-began)/1000.0)
			await frames(4);peak=maxf(peak,grid.last_rebuild_ms);visual=maxf(visual,manager.last_visual_ms);upload=maxf(upload,manager.last_upload_ms);bytes=maxi(bytes,manager.upload_bytes)
		var total:=0.0
		for t in times:total+=t
		print("PROBE size=",size," hit_mean_ms=",total/times.size()," hit_max_ms=",times.max()," rebuild_peak_ms=",peak," visual_max_ms=",visual," upload_max_ms=",upload," upload_bytes=",bytes," rigid_bodies=",grid.get_children().filter(func(n):return n is RigidBody2D).size())
		for tile in manager.bullet_tiles:
			if tile.image!=null:print("MASK ",tile.image.get_size())
	app.queue_free();await frames(3);quit()
