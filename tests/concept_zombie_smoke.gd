extends SceneTree
const ART = preload("res://scripts/core/concept_zombie_art.gd")
var lab: CoreMovementLab
var zombie: CoreConceptZombie
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
	zombie = lab.level.concept_zombie
	await frames(10)
	check(zombie != lab.level.zombie and zombie is CoreZombie and lab.level.enemies.has(zombie),"the illustrated zombie is a separate combat actor and the original remains")
	check(zombie.home.x < -5000 and zombie.home.x > CoreMovementLevel.LEFT_BOUND and zombie.is_on_floor(),"new arena extends the floor and has a separate standing patrol")
	check(zombie.target == lab.player and zombie.tuning == lab.zombie_settings and zombie.damage_tuning == lab.player.weapon.tuning,"AI, balance and location damage are wired to the shared game settings")
	check(ART.CLIPS.size() == 22 and ART.FRAME_COUNT == 16,"twenty-two named animations contain sixteen frames each")
	for prefix in ["","crawl_"]:
		var contact: Dictionary = ART.pose(prefix+"windup",15).parts.right_forearm
		var follow_through: Dictionary = ART.pose(prefix+"strike",0).parts.right_forearm
		check(contact.position.x > 10 and contact.position.distance_to(follow_through.position) < 1,"melee contact coincides with windup completion: "+prefix)
	zombie.set_test_frozen(true)
	for clip in ART.CLIPS:
		var texture := ART.texture(clip)
		var valid := texture != null and texture.get_size() == Vector2(1024,1024)
		if valid:
			var image := texture.get_image()
			for frame in 16:
				valid = valid and image.get_region(Rect2i(Vector2i(frame%4,frame/4)*256,Vector2i(256,256))).get_used_rect().has_area()
		check(valid,"all sixteen baked transparent frames exist: "+clip)
		for facing in [-1.0,1.0]:
			zombie.facing = facing
			zombie.preview_clip = clip
			var matched := true
			for frame in 16:
				zombie.preview_frame = frame
				zombie._sync_zones()
				for part in CoreEnemyDummy.PARTS:
					var shape: CollisionShape2D = zombie.hit_zones[part].get_child(0)
					var rect := ART.rect_for(ART.pose(clip,frame),part,facing,zombie.body_size/Vector2(32,64))
					matched = matched and rect.has_area() and shape.position.is_equal_approx(rect.get_center()+zombie.reaction_offset) and shape.shape.size.is_equal_approx(rect.size)
			check(matched,"hit regions match all sixteen poses, facing %.0f: %s" % [facing,clip])
	zombie.preview_clip = ""
	zombie.reset_target()
	zombie.set_test_frozen(false)
	lab._teleport_player(CoreMovementLevel.CONCEPT_ZOMBIE_TEST_SPAWN)
	await frames(3)
	var event := InputEventAction.new()
	event.action = "core_concept_zombie_test"
	event.pressed = true
	root.push_input(event,true)
	check(lab.player.global_position.distance_to(CoreMovementLevel.CONCEPT_ZOMBIE_TEST_SPAWN) < 2,"F10 teleports to the new arena")
	check(lab.concept_zombie_teleport_button.text.contains("F10"),"F6 exposes a discoverable shortcut to the new actor")
	zombie.facing = -1
	check(zombie.sees_player(zombie.tuning.forget_range),"the textured head and directed cone detect the real player")
	lab.player.set_invulnerable(false)
	lab.player.reset_to(zombie.position+Vector2(-42,0))
	await frames(120)
	check(zombie.attacks_started > 0 and zombie.attacks_landed > 0,"the new zombie actually chases and strikes the nearby player")
	lab.player.set_invulnerable(true)
	zombie.reset_target()
	zombie.tuning.vision_enabled = false
	zombie.tuning.hearing_enabled = false
	zombie.tuning.movement_enabled = false
	zombie.tuning.combat_enabled = false
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	for direction in [-1.0,1.0]:
		zombie.reset_target()
		zombie.facing = direction
		await frames(3)
		var point := zombie.aim_point_for_part("head")
		var query := PhysicsRayQueryParameters2D.create(point+Vector2(direction*50,0),point-Vector2(direction*15,0),16)
		query.collide_with_areas = true
		var hit := lab.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): CoreProjectile.resolve_impact(hit,10,Vector2(-direction,0),Callable(),lab.player.global_position,true,lab.player)
		check(not hit.is_empty() and zombie.health == 80 and zombie.last_hit_part == "head","real projectile queries hit the animated head, facing %.0f" % direction)
	zombie.reset_target()
	await frames(3)
	zombie.take_projectile_hit(100,"left_arm",Vector2.RIGHT)
	await frames(2)
	check(not zombie.has_part("left_arm") and zombie.health > 0 and zombie.detached_parts.back().has("concept_pose"),"severing an arm preserves health and drops the matching textured limb")
	zombie.take_projectile_hit(100,"left_leg",Vector2.RIGHT)
	check(zombie.is_prone() and zombie.visual_fall_left > 0,"a severed leg immediately triggers the sixteen-frame fall and crawling posture")
	await frames(35)
	check(zombie.animation_name == "prone_idle" and zombie.animation_frame in range(16),"a legless zombie settles into its own low idle without patrolling")
	zombie.apply_stun(.5)
	await frames(2)
	check(zombie.animation_name == "prone_stunned","crawlers use a dedicated stunned animation")
	zombie.reset_target()
	await frames(3)
	zombie.apply_stun(.5)
	await frames(2)
	check(zombie.animation_name == "stunned" and zombie.is_stunned(),"standing dash stun keeps the illustrated model")
	zombie.reset_target()
	await frames(3)
	zombie.take_projectile_hit(10,"torso",Vector2.RIGHT)
	await frames(2)
	check(zombie.animation_name == "hurt" and zombie.health < 100,"ordinary hits trigger the textured reaction")
	var frame_before := zombie.animation_frame
	var time_before := zombie.animation_elapsed
	zombie.set_test_frozen(true)
	await frames(20)
	check(zombie.animation_frame == frame_before and zombie.animation_elapsed == time_before,"enemy freeze stops both animation phase and physical motion")
	zombie.set_test_frozen(false)
	paused = true
	frame_before = zombie.animation_frame
	await frames(10)
	check(zombie.animation_frame == frame_before,"pause does not advance the new animation")
	paused = false
	zombie.reset_target()
	await frames(3)
	zombie.knock_down(.3,Vector2.ZERO)
	await frames(2)
	check(zombie.animation_name == "fall","slide knockdown starts the authored falling animation")
	await frames(25)
	check(zombie.animation_name == "get_up" and zombie.visual_getup_left > 0,"temporary knockdown transitions into sixteen-frame get-up")
	await frames(50)
	check(not zombie.is_prone() and zombie.visual_getup_left == 0,"get-up restores standing animation")
	zombie.reset_target()
	await frames(3)
	var before := zombie.ragdoll_pose()
	zombie.blast_ragdoll.start(Vector2(80,-70),.4,.12)
	var rag := zombie.blast_ragdoll
	check(rag.active and rag.zombie_skin.get_script().resource_path.ends_with("concept_zombie_ragdoll_skin.gd"),"explosions use the new character's artwork, never the green dummy")
	var matched := true
	for key in rag.rig.parts:
		matched = matched and rag.rig.parts[key].position.is_equal_approx(before.parts[key].position) and rag.rig.parts[key].skin_rendered
	check(matched,"physical fall inherits the exact current thirteen textured bone poses")
	check(not zombie.ragdoll_recovery_pose(false).prone and zombie.ragdoll_recovery_pose(true).prone,"recovery posture describes retained legs independently of active ragdoll")
	var recovery_phases := {}
	for index in 61: recovery_phases[zombie.ragdoll_recovery_phase(float(index)/60)] = true
	check(recovery_phases.size() == 16,"physical get-up also samples sixteen recovery poses")
	zombie._sever_part("right_arm",Vector2.RIGHT)
	await frames(2)
	check(not rag.rig.parts.right_forearm.visible and "right_forearm" not in rag.zombie_skin.visible_sections(),"ragdoll skin never restores a severed limb")
	for index in 350:
		await frames(1)
		if not rag.active: break
	check(not rag.active and zombie.health > 0 and not zombie.has_part("right_arm"),"explosion recovery keeps health and missing limbs")
	check(not rag.active and zombie.visual_getup_left == 0 and zombie.animation_name != "get_up","physical recovery never restarts the ordinary get-up animation")
	zombie.reset_target()
	await frames(3)
	zombie.blast_ragdoll.start(Vector2.ZERO,.1,.12)
	var saw_recovery := false
	for index in 180:
		await frames(1)
		if zombie.blast_ragdoll.recovering:
			saw_recovery = true
			break
	check(saw_recovery and not zombie.blast_ragdoll.recovery_target.prone,"intact legs start the standing physical recovery")
	if saw_recovery:
		zombie._sever_part("left_leg",Vector2.RIGHT)
		await frames(1)
	check(saw_recovery and not zombie.blast_ragdoll.recovering and not zombie.blast_ragdoll.rig.parts.left_thigh.visible,"losing a leg interrupts get-up without restoring its texture")
	await frames(350)
	check(not zombie.blast_ragdoll.active and zombie.is_prone() and zombie.animation_name == "prone_idle","interrupted standing recovery returns safely to the legless pose")
	zombie.reset_target()
	await frames(3)
	zombie.set_current_health(0)
	await frames(50)
	check(zombie.animation_name == "death" and zombie.animation_frame == 15,"HP death holds the final authored death frame")
	lab._respawn_enemies()
	check(zombie.health == 100 and zombie.missing_parts.is_empty() and zombie.animation_name == "idle" and zombie.position.is_equal_approx(zombie.home),"F7 restores the new actor, limbs, home and animation")
	check(lab.developer_mode.enemy_tools.target_choice.item_count == lab.level.enemies.size()+1,"global enemy tools include the separate soldier")
	lab._recover()
	check(zombie.health == 100 and not zombie.blast_ragdoll.active,"F8 resets the new arena opponent too")
	print("CONCEPT ZOMBIE: %d/%d passed" % [checks-failures,checks])
	lab.queue_free()
	await frames(4)
	quit(0 if failures == 0 else 1)
