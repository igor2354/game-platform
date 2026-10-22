extends SceneTree
const LADDER = preload("res://scripts/core/ladder_geometry.gd")
var checks := 0
var failures := 0
var hero: CoreMovementPlayer
var reach_ok := true
var bones_ok := true
var bends_ok := true
var maximum_grip_error := 0.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func release() -> void:
	for key in ["core_up","core_down","core_jump"]: Input.action_release(key)
func measure_arms() -> void:
	if not hero.climbing or hero.body.state != "climb": return
	for arm in [hero.body.near_arm,hero.body.far_arm]:
		var error: float = arm.hand.distance_to(arm.requested_hand)
		maximum_grip_error = maxf(maximum_grip_error,error)
		reach_ok = reach_ok and error < .1
		bones_ok = bones_ok and absf(arm.shoulder.distance_to(arm.elbow)-arm.upper_length) < .1 and absf(arm.elbow.distance_to(arm.hand)-arm.lower_length) < .1
		bends_ok = bends_ok and absf((arm.elbow-arm.shoulder).angle_to(arm.hand-arm.elbow)) < deg_to_rad(120.1)
func climb(ladder: Rect2,up: bool) -> bool:
	release()
	var action := "core_up" if up else "core_down"
	var target := ladder.position.y if up else ladder.end.y
	Input.action_press(action)
	for i in ceili(ladder.size.y/hero.tuning.climb_speed*60)+90:
		await frames(1)
		measure_arms()
		if not hero.climbing and absf(hero.position.y-target) < 2:
			release()
			await frames(15)
			return hero.is_on_floor() and absf(hero.position.y-target) < 2
	release()
	return false
func run() -> void:
	check(LADDER.WIDTH == 18 and LADDER.RUNG_SPACING == 12,"rails are half as wide and rungs twice as frequent")
	check(LADDER.CYCLE_DISTANCE == 48 and LADDER.HAND_STRIDE == 24,"denser rungs do not double the existing animation cadence")
	for character in ["sofia","harry"]:
		for campaign in [false,true]:
			var app := preload("res://scripts/campaign/frontend.gd").new()
			app.load_user_settings = false
			app.test_settings_directory = OS.get_environment("TEMP").path_join("ladder-dimensions-%d" % OS.get_process_id())
			root.add_child(app)
			app.selected_character = character
			app.launch(campaign)
			await frames(5)
			hero = app.game.player
			hero.weapon.tuning.sound_enabled = false
			hero.weapon.aim_override = hero.position+Vector2(300,-36)
			var ladders: Array[Rect2] = app.game.level.forest.ladders if campaign else app.game.level.ladders
			check(ladders.size() == (6 if campaign else 4),"all existing ladders present: "+character+str(campaign))
			if not campaign:
				check(ladders[0].get_center().x == 1446 and ladders[1].get_center().x == 2018 and ladders[2].get_center().x == 1668 and ladders[3].get_center().x == 2198,"polygon ladder centerlines remain fixed: "+character)
			for index in ladders.size():
				var ladder := ladders[index]
				var key: String = character+(" / forest / " if campaign else " / polygon / ")+str(index)
				check(ladder.size.x == 18,"narrow collision/entry rectangle: "+key)
				var levels := LADDER.rung_levels(ladder)
				var regular := true
				for i in range(1,levels.size()): regular = regular and is_equal_approx(levels[i]-levels[i-1],12)
				check(regular and is_equal_approx(fposmod(LADDER.rung_origin(ladder)-levels[0],12),0),"rendered rungs share the hand-target grid: "+key)
				release()
				hero.reset_to(Vector2(ladder.get_center().x,ladder.end.y))
				await frames(8)
				Input.action_press("core_up")
				await frames(8)
				measure_arms()
				check(hero.climbing and hero.ladder_side_view == (not campaign and index>=2),"entry preserves orientation: "+key)
				Input.action_release("core_up")
				await frames(2)
				var position := hero.position
				var phase := hero.body.phase
				await frames(5)
				check(hero.position.is_equal_approx(position) and is_equal_approx(hero.body.phase,phase),"stopping holds body and phase: "+key)
				check(await climb(ladder,true),"full ascent exits onto the same landing: "+key)
				check(await climb(ladder,false),"full descent returns to the same ground: "+key)
			await app.return_to_menu()
			app.queue_free()
			await frames(3)
	check(reach_ok,"both characters reach ladder targets without IK clamping, including side views")
	check(bones_ok,"ladder grips preserve shoulder/forearm lengths")
	check(bends_ok,"narrow ladders do not force elbow folding beyond 120 degrees")
	print("MAXIMUM LADDER GRIP ERROR: ",maximum_grip_error)
	print("LADDER DIMENSIONS: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
