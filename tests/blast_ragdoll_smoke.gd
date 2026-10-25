extends SceneTree
var lab: CoreMovementLab
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
	for index in count:
		await physics_frame
		await process_frame
func enemy(point: Vector2,zombie := false) -> CoreEnemyDummy:
	var actor: CoreEnemyDummy = CoreZombie.new() if zombie else CoreEnemyDummy.new()
	actor.position = point
	if zombie:
		actor.target = lab.player
		actor.tuning.movement_enabled = false
		actor.tuning.combat_enabled = false
	lab.level.add_child(actor)
	fixtures.append(actor)
	return actor
func wall(x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x,690)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,170)
	collider.shape = shape
	body.add_child(collider)
	lab.level.add_child(body)
	fixtures.append(body)
	return body
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	var directory := (OS.get_environment("TEMP") if OS.has_feature("windows") else "/private/tmp").path_join("blast_ragdoll_smoke-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,directory.path_join(key+".cfg"))
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	await frames(10)
	var profile := CoreExplosionSettings.new()
	profile.apply_values({"explosion_audio_enabled":false,"explosion_radius":80,"explosion_full_damage_radius":40,"explosion_shockwave_radius":300,"explosion_shockwave_damage":40,"explosion_sever_enabled":false,"explosion_ragdoll_min_distance":0,"explosion_chain_enabled":false,"explosion_ragdoll_duration":.5})
	var target := enemy(Vector2(5200,760))
	target.set_current_health(10)
	lab.player.reset_to(Vector2(4800,760))
	lab.player.set_current_health(10)
	await frames(3)
	var blast := CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health == 1 and lab.player.health == 1,"outer shockwave harms both player and enemy but cannot kill even at 10 HP")
	check(target.blast_ragdoll.active and lab.player.blast_ragdoll.active,"surviving player and enemy enter real articulated ragdoll")
	check(target.blast_ragdoll.rig.parts.size() == 13 and target.blast_ragdoll.rig.joints.size() == 12 and target.blast_ragdoll.rig.parts.values().all(func(part): return part is RigidBody2D and not part.freeze),"ragdoll consists of thirteen simulated bodies and twelve native joints")
	check(target.collision_layer == 0 and not lab.player.visuals.visible and target.hit_zones.values().all(func(zone): return zone.collision_layer == 0),"ragdoll replaces the old combat collider and visual without leaving duplicate bodies")
	var pelvis: RigidBody2D = target.blast_ragdoll.rig.parts.pelvis
	var start := pelvis.global_position
	await frames(15)
	check(pelvis.global_position.distance_to(start) > 20 and target.position.x > 5200,"blast impulse moves physical limbs and the logical combat target follows them")
	check(lab.player.weapon.shots_fired == 0,"the knocked-away player cannot fire a weapon during ragdoll")
	await frames(300)
	check(not target.blast_ragdoll.active and target.health == 1 and target.collision_layer == 4,"a surviving enemy safely recovers and restores its combat collider")
	check(not lab.player.blast_ragdoll.active and lab.player.health == 1 and lab.player.visuals.visible and lab.player.collision_layer == 2,"player recovers standing with control and preserved HP")
	target.reset_target()
	target.position = Vector2(5200,760)
	lab.player.reset_to(Vector2(4800,760))
	var cover := wall(5100)
	await frames(5)
	blast = CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health == 100 and not target.blast_ragdoll.active and not blast.affected.has(target.get_instance_id()),"a wall blocks all outer-wave damage and ragdoll activation")
	cover.queue_free()
	await frames(3)
	lab.player.reset_to(Vector2(4500,760))
	profile.explosion_shockwave_enabled = false
	blast = CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health == 100 and not target.blast_ragdoll.active,"the shockwave switch removes the outer blast area")
	profile.explosion_shockwave_enabled = true
	profile.explosion_ragdoll_enabled = false
	blast = CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health < 100 and not target.blast_ragdoll.active,"ragdoll can be disabled while keeping outer-wave damage and knockback")
	target.reset_target()
	target.position = Vector2(5200,760)
	target.set_invulnerable(true)
	profile.explosion_ragdoll_enabled = true
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health == 100 and target.blast_ragdoll.active,"enemy immortality preserves HP while allowing physical ragdoll")
	var hits := target.received_hits
	var torso: RigidBody2D = target.blast_ragdoll.rig.parts.torso
	var query := PhysicsRayQueryParameters2D.create(torso.global_position-Vector2(15,0),torso.global_position+Vector2(15,0),128)
	var hit := lab.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): CoreProjectile.resolve_impact(hit,15,Vector2.RIGHT,Callable(),Vector2.ZERO,true,lab.player)
	check(not hit.is_empty() and target.received_hits == hits+1 and target.health == 100,"bullets hitting physical ragdoll parts still resolve to the enemy's HP and immortality")
	target.set_test_frozen(true)
	await frames(3)
	var frozen: Transform2D = target.blast_ragdoll.rig.parts.pelvis.global_transform
	await frames(30)
	check(target.blast_ragdoll.rig.parts.pelvis.global_transform.is_equal_approx(frozen),"global enemy freeze also suspends every ragdoll segment")
	target.set_test_frozen(false)
	await frames(8)
	check(not target.blast_ragdoll.rig.parts.pelvis.freeze,"unfreezing resumes physical segments")
	target.reset_target()
	target.set_invulnerable(false)
	target.position = Vector2(5020,760)
	profile.explosion_damage = 20
	profile.explosion_sever_enabled = true
	profile.explosion_sever_chance = 1
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.health > 0 and target.health < 100 and target.missing_parts.size() == 4,"a full-strength blast uses the configured per-limb sever chance")
	check(target.blast_ragdoll.active and target.blast_ragdoll.rig.parts.left_thigh.visible == false,"severed legs are not visually regrown by the physical body")
	target.reset_target()
	target.position = Vector2(5020,760)
	profile.explosion_sever_enabled = false
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(target.missing_parts.is_empty(),"limb severing can be disabled independently")
	target.reset_target()
	target.position = Vector2(5200,760)
	profile.explosion_radius = 80
	var zombie := enemy(Vector2(5200,760),true)
	target.position = Vector2(5600,760)
	await frames(4)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(zombie.blast_ragdoll.active and zombie.health < 100,"zombies use the same articulated blast ragdoll as human opponents")
	await frames(300)
	check(not zombie.blast_ragdoll.active and zombie.health > 0,"a surviving zombie returns from ragdoll to its AI")
	profile.explosion_ragdoll_enabled = false
	var inside := enemy(Vector2(5094,760))
	var outside := enemy(Vector2(5098,760))
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(inside.health <= outside.health and outside.health < 100,"damage stays continuous when crossing from the primary blast into its outer wave")
	profile.explosion_ragdoll_enabled = true
	lab.player.reset_to(Vector2(4800,760))
	profile.explosion_player_damage_enabled = false
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(lab.player.health == 100 and lab.player.blast_ragdoll.active,"player-damage switch preserves physical shockwave feedback")
	lab._recover()
	check(not lab.player.blast_ragdoll.active and lab.player.visuals.visible and lab.player.collision_layer == 2,"F8 removes the player's physical proxy and restores normal controls")
	profile.explosion_player_damage_enabled = true
	profile.explosion_radius = 240
	profile.explosion_damage = 500
	lab.player.reset_to(Vector2(4800,760))
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	check(lab.player.health == 0 and lab.player.blast_ragdoll.active,"a lethal primary blast keeps a physical player corpse until revival")
	lab.player.set_current_health(100)
	check(not lab.player.blast_ragdoll.active and lab.player.collision_layer == 2 and lab.player.visuals.visible,"healing a dead ragdoll player restores its movement collider and visuals")
	lab.player.reset_to(Vector2(4800,760))
	await frames(3)
	CoreExplosion.spawn(lab.level,Vector2(5000,724),profile)
	lab._recover()
	check(lab.player.health == 100 and lab.player.collision_layer == 2 and not lab.player.blast_ragdoll.active,"F8 restores the player collider after a lethal ragdoll explosion")
	for fixture in fixtures:
		if is_instance_valid(fixture): fixture.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
