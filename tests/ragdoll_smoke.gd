extends SceneTree

var checks := 0
var failures := 0
var lab: CoreMovementLab
var mannequin: Node2D

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func dispatch(action: String) -> void:
	await process_frame
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
func anchors_close(tolerance: float) -> bool:
	for definition in mannequin.JOINTS:
		var a: RigidBody2D = mannequin.parts[definition[1]]
		var b: RigidBody2D = mannequin.parts[definition[2]]
		var a_rest := Vector2.ZERO
		var b_rest := Vector2.ZERO
		for part in mannequin.PARTS:
			if part[0] == definition[1]: a_rest = definition[3]-part[1]
			if part[0] == definition[2]: b_rest = definition[3]-part[1]
		if (a.global_transform*a_rest).distance_to(b.global_transform*b_rest) > tolerance: return false
	return true
func maximum_bend() -> float:
	var maximum := 0.0
	for definition in mannequin.JOINTS:
		maximum = maxf(maximum,absf(wrapf(mannequin.parts[definition[2]].rotation-mannequin.parts[definition[1]].rotation,-PI,PI)))
	return rad_to_deg(maximum)
func body_settled() -> bool:
	for part in mannequin.parts.values():
		if part.linear_velocity.length() >= 8: return false
	return true
func shoot_from(side: float) -> void:
	lab.player.reset_to(mannequin.global_position+Vector2(side*120,0))
	lab.player.weapon.aim_override = mannequin.parts.head.global_position
	await frames(6)
	lab.player.weapon._fire()
	await frames(12)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	mannequin = lab.level.ragdoll_mannequin
	check(mannequin.global_position.x < 0 and absf(mannequin.global_position.x-lab.level.physics_crate.global_position.x) < 250,"mannequin stands beside the crate in the left physics area")
	check(mannequin.parts.size() == 13 and mannequin.joints.size() == 12,"ragdoll contains thirteen physical segments and twelve joints")
	var held := true
	for part in mannequin.parts.values(): held = held and part is RigidBody2D and part.freeze and part.mass > 0 and not part.lock_rotation
	check(held and not mannequin.active,"initial pose is held with physical bodies ready for activation")
	await frames(120)
	check(absf(mannequin.parts.head.global_position.y-(CoreMovementLevel.FLOOR-85)) < .1,"initial mannequin remains upright until hit")
	check(lab.level.enemies.size() == 6,"physical mannequin does not enter the combat enemy roster")
	await shoot_from(1)
	check(mannequin.active and mannequin.impacts == 1,"a real projectile releases the entire ragdoll")
	var dynamic := true
	for part in mannequin.parts.values(): dynamic = dynamic and not part.freeze
	check(dynamic,"head, torso, arms and legs all enter physical simulation")
	var linked := true
	for joint in mannequin.joints: linked = linked and not joint.node_a.is_empty() and not joint.node_b.is_empty() and joint.angular_limit_upper > joint.angular_limit_lower and joint.disable_collision
	check(linked,"physical joints bind body parts with configured angular stops")
	check(lab.player.weapon.hits == 0 and lab.player.weapon.kills == 0,"test mannequin does not count as a killed enemy")
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	await frames(90)
	check(mannequin.parts.head.global_position.y < CoreMovementLevel.FLOOR-55,"muscle tension keeps the mannequin extended after a single shot")
	check(maximum_bend() < 25,"tense limbs keep their relative pose instead of folding after a shot")
	check(anchors_close(6),"joints keep limbs attached throughout the fall")
	await frames(240)
	var finite := true
	for part in mannequin.parts.values():
		finite = finite and part.global_position.is_finite() and is_finite(part.rotation) and part.global_position.y < CoreMovementLevel.FLOOR+20
	check(finite and anchors_close(6),"ragdoll remains intact above the floor after settling")
	# A tense body can rock on its feet before toppling as a whole.
	for i in 240:
		if body_settled(): break
		await physics_frame
	check(body_settled(),"friction and damping settle the physical body")
	check(maximum_bend() < 25,"the fallen tense body remains extended rather than crumpling")
	var torso: RigidBody2D = mannequin.parts.torso
	torso.apply_impulse(Vector2(-500,-1800))
	await frames(8)
	check(torso.linear_velocity.y < 0,"an impulse can lift the connected ragdoll off the ground")
	await dispatch("core_pause")
	var paused_pose := {}
	for key in mannequin.parts: paused_pose[key] = mannequin.parts[key].global_transform
	await frames(15)
	var frozen := paused
	for key in mannequin.parts: frozen = frozen and mannequin.parts[key].global_transform.is_equal_approx(paused_pose[key])
	check(frozen,"Escape freezes every ragdoll segment")
	await dispatch("core_pause")
	await frames(6)
	check(not paused and not torso.global_transform.is_equal_approx(paused_pose.torso),"Escape resumes the physical body")
	await dispatch("core_respawn_enemies")
	check(mannequin.active,"F7 restores enemies without resetting the ragdoll experiment")
	await dispatch("core_reset")
	await frames(5)
	var restored: bool = not mannequin.active and mannequin.impacts == 0
	for definition in mannequin.PARTS:
		var part: RigidBody2D = mannequin.parts[definition[0]]
		restored = restored and part.freeze and part.global_position.distance_to(mannequin.global_position+definition[1]) < .1 and absf(part.rotation) < .001 and part.linear_velocity.length() < .1
	check(restored,"F8 restores all segments to their original standing pose")
	check(mannequin.parts.size() == 13 and mannequin.get_child_count() == 37,"reset leaves one complete mannequin without duplicate parts or joints")
	await shoot_from(-1)
	check(mannequin.active and mannequin.impacts == 1,"a shot from the opposite side also activates ragdoll")
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	await frames(100)
	check(anchors_close(6),"ragdoll constraints remain stable after a mirrored impact")
	check(maximum_bend() < 25,"tense limbs also resist folding after an impact from the opposite side")
	for repeat in 3:
		await dispatch("core_reset")
		await frames(3)
		mannequin.parts.torso.receive_projectile_impulse(Vector2.LEFT,mannequin.parts.torso.global_position,25)
		await frames(70)
	check(mannequin.parts.size() == 13 and mannequin.get_child_count() == 37 and anchors_close(6),"repeated activation and reset keep a single stable ragdoll")
	mannequin.muscle_tension = 0
	await dispatch("core_reset")
	await shoot_from(1)
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	await frames(120)
	check(maximum_bend() > 60,"zero muscle tension restores the previous loose ragdoll for comparison")
	mannequin.muscle_tension = 1
	await dispatch("core_reset")
	await shoot_from(1)
	lab.player.reset_to(CoreMovementLevel.SPAWN)
	await frames(120)
	check(maximum_bend() < 25,"restoring tension brings back the supported pose after reset")
	lab.queue_free()
	await process_frame
	await create_timer(.12).timeout
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
