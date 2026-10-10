extends SceneTree
# Greybox rig checks: contract bone names, animations, and the sandbox
# controller driving walk, run, roll (under a low tunnel) and a ladder.
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var rig: HumanoidRig = load("res://scenes/characters/humanoid_greybox.tscn").instantiate()
	var missing := []
	for bone in ["pelvis","torso","head","arm_upper_l","arm_lower_l","hand_l","arm_upper_r","arm_lower_r","hand_r","thigh_l","shin_l","foot_l","thigh_r","shin_r","foot_r"]:
		var node := rig.find_child(bone)
		if not (node is Bone2D and node.has_node("art")): missing.append(bone)
	check(missing.is_empty(),"15 contract bones, each with an art part %s" % [missing])
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var loops := true
	for anim in ["idle","walk","run","climb"]: loops = loops and player.has_animation(anim) and player.get_animation(anim).loop_mode == Animation.LOOP_LINEAR
	check(loops and player.get_animation("roll").length == HumanoidRig.ROLL_TIME,"idle/walk/run/climb loop, roll lasts ROLL_TIME")
	check(is_equal_approx(rig.time_scale_for("walk",Vector2(90,0)),0.5) and is_equal_approx(rig.time_scale_for("climb",Vector2(0,-128)),2.0) and rig.time_scale_for("walk",Vector2(-90,0)) < 0,"playback speed follows movement speed; backpedal plays backwards")
	rig.free()

	var sandbox: Node2D = load("res://scenes/sandbox/rig_sandbox.tscn").instantiate()
	root.add_child(sandbox)
	await frames(4)
	var hero: GreyboxController = sandbox.player
	hero.scripted = true
	check(hero.is_on_floor(),"dummy stands on the floor")
	var start_x := hero.position.x
	hero.move_x = 1
	await frames(30)
	check(hero.position.x > start_x+60 and hero.rig.state == "walk","walking moves and plays walk")
	hero.running = true
	await frames(20)
	check(hero.rig.state == "run" and absf(hero.velocity.x) > 400,"running plays run at full speed")
	var steps_before: int = sandbox.steps
	await frames(40)
	check(sandbox.steps > steps_before,"footstep events fire from the animation")
	# The tunnel gap is 130: standing (210) is blocked, a roll (96) passes.
	hero.running = false
	hero.position = Vector2(sandbox.TUNNEL.position.x-60,sandbox.FLOOR_Y)
	hero.velocity = Vector2.ZERO
	await frames(60)
	check(hero.position.x < sandbox.TUNNEL.position.x-20,"standing dummy cannot enter the low tunnel")
	hero.roll_pressed = true
	await frames(3)
	check(hero.rolling > 0 and hero.capsule.height == GreyboxController.ROLL_HEIGHT and hero.rig.state == "roll","roll shrinks the collision capsule")
	await frames(4)
	check(hero.invulnerable(),"roll grants invulnerability early in the tumble")
	hero.move_x = 0
	await frames(90)
	check(hero.position.x > sandbox.TUNNEL.end.x and hero.rolling <= 0 and hero.capsule.height == GreyboxController.STAND_HEIGHT,"roll carries through the tunnel and stands up after it")
	# Ladder: bottom to the upper landing and back down.
	hero.position = Vector2(sandbox.LADDER_X-30,sandbox.FLOOR_Y)
	hero.velocity = Vector2.ZERO
	await frames(3)
	hero.climb_axis = -1
	await frames(4)
	check(hero.climbing and hero.rig.state == "climb" and is_equal_approx(hero.rig.tree.get("parameters/TimeScale/scale"),2.0),"W starts climbing; climb cycle synced to climb speed")
	await frames(170)
	hero.climb_axis = 0
	await frames(4)
	check(not hero.climbing and absf(hero.position.y-sandbox.LANDING_Y) < 2 and hero.is_on_floor(),"ladder ascent ends standing on the landing")
	hero.climb_axis = 1
	await frames(170)
	hero.climb_axis = 0
	await frames(4)
	check(not hero.climbing and absf(hero.position.y-sandbox.FLOOR_Y) < 2,"ladder descent returns to the floor")
	sandbox.queue_free()
	await create_timer(0.2).timeout
	print("RESULT: ",checks-failures,"/",checks," checks passed")
	quit(0 if failures == 0 else 1)
