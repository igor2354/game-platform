extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var field: CoreFuelField
var checks := 0
var failures := 0
var fixtures: Array[Node] = []
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
func barrel_at(point: Vector2,kind := 0) -> CoreExplosiveBarrel:
	var barrel: CoreExplosiveBarrel = load("res://scenes/core/explosive_barrel.tscn").instantiate()
	barrel.position = point
	barrel.contents = kind
	barrel.tuning = lab.ragdoll_settings
	lab.level.add_child(barrel)
	fixtures.append(barrel)
	return barrel
func clean() -> void:
	for action in ["core_fire","core_aim","core_grab","core_left","core_right"]: Input.action_release(action)
	hero.reset_to(Vector2(160,760))
	for node in fixtures:
		if is_instance_valid(node):
			if node is CoreExplosiveBarrel:
				for piece in node.debris:
					if is_instance_valid(piece): piece.queue_free()
			node.queue_free()
	fixtures.clear()
	field.clear_fuel()
	lab.ragdoll_settings.apply_values(lab.ragdoll_overlay.defaults.as_dictionary())
	lab.ragdoll_settings.explosion_audio_enabled = false
	lab.ragdoll_settings.explosion_camera_enabled = false
	for bullet in get_nodes_in_group("core_projectiles"): bullet.queue_free()
	await frames(3)
