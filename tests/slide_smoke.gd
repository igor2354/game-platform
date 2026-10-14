extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var enemy: CoreEnemyDummy
var checks := 0
var failures := 0
const ACTIONS := ["core_left","core_right","core_sprint","core_crouch","core_jump","core_dash","core_fire","core_aim"]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for tick in count: await physics_frame
func release() -> void:
	for action in ACTIONS: Input.action_release(action)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = false
	Input.parse_input_event(key)
func settle(point := Vector2(1800,760)) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(-1000,-36)
	await frames(8)
func sprint(point := Vector2(1800,760),direction := 1.0) -> void:
	await settle(point)
	Input.action_press("core_right" if direction > 0 else "core_left")
	Input.action_press("core_sprint")
	await frames(20)
func begin_slide() -> void:
	Input.action_press("core_crouch")
	await frames(2)
func attached() -> bool:
	var pose := hero.weapon.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	enemy = lab.level.enemies[0]
	await settle()
	Input.action_press("core_right")
	await frames(20)
	await begin_slide()
	check(hero.slides == 0 and hero.crouching,"crouch during ordinary movement remains a crouch")
	await settle()
	Input.action_press("core_right")
	Input.action_press("core_sprint")
	await begin_slide()
	check(hero.slides == 0 and hero.crouching,"crouching before building sprint speed cannot start a slide")
	await sprint()
	check(hero.sprinting and absf(hero.ground_speed-520) < 1,"the player first builds real sprint speed")
	var start := hero.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	check(hero.slides == 1 and hero.mode == "slide" and hero.slide_left > 0,"physical C during sprint starts a slide")
	check(hero.crouching and hero.collision_height() == 32 and hero.body.state == "slide" and hero.body.sprite.hframes == 8,"slide uses a low collider and eight distinct baked poses")
	check(hero.slide_speed > 670 and hero.body.facing == 1 and attached(),"slide starts from sprint momentum and locks body direction with attached hands")
	key.pressed = false
	Input.parse_input_event(key)
	Input.action_release("core_sprint")
	Input.action_release("core_right")
	Input.action_press("core_left")
	var seen := {}
	var grips := true
	for tick in 40:
		await physics_frame
		if hero.body.state == "slide": seen[hero.body.frame] = true
		grips = grips and attached()
	check(seen.size() == 8 and grips,"the complete slide plays every pose while keeping the weapon grips")
	check(hero.position.x-start.x > 300 and hero.position.x-start.x < 350 and hero.slide_left == 0,"release and reverse input do not steer a slide; braking produces its configured range")
	check(not hero.crouching and hero.collision_height() == 64,"finishing a released slide restores standing in open space")
	await sprint()
	await begin_slide()
	await frames(40)
	check(hero.slide_left == 0 and hero.slides == 1 and hero.crouching and hero.collision_height() == 42,"held crouch ends in an ordinary crouch without chaining slides")
	await sprint()
	await begin_slide()
	Input.action_press("core_jump")
	await frames(2)
	check(hero.slide_left == 0 and hero.jumps == 1 and hero.velocity.y < 0,"jump cancels a slide and executes from the floor")
	await sprint()
	await begin_slide()
	var paused_state := [hero.position,hero.slide_left,hero.slide_speed,hero.slide_cooldown_left]
	paused = true
	await frames(8)
	check(paused_state == [hero.position,hero.slide_left,hero.slide_speed,hero.slide_cooldown_left],"pause freezes slide movement and timers")
	paused = false
	hero.reset_to(Vector2(1800,760))
	check(hero.slide_left == 0 and hero.slide_cooldown_left == 0 and hero.slides == 0 and hero.collision_height() == 64,"respawn clears slide state and collider")
	await sprint(Vector2(440,760))
	await begin_slide()
	await frames(20)
	check(hero.slide_left == 0 and hero.position.x < 627 and hero.position.y > 759,"slide stops at the wall rather than tunnelling through terrain")
	await sprint()
	await begin_slide()
	await frames(36)
	Input.action_release("core_crouch")
	await frames(3)
	Input.action_press("core_crouch")
	await frames(1)
	check(hero.slides == 1 and hero.slide_cooldown_left > 0,"a fresh crouch press during cooldown cannot restart the slide")
	await sprint()
	var tunnel := StaticBody2D.new()
	tunnel.position = Vector2(2110,713)
	var tunnel_shape := CollisionShape2D.new()
	var tunnel_rect := RectangleShape2D.new()
	tunnel_rect.size = Vector2(400,20) # 37 px clearance: slide fits, normal crouch cannot.
	tunnel_shape.shape = tunnel_rect
	tunnel.add_child(tunnel_shape)
	hero.get_parent().add_child(tunnel)
	await begin_slide()
	Input.action_release("core_crouch")
	await frames(40)
	check(hero.crouching and hero.collision_height() == 32 and hero.position.y > 759,"slide passes under low geometry and cannot expand into its ceiling")
	tunnel.queue_free()
	await frames(3)
	check(not hero.crouching and hero.collision_height() == 64,"leaving slide headroom constraints restores the standing body")
	await settle()
	var group: Array[CoreEnemyDummy] = []
	for x in [2070,2086,2102]:
		var target := CoreEnemyDummy.new()
		target.position = Vector2(x,760)
		hero.get_parent().add_child(target)
		group.append(target)
	await sprint()
	await begin_slide()
	await frames(35)
	check(group.all(func(target: CoreEnemyDummy): return target.health == 75 and target.received_hits == 1 and target.is_knocked_down()),"a dense enemy group receives one separate damage and knockdown per target")
	check(hero.slide_hits == 3 and hero.position.x > 2135,"slide crosses a fallen group without phasing untouched standing targets")
	await settle()
	await frames(120)
	check(group.all(func(target: CoreEnemyDummy): return not target.is_knocked_down() and not target.is_prone()),"a packed fallen group can get up without blocking itself forever")
	for target in group: target.queue_free()
	await frames(2)
	for direction in [1.0,-1.0]:
		enemy.reset_target()
		await sprint(Vector2(2200 if direction > 0 else 2640,760),direction)
		await begin_slide()
		await frames(35)
		check(enemy.health == 75 and enemy.received_hits == 1 and hero.slide_hits == 1,"slide causes exactly one direct hit per enemy, direction %.0f" % direction)
		check(enemy.is_knocked_down() and enemy.is_prone() and enemy.missing_parts.is_empty(),"slide temporarily knocks down an intact enemy, direction %.0f" % direction)
		check((hero.position.x-enemy.position.x)*direction > 24,"a slide passes a knocked-down enemy without getting stuck, direction %.0f" % direction)
		check(enemy.part_rect("left_leg").has_area() and enemy.hit_zones.left_leg.collision_layer == CoreEnemyDummy.HIT_LAYER,"fallen surviving legs remain visible and hittable")
		await settle()
		await frames(110)
		check(not enemy.is_knocked_down() and not enemy.is_prone() and enemy.health == 75,"enemy gets up after its timer without restoring lost health")
		# Stationary targets remember no home; restore their test position explicitly.
		enemy.position = Vector2(2460,760)
	for failure_mode in ["disabled","zero_chance","speed_threshold"]:
		hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
		if failure_mode == "disabled": hero.tuning.slide_knockdown_enabled = false
		if failure_mode == "zero_chance": hero.tuning.slide_knockdown_chance = 0
		if failure_mode == "speed_threshold": hero.tuning.slide_knockdown_min_speed = 1000
		enemy.reset_target()
		enemy.position = Vector2(2460,760)
		await sprint(Vector2(2200,760))
		await begin_slide()
		await frames(35)
		check(enemy.health == 75 and not enemy.is_prone() and hero.slide_left == 0 and hero.position.x <= enemy.position.x-29,"damage remains but a non-fallen enemy stops the slide: "+failure_mode)
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.tuning.slide_damage_min_speed = 1000
	enemy.reset_target()
	await sprint(Vector2(2200,760))
	await begin_slide()
	await frames(30)
	check(enemy.health == 100 and enemy.received_hits == 0 and enemy.is_knocked_down(),"damage threshold is independent of knockdown eligibility")
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	hero.tuning.slide_damage = 40
	hero.tuning.slide_knockdown_duration = 2.3
	hero.tuning.slide_knockback_speed = 250
	enemy.reset_target()
	enemy.position = Vector2(2460,760)
	await sprint(Vector2(2200,760))
	await begin_slide()
	for tick in 30:
		await physics_frame
		if enemy.received_hits > 0: break
	check(enemy.health == 60 and enemy.knockdown_left > 2.2 and enemy.velocity.x > 215,"edited damage, fall duration and impulse affect the actual collision")
	await settle()
	enemy.reset_target()
	enemy.position = Vector2(2460,760)
	enemy.knock_down(.3,Vector2.ZERO)
	await settle(Vector2(2460,736))
	await frames(30)
	check(enemy.is_knocked_down() and hero.is_on_floor(),"an enemy cannot stand up inside the player standing on its fallen body")
	await settle()
	await frames(4)
	check(not enemy.is_knocked_down(),"enemy gets up once the player leaves its body")
	hero.tuning.apply_values(lab.movement_overlay.defaults.as_dictionary())
	enemy.reset_target()
	enemy.position = Vector2(2460,760)
	enemy.take_damage(80)
	await sprint(Vector2(2200,760))
	await begin_slide()
	await frames(30)
	check(enemy.health == 0 and enemy.collision_layer == 0 and not enemy.is_knocked_down(),"lethal slide damage disables the enemy instead of resurrecting it as fallen")
	var zombie := lab.level.zombie
	zombie.reset_target()
	zombie.position = Vector2(2460,760)
	zombie.tuning.hearing_range = 0
	zombie.tuning.detection_range = 1
	zombie.tuning.forget_range = 1
	zombie.state = CoreZombie.State.WINDUP
	zombie.state_left = 1
	zombie.facing = -1
	await sprint(Vector2(2200,760))
	await begin_slide()
	await frames(25)
	check(zombie.health == 75 and zombie.state == CoreZombie.State.KNOCKED_DOWN and zombie.is_knocked_down(),"a slide knocks down the actual zombie and cancels its committed attack")
	check(zombie.attacks_landed == 0 and zombie.shoves_landed == 0 and hero.health == 100,"a knocked-down zombie cannot melee or shove the player")
	await settle()
	await frames(ceili(hero.tuning.slide_zombie_knockdown_duration/hero.get_physics_process_delta_time())+5)
	check(not zombie.is_knocked_down() and not zombie.is_prone(),"the intact zombie gets up and returns to its AI")
	zombie.take_projectile_hit(50,"left_leg")
	zombie.knock_down(.3,Vector2.ZERO)
	await frames(25)
	check(not zombie.is_knocked_down() and zombie.is_prone() and not zombie.has_part("left_leg") and zombie.has_part("right_leg"),"knockdown recovery preserves permanent limb loss and crawling")
	zombie.reset_target()
	zombie.position = Vector2(2300,760)
	zombie.tuning.hearing_range = 600
	zombie.knock_down(.3,Vector2.ZERO)
	zombie.hear_noise(hero.position-Vector2(0,8),1,"step")
	await frames(25)
	check(not zombie.is_knocked_down() and zombie.state == CoreZombie.State.INVESTIGATE,"a zombie can resume investigating a heard source after recovering from knockdown")
	zombie.reset_target()
	enemy.reset_target()
	enemy.position = Vector2(2460,760)
	enemy.knock_down(.2,Vector2.ZERO)
	var ceiling := StaticBody2D.new()
	ceiling.position = enemy.position-Vector2(0,40)
	var ceiling_shape := CollisionShape2D.new()
	var ceiling_rect := RectangleShape2D.new()
	ceiling_rect.size = Vector2(100,16)
	ceiling_shape.shape = ceiling_rect
	ceiling.add_child(ceiling_shape)
	hero.get_parent().add_child(ceiling)
	await frames(30)
	check(enemy.is_knocked_down() and enemy.body_shape.shape is CircleShape2D,"fallen enemy cannot stand through a low ceiling")
	ceiling.queue_free()
	await frames(4)
	check(not enemy.is_knocked_down() and enemy.body_shape.shape is RectangleShape2D,"enemy stands once its headroom is free")
	var hill := lab.level.slopes[1]
	enemy.position = hill[0].lerp(hill[1],.5)-Vector2(0,10)
	enemy.knock_down(.5,Vector2.ZERO)
	await frames(65)
	check(not enemy.is_knocked_down() and not enemy.is_prone() and enemy.position.y < 720,"temporary knockdown can recover safely on a slope")
	enemy.reset_target()
	enemy.position = Vector2(2460,760)
	for side in [0,2]:
		await sprint(hill[side].lerp(hill[side+1],.3)-Vector2(0,10))
		await begin_slide()
		var grounded := true
		for tick in 35:
			await physics_frame
			grounded = grounded and hero.is_on_floor()
		check(hero.slides == 1 and grounded,"slide follows a slope without accidental lift-off, side %d" % side)
	await sprint(Vector2(770,760))
	await begin_slide()
	await frames(30)
	check(not hero.is_on_floor() and hero.slide_left == 0,"leaving a ledge ends the grounded slide and restores falling")
	await sprint()
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = lab.movement_overlay.groups.find("Подкат")
	var edit: LineEdit = lab.movement_overlay.rows.slide_damage.number.get_line_edit()
	edit.grab_focus()
	Input.action_press("core_crouch")
	await frames(3)
	edit.release_focus()
	await frames(3)
	check(hero.slides == 0 and hero.crouching,"typing crouch in F3 cannot queue a slide after editing ends")
	release()
	var toggle := lab.movement_overlay.slide_knockdown_toggle
	toggle.button_pressed = false
	check(not hero.tuning.slide_knockdown_enabled and not toggle.button_pressed,"F3 provides a live knockdown on/off switch")
	lab.movement_overlay.rows.slide_damage.number.value = 40
	lab.movement_overlay.rows.slide_knockdown_duration.slider.value = 2.3
	lab.movement_overlay.rows.slide_knockback_speed.number.value = 250
	check(hero.tuning.slide_damage == 40 and is_equal_approx(hero.tuning.slide_knockdown_duration,2.3) and hero.tuning.slide_knockback_speed == 250,"F3 independently adjusts damage, knockdown time and impulse")
	var path := "/private/tmp/slide-profile-%d.cfg" % OS.get_process_id()
	hero.tuning.save_saved(path)
	var saved := CoreMovementSettings.new()
	saved.load_saved(path)
	check(not saved.slide_knockdown_enabled and saved.slide_damage == 40 and is_equal_approx(saved.slide_knockdown_duration,2.3),"movement profiles persist slide values and the knockdown switch")
	DirAccess.remove_absolute(path)
	hero.tuning.apply_values({"slide_height":0,"slide_duration":2,"slide_cooldown":0,"slide_knockdown_chance":5})
	check(hero.tuning.slide_height == 28 and hero.tuning.slide_cooldown == 2 and hero.tuning.slide_knockdown_chance == 1,"slide settings keep a valid collider, cooldown and probability")
	lab.movement_overlay.reset_button.pressed.emit()
	check(hero.tuning.slide_knockdown_enabled and hero.tuning.slide_damage == 25 and hero.tuning.slide_duration == .65,"Reset restores project slide and knockdown defaults")
	paused = false
	release()
	hero.weapon.reset_state()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
