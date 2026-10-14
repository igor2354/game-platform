extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var noises: Array[Dictionary] = []
var shots: Array[Dictionary] = []
const ACTIONS := ["core_left","core_right","core_up","core_down","core_jump","core_dash","core_crouch","core_fire","core_aim"]

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
func settle(point := Vector2(1800,760)) -> void:
	release()
	hero.reset_to(point)
	hero.weapon.aim_override = point+Vector2(600,-30)
	await frames(8)
	noises.clear()
	shots.clear()
func grips_attached() -> bool:
	var pose := hero.weapon.visual_pose()
	return hero.body.near_arm.hand.distance_to(pose.rear_grip) < .001 and hero.body.far_arm.hand.distance_to(pose.front_grip) < .001

func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	hero.noise_emitted.connect(func(point: Vector2,loudness: float,kind: String): noises.append({"point":point,"loudness":loudness,"kind":kind}))
	hero.weapon.shot_fired.connect(func(origin: Vector2,direction: Vector2,aimed: bool,_spread: float): shots.append({"origin":origin,"direction":direction,"aimed":aimed,"hip":hero.weapon.pivot(),"height":hero.collision_height()}))
	await settle()
	check(InputMap.action_get_events("core_crouch").size() == 1 and InputMap.action_get_events("core_crouch")[0].physical_keycode == KEY_C,"only C is bound to held crouching")
	var origin := hero.position
	Input.action_press("core_crouch")
	await frames(4)
	check(hero.crouching and hero.mode == "crouch" and hero.is_on_floor() and hero.position.distance_to(origin) < .2,"crouching changes posture while feet stay planted")
	check(hero.collision_height() == 42 and hero.movement_shape.position.y == -21 and hero.body.state == "crouch","the baked crouch pose uses a genuinely shorter collider")
	check(hero.weapon.local_pivot().y > -20 and grips_attached(),"hip weapon and both hands lower with the crouched torso")
	Input.action_press("core_right")
	var seen := {}
	var attached := true
	for tick in 48:
		await physics_frame
		seen[hero.body.frame] = true
		attached = attached and grips_attached()
	check(hero.mode == "crouch_walk" and absf(hero.velocity.x-144) < .5 and seen.size() == 8,"crouch walking plays all eight poses at the reduced speed")
	check(attached,"hands stay on both grips throughout crouch walking")
	check(noises.any(func(event: Dictionary): return event.kind == "step" and is_equal_approx(event.loudness,.4)),"crouch footsteps use their quieter configured loudness")
	Input.action_release("core_right")
	Input.action_release("core_crouch")
	await frames(10)
	check(not hero.crouching and hero.collision_height() == 64 and hero.body.state == "idle","releasing crouch restores standing in open space")
	for fire_mode in [0,1]:
		for ads in [false,true]:
			for direction in [-1.0,1.0]:
				await settle()
				hero.weapon.tuning.fire_mode = fire_mode
				hero.weapon.tuning.sway_radius = 0
				hero.weapon.aim_override = hero.position+Vector2(direction*600,-30)
				Input.action_press("core_crouch")
				if ads: Input.action_press("core_aim")
				await frames(10)
				Input.action_press("core_fire")
				await frames(10)
				Input.action_release("core_fire")
				var label := "%s %s facing %.0f" % ["auto" if fire_mode == 0 else "single","ADS" if ads else "hip",direction]
				check(hero.crouching and shots.size() > 0 and (fire_mode == 0 or shots.size() == 1) and shots.all(func(shot: Dictionary): return shot.aimed == ads and shot.direction.x*direction > 0 and shot.height == 42),"crouched shooting works: "+label)
				check(grips_attached() and hero.body.facing == direction,"crouched weapon grips remain attached: "+label)
				if ads:
					check(hero.weapon.local_pivot().distance_to(hero.body.ads_anchor()) < .1 and hero.body.head_aim_stage() == 4 and hero.weapon.last_shot_spread == 0,"ADS mounts the gun at the crouched shoulder with a tilted head: "+label)
	# Actual low geometry blocks standing, but the player can walk underneath.
	await settle()
	Input.action_press("core_crouch")
	await frames(3)
	var ceiling := StaticBody2D.new()
	ceiling.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(180,20)
	shape.shape = rectangle
	ceiling.position = Vector2(1800,698) # Bottom 708: 52 px of clearance.
	ceiling.add_child(shape)
	lab.get_node("World").add_child(ceiling)
	await frames(3)
	Input.action_release("core_crouch")
	await frames(4)
	check(hero.crouching and hero.collision_height() == 42 and hero.position.y > 759,"a solid low ceiling prevents standing without displacing the player")
	Input.action_press("core_right")
	await frames(70)
	check(hero.position.x > 1905 and not hero.crouching and hero.collision_height() == 64,"walking out of the low passage automatically restores standing")
	await settle()
	# Teleporting directly under geometry is test setup; shrink before advancing.
	hero.crouching = true
	hero.movement_shape.shape = hero.crouching_capsule
	hero.movement_shape.position.y = -21
	Input.action_press("core_crouch")
	await frames(3)
	Input.action_press("core_dash")
	var safe := true
	for tick in 20:
		await physics_frame
		if hero.position.x < 1870: safe = safe and hero.collision_height() == 42
	check(safe and hero.dashes == 1 and hero.position.y > 759,"dash from a crouch retains a safe height inside the passage")
	ceiling.queue_free()
	await frames(3)
	await settle()
	Input.action_press("core_crouch")
	await frames(3)
	Input.action_press("core_jump")
	await frames(4)
	check(hero.jumps == 1 and hero.velocity.y < 0 and not hero.crouching and hero.collision_height() == 64,"jumping from a crouch stands first when there is room")
	await settle(Vector2(1446,760))
	Input.action_press("core_crouch")
	await frames(3)
	Input.action_press("core_up")
	await frames(4)
	check(hero.climbing and not hero.crouching and hero.collision_height() == 64,"ladder entry takes priority over held crouching")
	await settle()
	lab.movement_overlay.toggle()
	lab.movement_overlay.tabs.current_tab = 5
	lab.movement_overlay.rows.crouch_height.number.value = 36
	lab.movement_overlay.rows.crouch_speed_multiplier.slider.value = .6
	lab.movement_overlay.rows.crouch_noise_multiplier.number.value = .2
	Input.action_press("core_crouch")
	Input.action_press("core_right")
	await frames(12)
	check(hero.collision_height() == 36 and is_equal_approx(hero.velocity.x,192) and grips_attached(),"F3 height and speed edits affect actual crouching and weapon anchors")
	Input.action_release("core_right")
	await frames(8)
	var line: LineEdit = lab.movement_overlay.rows.crouch_height.number.get_line_edit()
	line.grab_focus()
	Input.action_release("core_crouch")
	await frames(4)
	check(hero.crouching,"numeric editing preserves the current crouched posture")
	line.text_submitted.emit(line.text)
	lab.movement_overlay.toggle()
	await frames(3)
	check(not hero.crouching,"finishing editing restores normal crouch input")
	Input.action_press("core_crouch")
	await frames(3)
	paused = true
	Input.action_release("core_crouch")
	var frozen := [hero.position,hero.collision_height(),hero.body.frame]
	await frames(6)
	check(frozen == [hero.position,hero.collision_height(),hero.body.frame],"pause freezes the crouched body and collider")
	paused = false
	hero.reset_to(Vector2(1800,760))
	check(not hero.crouching and hero.collision_height() == 64,"respawn restores standing and the normal collider")
	release()
	hero.weapon.reset_state()
	await create_timer(.15).timeout
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