func shot_at(point: Vector2) -> void:
	hero.weapon.aim_override = point
	await frames(2)
	hero.weapon._fire()
	await frames(12)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	field = lab.level.fuel_field
	hero.weapon.tuning.apply_values({"sound_enabled":false,"recoil_enabled":false,"sway_radius":0,"hip_spread":0,"hip_max_spread":0,"magazine_enabled":false})
	await clean()
	var variants: Array[CoreExplosiveBarrel] = []
	for kind in 4: variants.append(barrel_at(Vector2(-1200+kind*130,732),kind))
	await frames(12)
	var colours := {}
	for barrel in variants: colours[barrel.shell_color()] = true
	check(colours.size() == 4,"all four barrel types have distinct shell colours")
	check(variants.all(func(b): return b is RigidBody2D and b.mass == 10 and b.shape_node.shape.get_rect() == variants[0].shape_node.shape.get_rect()),"all contents share one physical body and silhouette")
	for index in [1,2]:
		variants[index].take_projectile_damage(100,hero)
		check(variants[index].destroyed and not variants[index].armed and not variants[index].leaking and not variants[index].arm(),"empty/inert shells break without leakage or detonation")
	check(get_nodes_in_group("core_explosions").is_empty(),"destroying nonfuel barrels creates no explosion")
	await clean()
	lab.ragdoll_settings.fuel_capacity = 300
	# Isolate the optional spill/fire path from direct bullet detonation.
	lab.ragdoll_settings.fuel_projectile_detonation_enabled = false
	var fuel := barrel_at(Vector2(-1100,732))
	lab.ragdoll_settings.barrel_leak_hits = 2
	hero.reset_to(Vector2(-1280,760))
	await frames(12)
	await shot_at(fuel.global_position)
	check(fuel.projectile_hits == 1 and not fuel.leaking and not fuel.armed,"a real first shot respects the two-hit perforation setting")
	await shot_at(fuel.global_position)
	fuel.freeze = true
	await frames(35)
	check(fuel.projectile_hits == 2 and fuel.leaking and not fuel.destroyed and not fuel.armed,"second bullet perforates the fuel shell without prematurely exploding it")
	check(field.cells.size() > 3 and fuel.fuel_left < lab.ragdoll_settings.fuel_capacity,"a stationary leaking barrel deposits an actual ground puddle and consumes fuel")
	var count := field.cells.size()
	await frames(100)
	check(field.cells.size() > count and field.ignitions == 0,"the puddle grows while the perforated barrel stands still")
	var leftmost := Vector2.INF
	for cell in field.cells.values():
		if cell.point.x < leftmost.x: leftmost = cell.point
	await shot_at(leftmost)
	await frames(110)
	check(field.ignitions > 0 and fuel.destroyed and fuel.instigator == hero,"a real projectile ignites the puddle and its fire detonates the fuel barrel with player credit")
	await clean()
	# A long connected path, a tank at its end, and a disconnected puddle.
	fuel = barrel_at(Vector2(-1000,732))
	for x in range(-1400,-990,5): field.deposit(Vector2(x,700),4)
	field.deposit(Vector2(-2300,700),20)
	var total := field.cells.size()
	check(field.ignite_at(Vector2(-1400,758),hero),"fuel can be ignited at a chosen point of its trail")
	await frames(12)
	check(field.ignitions > 0 and field.ignitions < total/2 and not fuel.armed,"the flame front travels progressively instead of igniting the whole trail instantly")
	paused = true
	var clock := field.clock
	var ignitions := field.ignitions
	await frames(12)
	check(field.clock == clock and field.ignitions == ignitions,"pause freezes flame propagation and burning")
	paused = false
	await frames(380)
	check(fuel.destroyed,"a flame front reaching the tank detonates it")
	var disconnected_safe := true
	for cell in field.cells.values():
		if cell.point.x < -2250: disconnected_safe = disconnected_safe and cell.ends == 0
	check(disconnected_safe,"a disconnected pool does not ignite from the same trail's propagation")
	check(field.cells.size() == total,"detonation and propagation do not remove the persistent fuel marks")
	lab.ragdoll_settings.fuel_fire_enabled = false
	clock = field.clock
	await frames(12)
	check(field.clock == clock,"the fire switch pauses an existing flame without deleting fuel")
	lab.ragdoll_settings.fuel_fire_enabled = true
	await frames(1100)
	check(field.cells.size() == total and field.burning.is_empty(),"burned areas become permanent scorch marks after flames end")
	await clean()
	# Actual gravity-driven rolling down the new ramp lays a continuous trail.
	for kind in 4:
		var ground := field.ground_below(Vector2(-2990,400))
		var upright := barrel_at(ground.position-Vector2(0,29),kind)
		var upright_start := upright.global_position
		await frames(100)
		check(upright.global_position.x > upright_start.x+30 and upright.global_position.y > upright_start.y+10,"an upright barrel also falls and rolls down the incline without G: "+str(kind))
		upright.queue_free()
		fixtures.erase(upright)
		await frames(2)
		var rolling := barrel_at(ground.position-Vector2(0,24),kind)
		rolling._set_shape(true)
		rolling.leaking = kind == 0
		var start := rolling.global_position
		await frames(90)
		check(rolling.global_position.x > start.x+50 and rolling.global_position.y > start.y+20 and absf(rolling.rotation) > .2,"all barrel contents roll and descend the real slope under gravity: "+str(kind))
		if kind == 0:
			check(field.cells.size() > 15,"a rolling fuel barrel leaves a path along the slope")
			var covered := true
			for cell in field.cells.values():
				var nearest := field.ground_below(cell.point-Vector2(0,6),[rolling.get_rid()],12)
				covered = covered and not nearest.is_empty()
			check(covered,"fuel marks follow world surfaces instead of floating between sample points")
		rolling.freeze = true
		fixtures.erase(rolling)
		rolling.queue_free()
		await frames(2)
	var before := field.cells.size()
	await frames(180)
	check(field.cells.size() == before,"spilled fuel does not disappear after its source has gone")
	await clean()
	# Real rigid-body collisions apply velocity-dependent damage/knockdown.
	var enemy := CoreEnemyDummy.new()
	enemy.position = Vector2(-1000,760)
	lab.level.add_child(enemy)
	fixtures.append(enemy)
	var moving := barrel_at(Vector2(-1190,736),1)
	moving._set_shape(true)
	await frames(4)
	moving.linear_velocity = Vector2(450,0)
	moving.angular_velocity = 450.0/24
	await frames(38)
	check(enemy.health < 100 and moving.impact_count > 0,"a real rolling barrel collision damages an enemy")
	check(enemy.is_knocked_down(),"a fast real collision knocks the enemy down")
	var hp := enemy.health
	await frames(8)
	check(enemy.health == hp,"one contact cannot deal damage every physics tick")
	await clean()
	hero.reset_to(Vector2(-1000,760))
	moving = barrel_at(Vector2(-1190,736),2)
	moving._set_shape(true)
	await frames(4)
	moving.linear_velocity = Vector2(450,0)
	moving.angular_velocity = 450.0/24
	await frames(38)
	check(hero.health < 100 and hero.barrel_knockdown_left > 0 and hero.mode == "knocked_down" and hero.collision_height() == 32,"a fast barrel also damages and visibly knocks the player down")
	var shots := hero.weapon.shots_fired
	hero.weapon._fire()
	check(hero.weapon.shots_fired == shots and not hero.dash_available(),"the knocked-down player cannot fire or dash before recovery")
	moving.freeze = true
	await frames(130)
	check(hero.barrel_knockdown_left == 0 and hero.collision_height() == 64,"player recovers from the temporary physical knockdown")
	await clean()
	lab._recover()
	await frames(4)
	check(field.cells.is_empty() and field.burning.is_empty() and lab.level.explosive_barrels.all(func(b): return not b.destroyed and not b.leaking and not b.side_on),"F8 restores all barrel variants and clears fuel, flames and shell debris")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
