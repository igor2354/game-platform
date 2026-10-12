extends SceneTree
var game: DeadPlatformGame
var failures := 0
var checks := 0

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
	game = load("res://scenes/archive/station_demo.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	# This regression suite exercises the retained greybox controller/roll.
	# The default painted character/dash has its own input-driven suite.
	game.player.set_body_mode("rig")
	# Ignore any values saved from the F3 tuner on this machine.
	game.feel.reset()
	check(game.level.spans.size() == 10,"10 connected walking spans")
	check(game.level.ladders.size() == 8,"8 integrated climbable ladders")
	check(game.enemies.size() == 18,"initial enemy population")
	var atlas: Image = game.enemies[0].sprite.texture.get_image()
	check(atlas.get_pixel(0,0).a == 0,"sprite atlas has real transparency")
	# Traverse the level graph: each gap is shorter than the actual jump envelope.
	var seen: Array[int] = [0]
	var pending: Array[int] = [0]
	var max_gap := Soldier.SPEED * (-2*Soldier.JUMP_SPEED/Soldier.GRAVITY)
	while not pending.is_empty():
		var a: int = pending.pop_front()
		for b in game.level.spans.size():
			if b in seen: continue
			var ra: Rect2 = game.level.spans[a]
			var rb: Rect2 = game.level.spans[b]
			var linked := false
			if ra.position.y == rb.position.y:
				var gap := maxf(ra.position.x,rb.position.x)-minf(ra.end.x,rb.end.x)
				linked = gap >= 0 and gap < max_gap-10
			for ladder in game.level.ladders:
				var x := ladder.get_center().x
				if x >= ra.position.x and x <= ra.end.x and x >= rb.position.x and x <= rb.end.x:
					linked = linked or ((absf(ra.position.y-(ladder.position.y+20)) < 2 and absf(rb.position.y-ladder.end.y) < 2) or (absf(rb.position.y-(ladder.position.y+20)) < 2 and absf(ra.position.y-ladder.end.y) < 2))
			if linked:
				seen.append(b)
				pending.append(b)
	check(seen.size() == 10,"all walking spans reachable through jumps and ladders")
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	await frames(2)
	game.start_game()
	await frames(3)
	check(game.player.is_on_floor(),"player lands on lower platform")
	var initial_x := game.player.position.x
	Input.action_press("right")
	await frames(24)
	var moving_state: String = game.player.rig.state
	Input.action_release("right")
	check(game.player.position.x > initial_x+70,"horizontal movement")
	check(moving_state == "run","greybox body plays the run cycle while moving")
	await frames(5)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(game.player.velocity.y < -400,"buffered jump applies upward velocity")
	await frames(65)
	check(game.player.is_on_floor(),"jump returns to platform")
	# Real input-driven climb, not teleporting between endpoints.
	game.player.position = Vector2(530,1120)
	game.player.velocity = Vector2.ZERO
	Input.action_press("up")
	await frames(119)
	Input.action_release("up")
	await frames(5)
	check(absf(game.player.position.y-820) < 3 and not game.player.climbing,"ladder ascent and dismount onto middle tier")
	Input.action_press("down")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("down")
	await frames(65)
	check(absf(game.player.position.y-1120) < 3,"drop through one-way platform to lower tier")
	# Descend an actual ladder and stand above the lower collision surface.
	game.player.position = Vector2(530,820)
	game.player.velocity = Vector2.ZERO
	Input.action_press("down")
	await frames(121)
	Input.action_release("down")
	await frames(5)
	check(game.player.is_on_floor() and absf(game.player.position.y-1120) < 3,"ladder descent lands on lower floor")
	# Find and cross the largest actual gap with real input, not only a graph estimate.
	var gap_from := Rect2()
	var gap_to := Rect2()
	var largest_gap := 0.0
	for left in game.level.spans:
		for right in game.level.spans:
			if left.position.y != right.position.y or right.position.x < left.end.x: continue
			var adjacent := true
			for other in game.level.spans:
				if other.position.y == left.position.y and other.position.x > left.position.x and other.position.x < right.position.x: adjacent = false
			var width := right.position.x-left.end.x
			if adjacent and width > largest_gap:
				largest_gap = width
				gap_from = left
				gap_to = right
	game.player.position = Vector2(gap_from.end.x-24,gap_from.position.y)
	game.player.velocity = Vector2.ZERO
	await frames(3)
	Input.action_press("right")
	await frames(4)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(58)
	Input.action_release("right")
	check(game.player.is_on_floor() and game.player.position.x >= gap_to.position.x and absf(game.player.position.y-gap_to.position.y) < 3,"largest actual platform gap (%s px) is physically jumpable" % largest_gap)
	game.player.position = Vector2(300,1120)
	game.player.velocity = Vector2.ZERO
	Input.action_press("right")
	await frames(15)
	var hip_speed := absf(game.player.velocity.x)
	Input.action_press("aim")
	await frames(15)
	var laser_speed := absf(game.player.velocity.x)
	Input.action_release("right")
	Input.action_release("aim")
	check(hip_speed > 280 and laser_speed == Soldier.AIM_SPEED,"laser reduces movement speed")
	# Roll: real input, lowers the capsule, ignores damage early on, covers ground.
	game.player.position = Vector2(300,1120)
	game.player.velocity = Vector2.ZERO
	await frames(10)
	var roll_from := game.player.position.x
	Input.action_press("right")
	Input.action_press("roll")
	await frames(2)
	Input.action_release("roll")
	Input.action_release("right")
	check(game.player.rolling > 0 and game.player.capsule.height == Soldier.ROLL_HEIGHT and game.player.rig.state == "roll","Shift starts a roll that lowers the collision capsule")
	await frames(4)
	var hp_before := game.player.health
	game.player.invulnerable = 0
	game.player.take_damage(17)
	check(game.player.health == hp_before,"roll invulnerability blocks damage early in the roll")
	await frames(30)
	check(game.player.rolling <= 0 and game.player.capsule.height == Soldier.STAND_HEIGHT and game.player.position.x > roll_from+120,"roll covers ground and stands back up")
	# Hybrid body: whole frames for the body, a separate arms layer while armed.
	game.player.set_body_mode("hybrid")
	await frames(3)
	check(game.player.rig is HybridBody and game.player.rig.state == "idle" and game.player.rig.arms.visible,"F4 hybrid body: frame-by-frame body with separate arms")
	Input.action_press("right")
	await frames(6)
	var first_frame: int = game.player.rig.frame
	await frames(8)
	check(game.player.rig.state == "run" and game.player.rig.frame != first_frame and game.player.rig.arms.visible,"hybrid run steps through frames with arms on the rifle")
	Input.action_press("roll")
	await frames(2)
	Input.action_release("roll")
	Input.action_release("right")
	await frames(3)
	check(game.player.rig.state == "roll" and not game.player.rig.arms.visible,"hybrid roll uses whole frames, arms layer hidden")
	await frames(40)
	game.player.set_body_mode("rig")
	await frames(2)
	check(game.player.rig is HumanoidRig,"F4 switches back to the segmented rig")
	if "adventurer" in game.player.body_modes():
		game.player.set_body_mode("adventurer")
		await frames(3)
		check(game.player.rig is HybridBody and game.player.rig.frames_dir == Soldier.ADVENTURER_FRAMES and not game.player.rig.arms.visible,"third-party hand-drawn frame set loads, no separate arms")
		game.player.set_body_mode("rig")
		await frames(2)
	# Stop the controller while checking the exact firing rule.
	game.player.set_physics_process(false)
	game.player.aim_direction = Vector2(0.92,-0.31).normalized()
	game.player.aiming = true
	var exact := true
	for i in 100: exact = exact and game.player.shot_direction().is_equal_approx(game.player.aim_direction)
	check(exact,"100 laser shots have zero angular spread")
	game.player.aiming = false
	var varied := false
	var bounded := true
	for i in 100:
		var angle := absf(game.player.shot_direction().angle_to(game.player.aim_direction))
		varied = varied or angle > 0.01
		bounded = bounded and angle <= game.player.current_spread()+0.0001
	check(varied and bounded,"hip shots vary within specified cone")
	var first_spread := game.player.current_spread()
	game.player.bloom = 1
	check(game.player.current_spread() > first_spread*2,"sustained fire widens spread")
	game.player.bloom = 0
	game.player.ammo = 7
	game.player.reserve = 20
	game.player.reload_weapon()
	check(game.player.reload_left > 0 and not game.player.fire(),"reloading prevents firing")
	game.player.finish_reload()
	check(game.player.ammo == 24 and game.player.reserve == 3,"reload conserves ammunition")
	# Actual moving projectile / ray collision against an actual physics body.
	game.player.position = Vector2(300,1120)
	game.player.aim_direction = Vector2.RIGHT
	game.player.facing = 1
	game.player.aiming = true
	game.player.cooldown = 0
	var enemy := game.spawn_enemy(Vector2(520,1120))
	enemy.set_physics_process(false)
	await frames(3)
	check(game.player.fire(),"weapon creates projectile")
	await frames(10)
	check(enemy.health == 64,"projectile hits torso for 36 damage")
	game.player.cooldown = 0
	game.player.fire()
	await frames(10)
	game.player.cooldown = 0
	game.player.fire()
	await frames(10)
	check(enemy.dead and game.kills == 1,"three torso hits kill and increment counter")
	game.register_hit(false,true)
	# process_frame fires before nodes' _process, so wait for the game to apply it.
	await process_frame
	await process_frame
	check(Engine.time_scale < 1 and game.hit_kind == "kill","kill triggers hitstop")
	await create_timer(0.15,true,false,true).timeout
	await process_frame
	check(Engine.time_scale == 1,"hitstop releases time scale")
	await create_timer(0.4).timeout
	check(enemy.sprite.rotation > 1,"zombie falls away from the bullet")
	var head := game.spawn_enemy(Vector2(700,1120))
	head.set_physics_process(false)
	check(not head.receive_shot(76,Vector2.LEFT,true) and head.health == 24 and head.punch_side < 0,"headshot damage and knockback direction")
	game.enemies.erase(head)
	head.queue_free()
	# Held fire at 60 physics ticks/s must still average the PPSh rate.
	game.player.set_physics_process(true)
	game.player.aiming = false
	game.player.ammo = 24
	game.player.reserve = 0
	game.player.cooldown = 0
	game.player.climbing = false
	game.player.position = Vector2(300,1120)
	game.player.velocity = Vector2.ZERO
	Input.warp_mouse(Vector2(1400,450))
	Input.action_press("shoot")
	await frames(60)
	Input.action_release("shoot")
	var fired := 24-game.player.ammo
	var expected: float = game.feel.rpm/60.0
	check(absf(fired-expected) <= 1,"held fire matches %d rpm (%d shots in 1 s)" % [game.feel.rpm,fired])
	game.player.set_physics_process(false)
	game.player.reserve = 20
	var melee := game.spawn_enemy(Vector2(325,1120))
	await frames(8)
	check(game.player.health == 83,"zombie melee damages player")
	game.player.take_damage(17)
	check(game.player.health == 83,"damage immunity prevents per-frame damage stacking")
	melee.queue_free()
	await frames(2)
	game.player.position = game.level.checkpoint
	await frames(3)
	check(game.checkpoint_taken and game.player.health == 100,"supply cache heals and records checkpoint")
	game.player.position = game.level.radio
	game.interact()
	check(game.radio_active and game.level.radio_active,"E activates radio objective")
	check(game.enemies.size() == 8,"radio triggers six-enemy return wave")
	game.player.position = game.level.exit_point
	await frames(3)
	check(game.state == "won","exit completes the mission after radio")
	game.state = "playing"
	game.player.health = 10
	game.player.invulnerable = 0
	game.player.take_damage(17)
	check(game.state == "dead","fatal damage opens death state")
	game.continue_checkpoint()
	check(game.state == "playing" and game.player.health == 100 and game.player.position.distance_to(game.respawn_point) < 12,"checkpoint continuation restores playable state")
	game.state = "paused"
	game.player.set_physics_process(true)
	var paused_position := game.player.position
	Input.action_press("right")
	await frames(8)
	Input.action_release("right")
	check(game.player.position.is_equal_approx(paused_position),"pause freezes movement")
	game.queue_free()
	await create_timer(0.2).timeout
	print("RESULT: ",checks-failures,"/",checks," checks passed")
	quit(0 if failures == 0 else 1)
