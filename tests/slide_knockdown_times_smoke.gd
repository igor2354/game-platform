extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var hero := lab.player
	var human := lab.level.enemies[0]
	var zombie := lab.level.zombie
	hero.set_physics_process(false)
	await frames(8)
	var settings := hero.tuning
	var overlay := lab.movement_overlay
	check(settings.slide_knockdown_duration == 1.5 and settings.slide_zombie_knockdown_duration == 3,"zombies stay down longer by default")
	overlay.toggle()
	overlay.tabs.current_tab = overlay.groups.find("Подкат")
	check(is_equal_approx(overlay.rows.slide_knockdown_duration.number.value,1.5) and is_equal_approx(overlay.rows.slide_zombie_knockdown_duration.number.value,3),"F3 exposes both ground-time controls in the combined slide tab")
	overlay.rows.slide_knockdown_duration.slider.value = .4
	overlay.rows.slide_zombie_knockdown_duration.number.value = 1
	check(is_equal_approx(settings.slide_knockdown_duration,.4) and settings.slide_zombie_knockdown_duration == 1 and overlay.readout.text.contains("человек 0.4 с · зомби 1.0 с"),"both controls update independently and show both times")
	overlay.toggle()
	hero.slide_direction = 1
	hero._slide_impact(human,800)
	hero._slide_impact(zombie,800)
	check(is_equal_approx(human.knockdown_left,.4) and zombie.knockdown_left == 1 and zombie.state == CoreZombie.State.KNOCKED_DOWN,"slide impact selects the duration for each enemy type")
	settings.slide_knockdown_duration = 1.2
	settings.slide_zombie_knockdown_duration = .3
	await frames(30)
	check(not human.is_knocked_down() and zombie.is_knocked_down(),"the human gets up first; editing settings does not shorten an active zombie timer")
	await frames(35)
	check(not zombie.is_knocked_down() and not zombie.is_prone(),"the zombie gets up after its captured timer expires")
	hero.slide_hit_enemies.clear()
	hero._slide_impact(human,800)
	hero._slide_impact(zombie,800)
	check(is_equal_approx(human.knockdown_left,1.2) and is_equal_approx(zombie.knockdown_left,.3),"next impacts use the edited independent durations")
	await frames(25)
	check(human.is_knocked_down() and not zombie.is_knocked_down(),"independent custom values can make the zombie recover before the human")
	await frames(55)
	zombie.take_projectile_hit(50,"left_leg")
	hero.slide_hit_enemies.clear()
	hero._slide_impact(zombie,800)
	await frames(25)
	check(not zombie.is_knocked_down() and zombie.is_prone() and not zombie.has_part("left_leg"),"recovery does not restore a missing leg")
	var path := "/private/tmp/slide-times-%d.cfg" % OS.get_process_id()
	var loaded := CoreMovementSettings.new()
	check(settings.save_saved(path) == OK and loaded.load_saved(path) == OK and is_equal_approx(loaded.slide_knockdown_duration,1.2) and is_equal_approx(loaded.slide_zombie_knockdown_duration,.3),"both timers round-trip through the movement profile")
	var legacy := ConfigFile.new()
	legacy.set_value("movement","slide_knockdown_duration",1.1)
	legacy.save(path)
	loaded = CoreMovementSettings.new()
	check(loaded.load_saved(path) == OK and is_equal_approx(loaded.slide_knockdown_duration,1.1) and loaded.slide_zombie_knockdown_duration == 3,"legacy profiles keep their human value and default zombie timing")
	DirAccess.remove_absolute(path)
	overlay.reset_button.pressed.emit()
	check(settings.slide_knockdown_duration == 1.5 and settings.slide_zombie_knockdown_duration == 3 and is_equal_approx(overlay.rows.slide_zombie_knockdown_duration.slider.value,3),"Reset restores both defaults and refreshes the new control")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
