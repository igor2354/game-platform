extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const ACTIONS := ["core_right","core_left","core_walk","core_sprint","core_crouch","core_aim","core_fire","core_jump","core_dash"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle() -> void:
	release()
	hero.reset_to(Vector2(1500,1000))
	hero.weapon.aim_override = Vector2(5500,964)
	await frames(10)
func sample(smoothing: float,gait := "run",rate := 800.0) -> Array:
	await settle()
	hero.tuning.acceleration_smoothing = smoothing
	hero.tuning.acceleration = rate
	hero.tuning.slow_walk_acceleration = rate
	Input.action_press("core_right")
	if gait == "walk": Input.action_press("core_walk")
	if gait == "sprint": Input.action_press("core_sprint")
	if gait == "crouch": Input.action_press("core_crouch")
	var target := 520.0 if gait == "sprint" else 140.0 if gait == "walk" else 144.0 if gait == "crouch" else 320.0
	var values := [0.0]
	for i in 180:
		await physics_frame
		values.append(hero.velocity.x)
		if is_equal_approx(hero.velocity.x,target): break
	return values
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	var floor := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6000,40)
	collision.shape = shape
	collision.position = Vector2(3000,1020)
	floor.add_child(collision)
	root.add_child(floor)
	var linear := await sample(0)
	var smooth := await sample(.35)
	check(is_equal_approx(linear.back(),320) and is_equal_approx(smooth.back(),320) and smooth.size() > linear.size()+12,"smoothing changes the whole acceleration interval and reaches the same cap (%.3f, %.3f; %d / %d ticks)" % [linear.back(),smooth.back(),linear.size(),smooth.size()])
	var increments: Array[float] = []
	var monotonic := true
	for i in range(1,smooth.size()):
		increments.append(smooth[i]-smooth[i-1])
		monotonic = monotonic and smooth[i] >= smooth[i-1] and smooth[i] <= 320
	var peak: float = increments.max()
	check(monotonic and increments[2] < peak*.4 and increments[-2] < peak*.4,"speed rises monotonically with gentle acceleration at both ends")
	check(increments[6] > increments[2] and increments[-4] < peak,"acceleration ramps up and tapers near maximum rather than merely delaying input")
	var softer := await sample(.8)
	var faster := await sample(.35,"run",1600)
	check(softer.size() > smooth.size() and faster.size() < smooth.size(),"smoothing and acceleration tempo are independent controls")
	for gait in ["walk","sprint","crouch"]:
		var old := await sample(0,gait)
		var soft := await sample(.35,gait)
		check(soft.size() > old.size() and is_equal_approx(soft.back(),old.back()),"common smoothing applies to "+gait)
	await settle()
	hero.tuning.acceleration = 2400
	hero.tuning.acceleration_smoothing = .4
	Input.action_press("core_right")
	Input.action_press("core_fire")
	await frames(90)
	check(absf(hero.velocity.x-208) < 1 and hero.weapon.shots_fired > 0,"continuous changing firing slowdown does not restart or stall the ramp")
	Input.action_press("core_aim")
	await frames(60)
	check(absf(hero.velocity.x-96) < 1,"smooth target changes still reach the aimed speed cap")
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	Input.action_release("core_right")
	await frames(15)
	check(hero.velocity.x == 0 and hero.ground_acceleration == 0,"release uses the configured braking and clears acceleration memory")
	Input.action_press("core_left")
	await frames(60)
	check(absf(hero.velocity.x+224) < 1,"smooth reversal reaches backward movement's reduced cap")
	Input.action_press("core_jump")
	await frames(3)
	check(hero.ground_acceleration == 0 and hero.air_move_speed == 224,"jump preserves takeoff speed and clears ground acceleration")
	await settle()
	Input.action_press("core_right")
	await frames(8)
	Input.action_press("core_dash")
	await frames(4)
	check(hero.dash_left > 0 and hero.ground_acceleration == 0 and absf(hero.velocity.length()-760) < 6,"dash keeps its independent instant impulse (left %.3f, accel %.3f, speed %.3f)" % [hero.dash_left,hero.ground_acceleration,hero.velocity.x])
	await settle()
	var overlay := lab.movement_overlay
	overlay.toggle()
	overlay.tabs.current_tab = overlay.groups.find("Разгон")
	check(overlay.tabs.get_tab_title(overlay.groups.find("Разгон")) == "Разгон" and overlay.acceleration_preview != null,"F3 provides the smoothing slider and live speed graph")
	overlay.rows.acceleration_smoothing.slider.value = .5
	check(hero.tuning.acceleration_smoothing == .5 and overlay.rows.acceleration_smoothing.number.value == .5 and overlay.readout.text.contains("Разгон с места"),"slider synchronizes exact input, player and graph readout")
	var frozen := hero.position
	paused = true
	overlay.rows.acceleration_smoothing.number.value = .25
	await frames(4)
	check(hero.position == frozen and hero.tuning.acceleration_smoothing == .25,"the curve remains editable while movement is paused")
	paused = false
	var path := "/private/tmp/acceleration-profile-%d.cfg" % OS.get_process_id()
	var loaded := CoreMovementSettings.new()
	check(hero.tuning.save_saved(path) == OK and loaded.load_saved(path) == OK and is_equal_approx(loaded.acceleration_smoothing,.25),"smoothing persists in the movement profile")
	DirAccess.remove_absolute(path)
	overlay.reset_button.pressed.emit()
	check(hero.tuning.acceleration_smoothing == .15,"Reset restores the soft default")
	# Frame-rate invariance of the speed envelope, not scene rendering timing.
	var times: Array[float] = []
	for fps in [30,60,120]:
		var state := Vector2.ZERO
		var ticks := 0
		while state.x < 320 and ticks < 300:
			state = hero.tuning.acceleration_step(state.x,320,state.y,800,1.0/fps)
			ticks += 1
		times.append(float(ticks)/fps)
	check(times.max()-times.min() < .08,"the full ramp duration remains stable at 30, 60 and 120 Hz")
	release()
	hero.reset_to(Vector2(1500,1000))
	check(hero.ground_acceleration == 0,"restart clears acceleration state")
	hero.weapon.reset_state()
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await frames(20)
	lab.queue_free()
	floor.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
