extends SceneTree

var lab: CoreMovementLab
var zombie: CoreZombie
var hero: CoreMovementPlayer
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
func reset_case() -> void:
	for action in ["core_left","core_right","core_jump","core_dash"]: Input.action_release(action)
	zombie.reset_target()
	zombie.tuning.apply_values(lab.zombie_overlay.defaults.as_dictionary())
	zombie.tuning.crawl_speed = 0
	zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	hero.reset_to(zombie.home+Vector2(80,0))
func land(side := 0.0) -> bool:
	hero.reset_to(zombie.home+Vector2(side,-80))
	for tick in 90:
		await physics_frame
		if zombie._player_on_top():
			await frames(2)
			return true
	return false
func wait_shove() -> void:
	for tick in 100:
		await physics_frame
		if zombie.shoves_landed > 0: return
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	await frames(8)
	reset_case()
	hero.reset_to(zombie.home+Vector2(0,-100))
	await frames(2)
	check(zombie.shove_left == 0 and not zombie._player_on_top(),"being airborne above the body does not start the warning early")
	check(await land(),"a real falling player lands on the prone zombie's physical body")
	check(zombie.shove_left > 0 and zombie.shoves_landed == 0 and hero.health == 100,"standing on the live body starts a warning rather than an instant shove")
	await frames(8)
	check(zombie.shoves_landed == 0 and zombie._player_on_top(),"default delay gives time to react while standing on the body")
	var start := hero.position
	await wait_shove()
	check(zombie.shoves_landed == 1 and hero.shove_left > 0 and hero.velocity.y < 0 and absf(hero.velocity.x) >= 250 and hero.health == 90 and hero.hurt_left > 0,"the completed warning applies the impulse and exactly 10 damage with normal hit immunity")
	await frames(16)
	check(absf(hero.position.x-start.x) > 30 and not zombie._player_on_top() and hero.health == 90,"the shove displaces the player and does not deal damage again on later frames")
	check(zombie.shove_cooldown_left > 0,"successful shoves have a cooldown instead of repeating every tick")
	await land()
	check(zombie.shoves_landed == 1 and zombie.shove_left == 0,"landing back during cooldown cannot trigger another immediate shove")
	reset_case()
	await land()
	Input.action_press("core_jump")
	await frames(6)
	Input.action_release("core_jump")
	check(zombie.shove_left == 0 and zombie.shoves_landed == 0 and hero.health == 100,"jumping away during the warning cancels both shove and damage")
	reset_case()
	await land()
	Input.action_press("core_dash")
	await frames(3)
	check(hero.dash_left > 0 and zombie.shove_left == 0 and zombie.shoves_landed == 0 and hero.health == 100,"an active dash escapes the warning and remains protected from shove damage")
	Input.action_release("core_dash")
	reset_case()
	await land()
	paused = true
	var timer := zombie.shove_left
	var frozen := hero.position
	await frames(8)
	check(zombie.shove_left == timer and hero.position == frozen and zombie.shoves_landed == 0,"pause freezes warning, player movement and the eventual shove")
	check(not hero.receive_shove(Vector2(260,-180)),"direct shove delivery also respects pause")
	paused = false
	await wait_shove()
	check(zombie.shoves_landed == 1,"the warning resumes normally after unpausing")
	reset_case()
	await land()
	zombie.take_damage(100)
	await frames(40)
	check(zombie.shoves_landed == 0 and zombie.shove_left == 0,"killing the zombie during preparation cancels its shove")
	reset_case()
	for part in ["left_arm","right_arm"]: zombie.take_projectile_hit(50,part)
	hero.reset_to(zombie.home+Vector2(0,-80))
	await frames(80)
	check(hero.is_on_floor() and zombie.shoves_landed == 0 and zombie.shove_left == 0,"an armless living zombie provides safe support and cannot shove")
	reset_case()
	zombie.take_projectile_hit(50,"right_arm")
	await land(4)
	await wait_shove()
	check(zombie.shoves_landed == 1 and hero.velocity.x > 150 and hero.velocity.x < 180 and hero.health == 93.5,"one surviving arm shoves and damages at 65 percent strength")
	await frames(18)
	check(not zombie._player_on_top(),"the weaker one-arm shove still gets the player off the body")
	for side in [-4.0,4.0]:
		reset_case()
		await land(side)
		await wait_shove()
		check(hero.velocity.x*side > 0,"the shove direction follows the player's side, including left and right")
	reset_case()
	hero.reset_to(zombie.home+Vector2(40,0))
	await frames(70)
	check(zombie.shoves_landed == 0 and zombie.shove_left == 0,"standing on the ground beside the crawler does not trigger a shove")
	reset_case()
	zombie.tuning.shove_delay = .15
	zombie.tuning.shove_speed = 400
	zombie.tuning.shove_lift = 260
	zombie.tuning.shove_damage = 27
	await land(4)
	await wait_shove()
	check(zombie.shove_duration == .15 and hero.velocity.x >= 390 and hero.velocity.y < -200 and hero.health == 73,"custom delay, force and damage affect an actual shove")
	reset_case()
	zombie.tuning.shove_damage = 0
	await land()
	await wait_shove()
	check(zombie.shoves_landed == 1 and hero.shove_left > 0 and hero.health == 100,"zero damage keeps the physical shove without health loss")
	reset_case()
	await land()
	hero.hurt_left = 1
	await wait_shove()
	check(zombie.shoves_landed == 1 and hero.shove_left > 0 and hero.health == 100,"existing hit immunity blocks damage while the physical shove still happens")
	reset_case()
	await land()
	hero.health = 5
	var lethal_start := hero.position
	await wait_shove()
	check(hero.health == 0 and zombie.shoves_landed == 1 and not hero.dash_available(),"lethal shove damage defeats the player without negative health")
	await frames(8)
	check(hero.health == 0 and zombie.shoves_landed == 1 and zombie.shove_left == 0 and absf(hero.position.x-lethal_start.x) > 15,"lethal damage retains shove momentum without allowing movement input or repeated damage")
	lab._recover()
	check(hero.health == 100 and hero.hurt_left == 0 and hero.shove_left == 0,"recovery after lethal shove restores health and clears the impulse")
	reset_case()
	await land()
	zombie.tuning.shove_delay = .15
	check(zombie.shove_duration == .45,"editing the next delay preserves an already running warning")
	zombie.reset_target()
	check(zombie.shove_left == 0 and zombie.shoves_landed == 0 and zombie.shove_cooldown_left == 0,"enemy respawn clears warnings, cooldown and shove counters")
	hero.receive_shove(Vector2(260,-180))
	hero.reset_to(CoreMovementLevel.SPAWN)
	check(hero.shove_left == 0 and hero.velocity == Vector2.ZERO,"player recovery clears the impulse and its control lock")
	check(not hero.receive_shove(Vector2(NAN,-180)) and not hero.receive_shove(Vector2(260,INF)),"non-finite impulses are rejected")
	hero.health = 0
	check(not hero.receive_shove(Vector2(260,-180)),"a defeated player cannot receive new shove motion")
	hero.reset_to(CoreMovementLevel.SPAWN)
	zombie.home = lab.level.slopes[1][0].lerp(lab.level.slopes[1][1],.5)-Vector2(0,10)
	zombie.reset_target()
	zombie.tuning.crawl_speed = 0
	zombie.take_projectile_hit(50,"left_leg")
	zombie.state = CoreZombie.State.RECOVERY
	zombie.state_left = 100
	await frames(30)
	hero.reset_to(zombie.body_shape.global_position-Vector2(0,80))
	for tick in 90:
		await physics_frame
		if zombie._player_on_top(): break
	await wait_shove()
	check(zombie.shoves_landed == 1 and hero.shove_left > 0 and absf(zombie.rotation) > .5,"actual support detection and shove also work on the 35° incline")
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
