extends SceneTree
## Opt-in external runner. No normal game scene loads this script.
var config: Dictionary
var stage: Node
var elapsed := 0.0
var wall_start := 0
var next_sample := 0.0
var decision_at := 0.0
var samples: Array = []
var map_data: Array = []
var last_hp := 100.0
var damage_taken := 0.0
var hits := 0
var kills := 0
var previous_frame: PackedByteArray
var motion := 1.0
var ready_run := false
var status := "running"
var held := {}
var policy: RefCounted
var profile_info := {}
var effective_balance := {}
var controls: Label
var background_mode := false
var saved_window_position := Vector2i(100,100)
var next_control_poll := 0
var jump_release_at := -1.0
var still_since := -1.0
var decision_log: Array = []
var minimized_pause := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--ubertest-config")
	if index<0 or index+1>=args.size():
		quit(2)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[index+1]))
	if not parsed is Dictionary:
		quit(2)
		return
	config = parsed
	call_deferred("setup")

func setup() -> void:
	# Override the game's fullscreen preference for this process only.
	root.mode = Window.MODE_WINDOWED
	root.borderless = false
	root.unresizable = false
	root.size = Vector2i(1280,720)
	root.min_size = Vector2i(800,500)
	root.title = "UBERTEST · симуляция · остановка на панели сверху"
	root.always_on_top = false
	auto_accept_quit = false
	root.close_requested.connect(func(): finish("stopped_by_window"))
	var sources := {"settings_path":CoreMovementSettings.SAVE_PATH,"shooting_settings_path":CoreShootingSettings.SAVE_PATH,"camera_settings_path":CoreCameraSettings.SAVE_PATH,"zombie_settings_path":CoreZombieSettings.SAVE_PATH,"ragdoll_settings_path":CoreRagdollSettings.SAVE_PATH}
	# Copy before loading. Every possible writer sees temporary paths only.
	for key in sources:
		var source: String = sources[key]
		var destination := str(config.output).path_join(key+".cfg")
		var exists := FileAccess.file_exists(source)
		if not exists and FileAccess.file_exists(destination): DirAccess.remove_absolute(destination)
		if exists and DirAccess.copy_absolute(ProjectSettings.globalize_path(source),destination)!=OK:
			push_error("UBERTEST: cannot snapshot "+source)
			quit(4)
			return
		profile_info[key] = {"source":ProjectSettings.globalize_path(source),"snapshot":destination,"saved_profile":exists,"sha256":FileAccess.get_sha256(source) if exists else ""}
	if bool(config.get("inspect_only",false)):
		write_profile_preview()
		quit()
		return
	stage = load("res://scenes/core/polygon_3d.tscn").instantiate()
	if not "load_user_settings" in stage:
		push_error("UBERTEST: game scene failed to load")
		quit(3)
		return
	stage.load_user_settings = true
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
		stage.set(key,str(config.output).path_join(key+".cfg"))
	stage.set_meta("ubertest_virtual_input",true)
	if bool(config.background):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_position(Vector2i(-20000,-20000))
	root.add_child(stage)
	current_scene = stage
	# The 3D combat scene does not load shooting CFG itself; apply its snapshot
	# after catalogue equip and before the first simulation tick.
	if profile_info.shooting_settings_path.saved_profile:
		stage.combat.gun.tuning.load_saved(stage.shooting_settings_path)
	for key in config.get("balance",{}):
		match key:
			"run_speed","jump_speed": stage.player.tuning.set_parameter(key,float(config.balance[key]))
			"damage": stage.combat.gun.tuning.set_parameter(key,float(config.balance[key]))
			"attack_damage": stage.combat.zombie_settings.set_parameter(key,float(config.balance[key]))
	stage.combat.gun.magazine = stage.combat.gun.tuning.magazine_capacity
	stage.combat.gun.reserve = stage.combat.gun.tuning.starting_reserve
	effective_balance = {"run_speed":stage.player.tuning.run_speed,"jump_speed":stage.player.tuning.jump_speed,"damage":stage.combat.gun.tuning.damage,"attack_damage":stage.combat.zombie_settings.attack_damage}
	var policy_path := ProjectSettings.globalize_path("res://").path_join("../UBERTEST/bot_policy.gd").simplify_path()
	var policy_script := GDScript.new()
	policy_script.source_code = FileAccess.get_file_as_string(policy_path)
	if policy_script.reload()!=OK:
		quit(5)
		return
	policy = policy_script.new()
	stage.combat.gun.hit_registered.connect(func(_a,_b,_c): hits+=1)
	stage.combat.gun.target_killed.connect(func(_a): kills+=1)
	# Reporting geometry is not passed to the visual policy.
	for child in stage.geometry.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var p: Vector3 = child.position
			var s: Vector3 = child.mesh.size
			map_data.append([p.x-s.x*.5,p.y-s.y*.5,s.x,s.y])
	Engine.time_scale = clampf(float(config.speed),1,4)
	# Keep physics step at 60 simulation Hz even when time is accelerated.
	Engine.physics_ticks_per_second = int(60*Engine.time_scale)
	wall_start = Time.get_ticks_msec()
	if bool(config.background):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	ready_run = true
	last_hp = stage.player.health
	make_controls()
	set_background(bool(config.background))

