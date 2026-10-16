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
	for index in count:
		await physics_frame
		await process_frame
func event(action: String,pressed := true) -> void:
	var input := InputEventAction.new()
	input.action = action
	input.pressed = pressed
	root.push_input(input,true)
func clean() -> void:
	for action in ["core_fire","core_aim","core_right","core_grenade"]: Input.action_release(action)
	lab._recover()
	await frames(8)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.explosion_audio_enabled = false
	lab.ragdoll_settings.explosion_sever_enabled = false
	await frames(12)
	var hero := lab.player
	var gren := hero.grenades
	var profile := lab.ragdoll_settings
	check(InputMap.action_get_events("core_grenade")[0].physical_keycode == KEY_T and InputMap.action_get_events("core_zombie_test")[0].physical_keycode == KEY_F9,"T equips a grenade; zombie test teleport moves to F9")
	var origin := hero.position
	hero.weapon.aim_override = origin+Vector2(600,-150)
	event("core_grenade")
	await frames(2)
	check(gren.preparing() and gren.count == 4 and hero.position.distance_to(origin) < 1,"one T press prepares a finite live grenade without teleporting the player")
	check(gren.trajectory.size() > 3 and gren.held_grenade.freeze and not hero.weapon.firing and not hero.weapon.aiming,"preparation holsters the weapon, holds a real grenade and displays a predicted arc")
	var fuse := gren.held_grenade.fuse_left
	await frames(300)
	check(gren.preparing() and not gren.held_grenade.fuse_started and is_equal_approx(gren.held_grenade.fuse_left,fuse),"preparation can outlast the entire fuse without starting the countdown")
	check(not gren.prepare() and gren.count == 4,"prepare cannot duplicate an already held grenade")
	var put_away := gren.held_grenade
	event("core_grenade")
	await frames(2)
	check(not gren.preparing() and not gren.busy() and gren.count == 5 and gren.trajectory.is_empty() and not is_instance_valid(put_away),"a second T holsters the unarmed grenade, clears its arc and returns it to inventory")
	var before_shots := hero.weapon.shots_fired
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	await frames(2)
	check(hero.weapon.shots_fired > before_shots,"the gun can fire again after holstering the grenade")
	event("core_grenade")
	await frames(2)
	check(gren.preparing() and gren.count == 4 and not gren.held_grenade.fuse_started,"T equips a fresh unarmed grenade after holstering")
	for cycle in 4:
		event("core_grenade")
		await frames(1)
		event("core_grenade")
		await frames(1)
	check(gren.count == 4 and get_nodes_in_group("core_grenades").size() == 1,"repeated equip/holster neither duplicates grenades nor consumes inventory")
	var shots := hero.weapon.shots_fired
	var held := gren.held_grenade
	var weak := gren.launch_velocity().length()
	event("core_fire",true)
	check(held.fuse_started,"LMB starts the fuse immediately, including a click between physics frames")
	event("core_fire",false)
	await frames(2)
	check(not gren.preparing() and gren.throws == 1 and not held.held and not held.freeze,"a quick press/release throws the live grenade")
	check(is_equal_approx(gren.last_launch.velocity.length(),weak) and is_equal_approx(weak,profile.grenade_min_speed),"a quick click uses the weak throw without an implicit full-strength throw")
	check(held.fuse_left < fuse and hero.weapon.shots_fired == shots,"throwing preserves cooked fuse time and cannot also fire the gun")
	await clean()
	Input.action_press("core_fire")
	gren.prepare()
	await frames(3)
	check(not gren.held_grenade.fuse_started,"equipping while LMB is already held waits for a fresh press")
	before_shots = hero.weapon.shots_fired
	event("core_grenade")
	await frames(3)
	check(not gren.preparing() and hero.weapon.shots_fired == before_shots,"holstering with LMB already held does not accidentally fire the gun")
	event("core_grenade")
	await frames(2)
	Input.action_release("core_fire")
	gren.input_trigger(false)
	await frames(3)
	check(not gren.held_grenade.fuse_started and gren.preparing(),"releasing the preexisting press neither arms nor throws the grenade")
	Input.action_press("core_fire")
	gren.input_trigger(true)
	await frames(6)
	fuse = gren.held_grenade.fuse_left
	gren.cancel_charge()
	Input.action_release("core_fire")
	gren.input_trigger(false)
	await frames(6)
	check(gren.held_grenade.fuse_left < fuse-.05,"canceling throw charge does not cancel an activated fuse")
	fuse = gren.held_grenade.fuse_left
	Input.action_press("core_fire")
	gren.input_trigger(true)
	check(is_equal_approx(gren.held_grenade.fuse_left,fuse),"pressing again cannot restart or refill the activated fuse")
	Input.action_release("core_fire")
	gren.input_trigger(false)
	await clean()
	gren.prepare()
	Input.action_press("core_fire")
	gren.input_trigger(true)
	var before_arc := gren.trajectory[-1]
	await frames(36)
	check(gren.power() > .45 and gren.power() < .55 and gren.launch_velocity().length() > weak*3,"holding LMB continuously raises throw strength")
	fuse = gren.held_grenade.fuse_left
	var active := gren.held_grenade
	event("core_grenade")
	await frames(2)
	check(gren.held_grenade == active and gren.charging and gren.count == 4 and active.fuse_left < fuse,"T cannot holster an armed grenade, refund it or reset the burning fuse")
	check(gren.trajectory[-1].distance_to(before_arc) > 50,"predicted landing point updates as charge increases")
	hero.weapon.aim_override = hero.position+Vector2(-600,-150)
	await frames(2)
	check(gren.launch_velocity().x < 0 and gren.trajectory[-1].x < hero.position.x,"the aiming cursor turns the charged trajectory to the other side")
	hero.weapon.aim_override = hero.position+Vector2(0,500)
	await frames(2)
	check(absf(gren.launch_velocity().x) < 1 and gren.launch_velocity().y > 0,"the grenade can be aimed straight down")
	hero.weapon.aim_override = hero.position-Vector2(0,600)
	await frames(2)
	check(absf(gren.launch_velocity().x) < 1 and gren.launch_velocity().y < 0,"the grenade can be aimed straight up")
	await frames(90)
	check(gren.power() == 1 and is_equal_approx(gren.launch_velocity().length(),profile.grenade_max_speed),"charge stops at the configured maximum")
	held = gren.held_grenade
	var cooked := held.fuse_left
	Input.action_release("core_fire")
	gren.input_trigger(false)
	await frames(2)
	check(not gren.preparing() and held.fuse_left < cooked and gren.last_launch.velocity.length() > 1000,"release launches the last preview's direction and strength with the same running fuse")
	await clean()
	profile.grenade_fuse = .5
	gren.prepare()
	Input.action_press("core_fire")
	gren.input_trigger(true)
	await frames(35)
	check(not gren.preparing() and hero.health < 100 and get_nodes_in_group("core_explosions").size() > 0,"an unthrown grenade detonates in the hand and harms its owner")
	await clean()
	hero.set_invulnerable(true)
	gren.prepare()
	Input.action_press("core_fire")
	gren.input_trigger(true)
	await frames(35)
	check(hero.health == 100 and not gren.preparing(),"immortality preserves HP without suppressing in-hand detonation")
	hero.set_invulnerable(false)
	await clean()
	profile.grenade_fuse = 4
	gren.prepare()
	Input.action_press("core_fire")
	gren.input_trigger(true)
	fuse = gren.held_grenade.fuse_left
	paused = true
	event("core_grenade")
	await frames(30)
	check(is_equal_approx(gren.held_grenade.fuse_left,fuse),"pause freezes both the cooking fuse and throw charge")
	paused = false
	profile.grenades_enabled = false
	lab._ragdoll_settings_changed()
	var transform := gren.held_grenade.global_transform
	await frames(20)
	check(is_equal_approx(gren.held_grenade.fuse_left,fuse) and gren.held_grenade.global_transform.is_equal_approx(transform),"the grenade switch pauses a prepared grenade and its fuse")
	profile.grenades_enabled = true
	lab._ragdoll_settings_changed()
	await frames(3)
	check(gren.held_grenade.fuse_left < fuse,"reenabling resumes the same live grenade")
	profile.grenade_trajectory_enabled = false
	await frames(2)
	check(gren.preparing() and gren.trajectory.is_empty(),"trajectory display can be disabled without canceling the live grenade")
	gren.count = 0
	lab._recover()
	await frames(4)
	check(gren.count == 5 and not gren.preparing() and get_nodes_in_group("core_grenades").is_empty(),"F8 clears all live grenades and restores configured inventory")
	gren.count = 0
	check(not gren.prepare(),"an empty inventory cannot create a grenade")
	gren.refill()
	profile.grenades_enabled = false
	check(not gren.prepare(),"a disabled grenade mechanic cannot prepare new grenades")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
