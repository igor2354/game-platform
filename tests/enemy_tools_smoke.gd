extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var directory := "/private/tmp/enemy-tools-%d" % OS.get_process_id()
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
func choose(index: int) -> void:
	var tools := lab.developer_mode.enemy_tools
	tools.target_choice.select(index)
	tools.target_choice.item_selected.emit(index)
func snapshot(enemy: CoreEnemyDummy) -> Array:
	var result := [enemy.global_transform,enemy.velocity,enemy.idle_clock,enemy.death_progress,enemy.reaction_offset,enemy.knockdown_left,enemy.detached_parts.duplicate(true)]
	if enemy is CoreZombie:
		result.append_array([enemy.state,enemy.state_left,enemy.walk_phase,enemy.unseen_left,enemy.noise_memory_left,enemy.shove_left,enemy.shove_cooldown_left,enemy.attacks_started,enemy.shoves_landed,enemy.facing])
	return result
func zones_aligned(enemy: CoreEnemyDummy) -> bool:
	for part in CoreEnemyDummy.PARTS:
		if not enemy.has_part(part) or enemy.health <= 0: continue
		var shape := enemy.hit_zones[part].get_child(0) as CollisionShape2D
		var rect := enemy.part_rect(part)
		if shape.position.distance_to(rect.get_center()+enemy.reaction_offset) > .001 or (shape.shape as RectangleShape2D).size != rect.size: return false
	return true
