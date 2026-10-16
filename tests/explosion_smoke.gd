extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
var fixtures: Array[Node] = []
var directory := "/private/tmp/explosions-%d" % OS.get_process_id()
const ORIGIN := Vector2(-1200,728)

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func profile() -> CoreExplosionSettings:
	var p := CoreExplosionSettings.new()
	p.explosion_audio_enabled = false
	p.explosion_visuals_enabled = false
	p.explosion_camera_enabled = false
	p.explosion_character_push = 0
	p.explosion_stun_duration = 0
	p.explosion_impulse = 0
	# This suite isolates the primary blast; the outer wave and articulated
	# response have their own blast_ragdoll_smoke coverage.
	p.explosion_shockwave_enabled = false
	p.explosion_ragdoll_enabled = false
	p.explosion_sever_enabled = false
	p.explosion_damage = 40
	return p
func enemy_at(point: Vector2) -> CoreEnemyDummy:
	var enemy := CoreEnemyDummy.new()
	enemy.position = point
	lab.level.add_child(enemy)
	fixtures.append(enemy)
	return enemy
func wall_at(point: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = point
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,150)
	collider.shape = shape
	body.add_child(collider)
	lab.level.add_child(body)
	fixtures.append(body)
	return body
func clear() -> void:
	for action in ["core_fire","core_grab","core_right","core_left"]: Input.action_release(action)
	hero.reset_to(Vector2(600,760))
	for node in fixtures:
		if is_instance_valid(node): node.queue_free()
	fixtures.clear()
	for node in get_nodes_in_group("core_explosions"): node.queue_free()
	# Fixtures can include a destructible prop with persistent sibling chips.
	for node in get_nodes_in_group("crate_debris"): node.queue_free()
	await frames(3)
