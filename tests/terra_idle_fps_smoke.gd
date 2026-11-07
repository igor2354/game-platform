extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func run() -> void:
	var options=preload("res://scripts/ui/display_options.gd").access(self,false)
	check(Engine.max_fps==200,"default startup ceiling is 200 FPS")
	var folder:=OS.get_environment("TEMP").path_join("terra-idle-fps-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(folder);options.settings_path=folder.path_join("display.cfg")
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false;app.test_settings_directory=folder;root.add_child(app)
	await frames(3);app.display_panel.open();app.display_panel.fps_number.value=30;app.display_panel.apply_button.pressed.emit()
	check(Engine.max_fps==30 and options.fps_limit==30,"shared menu applies a real FPS limit")
	var began:=Time.get_ticks_usec();await frames(45);var actual:=45.0*1000000/(Time.get_ticks_usec()-began)
	print("PACED FPS ",actual);check(actual<=31.5,"wall clock frame rate respects cap")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var folder_media:=preload("res://tools/media_paths.gd").path("docs/core/terra_idle_fps_20261102")
		root.get_texture().get_image().save_png(folder_media.path_join("fps_settings.png"))
	var loaded=preload("res://scripts/ui/display_options.gd").new();loaded.settings_path=options.settings_path
	check(loaded.load_saved()==OK and loaded.fps_limit==30,"FPS persists independently of scene")
	check(options.apply_preferences(Vector2i.ZERO,false,1,1,501)==ERR_INVALID_PARAMETER and Engine.max_fps==30,"invalid limit leaves active setting intact")
	app.display_panel.fps_number.value=120;app.display_panel.close();check(Engine.max_fps==30,"closing without apply keeps actual limit")
	options.apply_preferences(Vector2i.ZERO,false,1,1,0);check(Engine.max_fps==200,"zero restores the 200 FPS ceiling")
	check(options.apply_preferences(Vector2i.ZERO,false,1,1,201)==ERR_INVALID_PARAMETER and Engine.max_fps==200,"menu cannot exceed global ceiling")
	var legacy:=ConfigFile.new();legacy.load(options.settings_path);legacy.set_value("display","fps_limit",500);legacy.save(options.settings_path)
	check(loaded.load_saved()==OK and loaded.fps_limit==200,"legacy higher limit is clamped on load")
	app.selected_level="terra";app.selected_character="sofia";app.launch(true);await frames(15)
	var grid=app.game.level.ground;grid.tuning.terra_variation=0;grid.reset_ground();await frames(8)
	var before: int=grid.support_runs
	grid.bullet_hit(grid.global_position+Vector2(1100,.2),Vector2.DOWN,25);await frames(80)
	check(grid.load_runs>0,"subcell damage evaluates weight and connection strength")
	var rebuilds: int=grid.rebuild_runs;var support: int=grid.support_runs;var saved=grid.bullet_erased.duplicate()
	await frames(120)
	check(grid.rebuild_runs==rebuilds and grid.support_runs==support and grid.pending.is_empty(),"settled damage does no repeated rebuilding or support scans")
	check(grid.bullet_erased==saved and not saved.is_empty(),"idle geometry retains its actual damage")
	grid.bullet_hit(grid.global_position+Vector2(1120,.2),Vector2.DOWN,25);await frames(20)
	check(grid.rebuild_runs>rebuilds,"new local impact wakes geometry work")
	grid.deform(Vector2(1100,0),300,140);await frames(240)
	check(grid.support_runs>support,"material removal still triggers collapse checking")
	print("TERRA IDLE FPS: %d/%d"%[checks-failures,checks]);app.queue_free();await frames(3);Engine.max_fps=0;quit(1 if failures else 0)
