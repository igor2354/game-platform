extends SceneTree

var checks := 0
var failures := 0
var lab: CoreMovementLab
var directory := "/private/tmp/ragdoll-overlay-%d" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func new_lab(saved := false) -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = saved
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
func run() -> void:
	root.gui_embed_subwindows = true
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(directory)
	new_lab()
	await frames(5)
	var dev := lab.developer_mode
	var overlay := lab.ragdoll_overlay
	var doll: Node2D = lab.level.ragdoll_mannequin
	check(not overlay.visible and not dev.enabled,"new physics section starts hidden")
	dev.toggle_section(CoreDeveloperMode.Section.PHYSICS)
	await frames(5)
	check(dev.enabled and overlay.panel.is_visible_in_tree() and not dev.tools_scroll.visible,"Physics navigation opens the embedded mannequin page")
	check(overlay.rows.size() == 77 and overlay.tabs.get_tab_count() == 6,"physics pages preserve mannequin controls and add explosion and barrel controls")
	check(dev.panel.get_global_rect().encloses(overlay.save_button.get_global_rect()) and root.get_visible_rect().encloses(dev.panel.get_global_rect()),"physics controls and profile actions fit the screen")
	lab.ragdoll_activate_button.pressed.emit()
	check(doll.active,"Activate button starts the physical mannequin without firing")
	await frames(5)
	var pose := {}
	for key in doll.parts: pose[key] = doll.parts[key].global_transform
	overlay.rows.muscle_tension.slider.value = 0
	check(doll.muscle_tension == 0 and doll.muscle_braces.all(func(brace): return brace.node_a.is_empty() and brace.node_b.is_empty()),"zero tension immediately disconnects muscular supports")
	var unchanged := true
	for key in doll.parts: unchanged = unchanged and doll.parts[key].global_transform.is_equal_approx(pose[key])
	check(unchanged and doll.active,"live adjustment preserves current pose and simulation state")
	await frames(90)
	pose.clear()
	for key in doll.parts: pose[key] = doll.parts[key].global_transform
	overlay.rows.muscle_tension.number.value = .8
	unchanged = true
	for key in doll.parts: unchanged = unchanged and doll.parts[key].global_transform.is_equal_approx(pose[key])
	check(doll.muscle_tension == .8 and unchanged and doll.muscle_braces.all(func(brace): return not brace.node_a.is_empty() and not brace.node_b.is_empty()),"tightening a fallen ragdoll supports its current pose without teleporting")
	await frames(120)
	check(doll.parts.values().all(func(part): return part.global_position.is_finite() and part.global_position.y < CoreMovementLevel.FLOOR+20 and part.linear_velocity.length() < 1000),"the retightened fallen body remains physically stable during simulation")
	overlay.rows.muscle_stiffness.slider.value = 2000
	check(doll.muscle_stiffness == 2000 and is_equal_approx(doll.muscle_braces[0].softness,120.0/1600),"stiffness slider updates actual physical joint compliance")
	overlay.rows.muscle_damping.number.value = 12
	check(doll.parts.values().all(func(part): return is_equal_approx(part.angular_damp,lerpf(3,12,.8))),"damping numeric control updates all body parts")
	lab.ragdoll_reset_button.pressed.emit()
	check(not doll.active and doll.muscle_tension == .8 and doll.muscle_stiffness == 2000 and doll.parts.size() == 13,"Restore button preserves tuning and rebuilds the held standing pose")
	await process_frame
	paused = true
	pose.clear()
	for key in doll.parts: pose[key] = doll.parts[key].global_transform
	overlay.rows.muscle_tension.slider.value = .5
	overlay.rows.muscle_stiffness.number.value = 3000
	overlay.rows.muscle_damping.slider.value = 8
	await frames(5)
	unchanged = true
	for key in doll.parts: unchanged = unchanged and doll.parts[key].global_transform.is_equal_approx(pose[key])
	check(paused and unchanged and doll.muscle_tension == .5 and doll.muscle_stiffness == 3000,"sliders update on pause without advancing physical poses")
	var line: LineEdit = overlay.rows.muscle_stiffness.number.get_line_edit()
	line.grab_focus()
	await process_frame
	await process_frame
	line.text = "2500"
	var previous := lab.player.global_position
	Input.action_press("core_left")
	Input.action_press("core_fire")
	await process_frame
	paused = false
	await frames(6)
	check(lab._blocks_keyboard() and lab.player.global_position.distance_to(previous) < 1 and lab.player.weapon.shots_fired == 0,"numeric editing blocks movement and shooting")
	Input.action_release("core_left")
	Input.action_release("core_fire")
	dev.save_all()
	check(doll.muscle_stiffness == 2500 and root.gui_get_focus_owner() == null and FileAccess.file_exists(lab.ragdoll_settings_path),"Save All commits numeric editing and writes the ragdoll profile")
	var saved := lab.ragdoll_settings.as_dictionary()
	dev.reset_all()
	check(doll.muscle_tension == 1 and doll.muscle_stiffness == 1000 and doll.muscle_damping == 5,"Reset All restores mannequin project defaults")
	dev.load_all()
	check(lab.ragdoll_settings.as_dictionary() == saved and doll.muscle_tension == .5 and doll.muscle_stiffness == 2500,"Load All restores physical tuning and UI")
	check(lab.export_settings_file(directory+"/all.json"),"common JSON export includes the new profile")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/all.json"))
	check(data.ragdoll.size() == 98 and data.ragdoll.muscle_stiffness == 2500,"JSON preserves mannequin settings together with all physical props")
	var legacy_resources := lab._settings_resources()
	legacy_resources.erase("ragdoll")
	check(lab.SettingsFile.write_file(directory+"/legacy-tool.json",legacy_resources) == OK and JSON.parse_string(FileAccess.get_file_as_string(directory+"/legacy-tool.json")).ragdoll.muscle_tension == 1,"older four-resource export tools receive the default mannequin section")
	overlay.rows.muscle_tension.slider.value = 0
	check(lab.import_settings_file(directory+"/all.json") and doll.muscle_tension == .5,"common JSON import reapplies physical tuning")
	data.erase("ragdoll")
	var file := FileAccess.open(directory+"/legacy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(lab.import_settings_file(directory+"/legacy.json") and doll.muscle_tension == 1 and doll.muscle_stiffness == 1000,"older JSON without ragdoll imports with project defaults")
	data.ragdoll = {"muscle_tension":true}
	file = FileAccess.open(directory+"/invalid.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var before := lab.ragdoll_settings.as_dictionary()
	check(not lab.import_settings_file(directory+"/invalid.json") and lab.ragdoll_settings.as_dictionary() == before,"invalid mannequin settings reject JSON without partial changes")
	lab.ragdoll_teleport_button.pressed.emit()
	check(lab.player.global_position.distance_to(Vector2(-190,CoreMovementLevel.FLOOR)) < 2,"teleport button brings the player to the physics area")
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	check(dev.tools_scroll.is_visible_in_tree() and not overlay.visible,"Testing section remains independent of the new Physics section")
	dev.show_section(CoreDeveloperMode.Section.PHYSICS)
	overlay.rows.muscle_tension.slider.value = .6
	dev.save_all()
	lab.queue_free()
	await process_frame
	new_lab(true)
	await frames(5)
	check(lab.ragdoll_settings.muscle_tension == .6 and lab.level.ragdoll_mannequin.muscle_tension == .6 and not lab.developer_mode.enabled,"next launch loads the saved profile while developer mode remains closed")
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
