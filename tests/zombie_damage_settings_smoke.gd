extends SceneTree

var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
var overlay: CoreMovementOverlay
var checks := 0
var failures := 0
var path := "/private/tmp/zombie-damage-settings-%d.cfg" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for tick in count: await physics_frame
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func rest(prone := false) -> void:
	zombie.reset_target()
	zombie.tuning.hearing_range = 0
	zombie.tuning.detection_range = 32
	zombie.tuning.forget_range = 32
	if prone: zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.WAIT
	zombie.facing = -1
	hero.reset_to(zombie.home+Vector2(120,0))
	await frames(4)
	overlay._sync()
func hit() -> void:
	zombie.take_projectile_hit(10,"torso",Vector2.LEFT,hero.weapon.pivot())

func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.zombie_settings_path = path
	root.add_child(lab)
	zombie = lab.level.zombie
	hero = lab.player
	overlay = lab.zombie_overlay
	await frames(8)
	overlay.toggle()
	overlay.tabs.current_tab = 6
	check(overlay.tabs.get_tab_title(6) == "Попадания" and overlay.damage_reaction_toggle.button_pressed and is_equal_approx(overlay.rows.damage_memory_time.number.value,1.5) and is_equal_approx(overlay.rows.damage_chase_multiplier.slider.value,1),"the damage tab exposes the default toggle, memory and speed multiplier")
	overlay.damage_reaction_toggle.button_pressed = false
	await rest()
	hit()
	check(zombie.health == 90 and zombie.state == CoreZombie.State.WAIT and not zombie.damage_pursuit,"disabling the reaction still applies damage without waking an unaware zombie")
	overlay.rows.detection_range.slider.value = 360
	hero.reset_to(zombie.home+Vector2(-120,0))
	await frames(4)
	check(zombie.state == CoreZombie.State.CHASE,"disabling damage reaction leaves normal visual detection active")
	await rest()
	zombie.tuning.hearing_range = 180
	zombie.hear_noise(hero.weapon.pivot(),1)
	check(zombie.state == CoreZombie.State.INVESTIGATE,"disabling damage reaction leaves hearing active")
	overlay.damage_reaction_toggle.button_pressed = true
	await rest()
	overlay.rows.damage_memory_time.number.value = 2.5
	overlay.rows.damage_chase_multiplier.slider.value = 1.5
	hit()
	check(zombie.damage_pursuit and is_equal_approx(zombie.unseen_left,2.5) and is_equal_approx(overlay.rows.damage_memory_time.slider.value,2.5),"new damage uses the edited independent memory duration")
	await frames(8)
	check(is_equal_approx(zombie.velocity.x,157.5),"the multiplier changes actual standing approach speed")
	zombie.tuning.lose_sight_delay = .1
	zombie.apply_tuning()
	check(zombie.unseen_left > 2,"editing visual memory does not shorten active damage memory")
	paused = true
	var position := zombie.position
	overlay.rows.damage_memory_time.slider.value = .3
	check(is_equal_approx(zombie.unseen_left,.3),"shortening damage memory clamps the active search immediately")
	var memory := zombie.unseen_left
	await frames(6)
	check(zombie.position == position and zombie.unseen_left == memory,"pause freezes approach and damage memory")
	overlay.rows.damage_chase_multiplier.number.value = 2
	paused = false
	await frames(2)
	check(is_equal_approx(zombie.velocity.x,210),"a speed edit on pause takes effect when movement resumes")
	paused = true
	overlay.damage_reaction_toggle.button_pressed = false
	check(not zombie.damage_pursuit and zombie.state == CoreZombie.State.RETURN and zombie.health == 90,"disabling the reaction cancels an active unseen damage search without healing")
	overlay.save_button.pressed.emit()
	var saved := CoreZombieSettings.new()
	check(saved.load_saved(path) == OK and not saved.damage_reaction_enabled and saved.damage_memory_time == .3 and saved.damage_chase_multiplier == 2,"Save persists the toggle and both numeric settings")
	var old := ConfigFile.new()
	old.load(path)
	for key in ["damage_reaction_enabled","damage_memory_time","damage_chase_multiplier"]: old.erase_section_key("zombie",key)
	old.save(path+"-legacy")
	var legacy := CoreZombieSettings.new()
	check(legacy.load_saved(path+"-legacy") == OK and legacy.damage_reaction_enabled and legacy.damage_memory_time == 1.5 and legacy.damage_chase_multiplier == 1,"old local profiles load with the new project defaults")
	overlay.reset_button.pressed.emit()
	check(overlay.damage_reaction_toggle.button_pressed and is_equal_approx(overlay.rows.damage_memory_time.number.value,1.5) and is_equal_approx(overlay.rows.damage_chase_multiplier.slider.value,1),"Reset restores all three controls")
	overlay.load_button.pressed.emit()
	check(not overlay.damage_reaction_toggle.button_pressed and is_equal_approx(overlay.rows.damage_memory_time.number.value,.3) and is_equal_approx(overlay.rows.damage_chase_multiplier.slider.value,2),"Load restores the saved toggle and numeric controls")
	overlay.reset_button.pressed.emit()
	paused = false
	await rest(true)
	overlay.rows.damage_memory_time.number.value = 2
	overlay.rows.damage_chase_multiplier.slider.value = 2
	hit()
	await frames(8)
	check(zombie.damage_pursuit and is_equal_approx(zombie.velocity.x,44),"damage approach multiplier also applies to actual crawling")
	overlay.rows.detection_range.number.value = 360
	await frames(4)
	check(zombie.state == CoreZombie.State.CHASE and not zombie.damage_pursuit and is_equal_approx(zombie.velocity.x,22),"seeing the player ends source search and restores ordinary crawl speed")
	zombie.tuning.apply_values({"damage_memory_time":-1,"damage_chase_multiplier":9,"damage_reaction_enabled":0})
	check(zombie.tuning.damage_memory_time == .1 and zombie.tuning.damage_chase_multiplier == 3 and zombie.tuning.damage_reaction_enabled,"numeric bounds are enforced and an invalid toggle type is ignored")
	zombie.tuning.apply_values({"damage_memory_time":NAN,"damage_chase_multiplier":INF})
	check(zombie.tuning.damage_memory_time == .1 and zombie.tuning.damage_chase_multiplier == 3,"non-finite reaction settings are ignored")
	var defaults := load("res://resources/core/zombie.tres") as CoreZombieSettings
	check(defaults.damage_reaction_enabled and defaults.damage_memory_time == 1.5 and defaults.damage_chase_multiplier == 1,"runtime edits preserve the source resource")
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+"-legacy")
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
