extends RefCounted
var player: CharacterBody2D
var flight: Node2D
var progress := 0.0
var ignored: Array[PhysicsBody2D] = []
var noise_distance := 0.0
func _init(actor: CharacterBody2D) -> void: player=actor
func cancel() -> void:
	if is_instance_valid(flight): player.velocity=Vector2.ZERO;player.ground_speed=0
	for floor_body in ignored:
		if is_instance_valid(floor_body): player.remove_collision_exception_with(floor_body)
	ignored.clear();flight=null
	noise_distance=0
func refresh_floors() -> void:
	for floor_body in ignored:
		if is_instance_valid(floor_body): player.remove_collision_exception_with(floor_body)
	ignored.clear()
	for path in flight.pass_through_floors:
		var floor_body=flight.get_node_or_null(path)
		if floor_body is PhysicsBody2D:
			player.add_collision_exception_with(floor_body);ignored.append(floor_body)
func tick(delta: float, axis: float, vertical: float, allowed: bool) -> bool:
	if not ignored.is_empty() and not is_instance_valid(flight): cancel()
	if flight and (not is_instance_valid(flight) or not player.tuning.stairs_enabled or player.health<=0 or player.blast_ragdoll.active or player.barrel_knockdown_left>0): cancel()
	if not flight:
		if not allowed or not player.tuning.stairs_enabled or axis==0 or vertical==0 or not player.is_on_floor() or player.climbing or player.parkour_active() or player.pushing or player.crouching or player.shove_left>0 or player.dash_left>0 or player.slide_left>0 or player.grenades.busy() or Input.is_action_pressed("core_jump"): return false
		var best := INF
		for candidate in player.get_tree().get_nodes_in_group("ordinary_stairs"):
			var ends: PackedVector2Array = candidate.endpoints()
			if absf(ends[1].x-ends[0].x)<1 or ends[1].y>=ends[0].y: continue
			for i in 2:
				var distance := player.global_position.distance_to(ends[i])
				if distance>player.motion_value("stairs_entry_radius") or distance>=best or absf(player.position.y-ends[i].y)>player.motion_value("stairs_entry_height"): continue
				if signf(axis)!=signf(ends[1-i].x-ends[i].x) or signf(vertical)!=(-1.0 if i==0 else 1.0): continue
				flight=candidate;progress=float(i);best=distance
		if not flight: return false
		refresh_floors()
	# A shared unsupported half-landing connects two flights without a teleport.
	if allowed and vertical!=0 and axis!=0 and (progress==0 or progress==1):
		for candidate in player.get_tree().get_nodes_in_group("ordinary_stairs"):
			if candidate==flight: continue
			var points: PackedVector2Array=candidate.endpoints()
			var index := 0 if vertical<0 else 1
			if player.global_position.distance_to(points[index])<1 and signf(points[1-index].x-points[index].x)==signf(axis):
				flight=candidate;progress=float(index);refresh_floors();break
	# Keep world collision enabled: walls and props remain solid.
	var ends: PackedVector2Array=flight.endpoints()
	var next := progress
	player.weapon.update_state(delta,allowed)
	player.sprinting=allowed and player._can_sprint(axis)
	player.walking=player.walk_requested or not player.tuning.run_enabled
	var multiplier: float=player.tuning.stairs_sprint_multiplier if player.sprinting else 1.0 if player.walking else player.tuning.stairs_run_multiplier
	if allowed: next=clampf(progress+axis*signf(ends[1].x-ends[0].x)*player.motion_value("stairs_speed")*multiplier*delta/ends[0].distance_to(ends[1]),0,1)
	var target := ends[0].lerp(ends[1],next)-Vector2(0,.3)
	var before: Vector2=player.global_position
	player.move_and_collide(target-before)
	if player.global_position.distance_to(target)<.5: progress=next
	player.velocity=(player.global_position-before)/maxf(delta,.001)
	player.ground_speed=player.velocity.x;player.coyote=0;player.jump_buffer=0
	player.mode=("sprint" if player.sprinting else "walk" if player.walking else "run") if absf(player.velocity.x)>1 else "idle"
	player._tick_sprint_reserve(delta,false)
	player.body.advance(delta)
	player.weapon.finish_tick();player.body.update_arms();player.queue_redraw()
	noise_distance+=player.global_position.distance_to(before)
	if noise_distance>=64:
		noise_distance=fmod(noise_distance,64)
		var loudness: float=player.tuning.sprint_noise_multiplier if player.sprinting else player.tuning.slow_walk_noise_multiplier if player.walking else 1.0
		player.noise_emitted.emit(player.global_position-Vector2(0,8),loudness,"step")
	if (progress==0 or progress==1) and axis!=0 and player.parkour._supported(player.global_position): cancel()
	return true