func new_lab() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/ragdoll.cfg"
	root.add_child(lab)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1440,900)
	root.gui_embed_subwindows = true
	new_lab()
	await frames(8)
	var enemies := lab.level.enemies
	var hero := lab.player
	var zombie := lab.level.zombie
	var dev := lab.developer_mode
	var tools := dev.enemy_tools
	check(enemies.size() == 7 and enemies.all(func(enemy): return enemy.health == 100 and enemy.maximum_health() == 100 and not enemy.invulnerable and not enemy.test_frozen),"all seven opponents start with ordinary health and active simulation")
	dev.set_enabled(true)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	check(tools.is_visible_in_tree() and tools.target_choice.item_count == enemies.size()+1,"testing includes global controls and a selector for each enemy")
	tools.health_slider.value = 37.5
	check(enemies.all(func(enemy): return enemy.health == 37.5),"global current HP slider assigns all opponents")
	tools.maximum_number.value = 300
	check(enemies.all(func(enemy): return enemy.maximum_health() == 300 and enemy.health == 37.5),"increasing enemy maximum does not automatically heal")
	tools.heal_button.pressed.emit()
	check(enemies.all(func(enemy): return enemy.health == 300),"global healing fills the configured enemy maxima")
	choose(2)
	tools.maximum_slider.value = 125
	tools.health_number.value = 41.25
	check(enemies[1].health == 41.25 and enemies[1].maximum_health() == 125 and enemies[0].health == 300 and zombie.health == 300,"exact HP and maximum editing can target one enemy")
	enemies[1].take_damage(10)
	await frames(2)
	check(tools.health_number.value == 31.25 and tools.health_slider.value == 31.25,"tools track incoming combat damage")
	choose(0)
	check(tools.health_number.value == 31.25 and tools.readout.text.contains("31.25–300.00"),"mixed group health is displayed without silently changing other enemies")
	tools.invulnerable_toggle.button_pressed = true
	var hp := enemies.map(func(enemy): return enemy.health)
	for enemy in enemies: enemy.take_damage(10000)
	check(enemies.map(func(enemy): return enemy.health) == hp and enemies.all(func(enemy): return enemy.invulnerable),"global immortality blocks lethal generic damage for every enemy")
	zombie.take_projectile_hit(50,"left_leg",Vector2.RIGHT,hero.global_position)
	check(zombie.health == 300 and zombie.is_prone() and not zombie.has_part("left_leg") and zombie.received_hits > 0,"immortality retains hit reactions and anatomical severing")
	choose(4)
	var position := zombie.global_position
	var hits := zombie.received_hits
	tools.health_number.value = 0
	check(zombie.health == 0 and zombie.state == CoreZombie.State.DEAD and zombie.collision_layer == 0,"manual zero HP can deliberately kill an immortal zombie")
	tools.health_number.value = 72.25
	check(zombie.health == 72.25 and zombie.state == CoreZombie.State.WAIT and zombie.collision_layer == 4 and zombie.is_prone() and zombie.global_position == position and zombie.received_hits == hits,"positive manual HP revives in place without restoring limbs or clearing hit statistics")
	tools.maximum_number.value = 55
	check(zombie.health == 55 and zombie.maximum_health() == 55 and tools.health_number.value == 55,"reducing the maximum clamps current HP immediately")
	zombie.set_current_health(NAN)
	zombie.set_maximum_health(INF)
	check(zombie.health == 55 and zombie.maximum_health() == 55,"invalid enemy health values are ignored")
	zombie.set_current_health(-10)
	zombie.set_current_health(10000)
	check(zombie.health == 55,"enemy HP edits clamp to the valid range")
	# Freeze active combat, knockdown, gravity and detached limb simulation.
	zombie.reset_target()
	zombie.facing = 1
	zombie.tuning.apply_values({"attack_windup":1,"attack_recovery":1})
	hero.reset_to(zombie.home+Vector2(35,0))
	hero.set_invulnerable(true)
	await frames(5)
	check(zombie.state == CoreZombie.State.WINDUP,"fixture starts a real melee windup")
	enemies[0].knock_down(2,Vector2(180,-50))
	enemies[2].take_projectile_hit(50,"left_arm")
	tools.freeze_toggle.button_pressed = true
	var held := enemies.map(snapshot)
	dev.set_enabled(false)
	await frames(80)
	check(enemies.map(snapshot) == held and not paused,"freeze stops AI, attack timers, knockdown and detached parts without pausing the world")
	check(not zombie.hear_noise(zombie.home,1,"shot"),"a frozen zombie does not turn or change AI state on sound")
	zombie.take_projectile_hit(1,"torso",Vector2.LEFT,hero.global_position)
	check(zombie.state == CoreZombie.State.WINDUP and zombie.facing == 1,"frozen damage feedback cannot turn or restart its committed attack")
	zombie.global_position.y -= 120
	var airborne_position := zombie.global_position
	await frames(8)
	check(zombie.global_position == airborne_position,"a frozen airborne zombie does not fall under gravity")
	# Real bullets and hero movement still run while opponents remain frozen.
	hero.reset_to(Vector2(2330,760))
	hero.weapon.aim_override = enemies[0].aim_point_for_part("torso")
	await frames(3)
	Input.action_press("core_right")
	Input.action_press("core_fire")
	var starting_x := hero.position.x
	var hits_before := enemies[0].received_hits
	await frames(18)
	Input.action_release("core_right")
	Input.action_release("core_fire")
	check(hero.position.x > starting_x+20 and hero.weapon.shots_fired > 0,"player movement and gunfire continue with the developer window closed")
	check(enemies[0].received_hits > hits_before and enemies[0].health == enemies[0].maximum_health(),"real bullets hit a frozen immortal opponent without reducing its HP")
	check(enemies[0].global_transform == held[0][0],"impacts do not move the frozen enemy body")
	dev.set_enabled(true)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	tools.freeze_toggle.button_pressed = false
	hero.reset_to(CoreMovementLevel.SPAWN)
	await frames(12)
	check(zombie.state_left < held[3][8] and enemies[0].knockdown_left < held[0][5],"unfreezing resumes suspended combat and knockdown timers")
	check(zombie.global_position.y > airborne_position.y+10,"unfreezing also resumes the suspended fall")
	zombie.global_position.y = CoreMovementLevel.FALL_LIMIT+5
	await frames(2)
	check(zombie.health == 55 and zombie.state != CoreZombie.State.DEAD and zombie.global_position.distance_to(zombie.home) < 5,"an immortal zombie remains alive and returns home after falling outside the arena")
	tools.invulnerable_toggle.button_pressed = false
	var zombie_hp := zombie.health
	zombie.take_damage(5)
	check(zombie.health == zombie_hp-5 and enemies.all(func(enemy): return not enemy.invulnerable),"disabling global immortality restores normal damage")
	# Pause, exact input, target changes and hotkeys use the existing input gate.
	paused = true
	tools.freeze_toggle.button_pressed = true
	choose(1)
	var line := tools.health_number.get_line_edit()
	line.grab_focus()
	await process_frame
	line.text = "46.5"
	check(lab._blocks_keyboard(),"enemy HP numeric input blocks gameplay keys")
	choose(2)
	check(enemies[0].health == 46.5 and enemies[1].health == 31.25 and not lab._blocks_keyboard(),"switching target commits an unfinished edit to the original enemy")
	line = tools.maximum_number.get_line_edit()
	line.grab_focus()
	await process_frame
	line.text = "220"
	check(lab._blocks_keyboard(),"enemy maximum HP input also blocks gameplay")
	dev.set_enabled(false)
	check(enemies[1].maximum_health() == 220 and paused and not lab._blocks_keyboard(),"closing the window commits the maximum without resuming the world")
	dev.set_enabled(true)
	dev.show_section(CoreDeveloperMode.Section.TESTING)
	choose(0)
	tools.health_number.value = 0
	tools.invulnerable_toggle.button_pressed = true
	check(enemies.all(func(enemy): return enemy.invulnerable and enemy.health == enemy.maximum_health()),"enabling immortality revives all defeated targets on pause")
	var maxima := enemies.map(func(enemy): return enemy.maximum_health())
	lab._respawn_enemies()
	await frames(2)
	check(enemies.all(func(enemy): return enemy.invulnerable and enemy.test_frozen and enemy.missing_parts.is_empty() and enemy.health == enemy.maximum_health()) and enemies.map(func(enemy): return enemy.maximum_health()) == maxima,"F7 respawn restores anatomy while preserving session freeze, immortality and maximum HP")
	check(enemies.all(zones_aligned),"frozen respawn immediately aligns all body-part zones without a physics tick")
	lab._recover()
	check(enemies.all(func(enemy): return enemy.invulnerable and enemy.test_frozen),"level reset also preserves the active session test controls")
	dev.save_all()
	lab.export_settings_file(directory+"/balance.json")
	var exported: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/balance.json"))
	check(not exported.has("enemies") and not exported.has("enemy_tools") and not exported.zombie.has("invulnerable") and not exported.zombie.has("test_frozen") and not exported.zombie.has("max_health"),"session enemy cheats do not enter the balance JSON")
	paused = false
	lab.queue_free()
	await frames(2)
	new_lab()
	await frames(8)
	check(lab.level.enemies.all(func(enemy): return enemy.health == 100 and enemy.maximum_health() == 100 and not enemy.invulnerable and not enemy.test_frozen),"a new game starts without enemy test cheats")
	for enemy in lab.level.enemies:
		enemy.set_test_frozen(true)
		enemy.set_current_health(0)
		enemy.set_current_health(20)
	check(lab.level.enemies.all(func(enemy): return enemy.collision_layer == 4 and enemy.hit_zones.head.collision_layer == CoreEnemyDummy.HIT_LAYER),"manual revival restores the physical body and anatomical hit zones for every enemy")
	check(lab.level.enemies.all(zones_aligned),"manual revival of frozen enemies also aligns their arms with the revived pose")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
