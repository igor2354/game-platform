extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var game: DeadPlatformGame = load("res://scenes/archive/station_demo.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.feel.reset()
	game.player.set_process(false)
	game.player.set_physics_process(false)
	check(game.player.body_mode == "drawn", "new painted body is the default")
	check("concept" in game.player.body_modes(), "concept body appears in F4 modes")
	game.player.set_body_mode("concept")
	var body: ConceptBody = game.player.rig
	check(body.meta.animations.size() == 6, "idle, walk, run, air, roll and climb are authored")
	var image: Image = body.sprites.walk.texture.get_image()
	check(image.get_size() == Vector2i(6144,320) and image.get_pixel(0,0).a == 0, "RGBA frames have real transparency")
	check(image.get_region(Rect2i(0,0,256,320)).get_data() != image.get_region(Rect2i(6*256,0,256,320)).get_data(), "walking poses are different")
	body.face(1)
	var stride: float = body.meta.animations.walk.speed
	body.drive("walk",Vector2(stride,0))
	body.advance(3.1/24.0)
	check(body.frame == 3 and is_equal_approx(body.speed,1), "walk playback follows the authored stride speed")
	body.advance(1)
	check(body.frame == 3, "walk loops without a duplicate endpoint")
	body.face(-1)
	body.drive("walk",Vector2(stride,0))
	body.advance(.8/24.0)
	check(body.frame == 2 and body.speed < 0, "backpedal reverses playback")
	body.face(1)
	body.drive("run",Vector2(Soldier.SPEED/Soldier.BODY_SCALE,0))
	var run_rate := body.speed
	body.drive("walk",Vector2(Soldier.AIM_SPEED/Soldier.BODY_SCALE,0))
	var walk_rate := body.speed
	body.drive("climb",Vector2(0,-158.0/Soldier.BODY_SCALE))
	var climb_rate := body.speed
	body.drive("idle",Vector2.ZERO)
	check(run_rate <= 1.0 and walk_rate <= 1.2 and climb_rate <= 1.5 and body.speed < 1, "combat speeds keep a natural cadence; idle breathes slowly")
	body.drive("idle",Vector2.ZERO)
	var anchored := true
	for angle in [-1.2,-.6,0,.6,1.2]:
		body.update_combat(Vector2(15,-140),Vector2.from_angle(angle),-1,0)
		for side in ["near","far"]:
			var grip: Vector2 = body.near_target if side == "near" else body.far_target
			var target: Vector2 = body.weapon_origin+grip.rotated(body.weapon_angle)
			anchored = anchored and body.hand_positions[side].distance_to(target) < .15
	check(anchored, "both textured hands stay on the PPSh grips across aim angles")
	body.update_combat(Vector2(10,-140),Vector2.RIGHT,-1,.04)
	check(body.hand_positions.near.distance_to(body.weapon_origin+body.near_target.rotated(body.weapon_angle)) < .15 and body.flash > 0, "recoil moves the gun and the holding hands together")
	var slot: Vector2 = body.vector(body.meta.weapon.magazine)
	body.update_combat(Vector2(15,-140),Vector2.RIGHT,.32,0)
	check(body.magazine_position.y > slot.y+12 and body.magazine_visible, "reload hand removes the drum magazine")
	check(body.hand_positions.far.distance_to(body.weapon_origin+body.magazine_position.rotated(body.weapon_angle)) < .15, "support hand follows the removed magazine")
	body.update_combat(Vector2(15,-140),Vector2.RIGHT,.45,0)
	check(not body.magazine_visible, "old magazine is hidden while being exchanged")
	body.update_combat(Vector2(15,-140),Vector2.RIGHT,.65,0)
	check(body.magazine_visible and body.magazine_position.y < slot.y+12, "new magazine returns to its socket")
	body.update_combat(Vector2(15,-140),Vector2.RIGHT,.86,0)
	check(body.bolt_offset.x < -7 and body.hand_positions.far.distance_to(body.weapon_origin+body.far_target.rotated(body.weapon_angle)) < .15, "support hand pulls the visible bolt handle")
	body.drive("roll",Vector2.ZERO)
	body.advance(.25)
	check(body.state == "roll" and body.frame > 0 and not body.arms.visible and not body.weapon_layer.visible, "roll uses full-character frames including the gun")
	body.advance(1)
	check(body.frame == 15, "roll clamps at the end of its half-second animation")
	body.drive("climb",Vector2(0,-body.meta.animations.climb.speed))
	body.advance(.2)
	body.drive("climb",Vector2.ZERO)
	var stopped := body.frame
	body.advance(.4)
	check(body.frame == stopped and not body.arms.visible, "ladder grips freeze when climbing stops")
	body.drive("climb",Vector2(0,body.meta.animations.climb.speed))
	check(body.speed < 0, "ladder descent reverses the same climbing cycle")
	# Real controller input with the new body, not only playback calls.
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.start_game()
	game.player.set_process(true)
	game.player.set_physics_process(true)
	game.player.position = Vector2(300,1120)
	game.player.velocity = Vector2.ZERO
	await frames(8)
	Input.warp_mouse(game.get_viewport().get_canvas_transform()*Vector2(700,1036))
	Input.action_press("roll")
	Input.action_press("right")
	await frames(6)
	Input.action_release("roll")
	Input.action_release("right")
	check(body.state == "roll" and not body.weapon_layer.visible and game.player.capsule.height == Soldier.ROLL_HEIGHT, "Shift triggers the new roll with the smaller collision capsule")
	game.player.invulnerable = 0
	var hp := game.player.health
	game.player.take_damage(17)
	check(game.player.health == hp, "roll animation retains the actual invulnerability window")
	await frames(30)
	check(game.player.rolling <= 0 and body.arms.visible, "after the roll hands return to the automatic")
	game.player.position = Vector2(530,1120)
	game.player.velocity = Vector2.ZERO
	await frames(6)
	Input.action_press("up")
	await frames(12)
	check(body.state == "climb" and not body.weapon_layer.visible, "real ladder input selects the slung-gun climbing frames")
	await frames(110)
	Input.action_release("up")
	await frames(4)
	check(absf(game.player.position.y-820) < 3 and not game.player.climbing, "new animated body dismounts onto the upper platform")
	game.player.ammo = 5
	game.player.reserve = 50
	Input.action_press("reload")
	await frames(2)
	Input.action_release("reload")
	await frames(28)
	check(body.reload_fraction > .15 and body.reload_fraction < .5 and body.magazine_position.y > slot.y, "R drives the visible magazine interaction from the gameplay reload timer")
	await frames(85)
	check(game.player.ammo == Soldier.MAGAZINE and game.player.reserve == 31 and body.reload_fraction < 0, "reload returns the hand and conserves ammunition")
	check(body.muzzle_global().distance_to(game.player.muzzle()) < .2, "weapon flash and gameplay muzzle share the rendered muzzle anchor")
	Input.action_press("shoot")
	await frames(2)
	Input.action_release("shoot")
	await process_frame
	check(game.player.ammo == Soldier.MAGAZINE-1 and body.flash > 0, "actual trigger input fires from the held PPSh and shows its flash")
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.player.facing = -1
	game.player.aim_direction = Vector2(-.8,-.4).normalized()
	body.face(-1)
	var barrel := game.player.barrel_direction()
	body.set_weapon_pose(game.player.gun_origin()-barrel*game.player.recoil,barrel,-1,0)
	check(body.muzzle_global().distance_to(game.player.muzzle()) < .2, "left-facing upward aim uses the same muzzle anchor")
	game.player.set_body_mode("rig")
	check(game.player.rig is HumanoidRig, "old skeletal body can still be restored")
	game.ambient.stop()
	game.ambient.stream = null
	await create_timer(.2).timeout
	game.queue_free()
	await create_timer(.2).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
