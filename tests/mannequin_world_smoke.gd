extends SceneTree
const ART = preload("res://scripts/core/mannequin_art.gd")
const LIVE = preload("res://scripts/core/live_zombie.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	for map in [0,1,2]:
		var level := CoreMovementLevel.new()
		level.prologue_mode = map > 0
		level.prologue_version = maxi(1,map)
		root.add_child(level)
		await frames(4)
		var stationary := 0
		for enemy in level.enemies:
			check(enemy.has_method("draw_live_piece") and enemy is CoreConceptZombie,"all actors share mannequin presentation on map %d" % map)
			check(enemy.current_pose().parts.size() == 13,"all actors have physical bind segments")
			if enemy.stationary_target:
				stationary += 1
				var point: Vector2 = enemy.position
				await frames(4)
				check(enemy.position.distance_to(point) < .001,"static target retains stationary role")
				var foot: Dictionary = enemy.current_pose().parts.right_foot
				check(absf(foot.position.y+foot.dimensions.y*.5) < .01,"static mannequin feet stay on the support plane")
		check(stationary == 4,"three static targets and under-load target retained")
		for door in level.transition_doors: check(door.z_index < level.zombie.z_index,"door marker behind enemy")
		var actor: CoreConceptZombie = level.zombie
		actor.set_test_frozen(true)
		actor.walk_phase = TAU
		var phase := actor.locomotion_animation_phase("chase")
		actor.scale = Vector2(2,2)
		check(absf(actor.locomotion_animation_phase("chase")*2-phase) < .0001,"node transform scale also preserves world stride on every map")
		actor.scale = Vector2.ONE
		actor.missing_parts.assign(["left_arm","left_leg","right_leg"])
		actor.preview_clip = "crawl"
		actor.preview_frame = 0
		var start: Vector2 = actor.current_pose().parts.right_forearm.position
		actor.preview_frame = 8
		check(start.distance_to(actor.current_pose().parts.right_forearm.position) > 1,"remaining arm moves when crawling without legs")
		actor.missing_parts.assign(["left_leg"])
		actor.preview_frame = 0
		start = actor.current_pose().parts.right_shin.position
		actor.preview_frame = 8
		check(start.distance_to(actor.current_pose().parts.right_shin.position) > .1,"remaining leg participates in crawling")
		level.queue_free()
		await frames(4)
	for clip in CoreConceptZombieArt.CLIPS:
		var valid := true
		for i in 33:
			var p := ART.pose(clip,float(i)/32)
			for side in ["left","right"]:
				for bone in ["upper_arm","forearm","thigh","shin"]:
					var length: float = p.parts[side+"_"+bone].dimensions.y
					valid = valid and absf(length-({"upper_arm":10.2396288995,"forearm":16.3713163796,"thigh":13.3575821165,"shin":13.4440507289}[bone])) < .001
		check(valid,"fixed limb lengths across complete motion: "+clip)
	print("MANNEQUIN WORLD: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
