extends SceneTree

var lab: CoreMovementLab
var target: CoreEnemyDummy
var checks := 0
var failures := 0
var impacts: Array[Dictionary] = []
var profile_path := "/private/tmp/enemy-damage-%d.cfg" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func reset_target() -> void:
	target.reset_target()
	await frames(2)
func shoot(part: String,amount := 25.0) -> void:
	var point := target.aim_point_for_part(part)
	var direction := Vector2.LEFT if part.begins_with("right") or (part == "head" and target.is_prone()) else Vector2.RIGHT
	var bullet := CoreProjectile.new()
	bullet.direction = direction
	bullet.damage = amount
	bullet.speed = 4000
	bullet.position = point-direction*60
	bullet.shooter = lab.player.get_rid()
	bullet.impact_callback = func(_point: Vector2,hit: bool,killed: bool,_direction: Vector2): impacts.append({"hit":hit,"killed":killed})
	lab.get_node("World").add_child(bullet)
	bullet.add_to_group("core_projectiles")
	await frames(3)
func ray(from: Vector2,to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from,to,CoreProjectile.BULLET_MASK,[lab.player.get_rid()])
	query.collide_with_areas = true
	query.hit_from_inside = true
	return lab.player.get_world_2d().direct_space_state.intersect_ray(query)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.shooting_settings_path = profile_path
	root.add_child(lab)
	target = lab.level.enemies[0]
	await frames(8)
	check(target.hit_zones.size() == 6 and target.hit_zones.values().all(func(zone: Area2D): return zone.collision_layer == 16),"enemies expose six independent ray-hit regions")
	check(not lab.player.get_collision_mask_value(5) and target.collision_layer == 4,"movement and anatomical hit detection use separate collision layers")
	var expected := {"head":50.0,"torso":75.0,"left_arm":93.75,"right_arm":93.75,"left_leg":91.25,"right_leg":91.25}
	for part in CoreEnemyDummy.PARTS:
		await reset_target()
		var count := impacts.size()
		await shoot(part)
		check(target.last_hit_part == part and is_equal_approx(target.health,expected[part]) and target.received_hits == 1 and impacts.size() == count+1 and impacts[-1].hit and not impacts[-1].killed,"a swept projectile detects "+part+" and applies the correct health multiplier (%.2f HP)" % target.health)
	for index in [1,2]:
		target = lab.level.enemies[index]
		for part in CoreEnemyDummy.PARTS:
			await reset_target()
			await shoot(part)
			check(target.last_hit_part == part and is_equal_approx(target.health,expected[part]),"scaled enemy %s has a working %s hit region" % [target.identifier,part])
	target = lab.level.enemies[0]
	await reset_target()
	await shoot("left_arm")
	check(target.limb_health("left_arm") == 25 and target.limb_health("right_arm") == 50 and target.has_part("left_arm"),"limb durability is independent between the two arms")
	await shoot("left_arm")
	check(not target.has_part("left_arm") and target.health == 87.5 and target.detached_parts.size() == 1 and target.hit_zones.left_arm.collision_layer == 0 and not impacts[-1].killed,"two hits detach an arm without killing the enemy or awarding a kill")
	var previous := target.health
	check(not target.take_projectile_hit(25,"left_arm") and target.health == previous and target.detached_parts.size() == 1,"an absent limb cannot be damaged or detached again")
	await frames(12)
	var old_rect := target.part_rect("left_arm")
	var y := target.position.y+old_rect.get_center().y
	check(ray(Vector2(target.position.x-60,y),Vector2(target.position.x-10,y)).is_empty(),"bullets pass through the former arm region rather than an invisible enemy rectangle")
	var bullet := CoreProjectile.new()
	bullet.position = Vector2(target.position.x-60,y)
	bullet.direction = Vector2.RIGHT
	bullet.shooter = lab.player.get_rid()
	lab.get_node("World").add_child(bullet)
	await frames(3)
	check(target.last_hit_part == "torso" and target.health == previous-25,"a bullet through a missing arm can hit the torso behind it")
	await reset_target()
	for part in ["right_arm","left_arm","right_leg","left_leg"]:
		await shoot(part)
		await shoot(part)
		check(not target.has_part(part) and target.health > 0 and target.collision_layer == 4,"the enemy remains alive after losing "+part)
	check(target.health == 40 and target.missing_parts.size() == 4 and target.is_prone() and target.detached_parts.size() == 4,"all four limbs can be removed while leaving 40 HP and a prone survivor")
	check((target.body_shape.shape as RectangleShape2D).size.y == 24 and target.hit_zones.head.collision_layer == 16 and target.hit_zones.torso.collision_layer == 16,"the prone posture has a lower physical collider and active head/torso hitboxes")
	var head_hit := ray(target.aim_point_for_part("head")+Vector2(60,0),target.aim_point_for_part("head"))
	check(not head_hit.is_empty() and head_hit.collider == target.hit_zones.head,"the new prone head position can be targeted")
	var pieces := target.detached_parts.duplicate(true)
	var health := target.health
	paused = true
	await frames(8)
	check(target.detached_parts == pieces and target.health == health,"pause freezes detached body parts and the surviving enemy")
	paused = false
	await frames(70)
	check(target.detached_parts.all(func(piece: Dictionary): return piece.settled) and target.health == 40,"detached pieces land on world geometry without damaging their owner")
	await shoot("head")
	check(target.health == 0 and impacts[-1].killed and target.collision_layer == 0 and target.hit_zones.values().all(func(zone: Area2D): return zone.collision_layer == 0),"the limbless survivor can still be killed; all hitboxes then deactivate")
	lab.respawn_enemies_button.pressed.emit()
	await frames(3)
	check(target.health == 100 and target.missing_parts.is_empty() and target.detached_parts.is_empty() and target.limb_damage.is_empty() and not target.is_prone() and target.hit_zones.values().all(func(zone: Area2D): return zone.collision_layer == 16),"enemy respawn restores every limb, health, hitbox and posture and clears detached pieces")
	check((target.body_shape.shape as RectangleShape2D).size == Vector2(32,64),"respawn restores the standing movement collider")
	lab.player.reset_to(Vector2(2424,760))
	await frames(8)
	var standing_position := lab.player.position
	target.take_projectile_hit(50,"left_leg")
	target.take_projectile_hit(50,"right_leg")
	check(target in lab.player.get_collision_exceptions(),"a widened prone collider allows an already overlapping player to exit safely")
	await frames(3)
	check(lab.player.position.distance_to(standing_position) < .1,"changing to the prone posture does not push a nearby idle player")
	Input.action_press("core_left")
	await frames(14)
	Input.action_release("core_left")
	check(target not in lab.player.get_collision_exceptions(),"the posture-change exit exception clears after leaving the body")
	lab.player.reset_to(Vector2(160,760))
	await reset_target()
	await shoot("head")
	await shoot("head")
	check(target.health == 0 and impacts[-1].killed and target.missing_parts.is_empty(),"two headshots kill a standing enemy without treating the head as a removable limb")
	await reset_target()
	var overlay := lab.shooting_overlay
	overlay.toggle()
	overlay.tabs.current_tab = 5
	overlay.rows.head_damage_multiplier.slider.value = 3
	await shoot("head")
	check(target.health == 25 and overlay.rows.head_damage_multiplier.number.value == 3 and overlay.readout.text.contains("голова 75.0"),"F4 damage sliders affect real hits and synchronise the numeric field and preview")
	await reset_target()
	overlay.rows.arm_damage_multiplier.slider.value = 0
	overlay.rows.arm_durability.slider.value = 25
	await shoot("right_arm")
	check(target.health == 100 and not target.has_part("right_arm") and not impacts[-1].killed,"limb durability can be tuned independently from health damage, including zero health damage")
	overlay.save_profile()
	var saved := CoreShootingSettings.new()
	check(saved.load_saved(profile_path) == OK and saved.head_damage_multiplier == 3 and saved.arm_damage_multiplier == 0 and saved.arm_durability == 25,"the six damage settings persist in the existing shooting profile")
	overlay.reset_profile()
	await reset_target()
	overlay.toggle()
	lab.player.reset_to(Vector2(2425,760))
	var gun := lab.player.weapon
	gun.tuning.set_fire_mode(CoreShootingSettings.FireMode.SINGLE)
	gun.tuning.sway_radius = 0
	gun.aim_override = target.aim_point_for_part("torso")
	await frames(5)
	Input.action_press("core_aim")
	await frames(10)
	Input.action_press("core_fire")
	await frames(2)
	Input.action_release("core_fire")
	Input.action_release("core_aim")
	check(target.last_hit_part == "torso" and target.health == 75 and gun.hits == 1,"a muzzle overlapping an anatomical region uses the same zonal damage path")
	lab._recover()
	check(target.health == 100 and target.missing_parts.is_empty(),"full R reset also restores enemy anatomy")
	gun.shot_audio.stop()
	gun.hit_audio.stop()
	gun.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	DirAccess.remove_absolute(profile_path)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
