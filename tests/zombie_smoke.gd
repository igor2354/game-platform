extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
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
	for tick in count: await physics_frame
func reset_encounter(offset: float) -> void:
	for action in ["core_left","core_right","core_jump","core_dash","core_fire"]: Input.action_release(action)
	zombie.reset_target()
	hero.reset_to(zombie.home+Vector2(offset,0))
func wall_at(x: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20,120)
	shape.shape = rect
	wall.position = Vector2(x,700)
	wall.add_child(shape)
	lab.get_node("World").add_child(wall)
	return wall
func place_in_view(angle: float,distance: float) -> void:
	var direction := Vector2(zombie.facing,0).rotated(deg_to_rad(angle)*-zombie.facing)
	hero.global_position = zombie.eye_point()+direction*distance+Vector2(0,CoreMovementPlayer.HEIGHT*.5)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	check(zombie.target == hero and zombie in lab.level.enemies and zombie.hit_zones.size() == 6,"the playable lab contains an active zombie with six damage regions")
	check(zombie.state == CoreZombie.State.PATROL and zombie.position.x < zombie.home.x and zombie.is_on_floor(),"an unaware zombie patrols on solid ground")
	var leftmost := zombie.position.x
	var rightmost := leftmost
	var reversed := false
	for tick in 650:
		await physics_frame
		leftmost = minf(leftmost,zombie.position.x)
		rightmost = maxf(rightmost,zombie.position.x)
		reversed = reversed or zombie.patrol_direction > 0
	check(reversed and leftmost >= zombie.home.x-zombie.tuning.patrol_radius-1 and rightmost <= zombie.home.x+zombie.tuning.patrol_radius+1,"patrol reverses at its configured boundaries without leaving the area")
	reset_encounter(120)
	await frames(24)
	check(zombie.state == CoreZombie.State.PATROL and zombie.facing < 0 and not zombie.sees_player(360),"a left-facing patrol does not detect a nearby player behind its back")
	reset_encounter(-120)
	zombie.facing = 1
	zombie.patrol_direction = 1
	await frames(24)
	check(zombie.state == CoreZombie.State.PATROL and zombie.facing > 0 and not zombie.sees_player(360),"a right-facing patrol does not detect a nearby player behind its back")
	reset_encounter(120)
	zombie.position.x = zombie.home.x-zombie.tuning.patrol_radius+1
	hero.reset_to(zombie.position+Vector2(220,0))
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE and zombie.facing > 0 and zombie.velocity.x > 0,"a natural patrol turnaround detects the formerly hidden player once facing them")
	reset_encounter(-220)
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE and zombie.facing < 0,"the left-facing front sector also detects and pursues the player")
	reset_encounter(-450)
	zombie.set_physics_process(false)
	hero.set_physics_process(false)
	for look in [-1.0,1.0]:
		zombie.facing = look
		place_in_view(65,140)
		check(not zombie.sees_player(360),"an elevated player outside the 120-degree cone is unseen when facing %.0f" % look)
		place_in_view(55,140)
		check(zombie.sees_player(360),"an elevated player inside the cone is seen when facing %.0f" % look)
	zombie.tuning.vision_angle = 80
	check(not zombie.sees_player(360),"narrowing the exported view angle changes actual detection")
	zombie.tuning.vision_angle = 160
	check(zombie.sees_player(360),"widening the exported view angle restores detection")
	zombie.tuning.vision_angle = 120
	place_in_view(0,361)
	check(not zombie.sees_player(360),"being directly in front still requires being within the detection distance")
	hero.set_physics_process(true)
	zombie.set_physics_process(true)
	reset_encounter(-180)
	await frames(8)
	var remembered := zombie.last_seen_position
	hero.reset_to(zombie.position+Vector2(140,0))
	await frames(12)
	check(zombie.facing < 0 and zombie.last_seen_position == remembered and not zombie.sees_player(540),"pursuit remembers the last visible position instead of tracking and instantly facing an unseen player behind")
	hero.reset_to(Vector2(160,760))
	await frames(90)
	check(zombie.state == CoreZombie.State.RETURN,"an unseen target is forgotten after the normal delay")
	reset_encounter(-450)
	await frames(8)
	check(zombie.state == CoreZombie.State.PATROL,"a player beyond the detection radius does not alert the zombie")
	hero.reset_to(zombie.position+Vector2(-220,0))
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE and zombie.facing < 0 and is_equal_approx(zombie.velocity.x,-zombie.tuning.chase_speed),"a player inside the radius triggers pursuit at the chase speed")
	var pursuit_x := zombie.position.x
	await frames(30)
	check(zombie.position.x < pursuit_x-45,"pursuit actually moves the enemy towards the player")
	hero.reset_to(Vector2(160,760))
	await frames(100)
	check(zombie.state == CoreZombie.State.RETURN,"losing the player for the configured delay switches to return")
	await frames(300)
	check(zombie.state == CoreZombie.State.PATROL and absf(zombie.position.x-zombie.home.x) <= zombie.tuning.patrol_radius+1,"the zombie returns to its original patrol after pursuit")
	reset_encounter(-220)
	var wall := wall_at(zombie.home.x-100)
	await frames(12)
	check(zombie.state == CoreZombie.State.PATROL and not zombie.sees_player(360),"solid geometry blocks detection rather than allowing sight through walls")
	wall.queue_free()
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE,"removing an occluder allows detection on the next physics ticks")
	reset_encounter(-48)
	await frames(4)
	check(zombie.state == CoreZombie.State.WINDUP and zombie.attacks_started == 1 and hero.health == 100,"entering melee range starts a visible windup without immediate damage")
	await frames(12)
	check(hero.health == 100 and zombie.state == CoreZombie.State.WINDUP,"the player has time to react before the strike")
	await frames(14)
	check(hero.health == 85 and zombie.attacks_landed == 1 and zombie.state == CoreZombie.State.RECOVERY,"a completed strike deals exactly 15 damage once")
	var damaged_health := hero.health
	await frames(24)
	check(hero.health == damaged_health and zombie.attacks_landed == 1,"recovery prevents per-frame damage stacking")
	await frames(55)
	check(hero.health == 70 and zombie.attacks_landed == 2,"a second full attack is possible after recovery and a new windup")
	reset_encounter(-48)
	await frames(4)
	hero.reset_to(zombie.home+Vector2(-150,0))
	await frames(28)
	check(hero.health == 100 and zombie.attacks_landed == 0,"leaving reach during windup makes the committed strike miss")
	reset_encounter(-48)
	await frames(4)
	hero.reset_to(zombie.home+Vector2(48,0))
	await frames(28)
	check(hero.health == 100 and zombie.attacks_landed == 0,"moving behind the attacker avoids the committed facing of the strike")
	reset_encounter(-48)
	await frames(4)
	wall = wall_at(zombie.home.x-24)
	await frames(28)
	check(hero.health == 100 and zombie.attacks_landed == 0,"a wall introduced during the windup blocks the eventual melee strike")
	wall.queue_free()
	await frames(2)
	reset_encounter(-48)
	await frames(4)
	paused = true
	var frozen_position := zombie.position
	var frozen_timer := zombie.state_left
	await frames(20)
	check(zombie.position == frozen_position and zombie.state_left == frozen_timer and hero.health == 100,"pause freezes movement, the windup timer and player damage")
	paused = false
	await frames(28)
	check(hero.health == 85,"the paused attack resumes normally without skipping its strike")
	reset_encounter(-48)
	await frames(4)
	zombie.take_damage(100)
	await frames(35)
	check(zombie.state == CoreZombie.State.DEAD and hero.health == 100 and zombie.attacks_landed == 0 and zombie.collision_layer == 0,"killing a zombie during windup cancels its attack and blocking body")
	reset_encounter(-48)
	zombie.take_projectile_hit(50,"left_arm")
	await frames(32)
	check(zombie.health == 87.5 and not zombie.has_part("left_arm") and is_equal_approx(hero.health,90.25),"a survivor with one arm can still attack, with reduced damage")
	reset_encounter(-48)
	for part in ["left_arm","right_arm"]: zombie.take_projectile_hit(50,part)
	await frames(90)
	check(zombie.health == 75 and hero.health == 100 and zombie.attacks_started == 0,"removing both arms leaves the zombie alive but prevents melee attacks")
	reset_encounter(-220)
	zombie.take_projectile_hit(50,"left_leg")
	await frames(8)
	check(is_equal_approx(absf(zombie.velocity.x),zombie.tuning.chase_speed*.55),"losing one leg slows pursuit to 55 percent")
	zombie.take_projectile_hit(50,"right_leg")
	await frames(8)
	check(zombie.is_prone() and is_equal_approx(absf(zombie.velocity.x),zombie.tuning.crawl_speed) and zombie.health == 65,"losing both legs produces a living crawler with lower hitboxes")
	for part in ["left_arm","right_arm"]: zombie.take_projectile_hit(50,part)
	await frames(8)
	check(zombie.health == 40 and zombie.velocity.x == 0 and hero.health == 100,"a zombie without legs and arms survives but cannot move or attack")
	reset_encounter(-48)
	for part in ["left_leg","right_leg"]: zombie.take_projectile_hit(50,part)
	await frames(32)
	check(zombie.is_prone() and hero.health == 85,"a crawler retaining its arms can hit the feet of a nearby standing player")
	reset_encounter(-220)
	zombie.tuning.detection_range = 80
	await frames(8)
	check(zombie.state == CoreZombie.State.PATROL,"changing the exported detection distance affects behaviour")
	zombie.tuning.detection_range = 360
	await frames(8)
	check(zombie.state == CoreZombie.State.CHASE,"restoring the detection distance allows pursuit")
	reset_encounter(-48)
	await frames(4)
	zombie.state_left = .07
	Input.action_press("core_dash")
	await frames(6)
	check(hero.dash_left > 0 and hero.health == 100 and zombie.attacks_landed == 0,"an active dash avoids the melee strike")
	Input.action_release("core_dash")
	reset_encounter(-60)
	await frames(2)
	Input.action_press("core_right")
	Input.action_press("core_dash")
	await frames(10)
	check(hero.position.x > zombie.position.x+25 and hero.health == 100,"the player can dash through the moving zombie without being blocked")
	Input.action_release("core_right")
	Input.action_release("core_dash")
	reset_encounter(-48)
	await frames(4)
	zombie.take_projectile_hit(50,"left_arm")
	lab.respawn_enemies_button.pressed.emit()
	check(zombie.position == zombie.home and zombie.state == CoreZombie.State.PATROL and zombie.health == 100 and zombie.missing_parts.is_empty() and zombie.state_left == 0,"enemy respawn restores the zombie's home, patrol, limbs and cancels a pending attack")
	reset_encounter(-48)
	await frames(4)
	hero.health = 10
	await frames(32)
	check(hero.health == 0 and not hero.dash_available(),"lethal melee damage defeats the player and prevents further dashes")
	Input.action_press("core_right")
	Input.action_press("core_fire")
	var shots := hero.weapon.shots_fired
	var dead_x := hero.position.x
	await frames(8)
	check(hero.position.x == dead_x and hero.weapon.shots_fired == shots and not zombie.sees_player(360),"a defeated player cannot run or shoot and is no longer a detectable target")
	Input.action_release("core_right")
	Input.action_release("core_fire")
	lab._recover()
	check(hero.health == 100 and hero.hurt_left == 0 and hero.position == CoreMovementLevel.SPAWN and zombie.position == zombie.home and zombie.state == CoreZombie.State.PATROL,"R recovery restores player health and resets zombie AI")
	var event := InputEventAction.new()
	event.action = "core_zombie_test"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	check(hero.position.distance_to(CoreMovementLevel.ZOMBIE_TEST_SPAWN) < 1,"T provides a working shortcut to the zombie test area")
	# A patrol must turn before walking into the existing jump-test pit.
	hero.reset_to(Vector2(4000,760))
	zombie.global_position = Vector2(920,760)
	zombie.home = zombie.global_position
	zombie.patrol_direction = 1
	zombie.state = CoreZombie.State.PATROL
	await frames(100)
	check(zombie.position.y < 762 and zombie.position.x < 945,"ground probes keep a patrolling zombie from walking off a ledge")
	# Swept bullets use the same anatomical damage path while the zombie walks.
	zombie.home = Vector2(5400,760)
	reset_encounter(-450)
	await frames(8)
	var aim := zombie.aim_point_for_part("head")
	var bullet := CoreProjectile.new()
	bullet.position = aim-Vector2(60,0)
	bullet.direction = Vector2.RIGHT
	bullet.speed = 4000
	bullet.damage = 25
	bullet.shooter = hero.get_rid()
	lab.get_node("World").add_child(bullet)
	await frames(3)
	check(zombie.health == 50 and zombie.last_hit_part == "head","a fast projectile hits a moving zombie's head and applies its damage multiplier")
	hero.weapon.shot_audio.stop()
	hero.weapon.hit_audio.stop()
	hero.weapon.kill_audio.stop()
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
