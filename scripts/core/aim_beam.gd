extends Node
## Player-only HUD geometry. Never lights, damages or reveals anything to AI.
const SEGMENTS := 96
const RINGS := [0.0, .65, 1.0]
const COLOR := Color(.93,.96,1)
var weapon: Node2D
var mesh := ArrayMesh.new()
var origin := Vector2.ZERO
var end := Vector2.ZERO
var half_angle := 0.0
var points := PackedVector2Array()
var ready_to_draw := false
var rays_last_tick := 0
var update_usec := 0
var reach := 1.0

var ray := PhysicsRayQueryParameters2D.new()
var mesh_indices := PackedInt32Array()

func _init() -> void:
	ray.collision_mask = CoreProjectile.BULLET_MASK
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	for i in SEGMENTS:
		for ring in 2:
			var a := i * 3 + ring
			mesh_indices.append_array(PackedInt32Array([a,a+3,a+1,a+1,a+3,a+4]))

func allowed() -> bool:
	var p = weapon.player
	if weapon.input_blocker.is_valid() and bool(weapon.input_blocker.call()): return false
	return not weapon.shovel_selected() and weapon.tuning.aim_beam_enabled and weapon.tuning.weapon_enabled and p.health > 0 and not weapon.reloading and not p.climbing and not p.parkour_active() and not p.pushing and p.dash_left <= 0 and p.slide_left <= 0 and p.barrel_knockdown_left <= 0 and not p.blast_ragdoll.active and not p.grenades.busy()

func _physics_process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	ready_to_draw = false
	rays_last_tick = 0
	if not allowed(): return
	var cursor = weapon.aim_cursor
	if not is_instance_valid(cursor) or not cursor.active: return
	# Read the already-solved mount once. No IK or aim search per sample.
	var pivot: Vector2 = weapon.pivot()
	origin = weapon.muzzle_position()
	var space := weapon.get_world_2d().direct_space_state
	ray.exclude = [weapon.player.get_rid()]
	if not _hit(space,pivot,origin).is_empty(): return
	half_angle = deg_to_rad(weapon.spread_degrees())
	var projection: Transform2D = cursor._canvas_projection()
	reach = minf(weapon.tuning.bullet_speed*1.5,weapon.get_viewport_rect().size.length()/maxf(.01,projection.get_scale().x)*1.2)
	points.clear()
	var count := SEGMENTS if half_angle > .000001 else 0
	for i in count+1:
		var angle := lerpf(-half_angle,half_angle,float(i)/count) if count else 0.0
		var target: Vector2 = origin+weapon.aim_direction.rotated(angle)*reach
		var hit := _hit(space,origin,target)
		points.append(hit.position if not hit.is_empty() else target)
	end = points[count/2 if count else 0]
	if count: _build_mesh(reach)
	ready_to_draw = true
	update_usec = Time.get_ticks_usec()-started

func _hit(space: PhysicsDirectSpaceState2D,a: Vector2,b: Vector2) -> Dictionary:
	rays_last_tick += 1
	ray.from = a
	ray.to = b
	return space.intersect_ray(ray)

func _build_mesh(reach: float) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var opacity: float = weapon.tuning.beam_ads_opacity if weapon.aiming else weapon.tuning.beam_hip_opacity
	var softness: float = weapon.tuning.beam_edge_softness
	# Feather stays INSIDE the true angular envelope. No bright central spine.
	for i in points.size():
		var edge := 1.0-absf(2.0*i/SEGMENTS-1.0)
		var feather := smoothstep(0,maxf(.0001,softness),edge) if softness > 0 else 1.0
		for fraction in RINGS:
			var point := origin.lerp(points[i],fraction)
			vertices.append(Vector3(point.x,point.y,0))
			var fade: float = 1.0-weapon.tuning.beam_distance_fade*smoothstep(.2,1.0,origin.distance_to(point)/reach)
			colors.append(Color(COLOR,opacity*feather*fade))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = mesh_indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func draw_on(canvas: Node2D,world_projection: Transform2D) -> void:
	if not ready_to_draw or not allowed() or not weapon.aim_cursor.active: return
	if half_angle > .000001:
		canvas.draw_set_transform_matrix(world_projection)
		canvas.draw_mesh(mesh,null)
	else:
		# Screen-space width stays readable with every camera/pixel-world mode.
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		var a := world_projection*origin
		var b := world_projection*end
		var alpha: float = weapon.tuning.beam_ads_opacity if weapon.aiming else weapon.tuning.beam_hip_opacity
		var width: float = weapon.tuning.beam_line_width
		var softness: float = weapon.tuning.beam_edge_softness
		var fade: float = 1.0-weapon.tuning.beam_distance_fade*smoothstep(.2,1.0,origin.distance_to(end)/reach)
		if softness > 0:
			_strip(canvas,a,b,width+softness*6,alpha*.12,fade)
			_strip(canvas,a,b,width+softness*3,alpha*.2,fade)
		_strip(canvas,a,b,width,alpha,fade)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _strip(canvas: Node2D,a: Vector2,b: Vector2,width: float,alpha: float,fade: float) -> void:
	if a.distance_squared_to(b) < .01: return
	var normal := (b-a).normalized().orthogonal()*width*.5
	canvas.draw_polygon(PackedVector2Array([a-normal,b-normal,b+normal,a+normal]),PackedColorArray([Color(COLOR,alpha),Color(COLOR,alpha*fade),Color(COLOR,alpha*fade),Color(COLOR,alpha)]))
