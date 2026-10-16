extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var checks := 0
var failures := 0
var directory := "/private/tmp/zombie-stun-%d" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count:
		await physics_frame
		await process_frame
func release() -> void:
	for action in ["core_left","core_right","core_dash","core_fire","core_reload"]: Input.action_release(action)
func setup(side := 1.0,prone := false) -> void:
	release()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.tuning.movement_enabled = false
	zombie.tuning.combat_enabled = false
	zombie.reset_target()
	if prone: zombie.take_projectile_hit(50,"left_leg")
	zombie.facing = -side
	zombie._sync_zones()
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.reset_to(zombie.home-Vector2(side*50,0))
	hero.set_invulnerable(false)
	hero.weapon.aim_override = zombie.home-Vector2(side*300,38)
	await frames(5)
func dash(side: float) -> void:
	Input.action_press("core_right" if side > 0 else "core_left")
	Input.action_press("core_dash")
	await frames(1)
	for tick in 120:
		if hero.dash_left <= 0: break
		await frames(1)
	release()
func wall_at(position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(5,180)
	shape.shape = rectangle
	wall.add_child(shape)
	lab.level.add_child(wall)
	wall.global_position = position-Vector2(0,90)
	return wall

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	var panel := lab.zombie_overlay
	check(panel.groups.has("Ошеломление") and panel.zombie_toggles.has("stun_enabled") and panel.rows.has("dash_stun_duration"),"developer panel exposes an independent stun switch and duration")
	for side in [-1.0,1.0]:
		for prone in [false,true]:
			await setup(side,prone)
			zombie.tuning.combat_enabled = true
			await frames(2)
			var facing := zombie.facing
			await dash(side)
			check((hero.position.x-zombie.position.x)*side > 0 and zombie.is_stunned() and zombie.stuns_received == 1,"a real dash through standing/crawling zombie applies stun once: %s / %s" % [side,prone])
			check(zombie.state == CoreZombie.State.STUNNED and zombie.facing == facing and zombie.state_left == 0 and zombie.shove_left == 0,"crossing cancels attack and preserves facing")
			hero.reset_to(zombie.home+Vector2(side*40,0))
			await frames(4)
			var anchor := zombie.global_position
			var hp := hero.health
			await frames(35)
			check(zombie.is_stunned() and zombie.global_position.distance_to(anchor) < .5 and zombie.facing == facing and hero.health == hp,"stationary player is safe from turns, movement, melee and shove during stun")
			var enemy_hp := zombie.health
			zombie.take_projectile_hit(3,"torso",Vector2(side,0),hero.global_position)
			check(zombie.health < enemy_hp and zombie.is_stunned() and zombie.facing == facing,"counterattack damages zombie without cancelling stun or turning it")
			await frames(160)
			check(not zombie.is_stunned() and zombie.attacks_landed > 0 and hero.health < hp and zombie.facing == side,"after stun expires the zombie resumes sensing and attacks the stationary player")
	# Repeated applications refresh the remaining interval, never add durations.
	await setup()
	check(zombie.apply_stun(2),"generic API accepts a future gadget/stealth stun without a dash")
	await frames(30)
	var remaining := zombie.stun_left
	zombie.apply_stun(.2)
	check(is_equal_approx(zombie.stun_left,remaining),"a shorter stun cannot shorten or add to an active effect")
	zombie.apply_stun(2)
	check(zombie.stun_left == 2 and zombie.stun_duration == 2,"a fresh equal stun refreshes to its duration without stacking")
	paused = true
	var facing := zombie.facing
	var anchor := zombie.global_position
	await frames(15)
	check(zombie.stun_left == 2 and zombie.facing == facing and zombie.global_position == anchor and not zombie.apply_stun(3),"pause freezes stun and rejects new applications")
	paused = false
	zombie.set_test_frozen(true)
	await frames(15)
	check(zombie.stun_left == 2 and not zombie.apply_stun(3),"enemy freeze also freezes stun and rejects new effects")
	zombie.set_test_frozen(false)
	panel._sync()
	panel.zombie_toggles.stun_enabled.button_pressed = false
	check(not zombie.is_stunned() and zombie.state != CoreZombie.State.STUNNED and not zombie.apply_stun(1) and zombie.tuning.dash_stun_duration == 1.5,"turning off the feature immediately ends stun and preserves its numeric setting")
	await setup()
	zombie.tuning.stun_enabled = false
	await dash(1)
	check(zombie.stuns_received == 0 and not zombie.is_stunned() and hero.position.x > zombie.position.x,"disabled stun leaves ordinary dash-through available")
	await setup()
	zombie.tuning.vision_enabled = false
	zombie.tuning.hearing_enabled = false
	zombie.tuning.damage_reaction_enabled = false
	await dash(1)
	check(zombie.is_stunned() and zombie.stuns_received == 1,"stun works independently of sight, hearing, damage reaction and combat")
	await setup()
	hero.reset_to(zombie.home-Vector2(50,150))
	await frames(1)
	await dash(1)
	check(hero.position.x > zombie.position.x and zombie.stuns_received == 0,"a dash overhead does not stun a body it never touches")
	await setup()
	hero.reset_to(zombie.home-Vector2(120,0))
	var wall := wall_at(zombie.home-Vector2(65,0))
	await frames(3)
	await dash(1)
	check(hero.position.x < zombie.position.x and zombie.stuns_received == 0,"a wall-shortened dash cannot stun an enemy behind the wall")
	wall.queue_free()
	await frames(2)
	await setup()
	hero.tuning.dash_speed = 6000
	hero.tuning.dash_duration = .025
	await dash(1)
	check(hero.position.x > zombie.position.x and zombie.stuns_received == 1,"swept crossing detects an entire enemy passed within one physics tick")
	await setup()
	hero.tuning.dash_speed = 200
	hero.tuning.dash_duration = .1
	await dash(1)
	check(hero.position.x < zombie.position.x and zombie.stuns_received == 0,"a short dash ending before crossing the body does not apply stun")
	await setup()
	Input.action_press("core_right")
	await frames(30)
	release()
	check(zombie.stuns_received == 0,"ordinary running into an enemy cannot apply dash stun")
	await setup()
	var other := CoreZombie.new()
	other.tuning = zombie.tuning.duplicate()
	other.target = hero
	other.position = zombie.home+Vector2(55,0)
	lab.level.add_child(other)
	hero.tuning.dash_duration = .3
	await frames(2)
	await dash(1)
	check(zombie.stuns_received == 1 and other.stuns_received == 1 and zombie.is_stunned() and other.is_stunned(),"one dash can stun each of several actually crossed enemies once")
	hero.reset_to(zombie.home+Vector2(110,0))
	hero.tuning.dash_duration = .3
	var original_remaining := zombie.stun_left
	await dash(-1)
	check(zombie.stuns_received == 2 and other.stuns_received == 2 and zombie.stun_left > original_remaining,"a new reverse dash refreshes stun independently for each enemy")
	other.queue_free()
	await frames(2)
	await setup()
	await dash(1)
	hero.reset_to(zombie.home+Vector2(40,0))
	hero.set_current_health(30)
	hero.weapon.tuning.reload_duration = .5
	hero.weapon.magazine_ammo = 0
	hero.weapon.reserve_ammo = 21
	check(hero.weapon.request_reload(),"the player can start reloading during the granted opening")
	lab.developer_mode.heal_button.pressed.emit()
	await frames(35)
	check(zombie.is_stunned() and hero.weapon.magazine_ammo == 21 and hero.health == 100,"stun leaves the player free to heal and complete a short reload")
	hero.weapon.tuning.reload_duration = 2.4
	await setup()
	zombie.apply_stun(2)
	await frames(20)
	var active_remaining := zombie.stun_left
	panel.rows.dash_stun_duration.number.value = .4
	check(zombie.stun_left == active_remaining,"editing dash duration does not rewrite a currently active stun")
	zombie.reset_target()
	zombie.apply_dash_stun()
	check(is_equal_approx(zombie.stun_left,.4),"the next dash-triggered effect uses the edited duration")
	await setup()
	zombie.set_invulnerable(true)
	await dash(1)
	check(zombie.is_stunned() and zombie.health == 100,"damage immortality does not grant immunity to stun")
	zombie.set_invulnerable(false)
	zombie.take_damage(1000)
	await frames(2)
	check(not zombie.is_stunned() and zombie.state == CoreZombie.State.DEAD and not zombie.apply_stun(1),"death clears stun and dead enemies reject it")
	zombie.reset_target()
	check(zombie.stun_left == 0 and zombie.stuns_received == 0 and zombie.state != CoreZombie.State.STUNNED,"respawn clears stun state and counters")
	await setup()
	for value in [0.0,-1.0,INF,NAN]:
		check(not zombie.apply_stun(value),"invalid stun durations are rejected: "+str(value))
	zombie.apply_stun(2)
	zombie.knock_down(.2,Vector2(50,0))
	await frames(30)
	check(zombie.is_stunned() and zombie.state == CoreZombie.State.STUNNED and not zombie.is_knocked_down(),"finishing a shorter knockdown does not cancel the remaining stun")
	zombie.knock_down(3,Vector2.ZERO)
	await frames(110)
	check(not zombie.is_stunned() and zombie.is_knocked_down() and zombie.state == CoreZombie.State.KNOCKED_DOWN,"finishing stun does not prematurely end a longer knockdown")
	await setup()
	zombie.global_position -= Vector2(0,100)
	zombie.apply_stun(1)
	anchor = zombie.global_position
	await frames(10)
	check(zombie.is_stunned() and zombie.global_position.y > anchor.y+5,"stunned airborne enemies still obey gravity")
	# Real profile/UI/file integration; no writes to the user's settings.
	await setup()
	panel._sync()
	panel.rows.dash_stun_duration.slider.value = 2.8
	panel.zombie_toggles.stun_enabled.button_pressed = false
	check(is_equal_approx(zombie.tuning.dash_stun_duration,2.8) and not zombie.tuning.stun_enabled,"slider and switch edit live stun settings")
	panel.save_profile()
	var loaded := CoreZombieSettings.new()
	check(loaded.load_saved(lab.zombie_settings_path) == OK and not loaded.stun_enabled and is_equal_approx(loaded.dash_stun_duration,2.8),"CFG saves stun switch and duration")
	var preset := directory+"/preset.json"
	check(lab.export_settings_file(preset),"JSON export includes stun settings")
	panel.reset_profile()
	check(zombie.tuning.stun_enabled and zombie.tuning.dash_stun_duration == 1.5,"reset restores enabled stun and default duration")
	check(lab.import_settings_file(preset) and not panel.zombie_toggles.stun_enabled.button_pressed and is_equal_approx(panel.rows.dash_stun_duration.number.value,2.8),"JSON import restores both live controls")
	var old := JSON.parse_string(FileAccess.get_file_as_string(preset)) as Dictionary
	old.zombie.erase("stun_enabled")
	old.zombie.erase("dash_stun_duration")
	var file := FileAccess.open(preset,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	check(lab.import_settings_file(preset) and zombie.tuning.stun_enabled and zombie.tuning.dash_stun_duration == 1.5,"older JSON presets receive stun defaults instead of current edits")
	for path in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory+"/"+path)
	DirAccess.remove_absolute(directory)
	release()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
