extends SceneTree
var checks := 0
var failures := 0
var lab: CoreMovementLab
var hero: CoreMovementPlayer
const ACTIONS := ["core_right","core_sprint","core_jump","core_dash","core_crouch","core_aim","core_fire"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
func settle() -> void:
	release()
	hero.reset_to(Vector2(1500,1000))
	hero.weapon.aim_override = Vector2(4500,968)
	await frames(8)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	# A separate flat floor below the arena isolates time from enemy/wall collisions.
	var floor := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6000,40)
	collision.shape = shape
	collision.position = Vector2(3000,1020)
	floor.add_child(collision)
	root.add_child(floor)
	await settle()
	check(hero.tuning.sprint_duration == 3 and hero.tuning.sprint_recovery_time == 2 and hero.sprint_reserve == 1,"default sprint reserve lasts three seconds and fully recovers in two")
	Input.action_press("core_sprint")
	await frames(15)
	check(hero.sprint_reserve == 1,"Shift without moving does not spend sprint time")
	Input.action_press("core_right")
	var ticks := 0
	while not hero.sprint_exhausted and ticks < 200:
		await physics_frame
		ticks += 1
	check(abs(ticks-180) <= 1 and hero.sprint_exhausted and not hero.sprinting,"holding Shift reaches exhaustion at the configured duration")
	await frames(15)
	check(not hero.sprinting and hero.velocity.x <= 321 and hero.mode == "run","exhaustion returns to ordinary movement even while Shift is held")
	check(lab.telemetry.text.contains("Спринт: восст."),"HUD shows remaining recovery time after exhaustion")
	Input.action_release("core_sprint")
	await frames(1)
	Input.action_press("core_sprint")
	await frames(1)
	check(hero.sprint_exhausted and not hero.sprinting,"re-pressing Shift cannot bypass exhaustion")
	Input.action_release("core_sprint")
	var reserve := hero.sprint_reserve
	await frames(30)
	check(absf(hero.sprint_reserve-reserve-.25) < .02 and hero.sprint_exhausted,"ordinary walking recovers reserve at the configured rate without unlocking early")
	await frames(100)
	check(hero.sprint_reserve == 1 and not hero.sprint_exhausted,"full recovery restores sprint availability")
	Input.action_press("core_sprint")
	await frames(12)
	check(hero.sprinting and hero.velocity.x > 510,"sprint becomes available again after full recovery")
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(30)
	reserve = hero.sprint_reserve
	Input.action_release("core_sprint")
	await frames(1)
	check(hero.sprint_reserve < 1 and hero.sprint_reserve > reserve,"early release starts gradual recovery rather than resetting the timer")
	Input.action_press("core_sprint")
	await frames(1)
	check(hero.sprinting and hero.sprint_reserve < reserve+.01,"short Shift taps reuse only the remaining reserve")
	release()
	await frames(15)
	reserve = hero.sprint_reserve
	paused = true
	await frames(30)
	check(hero.sprint_reserve == reserve,"pause freezes recovery and sprint time")
	paused = false
	await settle()
	hero.tuning.sprint_duration = .6
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(22)
	Input.action_press("core_jump")
	await frames(3)
	var jump_speed := hero.air_move_speed
	await frames(15)
	check(hero.sprint_exhausted and not hero.is_on_floor(),"a sprint jump still spends its remaining time in the air")
	check(is_equal_approx(hero.air_move_speed,jump_speed) and hero.velocity.x > 590,"exhaustion during flight preserves the already launched jump")
	await frames(5)
	check(hero.sprint_reserve == 0,"airborne exhaustion cannot recover reserve before landing")
	await frames(35)
	check(hero.is_on_floor() and not hero.sprinting and hero.velocity.x <= 321,"landing after an exhausted sprint jump uses ordinary movement")
	await settle()
	hero.tuning.sprint_duration = 3
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await frames(30)
	reserve = hero.sprint_reserve
	hero.tuning.set_parameter("sprint_duration",6)
	check(hero.sprint_reserve == reserve and is_equal_approx(hero.sprint_seconds_left(),reserve*6),"editing duration preserves the spent fraction instead of refilling it")
	await frames(12)
	check(absf(hero.sprint_reserve-reserve+.2/6) < .01,"live duration edits change the real depletion rate")
	await settle()
	hero.sprint_reserve = .4
	hero.sprint_exhausted = true
	hero.tuning.sprint_recovery_time = 1
	await frames(12)
	check(absf(hero.sprint_reserve-.6) < .02,"live recovery edits change the real refill rate")
	hero.reset_to(Vector2(1500,1000))
	check(hero.sprint_reserve == 1 and not hero.sprint_exhausted,"respawn restores a full sprint reserve")
	lab.movement_overlay.toggle()
	var overlay := lab.movement_overlay
	overlay.tabs.current_tab = 6
	overlay._sync()
	overlay.rows.sprint_duration.slider.value = 4.5
	overlay.rows.sprint_recovery_time.number.value = 3.2
	check(is_equal_approx(hero.tuning.sprint_duration,4.5) and is_equal_approx(hero.tuning.sprint_recovery_time,3.2),"F3 sliders and exact inputs adjust both timer settings")
	var path := "/private/tmp/sprint-limit-%d.cfg" % OS.get_process_id()
	hero.tuning.save_saved(path)
	var loaded := CoreMovementSettings.new()
	loaded.load_saved(path)
	check(is_equal_approx(loaded.sprint_duration,4.5) and is_equal_approx(loaded.sprint_recovery_time,3.2),"both timer values survive a movement-profile round trip")
	DirAccess.remove_absolute(path)
	var old_profile := ConfigFile.new()
	old_profile.set_value("movement","run_speed",400)
	old_profile.save(path)
	loaded = CoreMovementSettings.new()
	loaded.load_saved(path)
	check(loaded.run_speed == 400 and loaded.sprint_duration == 3 and loaded.sprint_recovery_time == 2,"legacy profiles receive limited-sprint defaults")
	DirAccess.remove_absolute(path)
	hero.tuning.apply_values({"sprint_duration":0,"sprint_recovery_time":-5})
	check(hero.tuning.sprint_duration == .2 and hero.tuning.sprint_recovery_time == .2,"zero or negative durations cannot create infinite sprint or divide by zero")
	overlay.reset_button.pressed.emit()
	check(hero.tuning.sprint_duration == 3 and hero.tuning.sprint_recovery_time == 2,"Reset restores default sprint timing")
	release()
	lab.queue_free()
	floor.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