func _process(dt: float) -> bool:
	if not ready_run: return false
	if Time.get_ticks_msec()>=next_control_poll:
		next_control_poll = Time.get_ticks_msec()+100
		poll_commands()
	if not ready_run: return false
	if FileAccess.file_exists(str(config.output).path_join("stop")):
		finish("stopped")
		return false
	if not background_mode and root.mode==Window.MODE_MINIMIZED:
		if not paused:
			paused = true
			minimized_pause = true
	elif minimized_pause:
		paused = false
		minimized_pause = false
	if paused: return false
	elapsed += dt
	if jump_release_at>=0 and elapsed>=jump_release_at:
		action("core_jump",false)
		jump_release_at = -1
	if elapsed>=float(config.duration):
		finish("time_limit_without_confirmed_finish")
		return false
	if elapsed>=decision_at and elapsed>1.0:
		decision_at = elapsed+float(config.preset.reaction)
		visual_step()
	if elapsed>=next_sample:
		next_sample = elapsed+.5
		# Observer-only telemetry. Never passed to visual_step().
		var hp: float = stage.player.health
		damage_taken += maxf(0,last_hp-hp)
		last_hp = hp
		samples.append({"t":elapsed,"x":stage.player.position.x,"y":stage.player.position.y,"hp":hp,"motion":motion})
		write_report()
	return false

func action(name: String, down: bool) -> void:
	if bool(held.get(name,false))==down: return
	held[name] = down
	var event := InputEventAction.new()
	event.action = name
	event.pressed = down
	Input.parse_input_event(event)

func mouse_button(index: int, down: bool) -> void:
	var key := "mouse"+str(index)
	if bool(held.get(key,false))==down: return
	held[key] = down
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = down
	event.position = root.size*.5+Vector2(160,0)
	Input.parse_input_event(event)

func visual_step() -> void:
	# Only rendered pixels, time and tactical settings enter the policy.
	var image := root.get_texture().get_image()
	if image==null or image.is_empty():
		finish("render_unavailable")
		return
	image.resize(64,36,Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_L8)
	var frame := image.get_data()
	motion = 0
	if previous_frame.size()==frame.size():
		for i in range(64*10,64*30): motion += absf(float(frame[i])-float(previous_frame[i]))
		motion /= 1280.0*255.0
	else: motion = 1
	previous_frame = frame
	if motion<.002:
		if still_since<0: still_since = elapsed
	else: still_since = -1
	# No confirmed target detector yet: never invent targets or fire blindly.
	var observation := {"blocked":still_since>=0 and elapsed-still_since>1.0,"forward_progress":motion>=.002 and held.get("core_right",false)}
	var decision: Dictionary = policy.decide(observation,config.preset,elapsed)
	for key in ["right","left","up","sprint","walk"]: action("core_"+key,decision[key])
	if decision.jump:
		action("core_jump",true)
		jump_release_at = elapsed+.09
	if decision.aim.is_finite():
		var event := InputEventMouseMotion.new()
		event.position = decision.aim
		Input.parse_input_event(event)
	mouse_button(MOUSE_BUTTON_LEFT,decision.fire)
	mouse_button(MOUSE_BUTTON_RIGHT,decision.ads)
	if decision_log.is_empty() or decision_log[-1].state!=policy.state:
		decision_log.append({"t":elapsed,"state":policy.state})
	controls.text = "%s · %.1f с · %s\nНет подтверждённого распознавания целей: стрельба запрещена" % [config.preset_name,elapsed,policy.state]

