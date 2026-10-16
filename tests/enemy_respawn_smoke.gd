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
func mouse_button(pressed: bool,point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	root.push_input(event,true)
	await process_frame
func move_pointer(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event,true)
	await process_frame
func run() -> void:
	root.size = Vector2i(1440,900)
	root.gui_embed_subwindows = true
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	await frames(8)
	var hero := lab.player
	var gun := hero.weapon
	hero.reset_to(Vector2(2320,760))
	gun.aim_override = Vector2(3000,724)
	hero.tuning.run_speed = 450
	lab.camera_settings.zoom = 1.5
	gun.shots_fired = 7
	gun.hits = 4
	gun.kills = 2
	var positions := []
	for target in lab.level.enemies: positions.append(target.position)
	lab.level.enemies[0].take_damage(100)
	lab.level.enemies[1].take_damage(25)
	lab.level.enemies[2].take_damage(100)
	await frames(16)
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.show_section(CoreDeveloperMode.Section.TESTING)
	await process_frame
	await process_frame
	lab.developer_mode.tools_scroll.ensure_control_visible(lab.respawn_enemies_button)
	await frames(4)
	check(lab.respawn_enemies_button.is_visible_in_tree() and lab.respawn_enemies_button.text.begins_with("Возродить врагов"),"developer testing exposes the enemy respawn button in its scroll area")
	paused = true
	var player_position := hero.position
	var bullet := CoreProjectile.new()
	bullet.position = Vector2(2400,728)
	bullet.damage = 100
	bullet.shooter = hero.get_rid()
	hero.get_parent().add_child(bullet)
	bullet.add_to_group("core_projectiles")
	var point := lab.respawn_enemies_button.get_global_rect().get_center()
	await move_pointer(point)
	await mouse_button(true,point)
	await mouse_button(false,point)
	await process_frame
	var all_restored := true
	for target in lab.level.enemies:
		all_restored = all_restored and target.health == 100 and target.collision_layer == 4 and target.death_progress == 0 and target.received_hits == 0 and target.hit_flash == 0 and target.reaction_offset == Vector2.ZERO
	check(all_restored,"a real button click restores dead and damaged enemies, collisions and visual state")
	check(paused and hero.position == player_position and lab.respawns == 0,"enemy respawn works on pause without moving the hero or recording a player recovery")
	check(hero.tuning.run_speed == 450 and lab.camera_settings.zoom == 1.5 and gun.shots_fired == 7 and gun.hits == 4 and gun.kills == 2,"enemy respawn preserves settings and accumulated combat statistics")
	check(not is_instance_valid(bullet) and get_nodes_in_group("core_projectiles").is_empty(),"old projectiles are removed before they can hit restored enemies")
	var unchanged := true
	for i in 3: unchanged = unchanged and lab.level.enemies[i].position == positions[i]
	check(unchanged,"enemies revive at their original test positions")
	paused = false
	Input.action_press("core_fire")
	await frames(4)
	check(gun.shots_fired == 7,"hovering the respawn button blocks shooting")
	lab.respawn_enemies_button.pressed.emit()
	await move_pointer(Vector2(100,400))
	await frames(4)
	check(gun.shots_fired == 7,"dragging away with the UI click held cannot fire after respawn")
	Input.action_release("core_fire")
	await frames(3)
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	check(gun.shots_fired > 7,"a fresh trigger press works after releasing the UI click")
	lab.camera_overlay.toggle()
	var line: LineEdit = lab.camera_overlay.rows.zoom.number.get_line_edit()
	line.grab_focus()
	line.text = "2.25"
	lab.respawn_enemies_button.pressed.emit()
	check(lab.camera_settings.zoom == 2.25 and not lab.camera_overlay.blocks_gameplay_input(),"respawn commits an unfinished settings edit and releases keyboard focus")
	var target := lab.level.enemies[0]
	target.take_damage(100)
	hero.reset_to(target.position)
	await frames(6)
	paused = true
	player_position = hero.position
	lab.respawn_enemies_button.pressed.emit()
	check(target in hero.get_collision_exceptions() and hero.position == player_position,"respawning around the hero grants an exit exception without teleporting the hero")
	paused = false
	await frames(3)
	check(hero.position.distance_to(player_position) < .1,"the restored collider does not push the idle hero out on resume")
	Input.action_press("core_right")
	await frames(18)
	Input.action_release("core_right")
	check(hero.position.x > target.position.x+30 and target not in hero.get_collision_exceptions(),"walking out of the restored enemy removes the temporary exception")
	lab._recover()
	check(hero.position == CoreMovementLevel.SPAWN and lab.level.enemies.all(func(enemy: CoreEnemyDummy) -> bool: return enemy.health == 100),"full R recovery still restores the hero and all enemies")
	gun.shot_audio.stop()
	gun.hit_audio.stop()
	gun.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
