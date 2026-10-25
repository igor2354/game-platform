extends RefCounted
## Collision-driven traversal. Artwork/animation can later follow stage/progress.
const SURFACES := 1 | 8
const SKIN := 0.3
var player: CharacterBody2D
var active := false
var kind := ""
var stage := ""
var progress := 0.0
var direction := 1.0
var cooldown := 0.0
var source: StaticBody2D
var ledge := Vector2.ZERO
var destination := Vector2.ZERO
var waypoints := PackedVector2Array()
var waypoint := 0
var from := Vector2.ZERO
var elapsed := 0.0
var duration := 0.0
var segment_duration := 0.0
var hang_time := 0.0
var jump_was_held := true
var climb_requested := false
var jump_rearm_required := false
var sprint_assist := false
var entry_speed := 0.0

func _init(actor: CharacterBody2D) -> void:
	player = actor

func cancel(delay := true) -> void:
	active = false
	stage = ""
	progress = 0
	source = null
	waypoints.clear()
	climb_requested = false
	sprint_assist = false
	entry_speed = 0
	player.jump_buffer = 0
	player.coyote = 0
	if delay: cooldown = player.tuning.parkour_regrab_delay
	else:
		cooldown = 0
		jump_rearm_required = false

func _ray(a: Vector2,b: Vector2,mask := SURFACES) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(a,b,mask,[player.get_rid()])
	return player.get_world_2d().direct_space_state.intersect_ray(query)

func _surface(hit: Dictionary) -> bool:
	return not hit.is_empty() and hit.collider is StaticBody2D

