extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var crate: RigidBody2D
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
func reset_box(distance := 125.0) -> void:
	for action in ["core_grab","core_right","core_left"]: Input.action_release(action)
	hero.reset_to(Vector2(-800-distance,760))
	crate.home_transform = Transform2D(0,Vector2(-800,728))
	crate.reset_crate()
	await frames(12)
func shoot() -> void:
	hero.weapon.aim_override = crate.global_position
	await frames(2)
	hero.weapon._fire()
	await frames(14)
func impact(amount: float,damage_enabled := true) -> void:
	CoreProjectile.resolve_impact({"collider":crate,"position":crate.global_position-Vector2(32,0)},amount,Vector2.RIGHT,hero.weapon._on_impact,hero.position,damage_enabled)
func environment_hit(point: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(point-Vector2(0,50),point+Vector2(0,50),1,[hero.get_rid()])
	return hero.get_world_2d().direct_space_state.intersect_ray(query)

func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	crate = lab.level.physics_crate
	hero.weapon.tuning.hip_spread = 0
	hero.weapon.tuning.hip_max_spread = 0
	hero.weapon.tuning.recoil_enabled = false
	await reset_box()
	check(crate.health == 100 and crate.max_health == 100 and not crate.destroyed,"crate starts with its own 100 HP")
	check(crate.visible and crate.can_grab() and crate.collision_layer == 1,"intact crate remains visible, solid and grabbable")
	var before_shot := crate.position
	await shoot()
	check(crate.health == 75 and not crate.destroyed,"a real 25 damage bullet removes exactly 25 crate HP")
	check(hero.weapon.hits == 0 and hero.weapon.kills == 0,"crate damage does not count as an enemy hit or kill")
	check(crate.position.x > before_shot.x+.2,"nonlethal shots retain physical impact before friction settles the body")
	hero.weapon.tuning.damage_enabled = false
	await shoot()
	check(crate.health == 75,"the weapon damage switch also disables crate damage")
	hero.weapon.tuning.damage_enabled = true
	crate.take_damage(0)
	crate.take_damage(-5)
	crate.take_damage(NAN)
	crate.take_damage(INF)
	check(crate.health == 75,"invalid damage cannot heal, corrupt or destroy the crate")
	await shoot()
	await shoot()
	check(crate.health == 25 and not crate.destroyed and crate.visible,"crate survives until the last of its HP")
	var destroyed_at := crate.global_position
	await shoot()
	check(crate.health == 0 and crate.destroyed and not crate.visible,"the fourth damaging bullet destroys the crate")
	check(crate.collision_layer == 0 and crate.collision_mask == 0 and not crate.can_grab(),"destroyed crate immediately stops blocking rays, movement and grabs")
	check(crate.debris.size() == crate.DEBRIS_COUNT and get_nodes_in_group("crate_debris").size() == crate.DEBRIS_COUNT,"one destruction spawns the configured physical fragments")
	var ids := {}
	var physical := true
	var finite := true
	for fragment in crate.debris:
		ids[fragment.get_instance_id()] = true
		physical = physical and fragment is RigidBody2D and not fragment.freeze and fragment.mass > 0 and fragment.collision_layer == CoreCrateDebris.COLLISION_LAYER
		finite = finite and fragment.global_position.is_finite() and fragment.linear_velocity.is_finite()
	check(physical and finite,"fragments have real mass, colliders, gravity and finite launch velocity")
	check(hero.weapon.hits == 0 and hero.weapon.kills == 0,"destruction preserves enemy-only hit and kill statistics")
	crate.take_damage(500)
	impact(500)
	await frames(2)
	check(crate.health == 0 and crate.debris.size() == crate.DEBRIS_COUNT,"extra damage cannot destroy twice or duplicate debris")
	var ray := environment_hit(destroyed_at)
	check(ray.get("collider") != crate,"a real physics ray no longer hits the destroyed box")
	await frames(900)
	var persistent: bool = get_nodes_in_group("crate_debris").size() == crate.DEBRIS_COUNT
	for fragment in crate.debris:
		persistent = persistent and is_instance_valid(fragment) and ids.has(fragment.get_instance_id()) and fragment.visible
		finite = finite and fragment.global_position.is_finite() and fragment.global_position.y < 780
	check(persistent,"the same debris remains after fifteen seconds, with no lifetime cleanup")
	check(finite,"persistent pieces settle above the solid floor")
	var fragment: RigidBody2D = crate.debris[0]
	fragment.receive_projectile_impulse(Vector2.UP,fragment.global_position,25)
	await frames(2)
	check(fragment.linear_velocity.y < 0,"settled debris can be disturbed by another bullet")
	paused = true
	var transforms := []
	for piece in crate.debris: transforms.append(piece.global_transform)
	await frames(12)
	var stationary := true
	for i in crate.debris.size(): stationary = stationary and transforms[i].is_equal_approx(crate.debris[i].global_transform)
	check(stationary and get_nodes_in_group("crate_debris").size() == crate.DEBRIS_COUNT,"pause freezes fragments without removing them")
	paused = false
	lab._respawn_enemies()
	await frames(2)
	check(crate.destroyed and get_nodes_in_group("crate_debris").size() == crate.DEBRIS_COUNT,"enemy-only respawn preserves the destroyed box and its debris")
	lab._recover()
	await frames(12)
	check(not crate.destroyed and crate.health == 100 and crate.visible and crate.can_grab(),"full arena reset restores the same crate with full HP")
	check(crate.debris.is_empty() and get_nodes_in_group("crate_debris").is_empty(),"only explicit arena reset clears the old fragments")
	check(crate.collision_layer == 1 and crate.collision_mask == 15 and not crate.freeze,"reset restores the original physical collisions")
	await reset_box()
	crate.max_health = 180
	crate.reset_crate()
	await frames(4)
	check(crate.health == 180,"max_health in the inspector controls HP restored by reset")
	impact(200)
	await frames(2)
	check(crate.destroyed and crate.health == 0 and crate.debris.size() == crate.DEBRIS_COUNT,"overkill clamps HP to zero and still creates one debris set")
	crate.max_health = 100
	await reset_box(46)
	Input.action_press("core_grab")
	await frames(1)
	Input.action_release("core_grab")
	await frames(6)
	check(hero.pushing and hero.push_target == crate,"the intact destructible crate still supports two-handed G grabbing")
	impact(100)
	await frames(2)
	check(not hero.pushing and hero.push_target == null,"destroying a held crate safely releases both hands")
	check(hero.body.state not in ["push","pull"] and not hero.weapon.reloading,"normal animation returns after destruction")
	await reset_box(46)
	hero.weapon.aim_override = crate.position
	await frames(3)
	var projectile_count := get_nodes_in_group("core_projectiles").size()
	hero.weapon._fire()
	check(crate.health == 75 and get_nodes_in_group("core_projectiles").size() == projectile_count,"close-range muzzle collision uses the same crate damage path")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
