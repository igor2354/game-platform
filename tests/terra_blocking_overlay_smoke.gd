extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("terra-overlay-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_character="sofia";app.selected_level="prologue_v2";app.launch(true);await frames(12)
	var lab=app.game;lab.camera_settings.blocking_overlay_enabled=true;lab.blocking_overlay.apply_settings(lab.camera_settings)
	var manager=lab.level.get_node("Terraforming");var house
	for patch in manager.owners:
		if "house_roof" in patch.id:house=patch
	var old_shape=house.original.get_child(0)
	check(lab.blocking_overlay.shapes.has(old_shape),"original roof shown before impact")
	var point:=Vector2(house.box.get_center().x,house.box.position.y+.1)
	house.bullet_hit(point,Vector2.DOWN,1000);await frames(12)
	check(not lab.blocking_overlay.shapes.has(old_shape),"disabled original roof removed from overlay")
	var found:=false
	for shape in lab.blocking_overlay.shapes:
		if is_instance_valid(shape) and shape.get_parent().get_parent()==house.grid:found=true
	check(found,"overlay follows replacement collision chunks")
	var before=house.grid.health.duplicate();var profile:=CoreExplosionSettings.new()
	lab.player.tuning.terra_explosions_enabled=false
	house.grid.on_explosion(point,profile,null);await frames(3)
	check(house.grid.health==before,"explosion switch preserves geometry")
	house.bullet_hit(point+Vector2(40,0),Vector2.DOWN,65);await frames(5)
	check(house.grid.health!=before,"bullets remain enabled independently")
	lab.player.tuning.terra_explosions_enabled=true;house.grid.on_explosion(point,profile,null);await frames(15)
	check(house.grid.health!=before,"explosions work after re-enable")
	print("TERRA BLOCKING failures=",failures);app.queue_free();await frames(3);quit(1 if failures else 0)