func shoot(barrel: CoreExplosiveBarrel) -> void:
	hero.weapon.aim_override = barrel.global_position
	await frames(2)
	hero.weapon._fire()
	await frames(12)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	lab.settings_path = directory+"/movement.cfg"
	lab.shooting_settings_path = directory+"/shooting.cfg"
	lab.camera_settings_path = directory+"/camera.cfg"
	lab.zombie_settings_path = directory+"/zombie.cfg"
	lab.ragdoll_settings_path = directory+"/physics.cfg"
	root.add_child(lab)
	hero = lab.player
	await clear()
	var near := enemy_at(ORIGIN+Vector2(60,32))
	var far := enemy_at(ORIGIN+Vector2(185,32))
	var outside := enemy_at(ORIGIN+Vector2(320,32))
	await frames(3)
	var p := profile()
	var blast := CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(near.health < far.health and far.health < 100 and outside.health == 100,"blast damage decreases with distance and stops outside its radius")
	check(near.received_hits == 1 and far.received_hits == 1,"body and limb hit zones cannot multiply explosion damage")
	check(is_equal_approx(100-near.health,p.explosion_damage*blast.affected[near.get_instance_id()]),"damage matches the sampled surface falloff")
	check(blast.strength_at(0) == 1 and blast.strength_at(40) == 1 and blast.strength_at(240) == 0,"full-damage core and outer boundary are defined")
	var hp := near.health
	blast.detonate()
	check(near.health == hp and near.received_hits == 1,"a blast resolves only once")
	p.explosion_radius = 800
	p.explosion_damage = 500
	check(blast.tuning.explosion_radius == 240 and blast.tuning.explosion_damage == 40,"detonation snapshots settings for an independent effect")
	await clear()
	near = enemy_at(ORIGIN+Vector2(85,32))
	wall_at(ORIGIN+Vector2(40,0))
	await frames(3)
	p = profile()
	blast = CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(near.health == 100 and not blast.affected.has(near.get_instance_id()),"solid wall blocks damage and impulse")
	p.explosion_occlusion_enabled = false
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(near.health < 100,"the cover switch independently disables shielding")
	await clear()
	near = enemy_at(ORIGIN+Vector2(120,32))
	var crate = load("res://scenes/core/physics_crate.tscn").instantiate()
	crate.position = ORIGIN+Vector2(45,0)
	lab.level.add_child(crate)
	fixtures.append(crate)
	await frames(3)
	p = profile()
	p.explosion_damage = 500
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(crate.destroyed and near.health == 100,"cover destroyed by this blast still shields a target during the same wave")
	await clear()
	var light := RigidBody2D.new()
	light.mass = .05
	light.gravity_scale = 0
	light.position = ORIGIN+Vector2(60,0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8,8)
	collider.shape = shape
	light.add_child(collider)
	lab.level.add_child(light)
	fixtures.append(light)
	await frames(3)
	p = profile()
	p.explosion_damage = 0
	p.explosion_impulse = 5000
	p.explosion_prop_speed_limit = 200
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	await frames(2)
	check(light.linear_velocity.x > 20 and light.linear_velocity.length() <= 200.1,"blast moves rigid bodies with a mass-aware speed cap")
	await clear()
	var doll = load("res://scenes/core/ragdoll_mannequin.tscn").instantiate()
	doll.position = Vector2(ORIGIN.x,760)
	lab.level.add_child(doll)
	fixtures.append(doll)
	await frames(3)
	p.explosion_occlusion_enabled = false
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	await frames(2)
	check(doll.active and doll.parts.values().all(func(part): return not part.freeze and part.linear_velocity.is_finite()),"blast activates the ragdoll and keeps impulses finite")
	doll.reset_mannequin()
	doll.set_simulation_enabled(false)
	await frames(2)
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(not doll.active and doll.parts.values().all(func(part): return part.freeze),"disabled ragdoll simulation rejects blast impulses")
	await clear()
	hero.reset_to(ORIGIN+Vector2(60,32))
	await frames(4)
	p = profile()
	p.explosion_damage = 20
	p.explosion_character_push = 200
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(hero.health < 100 and hero.shove_left > 0 and hero.velocity.x > 0,"player receives radial damage and a physical shove")
	hero.reset_to(ORIGIN+Vector2(60,32))
	hero.set_invulnerable(true)
	await frames(3)
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(hero.health == 100 and hero.shove_left > 0,"player immortality blocks HP loss but preserves shove")
	hero.set_invulnerable(false)
	hero.reset_to(ORIGIN+Vector2(60,32))
	await frames(3)
	p.explosion_player_damage_enabled = false
	CoreExplosion.spawn(lab.level,ORIGIN,p)
	check(hero.health == 100 and hero.shove_left > 0,"player damage switch is independent from blast force")
	await clear()
	var zombie: CoreZombie = load("res://scenes/core/zombie.tscn").instantiate()
	zombie.position = ORIGIN+Vector2(80,32)
	lab.level.add_child(zombie)
	zombie.target = hero
	zombie.tuning.movement_enabled = false
	zombie.tuning.combat_enabled = false
	fixtures.append(zombie)
	await frames(3)
	p = profile()
	p.explosion_damage = 15
	p.explosion_stun_duration = 1
	p.explosion_character_push = 100
	CoreExplosion.spawn(lab.level,ORIGIN,p,null,hero)
	check(zombie.health < 100 and zombie.is_stunned() and zombie.is_knocked_down(),"surviving zombie takes damage, is knocked down and uses shared stun")
	check(hero.weapon.hits == 1 and hero.weapon.kills == 0,"explosive damage is credited to the attacking player once")
	await clear()
	near = enemy_at(ORIGIN+Vector2(30,32))
	await frames(3)
	p = profile()
	p.explosion_damage = 200
	CoreExplosion.spawn(lab.level,ORIGIN,p,null,hero)
	check(near.health == 0 and hero.weapon.kills == 1,"explosive kill is credited to the original player")
	await clear()
	p = profile()
	p.explosions_enabled = false
	check(CoreExplosion.spawn(lab.level,ORIGIN,p) == null,"global explosion switch prevents blasts")
	p.explosions_enabled = true
	paused = true
	check(CoreExplosion.spawn(lab.level,ORIGIN,p) == null,"direct API cannot bypass pause")
	paused = false
	check(CoreExplosion.spawn(lab.level,Vector2(NAN,0),p) == null,"invalid origins cannot corrupt the world")
	# Real barrel shots and an asynchronous two-barrel chain.
	var barrel := lab.level.explosive_barrels[1]
	var neighbor := lab.level.explosive_barrels[0]
	lab.ragdoll_settings.explosion_audio_enabled = false
	lab.ragdoll_settings.explosion_visuals_enabled = false
	lab.ragdoll_settings.explosion_camera_enabled = false
	lab._reset_explosives()
	hero.reset_to(CoreMovementLevel.EXPLOSION_TEST_SPAWN)
	hero.weapon.tuning.hip_spread = 0
	hero.weapon.tuning.hip_max_spread = 0
	hero.weapon.tuning.recoil_enabled = false
	await frames(12)
	await shoot(barrel)
	check(barrel.health == 25 and not barrel.armed,"one real bullet damages but does not detonate a 50 HP barrel")
	await shoot(barrel)
	await frames(45)
	check(barrel.destroyed and not barrel.leaking,"second shot detonates the explosive barrel without leaking fuel")
	check(barrel.destroyed and neighbor.destroyed,"a shot detonates the explosive barrel and chains to its explosive neighbour")
	check(barrel.debris.size() == 12 and neighbor.debris.size() == 12,"both barrels leave persistent passable metal fragments")
	check(barrel.instigator == hero and neighbor.instigator == hero,"chain retains the player responsible for the first detonation")
	barrel.take_damage(500)
	barrel.arm()
	check(barrel.debris.size() == 12,"destroyed barrel cannot duplicate its explosion or fragments")
	lab._reset_explosives()
	lab.ragdoll_settings.explosion_chain_enabled = false
	await frames(5)
	barrel.arm()
	await frames(40)
	check(barrel.destroyed and not neighbor.destroyed and neighbor.health == 50,"chain switch preserves neighboring barrel health")
	lab._reset_explosives()
	lab.ragdoll_settings.barrel_fuse = .4
	await frames(4)
	barrel.arm()
	await frames(3)
	var fuse := barrel.fuse_left
	paused = true
	await frames(25)
	check(barrel.armed and barrel.fuse_left == fuse and not barrel.destroyed,"pause freezes an armed barrel fuse")
	paused = false
	lab.ragdoll_settings.explosions_enabled = false
	await frames(35)
	check(barrel.armed and barrel.fuse_left == fuse,"global switch suspends an already armed fuse")
	lab.ragdoll_settings.explosions_enabled = true
	await frames(35)
	check(barrel.destroyed,"reenabling resumes the committed fuse")
	lab._recover()
	await frames(5)
	check(lab.level.explosive_barrels.all(func(b): return not b.destroyed and not b.armed and b.health == 50 and b.can_grab()) and get_nodes_in_group("core_explosions").is_empty(),"F8 cancels waves and fuses, restores barrels and clears their fragments")
	check(get_nodes_in_group("crate_debris").is_empty(),"arena reset removes persistent barrel debris")
	# A silent-for-the-player explosion still enters zombie hearing.
	var listener := lab.level.zombie
	hero.reset_to(Vector2(590,760))
	listener.tuning.vision_enabled = false
	listener.tuning.movement_enabled = false
	listener.reset_target()
	p = profile()
	p.explosion_radius = 40
	p.explosion_damage = 0
	CoreExplosion.spawn(lab.level,listener.global_position+Vector2(-450,-32),p)
	check(listener.last_heard_kind == "explosion" and listener.noise_memory_left > 0,"explosion emits gameplay noise even when its audio is disabled")
	var stream := CoreCombatAudio.make_stream("explosion")
	check(stream.data.size() > 30000 and stream.mix_rate == 22050,"explosion has a dedicated procedural audio tail")
	await clear()
	lab.queue_free()
	await process_frame
	DirAccess.remove_absolute(directory)
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
