extends SceneTree
var count:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame;await physics_frame
func check(ok: bool,label: String) -> void:
	count+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func run() -> void:
	var options=preload("res://scripts/ui/display_options.gd").access(self,false)
	var folder:=OS.get_environment("TEMP").path_join("fps-display-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(folder);options.settings_path=folder.path_join("display.cfg")
	var app:=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false;app.test_settings_directory=folder;root.add_child(app);await frames(4)
	var display=root.get_node("FpsCounter")
	check(not display.visible and not display.is_processing(),"disabled counter does no frame work")
	app.display_panel.open();app.display_panel.fps_counter_toggle.button_pressed=true;app.display_panel.apply_button.pressed.emit();await frames(4)
	check(options.show_fps and display.visible and display.label.text.begins_with("FPS:"),"main menu enables actual FPS display")
	var loaded=preload("res://scripts/ui/display_options.gd").new();loaded.settings_path=options.settings_path
	check(loaded.load_saved()==OK and loaded.show_fps,"display preference persists")
	app.display_panel.fps_counter_toggle.button_pressed=false;app.display_panel.close();check(display.visible,"closing without apply does not hide counter")
	app.selected_level="terra";app.selected_character="sofia";app.launch(true);await frames(12)
	check(root.get_node("FpsCounter")==display and display.visible,"counter persists across map loading")
	paused=true;await frames(4);check(display.can_process(),"counter updates during pause")
	options.apply_preferences(options.resolution,options.fullscreen,1,1,-1,false);await frames(3)
	check(not display.visible and not display.is_processing() and Engine.max_fps==200,"hiding counter preserves FPS ceiling")
	paused=false
	if "--capture" in OS.get_cmdline_user_args():
		options.apply_preferences(options.resolution,options.fullscreen,1,1,-1,true);await frames(5)
		app.game._set_pause(true);app.game.pause_menu.settings.open();await frames(3)
		var settled:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-settled<1500000:await process_frame
		await RenderingServer.frame_post_draw
		var media:=preload("res://tools/media_paths.gd").path("docs/core/terra_perf_20261102")
		root.get_texture().get_image().save_png(media.path_join("fps_counter_settings.png"))
	print("FPS DISPLAY: %d/%d"%[count-failures,count]);app.queue_free();await frames(3);quit(1 if failures else 0)
