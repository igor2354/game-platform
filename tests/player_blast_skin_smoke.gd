extends SceneTree
var lab: CoreMovementLab
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
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.explosion_audio_enabled = false
	await frames(10)
	var hero := lab.player
	for facing in [-1.0,1.0]:
		for animation in ["idle","run","sprint","jump","crouch","slide"]:
			hero.reset_to(Vector2(4800,760))
			hero._update_crouch(animation == "crouch")
			hero.body.state = animation
			hero.body.frame = 0 if animation in ["idle","crouch"] else 3
			hero.body.facing = facing
			hero.weapon.aim_facing = facing
			hero.weapon.aim_override = hero.global_position+Vector2(facing*300,-40)
			hero.body._show_frame()
			hero.body.update_arms()
			var pose := hero.body.ragdoll_pose()
			hero.blast_ragdoll.start(Vector2(facing*200,-80),1.5,.12)
			var rig = hero.blast_ragdoll.rig
			var matched := true
			for key in rig.parts:
				var expected: Dictionary = pose.parts[key]
				matched = matched and rig.parts[key].position.distance_to(expected.position) < .001
				matched = matched and absf(angle_difference(rig.parts[key].rotation,expected.rotation)) < .001
			check(matched,"physical fall inherits the exact current pose: %s facing %.0f" % [animation,facing])
			check(is_instance_valid(hero.blast_ragdoll.player_skin) and hero.blast_ragdoll.player_skin.facing == facing and rig.parts.values().all(func(part): return part.skin_rendered),"hero appearance replaces every mannequin segment: %s facing %.0f" % [animation,facing])
			hero.blast_ragdoll.cancel()
			await frames(1)
	hero.reset_to(Vector2(4800,760))
	var profile := lab.ragdoll_settings
	profile.apply_values({"grenade_fuse":.5,"grenade_blast_damage":20,"explosion_ragdoll_duration":.5,"explosion_sever_enabled":false})
	hero.grenades.prepare()
	Input.action_press("core_fire")
	hero.grenades.input_trigger(true)
	await frames(33)
	check(hero.blast_ragdoll.active and is_instance_valid(hero.blast_ragdoll.player_skin) and hero.health > 0 and hero.health < 100,"a real cooked grenade knocks away the dressed hero and applies damage")
	var skin := hero.blast_ragdoll.player_skin
	var rig = hero.blast_ragdoll.rig
	var head_before: Transform2D = rig.parts.head.global_transform
	var hp: float = hero.health
	hero.blast_ragdoll.start(Vector2(-100,-40),.5,.12)
	check(hero.blast_ragdoll.player_skin == skin and hero.blast_ragdoll.rig == rig,"a second blast keeps the same hero skin and physical body")
	await frames(15)
	check(not rig.parts.head.global_transform.is_equal_approx(head_before) and hero.health == hp,"the helmet and body move with real simulated bones without changing HP")
	paused = true
	head_before = rig.parts.head.global_transform
	await frames(10)
	check(rig.parts.head.global_transform.is_equal_approx(head_before),"pause stops the physical character and its appearance together")
	paused = false
	Input.action_release("core_fire")
	await frames(360)
	check(not hero.blast_ragdoll.active and not is_instance_valid(skin) and hero.visuals.visible and hero.health == hp,"recovery restores the ordinary hero without duplicate artwork or lost HP")
	hero.blast_ragdoll.start(Vector2(200,-80),2,.12)
	skin = hero.blast_ragdoll.player_skin
	lab._recover()
	await frames(3)
	check(not is_instance_valid(skin) and not hero.blast_ragdoll.active and hero.visuals.visible and hero.collision_layer == 2,"F8 removes the fall appearance and restores the normal character")
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