func _clear_at(feet: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.standing_capsule
	query.transform = Transform2D(0,Vector2.ONE*player.body_scale,0,feet-Vector2(0,(player.HEIGHT*player.body_scale)*.5))
	query.collision_mask = player.WORLD_MASK
	query.exclude = [player.get_rid()]
	query.margin = .01
	return player.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _clear_segment(a: Vector2,b: Vector2) -> bool:
	if not _clear_at(b): return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.standing_capsule
	query.transform = Transform2D(0,Vector2.ONE*player.body_scale,0,a-Vector2(0,(player.HEIGHT*player.body_scale)*.5))
	query.motion = b-a
	query.collision_mask = player.WORLD_MASK
	query.exclude = [player.get_rid()]
	query.margin = .01
	return player.get_world_2d().direct_space_state.cast_motion(query)[0] >= 1.0

func _supported(feet: Vector2) -> bool:
	# Both sides need support: no landing on the very tip of a narrow post.
	for offset in [-player.world_radius()+2,player.world_radius()-2]:
		var hit := _ray(feet+Vector2(offset,-2),feet+Vector2(offset,3))
		if not _surface(hit) or hit.normal.y > -.85: return false
	return true

func try_sprint(axis: float) -> bool:
	if not player.tuning.sprint_auto_parkour_enabled or not player.is_on_floor() or not player._can_sprint(axis): return false
	return try_start(axis,true,true)

func try_start(axis: float,held: bool,automatic := false) -> bool:
	if not held: jump_rearm_required = false
	if jump_rearm_required: return false
	if not held or cooldown > 0 or not player.tuning.parkour_enabled: return false
	if player.health <= 0 or player.climbing or player.pushing or player.dash_left > 0 or player.slide_left > 0 or player.shove_left > 0 or player.barrel_knockdown_left > 0 or player.grenades.busy() or player.blast_ragdoll.active: return false
	# The visible gaze, including backwards movement, decides which edge is reachable.
	direction = signf(axis) if automatic else player.weapon.look_facing()
	if axis != 0 and signf(axis) != direction: return false
	var feet: Vector2 = player.global_position
	var reach: float = player.world_radius()+player.motion_value("parkour_reach")
	var max_height: float = player.HEIGHT*player.body_scale*player.tuning.sprint_auto_max_height_ratio if automatic else player.motion_value("parkour_ledge_height")
	var min_height: float = player.HEIGHT*player.body_scale*player.tuning.sprint_auto_min_height_ratio if automatic else (16 if player.is_on_floor() else 40)*player.body_scale
	# Several short probes also catch the vertical edge of thin one-way decks.
	var visited := {}
	for height_probe in range(8,ceili(max_height)+8,8):
		var origin := feet-Vector2(0,minf(height_probe,max_height))
		var wall := _ray(origin,origin+Vector2(direction*reach,0))
		if not _surface(wall) or wall.normal.x*direction > -.85: continue
		var edge_x: float = wall.position.x
		var id: int = wall.collider.get_instance_id()
		if visited.has(id) and is_equal_approx(visited[id],edge_x): continue
		visited[id] = edge_x
		var top := _ray(Vector2(edge_x+direction*2,feet.y-max_height-1),Vector2(edge_x+direction*2,feet.y-8))
		if not _surface(top) or top.collider != wall.collider or top.normal.y > -.85: continue
		ledge = Vector2(edge_x,top.position.y)
		var height: float = feet.y-ledge.y
		var tolerance := .01 if automatic else 0.0
		if height < min_height-tolerance or height > max_height+tolerance: continue
		var landing := Vector2(edge_x+direction*(player.world_radius()+3),ledge.y-SKIN)
		if not _supported(landing) or not _clear_at(landing): continue
		source = wall.collider
		kind = "mantle"
		destination = landing
		if player.is_on_floor() and (automatic or height <= player.motion_value("parkour_vault_height")):
			var other := _vault_landing(automatic)
			if other != Vector2.INF:
				kind = "vault"
				destination = other
		var start := feet
		if kind == "mantle":
			start = Vector2(edge_x-direction*(player.world_radius()+SKIN),maxf(feet.y,ledge.y+(player.HEIGHT*player.body_scale)*.85))
			# Don't pull a grounded actor down through its floor to create a hang.
			if player.is_on_floor(): start.y = feet.y-SKIN
			if not _clear_segment(feet,start): continue
		var up := Vector2(start.x,ledge.y-player.motion_value("parkour_clearance"))
		var across := Vector2(destination.x,up.y)
		if not _clear_segment(start,up) or not _clear_segment(up,across) or not _clear_segment(across,destination): continue
		# Searching must not repeatedly stand up a crouching actor away from edges.
		if not player._try_stand(): continue
		waypoints = PackedVector2Array([up,across,destination])
		sprint_assist = automatic
		entry_speed = absf(player.velocity.x)
		player.move_and_collide(start-feet)
		player.velocity = Vector2.ZERO
		player.ground_speed = 0
		player.ground_acceleration = 0
		player.jump_buffer = 0
		player.coyote = 0
		player.sprinting = false
		player.walking = false
		player.weapon.cancel_reload()
		active = true
		stage = "ledge_hang" if kind == "mantle" and not automatic else kind
		progress = 0
		jump_was_held = true
		climb_requested = false
		hang_time = player.tuning.parkour_hang_time if kind == "mantle" else 0.0
		duration = (player.tuning.parkour_mantle_time if kind == "mantle" else player.tuning.parkour_vault_time)/player.motion_scale()
		if automatic: duration = player.tuning.sprint_auto_vault_time
		waypoint = 0
		_begin_segment()
		return true
	source = null
	return false

func _vault_landing(automatic := false) -> Vector2:
	# Find a far edge on the same static obstacle, with bounded work per attempt.
	var previous := 2.0
	var distance := 8.0
	var limit: float = player.motion_value("sprint_auto_max_width" if automatic else "parkour_vault_width")
	while distance <= limit+8:
		var x := ledge.x+direction*distance
		var hit := _ray(Vector2(x,ledge.y-2),Vector2(x,ledge.y+4))
		if not _surface(hit) or hit.collider != source:
			var low := previous
			var high := distance
			for i in 6:
				var mid := (low+high)*.5
				var probe := _ray(Vector2(ledge.x+direction*mid,ledge.y-2),Vector2(ledge.x+direction*mid,ledge.y+4))
				if _surface(probe) and probe.collider == source: low = mid
				else: high = mid
			if high > limit: return Vector2.INF
			var landing_x: float = ledge.x+direction*(high+player.world_radius()+3)
			var drop: float = player.motion_value("parkour_drop_limit")
			var ground := _ray(Vector2(landing_x,ledge.y-2),Vector2(landing_x,player.global_position.y+drop))
			if not _surface(ground) or ground.normal.y > -.85: return Vector2.INF
			var feet := Vector2(landing_x,ground.position.y-SKIN)
			if _supported(feet) and _clear_at(feet): return feet
			return Vector2.INF
		previous = distance
		distance += 8
	return Vector2.INF

func _begin_segment() -> void:
	from = player.global_position
	elapsed = 0
	# Vertical lift, crossing, controlled landing; timings are frozen at entry.
	segment_duration = duration*[.40,.45,.15][waypoint]

func tick(delta: float,held: bool,cancel_requested: bool,input_allowed: bool) -> void:
	player.velocity = Vector2.ZERO
	var jump_pressed := held and not jump_was_held
	jump_was_held = held
	if not is_instance_valid(source) or source.collision_layer & SURFACES == 0 or not player.tuning.parkour_enabled or (sprint_assist and not player.tuning.sprint_auto_parkour_enabled):
		cancel()
		return
	if not input_allowed: return
	if sprint_assist:
		player.sprint_reserve = maxf(0,player.sprint_reserve-delta/player.tuning.sprint_duration)
		if player.sprint_reserve <= .00001: player.sprint_exhausted = true
	if cancel_requested:
		cancel()
		# A held Jump must not immediately catch the same ledge after dropping.
		jump_rearm_required = held
		return
	if stage == "ledge_hang":
		hang_time = maxf(0,hang_time-delta)
		if jump_pressed: climb_requested = true
		if not climb_requested or hang_time > 0: return
		stage = "mantle"
	# Moving props/enemies can block a previously clear route: sweep every tick.
	elapsed = minf(elapsed+delta,segment_duration)
	var weight := smoothstep(0,1,elapsed/segment_duration)
	var next := from.lerp(waypoints[waypoint],weight)
	var collision := player.move_and_collide(next-player.global_position)
	if collision:
		cancel()
		return
	progress = (waypoint+weight)/3.0
	if elapsed < segment_duration: return
	waypoint += 1
	if waypoint < waypoints.size():
		_begin_segment()
		return
	var axis := Input.get_axis("core_left","core_right")
	var resume: bool = sprint_assist and player._can_sprint(axis) and signf(axis)==direction
	var outgoing := direction*minf(entry_speed,player.motion_value("sprint_speed")) if resume else 0.0
	cancel()
	player.velocity = Vector2(outgoing,1)
	player.move_and_slide()
	player.apply_floor_snap()
	player.velocity = Vector2(outgoing,0)
	if resume:
		player.ground_speed = outgoing
		player.sprinting = true
