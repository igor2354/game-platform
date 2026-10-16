extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var field: CoreFuelField
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
	for tick in count:
		await physics_frame
		await process_frame
func wall_at(point: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = point
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(5,110)
	collider.shape = rect
	wall.add_child(collider)
	lab.level.add_child(wall)
	return wall
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	field = lab.level.fuel_field
	var tuning := lab.ragdoll_settings
	tuning.explosion_audio_enabled = false
	hero.weapon.tuning.apply_values({"recoil_enabled":false,"hip_spread":0,"hip_max_spread":0,"sound_enabled":false})
	await frames(6)
	var barrel: CoreExplosiveBarrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	barrel.position = Vector2(-1100,732)
	barrel.tuning = tuning
	lab.level.add_child(barrel)
	barrel.freeze = true
	barrel.take_projectile_damage(25,hero)
	await frames(30)
	check(barrel.leaking and field.cells.size() > 0 and is_inf(barrel.fuel_left),"one accepted hit starts leakage; the default trail has no fuel/time expiry")
	var count := field.cells.size()
	var keys := field.cells.keys()
	tuning.fuel_leak_enabled = false
	barrel.position.x += 150
	await frames(30)
	check(field.cells.size() == count,"leak switch preserves old marks and creates no new ones")
	tuning.fuel_leak_enabled = true
	await frames(12)
	var empty_gap := true
	for cell in field.cells.values():
		if cell.point.x > -1060 and cell.point.x < -990: empty_gap = false
	check(empty_gap,"reenabling leakage does not paint a retroactive trail across the disabled interval")
	barrel.queue_free()
	await frames(2)
	field.clear_fuel()
	field.deposit(Vector2(-1200,700),36)
	count = field.cells.size()
	hero.reset_to(Vector2(-1400,760))
	var wall := wall_at(Vector2(-1300,710))
	await frames(4)
	hero.weapon.aim_override = Vector2(-1200,758)
	await frames(2)
	hero.weapon._fire()
	await frames(20)
	check(field.ignitions == 0,"a real bullet blocked by a wall cannot ignite fuel behind it")
	wall.queue_free()
	await frames(2)
	hero.weapon._fire()
	await frames(90)
	check(field.ignitions == count and field.burning.size() == count,"a real unblocked shot spreads fire over the entire connected puddle")
	lab._respawn_enemies()
	check(field.cells.size() == count,"enemy respawn preserves spilled fuel and burning puddles")
	field.clear_fuel()
	hero.reset_to(Vector2(160,760))
	var enemy := CoreEnemyDummy.new()
	enemy.position = Vector2(-1200,760)
	lab.level.add_child(enemy)
	field.deposit(Vector2(-1200,700),38)
	field.ignite_at(Vector2(-1200,758),hero)
	await frames(15)
	check(enemy.received_hits == 1 and enemy.health < 100,"many burning fuel cells apply only one damage tick per exposed actor")
	var hp := enemy.health
	enemy.set_invulnerable(true)
	await frames(60)
	check(enemy.health == hp,"enemy immortality also protects against burning fuel")
	field.clear_fuel()
	enemy.queue_free()
	await frames(2)
	for kind in [1,2]:
		barrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
		barrel.contents = kind
		barrel.position = Vector2(-1200,732)
		barrel.tuning = tuning
		lab.level.add_child(barrel)
		check(not barrel.ignite_from_fire(hero) and not barrel.arm(),"empty/inert contents cannot be armed by any fire API")
		barrel.queue_free()
	await frames(2)
	barrel = load("res://scenes/core/fuel_barrel.tscn").instantiate()
	barrel.position = Vector2(-1200,732)
	barrel.tuning = tuning
	lab.level.add_child(barrel)
	barrel.freeze = true
	hero.reset_to(Vector2(-1000,760))
	tuning.barrel_impact_enabled = false
	barrel._hit_actor(hero,400,Vector2.RIGHT)
	check(hero.health == 100 and hero.barrel_knockdown_left == 0,"impact switch independently disables collision damage and knockdown")
	tuning.barrel_impact_enabled = true
	barrel._hit_actor(hero,20,Vector2.RIGHT)
	check(hero.health == 100 and hero.barrel_knockdown_left == 0,"a slow or resting barrel cannot damage or knock down the player")
	hero.set_invulnerable(true)
	barrel._hit_actor(hero,400,Vector2.RIGHT)
	check(hero.health == 100 and hero.barrel_knockdown_left > 0,"player immortality protects HP while preserving physical knockdown")
	paused = true
	var down := hero.barrel_knockdown_left
	await frames(10)
	check(hero.barrel_knockdown_left == down,"pause freezes player knockdown")
	paused = false
	hero.reset_to(Vector2(160,760))
	check(hero.barrel_knockdown_left == 0,"player respawn clears collision knockdown")
	barrel.queue_free()
	await frames(2)
	lab._recover()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
