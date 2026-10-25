extends SceneTree
## Explicit --apply-user uses the same numeric controls and Save button as F2.
const KEYS := ["run_speed","slow_walk_speed","sprint_speed","crouch_speed_multiplier","acceleration","braking","air_acceleration","slow_walk_acceleration","slow_walk_braking","slow_walk_air_acceleration","jump_speed","jump_cut_speed","gravity","walk_jump_multiplier","sprint_jump_multiplier","slow_walk_jump_multiplier"]
const MEDIA = preload("res://tools/media_paths.gd")
const V2 = preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab: CoreMovementLab
var output := ""
func _initialize() -> void: call_deferred("run")
func frames(n:int) -> void:
	for i in n: await physics_frame; await process_frame
func capture(name: String) -> void:
	await frames(3); await RenderingServer.frame_post_draw
	var path := output.path_join(name+".png")
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ",error," ",path)
func run() -> void:
	output=MEDIA.path("docs/locations/mvp_village/Проверки/tactical_ceilings_2026-10-25")
	var apply := "--apply-user" in OS.get_cmdline_user_args()
	if apply:
		var backup := output.path_join("core_movement_before.cfg")
		if not FileAccess.file_exists(backup) or FileAccess.get_sha256(backup)!=FileAccess.get_sha256(ProjectSettings.globalize_path(CoreMovementSettings.SAVE_PATH)):
			push_error("Existing movement profile must have an exact backup before intentional tuning"); quit(1); return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600,1000));root.size=Vector2i(1600,1000)
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate()
	lab.load_user_settings=apply
	if not apply:
		var isolated:=OS.get_environment("TEMP").path_join("tactical-ui-%d"%OS.get_process_id())
		DirAccess.make_dir_recursive_absolute(isolated)
		for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,isolated.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12)
	preload("res://scripts/campaign/catalog.gd").equip(lab.player.weapon,"stg44")
	var before: Dictionary=lab.player.tuning.as_dictionary().duplicate()
	var proposed: Resource=load("res://resources/campaign/prologue_v2_movement.tres")
	lab.developer_mode.set_enabled(true);lab.developer_mode.show_overlay(0)
	for key in KEYS: lab.movement_overlay.rows[key].number.value=proposed.get(key)
	await frames(3)
	for key in before:
		if key not in KEYS and lab.player.tuning.get(key)!=before[key]:push_error("Unrelated setting changed: "+key);quit(1);return
	for key in KEYS:
		if not is_equal_approx(float(lab.player.tuning.get(key)),float(proposed.get(key))):push_error("UI value mismatch: "+key);quit(1);return
	lab.movement_overlay.save_button.pressed.emit()
	var reload:=CoreMovementSettings.new()
	if reload.load_saved(lab.settings_path)!=OK:push_error("Saved profile failed to load");quit(1);return
	for key in KEYS:
		if not is_equal_approx(float(reload.get(key)),float(proposed.get(key))):push_error("Save mismatch: "+key);quit(1);return
	for title in ["Бег","Ходьба","Спринт","Приседание","Прыжок"]:
		for i in lab.movement_overlay.tabs.get_tab_count():
			if lab.movement_overlay.tabs.get_tab_title(i)==title:lab.movement_overlay.tabs.current_tab=i
		await capture("developer_"+title)
	lab.developer_mode.set_enabled(false)
	lab.player.weapon.tuning.sound_enabled=false
	lab.camera_settings.apply_values({"noir_enabled":false,"pixel_enabled":false,"world_pixel_enabled":false,"stable_pixel_enabled":false,"limit_to_level":false,"follow_speed":0})
	lab._camera_settings_changed();lab.set_process(false)
	lab.camera.zoom=Vector2.ONE*1.25
	for child in lab.get_children():
		if child is CanvasLayer:child.hide()
	var balcony:Rect2=lab.level.forest.features["09_1"] if lab.level.forest.features.has("09_1") else Rect2(V2.point(324,3.1),Vector2(500,16))
	lab.player.reset_to(V2.point(324.5,0));await frames(10)
	lab.camera.position=V2.point(325,2.3);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	Input.action_press("core_jump")
	for tick in 70:
		await frames(1)
		if lab.player.is_on_ceiling():await capture("balcony_ceiling_contact");break
	Input.action_release("core_jump")
	var r:Rect2=lab.level.forest.features["house_inner_ladder"]
	lab.player.reset_to(Vector2(r.get_center().x,r.end.y));await frames(3)
	lab.camera.position=V2.point(310,3.7);lab.camera.reset_smoothing();lab.camera.force_update_scroll()
	Input.action_press("core_up")
	for tick in 400:
		await frames(1)
		if not lab.player.climbing and not lab.player.ladder_exit.is_finite() and lab.player.is_on_floor() and absf(lab.player.position.y-r.position.y)<3:break
	Input.action_release("core_up");await frames(12);await capture("house_ladder_opening")
	for record in [["J07",Vector2(29125.99,638.7618),V2.point(170,2.8)],["J12",Vector2(48614.36,961.8851),V2.point(363,-.3)],["J18",Vector2(58005.13,759.9333),V2.point(457,3)]]:
		lab.player.reset_to(record[1]);await frames(10)
		lab.player.weapon.aim_override=lab.player.position+Vector2(700,-80)
		lab.camera.position=record[2];lab.camera.reset_smoothing();lab.camera.force_update_scroll()
		await capture("route_review_"+record[0])
	print("TACTICAL UI: sixteen values applied through numeric controls and Save; apply_user=",apply)
	lab.queue_free();await frames(3);quit()