func write_report() -> void:
	var report := {"schema":1,"status":status,"preset":config.preset_name,"seed":config.seed,"game_seconds":elapsed,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"speed":Engine.time_scale,"shots":stage.combat.gun.shots_fired,"hits":hits,"kills":kills,"respawns":stage.respawns,"damage_taken":damage_taken,"samples":samples,"map":map_data,"policy":"experimental_frame_motion","confirmed_finish":false}
	report.policy = "tactical_v2_no_unconfirmed_fire"
	report.profiles = profile_info
	report.effective_balance = effective_balance
	report.balance_overrides = config.get("balance",{})
	report.decisions = decision_log
	report.target_detection = "not_implemented"
	var file := FileAccess.open(str(config.output).path_join("report.json.tmp"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	DirAccess.rename_absolute(str(config.output).path_join("report.json.tmp"),str(config.output).path_join("report.json"))

func finish(reason: String) -> void:
	if not ready_run: return
	ready_run = false
	paused = false
	status = reason
	for key in held.keys():
		if str(key).begins_with("mouse"): mouse_button(int(str(key).trim_prefix("mouse")),false)
		else: action(key,false)
	write_report()
	var csv := FileAccess.open(str(config.output).path_join("samples.csv"),FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["simulation_seconds","x_m","y_m","health","visual_motion"]))
	for s in samples: csv.store_csv_line(PackedStringArray([str(s.t),str(s.x),str(s.y),str(s.hp),str(s.motion)]))
	csv.close()
	quit()

func write_profile_preview() -> void:
	var movement = preload("res://resources/core/movement.tres").duplicate(true)
	var shooting = preload("res://resources/core/shooting.tres").duplicate(true)
	var zombies = preload("res://resources/core/zombie.tres").duplicate(true)
	var catalog = preload("res://scripts/campaign/catalog.gd")
	shooting.apply_values(catalog.WEAPONS[catalog.index_for("stg44")].values)
	for pair in [[movement,"settings_path"],[shooting,"shooting_settings_path"],[zombies,"zombie_settings_path"]]:
		if profile_info[pair[1]].saved_profile:
			var error: Error = pair[0].load_saved(profile_info[pair[1]].snapshot)
			if error!=OK:
				push_error("UBERTEST: invalid saved profile "+str(pair[1]))
				quit(6)
				return
	var preview := {"values":{"run_speed":movement.run_speed,"jump_speed":movement.jump_speed,"damage":shooting.damage,"attack_damage":zombies.attack_damage},"profiles":profile_info}
	var file := FileAccess.open(str(config.output).path_join("profile-preview.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(preview,"\t"))
	file.close()

func make_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12,8)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	for entry in [["Остановить и выйти",func(): finish("stopped_by_button")],["Пауза / продолжить",toggle_pause],["В фон",func(): set_background(true)],["Свернуть",func(): root.mode = Window.MODE_MINIMIZED],["Окно / весь экран",toggle_fullscreen]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		row.add_child(button)
	controls = Label.new()
	controls.text = "Подготовка · ваши сохранённые настройки · без случайных действий"
	column.add_child(controls)

func toggle_pause() -> void:
	paused = not paused
	minimized_pause = false
	# Release held keys before pausing; no stuck trigger after resume.
	if paused:
		for key in held.keys():
			if str(key).begins_with("mouse"): mouse_button(int(str(key).trim_prefix("mouse")),false)
			else: action(key,false)

func toggle_fullscreen() -> void:
	root.mode = Window.MODE_WINDOWED if root.mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	if root.mode==Window.MODE_WINDOWED:
		root.borderless = false
		root.unresizable = false

func set_background(enabled: bool) -> void:
	if enabled and not background_mode and root.position.x> -10000: saved_window_position = root.position
	background_mode = enabled
	root.mode = Window.MODE_WINDOWED
	root.borderless = false
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,enabled)
	if enabled: root.position = Vector2i(-20000,-20000)
	else:
		root.position = saved_window_position
		root.grab_focus()
	if minimized_pause:
		paused = false
		minimized_pause = false

func poll_commands() -> void:
	var path := str(config.output).path_join("command.json")
	if not FileAccess.file_exists(path): return
	var command = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	if not command is Dictionary: return
	match command.get("action",""):
		"show": set_background(false)
		"background": set_background(true)
		"pause": toggle_pause()
		"stop": finish("stopped_by_controller")
