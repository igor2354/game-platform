extends SceneTree
const ART = preload("res://scripts/core/concept_zombie_art.gd")
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
	for clip in ART.CLIPS:
		var valid := true
		var shoulders_valid := true
		for frame in 16:
			var p: Dictionary = ART.pose(clip,frame)
			var torso: Dictionary = p.parts.torso
			var torso_inverse := Transform2D(torso.rotation,torso.position).affine_inverse()
			for side in ["left","right"]:
				var socket: Vector2 = p.joints[side+"_shoulder"]
				var local: Vector2 = torso_inverse*socket
				var from_collar: float = local.y/torso.dimensions.y+.5
				var upper: Dictionary = p.parts[side+"_upper_arm"]
				var arm_root: Vector2 = Transform2D(upper.rotation,upper.position)*Vector2(0,-upper.dimensions.y*.5)
				shoulders_valid = shoulders_valid and from_collar > .23 and from_collar < .38
				shoulders_valid = shoulders_valid and absf(local.x) > torso.dimensions.x*.22 and absf(local.x) < torso.dimensions.x*.45
				shoulders_valid = shoulders_valid and arm_root.distance_to(socket) < .01 and socket.distance_to(p.joints.neck) > 5
			for direction in [-1.0,1.0]:
				for side in ["left","right"]:
					for pair in [["upper_arm","forearm",12.0,-1.0],["thigh","shin",13.0,1.0]]:
						var upper: Dictionary = p.parts[side+"_"+pair[0]]
						var lower: Dictionary = p.parts[side+"_"+pair[1]]
						var a := Vector2.DOWN.rotated(upper.rotation)*Vector2(direction,1)
						var b := Vector2.DOWN.rotated(lower.rotation)*Vector2(direction,1)
						var bend: float = rad_to_deg(a.angle_to(b))*direction*pair[3]
						valid = valid and bend >= 4.9 and bend <= 145.1
						valid = valid and absf(upper.dimensions.y-pair[2]) < .01 and absf(lower.dimensions.y-pair[2]) < .01
			var head: Dictionary = p.parts.head
			var anchor: Vector2 = Transform2D(head.rotation,head.position).affine_inverse()*p.joints.neck
			# Neck enters the lower third of the head artwork, inside the collar.
			valid = valid and absf(anchor.x) < 1 and anchor.y > 3 and anchor.y < 5
			valid = valid and absf(wrapf(head.rotation-p.parts.torso.rotation,-PI,PI)) <= .951
		check(valid,"anatomical bends, fixed segment lengths and attached neck in all 16 frames, both facings: "+clip)
		check(shoulders_valid,"arms attach to deltoids below collar, including torso rotation and pose blends: "+clip)
	for prefix in ["","crawl_"]:
		var a: Dictionary = ART.pose(prefix+"windup",15)
		var b: Dictionary = ART.pose(prefix+"strike",0)
		check(a.parts.right_forearm.position.distance_to(b.parts.right_forearm.position) < .01,"melee contact stays continuous: "+prefix)
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	var zombie: CoreConceptZombie = lab.level.concept_zombie
	zombie.tuning.apply_values({"movement_enabled":false,"combat_enabled":false,"vision_enabled":false,"hearing_enabled":false})
	lab.player.reset_to(Vector2(160,760))
	await frames(5)
	for direction in [-1.0,1.0]:
		zombie.reset_target()
		await frames(3)
		zombie.facing = direction
		var pose := zombie.ragdoll_pose()
		zombie.blast_ragdoll.start(Vector2(-direction*210,-90),.45,.12)
		var rag := zombie.blast_ragdoll
		var attached := true
		var recovering := false
		var anatomical_recovery := true
		var max_joint_gap := 0.0
		var min_bend := 180.0
		var max_bend := -180.0
		var head_anchor: Vector2 = (Transform2D(pose.parts.head.rotation,pose.parts.head.position).affine_inverse()*pose.joints.neck)/pose.parts.head.dimensions
		var torso_anchor: Vector2 = (Transform2D(pose.parts.torso.rotation,pose.parts.torso.position).affine_inverse()*pose.joints.neck)/pose.parts.torso.dimensions
		for index in 360:
			await frames(1)
			if not rag.active: break
			var head: RigidBody2D = rag.rig.parts.head
			var torso: RigidBody2D = rag.rig.parts.torso
			var neck := torso.to_global(torso_anchor*torso.dimensions)
			var visual: Transform2D = rag.zombie_skin.connected_head_transform()
			attached = attached and (visual*(head_anchor*head.dimensions)).distance_to(neck) < .01
			max_joint_gap = maxf(max_joint_gap,head.to_global(head_anchor*head.dimensions).distance_to(neck))
			if rag.recovering:
				recovering = true
				for side in ["left","right"]:
					for pair in [["upper_arm","forearm",-1.0],["thigh","shin",1.0]]:
						var a: RigidBody2D = rag.rig.parts[side+"_"+pair[0]]
						var b: RigidBody2D = rag.rig.parts[side+"_"+pair[1]]
						var bend: float = rad_to_deg(wrapf(b.rotation-a.rotation,-PI,PI))*direction*pair[2]
						min_bend = minf(min_bend,bend)
						max_bend = maxf(max_bend,bend)
						anatomical_recovery = anatomical_recovery and bend > 3 and bend < 150
		check(attached,"head stays joined to collar during actual blast/fall/get-up, facing %.0f" % direction)
		check(max_joint_gap < 7,"physical neck remains connected under impact, facing %.0f (gap %.3f px)" % [direction,max_joint_gap])
		print("RECOVERY facing ",direction," seen ",recovering," active ",rag.active," bend ",min_bend,"..",max_bend)
		check(recovering and anatomical_recovery and not rag.active,"get-up respects elbow/knee anatomy and returns control, facing %.0f" % direction)
	print("CONCEPT ANATOMY: %d/%d passed" % [checks-failures,checks])
	lab.queue_free()
	await frames(4)
	quit(0 if failures == 0 else 1)
