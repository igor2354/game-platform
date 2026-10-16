extends SceneTree
var lab: CoreMovementLab
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
	for index in count:
		await physics_frame
		await process_frame
func reset() -> void:
	zombie.reset_target()
	zombie.position = Vector2(4800,760)
	await frames(5)
func wait_for_recovery() -> bool:
	for index in 400:
		if zombie.blast_ragdoll.recovering: return true
		if not zombie.blast_ragdoll.active: return false
		await frames(1)
	return false
func blast_grenade() -> void:
	var grenade: CoreGrenade = load("res://scenes/core/grenade.tscn").instantiate()
	grenade.tuning = lab.ragdoll_settings
	grenade.instigator = lab.player
	lab.level.add_child(grenade)
	grenade.global_position = zombie.global_position+Vector2(-70,-15)
	grenade.start_fuse()
	grenade.explode()
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.reset_to(Vector2(4300,760))
	lab.ragdoll_settings.apply_values({"explosion_audio_enabled":false,"grenade_blast_damage":12,"explosion_ragdoll_min_distance":0,"explosion_ragdoll_duration":.3,"explosion_sever_enabled":false})
	zombie = CoreZombie.new()
	zombie.target = lab.player
	zombie.position = Vector2(4800,760)
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"vision_enabled":false,"hearing_enabled":false})
	lab.level.add_child(zombie)
	await frames(10)
	for facing in [-1.0,1.0]:
		for posture in ["standing","walking","winding_up","crawling"]:
			await reset()
			zombie.facing = facing
			if posture == "walking": zombie.velocity.x = 50; zombie.walk_phase = 1.2
			if posture == "winding_up": zombie.state = CoreZombie.State.WINDUP; zombie.state_left = .2
			if posture == "crawling": zombie._sever_part("left_leg",Vector2.LEFT); zombie.rotation = -.3
			var snapshot := zombie.blast_ragdoll.capture_pose()
			zombie.blast_ragdoll.start(Vector2(facing*150,-70),.3,.12)
			var rig = zombie.blast_ragdoll.rig
			var matched := true
			for key in rig.parts:
				var definition: Dictionary = snapshot.parts[key]
				matched = matched and rig.parts[key].position.distance_to(definition.position) < .001
				matched = matched and absf(angle_difference(rig.parts[key].rotation,definition.rotation)) < .001
			check(matched,"fall keeps the current animated silhouette: %s facing %.0f" % [posture,facing])
			var skin = zombie.blast_ragdoll.zombie_skin
			check(is_instance_valid(skin) and rig.parts.values().all(func(part): return part.skin_rendered) and skin.pose.facing == facing,"zombie artwork replaces every mannequin segment: %s facing %.0f" % [posture,facing])
			if posture == "crawling":
				check(not skin.visible_sections().has("left_thigh") and not rig.parts.left_thigh.visible and rig.parts.left_thigh.collision_layer == 0,"the missing leg remains absent from appearance and physical collisions")
	await reset()
	var original := zombie.blast_ragdoll.capture_pose()
	blast_grenade()
	check(zombie.health < 100 and zombie.blast_ragdoll.active and is_instance_valid(zombie.blast_ragdoll.zombie_skin),"a real grenade damages and knocks away the zombie in its own appearance")
	check(zombie.blast_ragdoll.zombie_skin.pose.parts == original.parts,"explosion captures the standing pose before the knockdown changes posture")
	var getting_up := await wait_for_recovery()
	check(getting_up,"a surviving zombie starts a gradual get-up after landing")
	if getting_up:
		var controller := zombie.blast_ragdoll
		var rig = controller.rig
		var skin = controller.zombie_skin
		check(not rig.simulation_enabled and zombie.collision_layer == 0 and zombie.hit_zones.values().all(func(zone): return zone.collision_layer == 0),"get-up owns the same bones and colliders without enabling AI or duplicate hit zones")
		var before: Vector2 = rig.parts.torso.global_position
		await frames(8)
		check(controller.recovering and rig.parts.torso.global_position.distance_to(before) > 1,"the torso visibly rises across multiple animation frames")
		var pose: Transform2D = rig.parts.head.global_transform
		var elapsed: float = controller.recovery_elapsed
		zombie.set_test_frozen(true)
		await frames(12)
		check(rig.parts.head.global_transform.is_equal_approx(pose) and controller.recovery_elapsed == elapsed,"enemy freeze pauses the get-up animation")
		zombie.set_test_frozen(false)
		await frames(2)
		check(controller.recovering and not rig.simulation_enabled and controller.recovery_elapsed > elapsed,"unfreezing resumes the animation without reactivating its physical constraints")
		blast_grenade()
		await frames(1)
		check(controller.active and not controller.recovering and rig.simulation_enabled and controller.rig == rig and controller.zombie_skin == skin,"another grenade interrupts get-up and resumes the same physical zombie")
		await frames(420)
		check(not controller.active and not is_instance_valid(skin) and zombie.health > 0 and zombie.collision_layer == 4,"the zombie ultimately recovers its normal model and AI")
	await reset()
	zombie._sever_part("left_leg",Vector2.LEFT)
	zombie.blast_ragdoll.start(Vector2(120,-70),.3,.12)
	getting_up = await wait_for_recovery()
	check(getting_up and zombie.blast_ragdoll.recovery_target.prone,"a zombie missing one leg transitions back to a crawling pose")
	await frames(90)
	check(not zombie.blast_ragdoll.active and zombie.is_prone() and not zombie.has_part("left_leg") and zombie.has_part("right_leg"),"recovery never stands the crawler upright or regrows its leg")
	await reset()
	zombie.blast_ragdoll.start(Vector2(100,-60),.3,.12)
	getting_up = await wait_for_recovery()
	check(getting_up,"a fresh intact zombie reaches get-up")
	if getting_up:
		zombie._sever_part("right_leg",Vector2.RIGHT)
		await frames(1)
		check(not zombie.blast_ragdoll.recovering and zombie.blast_ragdoll.rig.simulation_enabled,"losing a leg during get-up interrupts standing and restores the fall")
		await frames(420)
		check(not zombie.blast_ragdoll.active and zombie.is_prone() and not zombie.has_part("right_leg"),"the newly crippled zombie recovers as a crawler")
	await reset()
	zombie.blast_ragdoll.start(Vector2(100,-60),.3,.12)
	getting_up = await wait_for_recovery()
	check(getting_up,"a living zombie can begin recovery before a lethal hit")
	if getting_up:
		zombie.take_damage(1000)
		await frames(2)
		check(zombie.health == 0 and zombie.blast_ragdoll.active and not zombie.blast_ragdoll.recovering,"death interrupts get-up and leaves the dressed physical corpse")
		await frames(100)
		check(zombie.blast_ragdoll.active and zombie.blast_ragdoll.rig.parts.values().all(func(part): return part.global_position.is_finite() and part.global_position.y < 785),"a dead zombie stays physical and settles on the floor")
		var skin = zombie.blast_ragdoll.zombie_skin
		await reset()
		check(not is_instance_valid(skin) and not zombie.blast_ragdoll.active and zombie.missing_parts.is_empty() and zombie.health == 100,"respawn removes the fall appearance and restores the original full zombie")
	await reset()
	for limb in CoreEnemyDummy.LIMBS: zombie._sever_part(limb,Vector2.LEFT)
	zombie.blast_ragdoll.start(Vector2(90,-40),.3,.12)
	await frames(2)
	check(zombie.blast_ragdoll.zombie_skin.visible_sections().all(func(key): return key in ["torso","pelvis","head"]),"a limbless zombie displays only its surviving body and head")
	await frames(420)
	check(not zombie.blast_ragdoll.active and zombie.is_prone() and zombie.arm_count() == 0 and zombie.missing_parts.size() == 4,"a limbless zombie stays prone and never regrows limbs during recovery")
	await reset()
	zombie.knock_down(1,Vector2.ZERO)
	zombie.blast_ragdoll.start(Vector2(20,-10),.3,.12)
	var ceiling := StaticBody2D.new()
	ceiling.position = Vector2(4800,715)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(180,10)
	collider.shape = shape
	ceiling.add_child(collider)
	lab.level.add_child(ceiling)
	await frames(180)
	check(zombie.blast_ragdoll.active and not zombie.blast_ragdoll.recovering,"a low ceiling prevents the standing animation from clipping into cover")
	ceiling.queue_free()
	await frames(420)
	check(not zombie.blast_ragdoll.active and not zombie.is_prone(),"clearing headroom allows the zombie to finish getting up")
	zombie.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
