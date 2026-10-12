extends SceneTree

var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
# Contact recovery may add/remove up to safe_margin (0.08 px) per tick.
# Check the tangential target separately; capsule contact normals also vary
# slightly around the polygon's geometric angle.
const CONTACT_SPEED_TOLERANCE := 5.0
const TARGET_SPEED_TOLERANCE := 2.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func sample_speed() -> Vector2:
	var origin := hero.position
	var target_total := 0.0
	for tick in 6:
		await physics_frame
		target_total += absf(hero.ground_speed)
	return Vector2(hero.position.distance_to(origin)/(6*hero.get_physics_process_delta_time()),target_total/6)
func release_inputs() -> void:
	for action in ["core_left","core_right","core_jump","core_dash"]: Input.action_release(action)
func settle(point: Vector2) -> void:
	release_inputs()
	hero.reset_to(point)
	await frames(30)
func ramp_point(points: PackedVector2Array,side: int) -> Vector2:
	return points[side].lerp(points[side+1],.5)-Vector2(0,10)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	await frames(8)
	check(lab.level.slopes.size() == 2,"two hills have real solid collision ramps")
	for i in lab.level.slopes.size():
		var points := lab.level.slopes[i]
		var label := "%d degree hill" % [20 if i == 0 else 35]
		for sign in [1,-1]:
			var start_x := points[0].x-35 if sign == 1 else points[3].x+35
			var finish_x := points[3].x+30 if sign == 1 else points[0].x-30
			await settle(Vector2(start_x,760))
			Input.action_press("core_right" if sign == 1 else "core_left")
			var airborne_frames := 0
			var min_y := hero.position.y
			var finished := false
			for tick in 230:
				await physics_frame
				if not hero.is_on_floor(): airborne_frames += 1
				min_y = minf(min_y,hero.position.y)
				if (hero.position.x-finish_x)*sign >= 0:
					finished = true
					break
			check(finished and min_y < points[1].y+3,"run traverses ascent, crest and descent of "+label+" direction "+str(sign)+" (x %.1f, top %.1f, target %.1f)" % [hero.position.x,min_y,points[1].y])
			check(airborne_frames == 0,"no unwanted lift-off on "+label+" direction "+str(sign)+" (air frames %d)" % airborne_frames)
		for side in [0,2]:
			await settle(ramp_point(points,side))
			check(hero.is_on_floor(),"player lands on "+label+" ramp "+str(side))
			var rest := hero.position
			await frames(40)
			check(hero.position.distance_to(rest) < .1,"standing still does not slide on "+label+" ramp "+str(side))
			for sign in [1,-1]:
				await settle(ramp_point(points,side))
				Input.action_press("core_right" if sign == 1 else "core_left")
				await frames(15)
				var sample := await sample_speed()
				var uphill: bool = (side == 0 and sign == 1) or (side == 2 and sign == -1)
				# Independent numeric expectations for the default 20°/35° ramps.
				var expected := (267.51 if uphill else 346.25) if i == 0 else (224.0 if uphill else 368.0)
				check(absf(sample.x-expected) < CONTACT_SPEED_TOLERANCE and absf(sample.y-expected) < TARGET_SPEED_TOLERANCE,"surface running speed responds to "+label+" ramp "+str(side)+" direction "+str(sign)+" (%.1f px/s, mean target %.3f, expected %.1f)" % [sample.x,sample.y,expected])
				release_inputs()
				await frames(15)
				var stopped := hero.position
				await frames(15)
				check(hero.position.distance_to(stopped) < .1,"braking holds position on "+label+" ramp "+str(side)+" direction "+str(sign))
				await settle(ramp_point(points,side))
				Input.action_press("core_right" if sign == 1 else "core_left")
				Input.action_press("core_dash")
				var origin := hero.position
				var grounded := true
				await frames(2)
				for tick in 10:
					await physics_frame
					grounded = grounded and hero.is_on_floor()
				check(grounded and hero.position.distance_to(origin) > 115 and hero.dashes == 1,"dash follows "+label+" ramp "+str(side)+" direction "+str(sign)+" (grounded %s, distance %.1f, dashes %d)" % [grounded,hero.position.distance_to(origin),hero.dashes])
			await settle(ramp_point(points,side))
			var jump_y := hero.position.y
			Input.action_press("core_jump")
			await frames(4)
			check(not hero.is_on_floor() and hero.position.y < jump_y-20 and hero.jumps == 1,"jump detaches freely from "+label+" ramp "+str(side))
			await frames(55)
			check(hero.is_on_floor(),"jump lands back on "+label+" ramp "+str(side))
		# Dash across both convex transitions with uninterrupted ground contact.
		await settle(points[1]-Vector2(10,25))
		Input.action_press("core_right")
		Input.action_press("core_dash")
		var on_crest := true
		await frames(2)
		for tick in 13:
			await physics_frame
			on_crest = on_crest and hero.is_on_floor()
		check(on_crest and hero.position.x > points[2].x,"dash remains grounded across the crest of "+label)
	# Change the live runtime settings on each side of the steep hill, then
	# neutralise the effect without resetting the moving player.
	var steep := lab.level.slopes[1]
	for side in [0,2]:
		for sign in [1,-1]:
			hero.tuning.apply_values({"uphill_multiplier":.5,"downhill_multiplier":1.25})
			await settle(steep[side].lerp(steep[side+1],.3 if sign == 1 else .7)-Vector2(0,10))
			Input.action_press("core_right" if sign == 1 else "core_left")
			await frames(12)
			var sample := await sample_speed()
			var uphill: bool = (side == 0 and sign == 1) or (side == 2 and sign == -1)
			var expected := 160.0 if uphill else 400.0
			check(absf(sample.x-expected) < CONTACT_SPEED_TOLERANCE and absf(sample.y-expected) < TARGET_SPEED_TOLERANCE,"custom slope speeds work on both faces and directions (%.1f px/s)" % sample.x)
			hero.tuning.apply_values({"uphill_multiplier":1.0,"downhill_multiplier":1.0})
			await frames(7)
			sample = await sample_speed()
			check(absf(sample.x-320) < CONTACT_SPEED_TOLERANCE and absf(sample.y-320) < .1 and hero.is_on_floor(),"live 1x settings restore ordinary surface speed without lifting off (%.1f px/s)" % sample.x)
	# The angle sliders must affect actual movement, not just the preview.
	for full_angle in [45.0,16.0]:
		hero.tuning.apply_values({"uphill_multiplier":.5,"slope_start_angle":15.0,"slope_full_angle":full_angle})
		await settle(ramp_point(lab.level.slopes[0],0))
		Input.action_press("core_right")
		await frames(12)
		var sample := await sample_speed()
		var expected := 308.15 if full_angle == 45 else 160.0
		check(absf(sample.x-expected) < CONTACT_SPEED_TOLERANCE and absf(sample.y-expected) < TARGET_SPEED_TOLERANCE,"angle thresholds alter measured running speed (full angle %.0f°, %.1f px/s)" % [full_angle,sample.x])
	release_inputs()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
