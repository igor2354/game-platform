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
	for frame in count:
		await physics_frame
		await process_frame
func fixture(kind: int,scale_value := 1.0) -> CoreHangingLoad:
	var item: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
	item.contents = kind
	item.position = Vector2(-1300,80)
	item.tuning = lab.ragdoll_settings.duplicate()
	item.tuning.hanging_scale = scale_value
	lab.level.add_child(item)
	return item
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	await frames(10)
	for kind in 3:
		for scale_value in [.5,1.0,2.0]:
			var item := fixture(kind,scale_value)
			await frames(8)
			item.release_load()
			await frames(2)
			var velocity := Vector2(130,470)
			item.queue_net_impact({"speed":470.0,"normal":Vector2.UP,"point":item.body.global_position+Vector2(0,item.body.dimensions.y*.5),"velocity":velocity,"spin":2.1})
			item.rupture_net()
			var momentum := Vector2.ZERO
			var correct_shapes := true
			var minimum_mass := INF
			var maximum_mass := 0.0
			for index in item.fragments.size():
				var piece := item.fragments[index]
				momentum += piece.linear_velocity*piece.mass
				minimum_mass = minf(minimum_mass,piece.mass)
				maximum_mass = maxf(maximum_mass,piece.mass)
				var collider := piece.get_child(0) as CollisionShape2D
				correct_shapes = correct_shapes and collider.shape is ConvexPolygonShape2D and collider.shape.points == item.body.chunks[index].polygon and is_equal_approx(piece.angular_velocity,2.1)
			check((momentum/item.body.mass).distance_to(velocity) < .001 and correct_shapes and maximum_mass > minimum_mass*1.2,"release conserves linear momentum, uses visible geometry and unequal material mass: %d at %.1f×" % [kind,scale_value])
			var overlaps := false
			for a in item.fragments.size():
				for b in range(a+1,item.fragments.size()):
					var first: PackedVector2Array = item.fragments[a].global_transform*item.fragments[a].polygon
					var second: PackedVector2Array = item.fragments[b].global_transform*item.fragments[b].polygon
					for intersection in Geometry2D.intersect_polygons(first,second):
						if CoreHangingLoadBody.MATERIAL.polygon_area(intersection) > .01: overlaps = true
			check(not overlaps,"activating contents never starts overlapping colliders: %d at %.1f×" % [kind,scale_value])
			check(item.torn_net.tethers.size() == 12 and item.fragments.all(func(piece): return piece.physics_material_override.bounce < .15),"the torn fabric stays attached to contents with low material restitution: %d at %.1f×" % [kind,scale_value])
			if kind == 0 and scale_value == 1.0:
				var piece := item.fragments[0]
				piece.apply_central_impulse(Vector2(-2000,-400)*piece.mass)
				await frames(15)
				check(item.torn_net.tethers.any(func(tether): return not is_instance_valid(tether.joint)),"an escaping physical piece tears its fabric attachment under tension")
			item.queue_free()
			await frames(3)
	# Opposite angular velocities exercise genuine tilted impacts, including
	# long thin boards and beams at the smallest supported collider scale.
	for kind in 3:
		for spin in [-1.1,1.1]:
			var item := fixture(kind,.5 if kind > 0 else 1.0)
			await frames(8)
			item.release_load()
			await frames(2)
			item.body.angular_velocity = spin
			await frames(260)
			var stable := item.ruptured and item.fragments.size() == 12
			for piece in item.fragments:
				stable = stable and piece.global_position.is_finite() and piece.global_position.y < 785 and piece.global_position.y > 500 and piece.linear_velocity.length() < 150
			check(stable,"tilted physical fall settles without tunnelling or unstable ejection: %d spin %.1f" % [kind,spin])
			item.queue_free()
			await frames(3)
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
