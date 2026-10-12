extends SceneTree

var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/settings-file-test-%d" % OS.get_process_id()
var preset_path: String
var scratch_path: String
var bad_path: String

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func write_text(path: String,text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
func snapshot() -> Dictionary:
	var values := {}
	for section in lab._settings_resources(): values[section] = lab._settings_resources()[section].as_dictionary()
	return values
func saved_texts() -> Array:
	return [FileAccess.get_file_as_string(lab.settings_path),FileAccess.get_file_as_string(lab.shooting_settings_path),FileAccess.get_file_as_string(lab.camera_settings_path),FileAccess.get_file_as_string(lab.zombie_settings_path)]
func same_json_values(actual: Dictionary,expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key in expected:
		if not actual.has(key): return false
		if expected[key] is bool:
			if actual[key] != expected[key]: return false
		elif not is_equal_approx(float(actual[key]),float(expected[key])): return false
	return true
func new_lab(load_saved: bool) -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = load_saved
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	root.add_child(lab)
func reject(data,expected: Dictionary,persisted: Array,message: String) -> void:
	write_text(bad_path,JSON.stringify(data))
	check(not lab.import_settings_file(bad_path) and snapshot() == expected and saved_texts() == persisted,message)
func run() -> void:
	root.gui_embed_subwindows = true
	DirAccess.make_dir_recursive_absolute(directory)
	preset_path = directory+"/all-settings.json"
	scratch_path = directory+"/scratch.json"
	bad_path = directory+"/invalid.json"
	new_lab(false)
	await frames(8)
	var hero := lab.player
	var gun := hero.weapon
	var movement := lab.movement_overlay
	var shooting := lab.shooting_overlay
	var camera := lab.camera_overlay
	var zombie := lab.zombie_overlay
	check(not lab.settings_dialog_open and not lab.settings_dialog.visible and movement.export_button != null and shooting.import_button != null and camera.export_button != null and zombie.import_button != null,"all four settings windows expose shared file actions; dialog starts closed")
	movement.toggle()
	movement.rows.uphill_multiplier.slider.value = .55
	movement.rows.downhill_multiplier.number.value = 1.3
	shooting.rows.rounds_per_minute.number.value = 1300
	gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	gun.tuning.kill_volume = -5
	gun.tuning.apply_values({"head_damage_multiplier":3.4,"torso_damage_multiplier":.75,"arm_damage_multiplier":.2,"leg_damage_multiplier":.6,"arm_durability":75,"leg_durability":90})
	lab.camera_settings.apply_values({"zoom":1.75,"offset_x":123,"limit_to_level":false})
	lab.zombie_settings.apply_values({"detection_range":480,"vision_angle":90,"forget_range":700,"lose_sight_delay":2.5,"patrol_radius":140,"patrol_speed":70,"chase_speed":160,"crawl_speed":30,"attack_range":75,"attack_damage":22,"attack_windup":.65,"attack_recovery":1.1})
	lab.zombie_settings.apply_values({"vision_offset_x":24,"hearing_range":250,"shot_noise_multiplier":3,"movement_noise_multiplier":.8,"noise_occlusion_multiplier":.25,"noise_memory_time":3})
	var line: LineEdit = movement.rows.run_speed.number.get_line_edit()
	line.grab_focus()
	line.text = "420"
	movement.export_button.pressed.emit()
	await process_frame
	check(hero.tuning.run_speed == 420 and lab.settings_dialog_open and paused and lab.settings_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE,"Export commits pending numeric edits, opens a save dialog and pauses the game")
	var position := hero.position
	var shots := gun.shots_fired
	for action in ["core_right","core_jump","core_dash","core_fire","core_aim"]: Input.action_press(action)
	await frames(8)
	check(hero.position == position and hero.dashes == 0 and gun.shots_fired == shots and lab._blocks_keyboard() and lab._blocks_shooting(),"the file dialog freezes physics and blocks gameplay input")
	var toggle := InputEventAction.new()
	toggle.action = "core_camera_tuner"
	toggle.pressed = true
	root.push_input(toggle,true)
	await process_frame
	check(movement.visible and not camera.visible,"settings hotkeys cannot switch windows behind a modal dialog")
	for action in ["core_right","core_jump","core_dash","core_fire","core_aim"]: Input.action_release(action)
	lab.settings_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not lab.settings_dialog_open and not paused and not FileAccess.file_exists(preset_path),"Cancel restores the original play state without exporting anything")
	var expected := snapshot()
	movement.export_button.pressed.emit()
	lab.settings_dialog.file_selected.emit(preset_path)
	check(not lab.settings_dialog_open and not paused and FileAccess.file_exists(preset_path),"selecting a save path exports one combined file and resumes the game")
	var data = JSON.parse_string(FileAccess.get_file_as_string(preset_path))
	check(data.format == "dead-platform-settings" and data.version == 1 and same_json_values(data.movement,expected.movement) and same_json_values(data.shooting,expected.shooting) and same_json_values(data.camera,expected.camera) and same_json_values(data.zombie,expected.zombie),"export contains all 73 values including hearing and vision offset")
	check(not FileAccess.file_exists(lab.settings_path) and hero.tuning.run_speed == 420 and gun.shots_fired == shots,"export preserves the active game and does not overwrite local profiles")
	Input.action_press("core_fire")
	await frames(4)
	check(gun.shots_fired == shots,"a held file-dialog click cannot become a shot after the picker closes")
	Input.action_release("core_fire")
	await frames(2)
	Input.action_press("core_fire")
	await frames(2)
	check(gun.shots_fired == shots+1,"a fresh trigger press works after releasing the file-dialog click")
	Input.action_release("core_fire")
	await frames(2)
	shots = gun.shots_fired
	paused = true
	hero.tuning.run_speed = 220
	gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.AUTO)
	lab.camera_settings.zoom = .5
	lab.zombie_settings.vision_angle = 160
	movement.import_button.pressed.emit()
	check(lab.settings_dialog_open and lab.settings_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE,"Import opens a file picker from an already paused game")
	lab.settings_dialog.file_selected.emit(preset_path)
	await frames(3)
	check(paused and not lab.settings_dialog_open and snapshot() == expected,"import restores every exported setting and retains the existing pause")
	check(movement.rows.run_speed.slider.value == 420 and movement.rows.uphill_multiplier.number.value == .55 and shooting.fire_mode_selector.selected == 1 and camera.rows.zoom.slider.value == 1.75 and not camera.camera_limits_toggle.button_pressed and zombie.rows.vision_angle.slider.value == 90 and zombie.rows.chase_speed.number.value == 160,"all controls refresh together after import")
	check(lab.camera.zoom == Vector2(1.75,1.75) and hero.position == position and gun.shots_fired == shots,"import updates the actual camera while preserving hero position and combat statistics")
	check(movement.saved_values == expected.movement and shooting.saved_values == expected.shooting and camera.saved_values == expected.camera and zombie.saved_values == expected.zombie,"successful import saves all four local profiles and updates their saved indicators")
	var persisted := saved_texts()
	var source_movement := load("res://resources/core/movement.tres") as CoreMovementSettings
	var source_shooting := load("res://resources/core/shooting.tres") as CoreShootingSettings
	var source_camera := load("res://resources/core/camera.tres") as CoreCameraSettings
	var source_zombie := load("res://resources/core/zombie.tres") as CoreZombieSettings
	check(source_movement.run_speed == 320 and source_shooting.fire_mode == 0 and source_camera.zoom == 1 and source_zombie.vision_angle == 120 and source_zombie.attack_damage == 15,"import leaves editor resources unchanged")
	write_text(bad_path,"{ broken JSON")
	check(not lab.import_settings_file(bad_path) and snapshot() == expected and saved_texts() == persisted,"malformed JSON is rejected without changing active or saved values")
	reject([],expected,persisted,"a non-object JSON root is rejected")
	var invalid: Dictionary = data.duplicate(true)
	invalid.format = "another-game"
	reject(invalid,expected,persisted,"a foreign preset is rejected")
	invalid = data.duplicate(true)
	invalid.version = 2
	reject(invalid,expected,persisted,"an unsupported format version is rejected")
	invalid.version = true
	reject(invalid,expected,persisted,"a boolean cannot replace the numeric format version")
	invalid = data.duplicate(true)
	invalid.erase("camera")
	reject(invalid,expected,persisted,"an absent section is rejected before applying any other section")
	invalid = data.duplicate(true)
	invalid.movement.run_speed = "fast"
	reject(invalid,expected,persisted,"strings cannot replace numeric settings")
	invalid = data.duplicate(true)
	invalid.shooting.damage = true
	reject(invalid,expected,persisted,"booleans cannot replace numeric settings")
	invalid = data.duplicate(true)
	invalid.camera.limit_to_level = 1
	reject(invalid,expected,persisted,"camera bounds require an actual boolean")
	invalid = data.duplicate(true)
	invalid.shooting.fire_mode = .5
	reject(invalid,expected,persisted,"fractional fire modes are rejected")
	invalid = data.duplicate(true)
	invalid.zombie = "bad"
	reject(invalid,expected,persisted,"a malformed zombie section rejects the entire import atomically")
	invalid = data.duplicate(true)
	invalid.zombie.vision_angle = "wide"
	reject(invalid,expected,persisted,"non-numeric zombie settings cannot modify active or saved profiles")
	invalid = data.duplicate(true)
	invalid.zombie.hearing_range = true
	reject(invalid,expected,persisted,"boolean hearing ranges cannot modify any active or saved settings")
	write_text(bad_path,"x".repeat(1024*1024+1))
	check(not lab.import_settings_file(bad_path) and snapshot() == expected,"oversized input is rejected without applying changes")
	check(not lab.import_settings_file(directory+"/missing.json") and snapshot() == expected,"missing input is reported without changing values")
	check(not lab.export_settings_file(directory+"/missing-directory/output.json") and snapshot() == expected,"an unwritable export path reports a failure without changing settings")
	invalid = {"format":"dead-platform-settings","version":1,"movement":{"run_speed":400},"shooting":{"fire_mode":0},"camera":{"zoom":2},"unknown_section":{"ignored":true}}
	write_text(scratch_path,JSON.stringify(invalid))
	check(lab.import_settings_file(scratch_path) and hero.tuning.run_speed == 400 and hero.tuning.uphill_multiplier == .7 and gun.tuning.kill_volume == -10 and gun.tuning.head_damage_multiplier == 2 and gun.tuning.arm_durability == 50 and lab.camera_settings.offset_x == 0 and lab.zombie_settings.vision_angle == 120 and lab.zombie_settings.attack_damage == 15,"older three-section presets import with project defaults for zombies and missing keys")
	invalid = data.duplicate(true)
	for key in ["vision_offset_x","hearing_range","shot_noise_multiplier","movement_noise_multiplier","noise_occlusion_multiplier","noise_memory_time"]: invalid.zombie.erase(key)
	write_text(scratch_path,JSON.stringify(invalid))
	check(lab.import_settings_file(scratch_path) and lab.zombie_settings.vision_offset_x == 0 and lab.zombie_settings.hearing_range == 180 and lab.zombie_settings.noise_memory_time == 5 and lab.zombie_settings.detection_range == 480,"older zombie profiles retain their values and receive base hearing and cone-offset settings")
	invalid = data.duplicate(true)
	invalid.movement.run_speed = -20
	invalid.movement.jump_speed = 200
	invalid.movement.jump_cut_speed = 1000
	invalid.movement.dash_duration = .6
	invalid.movement.dash_cooldown = .1
	invalid.camera.zoom = 100
	invalid.shooting.hip_spread = 12
	invalid.shooting.hip_max_spread = 2
	invalid.zombie.vision_angle = 360
	invalid.zombie.detection_range = 900
	invalid.zombie.forget_range = 100
	invalid.zombie.vision_offset_x = 999
	invalid.zombie.hearing_range = -10
	write_text(scratch_path,JSON.stringify(invalid))
	check(lab.import_settings_file(scratch_path) and hero.tuning.run_speed == 100 and hero.tuning.jump_cut_speed == 200 and hero.tuning.dash_cooldown == .6 and lab.camera_settings.zoom == 3 and gun.tuning.hip_max_spread == 12 and lab.zombie_settings.vision_angle == 180 and lab.zombie_settings.forget_range == 900 and lab.zombie_settings.vision_offset_x == 120 and lab.zombie_settings.hearing_range == 0 and movement.status.text.contains("диапазонами"),"out-of-range values including hearing and cone offset are normalised with a visible notice")
	check(lab.import_settings_file(preset_path),"the original preset can be restored after importing a different profile")
	paused = false
	lab.queue_free()
	await process_frame
	new_lab(true)
	await frames(8)
	check(snapshot() == expected,"a new game automatically loads all settings imported in the previous session")
	lab.camera_overlay.toggle()
	lab.camera_overlay.import_button.pressed.emit()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	lab.settings_dialog.push_input(escape,true)
	await process_frame
	await process_frame
	check(not lab.settings_dialog_open and not paused and snapshot() == expected,"Escape cancels the file picker without toggling gameplay pause or changing values")
	if lab.settings_dialog_open: lab._close_settings_dialog()
	lab.camera_overlay.export_button.pressed.emit()
	lab.settings_dialog.close_requested.emit()
	await process_frame
	check(not lab.settings_dialog_open and not paused and snapshot() == expected,"the title-bar close button cancels the picker and restores the previous state")
	write_text(bad_path,"{ broken JSON")
	lab.camera_overlay.import_button.pressed.emit()
	lab.settings_dialog.file_selected.emit(bad_path)
	check(not lab.settings_dialog_open and not paused and snapshot() == expected and lab.camera_overlay.status.text.contains("Ошибка JSON"),"selecting an invalid preset closes the dialog and displays an error without applying changes")
	paused = false
	lab.queue_free()
	await process_frame
	for file_name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+file_name)
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
