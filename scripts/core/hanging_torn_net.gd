extends Node2D
## A sheet of physical knots joined by breakable springs. The impact opens
## the loaded seam; surviving links stretch, sag, collide and can tear again.
var assembly: Node2D
var knots: Array[RigidBody2D] = []
var links: Array[Dictionary] = []
var broken_links := 0
var strain_breaks := 0
var frozen_states: Array[Dictionary] = []
var tethers: Array[Dictionary] = []
var ground_tear := false
var tear_age := 0.0
var tear_speed := 0.0
var tear_normal := Vector2.UP
var tear_queue: Array[Dictionary] = []
var fibres: Array[Dictionary] = []
var previous_velocities: Array[Vector2] = []

func build(pose: Transform2D,size: Vector2,velocity: Vector2,spin: float,impact: Vector2,ground_hit := false,normal := Vector2.UP,speed := 0.0) -> void:
	for row in 4:
		for column in 5:
			var knot := RigidBody2D.new()
			knot.mass = .035
			knot.collision_layer = 32
			knot.collision_mask = 1|8
			knot.linear_damp = .6
			knot.angular_damp = 1.0
			knot.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
			knot.max_contacts_reported = 4
			var material := PhysicsMaterial.new()
			material.friction = .8
			knot.physics_material_override = material
			var local_point := Vector2((column/4.0-.5)*size.x*[.86,.96,.9,.64][row],(row/3.0-.5)*size.y)
			add_child(knot)
			knot.global_position = pose*local_point
			var collider := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 2
			collider.shape = shape
			knot.add_child(collider)
			# The web lies on the front face of the cargo in this 2D view.
			# Do not spawn overlapping knots inside the solid contents.
			for piece in assembly.fragments: knot.add_collision_exception_with(piece)
			knot.linear_velocity = velocity+Vector2(-spin*local_point.y,spin*local_point.x).rotated(pose.get_rotation())
			knots.append(knot)
			previous_velocities.append(knot.linear_velocity)
	for row in 4:
		for column in 5:
			var index := row*5+column
			if column < 4: _connect(index,index+1)
			if row < 3: _connect(index,index+5)
	# Impact stress first ruptures the seam nearest the contact, rather than
	# turning the entire net into disconnected particles.
	var nearest := 0
	for index in knots.size():
		if knots[index].global_position.distance_squared_to(impact) < knots[nearest].global_position.distance_squared_to(impact): nearest = index
	for link in links:
		if link.a == nearest or link.b == nearest: _break(link,false)
	# A few surviving fabric attachments keep the sheet draped over the
	# contents. They pull physical knots, then tear as pieces leave the bag.
	for piece in assembly.fragments:
		var closest := 6
		for index in [6,7,8,11,12,13]:
			if knots[index].global_position.distance_squared_to(piece.global_position) < knots[closest].global_position.distance_squared_to(piece.global_position): closest = index
		var offset: Vector2 = piece.global_position-knots[closest].global_position
		var spring := DampedSpringJoint2D.new()
		add_child(spring)
		spring.global_position = knots[closest].global_position
		spring.global_rotation = Vector2.DOWN.angle_to(offset)
		spring.length = maxf(1,offset.length())
		spring.rest_length = spring.length
		spring.stiffness = 9
		spring.damping = .8
		spring.node_a = spring.get_path_to(knots[closest])
		spring.node_b = spring.get_path_to(piece)
		tethers.append({"knot":closest,"piece":piece,"joint":spring,"length":spring.length,"allowance":size.y*.45})
	if ground_hit: start_ground_tear(impact,normal,speed)
	queue_redraw()

func start_ground_tear(point: Vector2,normal: Vector2,speed: float) -> void:
	if ground_tear or not assembly.tuning.hanging_net_tear_enabled: return
	ground_tear = true
	tear_normal = normal.normalized()
	tear_speed = clampf(speed*.11,28,85)
	# Open a complete seam, rather than punching a barely visible hole at
	# one knot. Sort the four rows by distance from the actual contact so
	# the crack travels away from the ground over 0.12 seconds.
	for link in links:
		if link.a%5 == 1 and link.b == link.a+1:
			var middle: Vector2 = (knots[link.a].global_position+knots[link.b].global_position)*.5
			tear_queue.append({"link":link,"distance":middle.distance_squared_to(point)})
	tear_queue.sort_custom(func(a,b): return a.distance < b.distance)
	for index in tear_queue.size(): tear_queue[index].time = index*.04
	_emit_fibres(point,10)
	assembly.queue_floor_impact(point,speed)
	_advance_ground_tear()

func _advance_ground_tear() -> void:
	while not tear_queue.is_empty() and tear_queue[0].time <= tear_age:
		var cut: Dictionary = tear_queue.pop_front()
		var link: Dictionary = cut.link
		_break(link,false)
		link.ground_cut = true
		var middle: Vector2 = (knots[link.a].global_position+knots[link.b].global_position)*.5
		_emit_fibres(middle,5)
		var row: int = link.a/5
		# Release fabric attachments along the opening. Outer attachments
		# still hold the flaps against the cargo as the two sides peel apart.
		for tether in tethers:
			if tether.knot/5 == row and tether.knot%5 in [1,2]: _detach_tether(tether)
		var tangent := Vector2(-tear_normal.y,tear_normal.x)
		for column in 5:
			var knot := knots[row*5+column]
			var side := -1.0 if column < 2 else 1.0
			knot.apply_central_impulse((tangent*side*tear_speed+tear_normal*12)*knot.mass)
			knot.sleeping = false

func _detach_tether(tether: Dictionary) -> void:
	if not is_instance_valid(tether.joint): return
	tether.joint.node_a = NodePath()
	tether.joint.node_b = NodePath()
	tether.joint.queue_free()
	tether.joint = null

func _emit_fibres(point: Vector2,count: int) -> void:
	var tangent := Vector2(-tear_normal.y,tear_normal.x)
	for index in count:
		var phase := float(index)*2.399+broken_links*.71
		fibres.append({"point":point+tear_normal*1.5,"velocity":tangent*sin(phase)*tear_speed+tear_normal*(20+absf(cos(phase))*45),"life":.42,"angle":phase})

func _check_ground_contacts() -> void:
	if ground_tear: return
	for index in knots.size():
		var knot := knots[index]
		if not ground_tear:
			var state := PhysicsServer2D.body_get_direct_state(knot.get_rid())
			if state:
				for contact in state.get_contact_count():
					var surface := state.get_contact_collider_object(contact)
					var normal := state.get_contact_local_normal(contact)
					var speed := maxf(-previous_velocities[index].dot(normal),-state.linear_velocity.dot(normal))
					if surface is StaticBody2D and normal.dot(Vector2.UP) > .2 and speed > 60:
						start_ground_tear(state.get_contact_collider_position(contact),normal,speed)
						break
		previous_velocities[index] = knot.linear_velocity

func _connect(a: int,b: int) -> void:
	var delta := knots[b].global_position-knots[a].global_position
	var spring := DampedSpringJoint2D.new()
	add_child(spring)
	spring.global_position = knots[a].global_position
	spring.global_rotation = Vector2.DOWN.angle_to(delta)
	spring.length = delta.length()
	spring.rest_length = delta.length()
	spring.stiffness = 18
	spring.damping = 1.5
	spring.node_a = spring.get_path_to(knots[a])
	spring.node_b = spring.get_path_to(knots[b])
	links.append({"a":a,"b":b,"length":delta.length(),"joint":spring,"broken":false})

func _break(link: Dictionary,from_strain: bool) -> void:
	if link.broken: return
	link.broken = true
	link.age = 0.0
	link.axis = (knots[link.b].global_position-knots[link.a].global_position).normalized()
	broken_links += 1
	if from_strain: strain_breaks += 1
	var spring: DampedSpringJoint2D = link.joint
	spring.node_a = NodePath()
	spring.node_b = NodePath()
	spring.queue_free()
	link.joint = null

func set_simulation_enabled(enabled: bool) -> void:
	if enabled:
		for index in frozen_states.size():
			knots[index].freeze = false
			knots[index].linear_velocity = frozen_states[index].velocity
			knots[index].angular_velocity = frozen_states[index].spin
			knots[index].sleeping = false
		frozen_states.clear()
	elif frozen_states.is_empty():
		for knot in knots:
			frozen_states.append({"pose":knot.global_transform,"velocity":knot.linear_velocity,"spin":knot.angular_velocity})
			knot.freeze = true

func _physics_process(delta: float) -> void:
	if not frozen_states.is_empty():
		for index in knots.size(): knots[index].global_transform = frozen_states[index].pose
		return
	_check_ground_contacts()
	if ground_tear:
		tear_age += delta
		_advance_ground_tear()
	for fibre in fibres:
		fibre.life -= delta
		fibre.velocity += Vector2.DOWN*420*delta
		var next_point: Vector2 = fibre.point+fibre.velocity*delta
		if fibre.point.distance_squared_to(next_point) > .001:
			var query := PhysicsRayQueryParameters2D.create(fibre.point,next_point,1|8)
			var hit := get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				next_point = hit.position+hit.normal*.5
				fibre.velocity = fibre.velocity.bounce(hit.normal)*.2
		fibre.point = next_point
		fibre.angle += delta*7
	fibres = fibres.filter(func(fibre): return fibre.life > 0)
	for link in links:
		if link.broken:
			link.age += delta
			continue
		var edge := knots[link.b].global_position-knots[link.a].global_position
		var separating_speed := maxf(0,(knots[link.b].linear_velocity-knots[link.a].linear_velocity).dot(edge.normalized()))
		# Account for tensile velocity before the next solver step constrains
		# the joint: a violent pull can rupture a taut strand immediately.
		if edge.length()+separating_speed*delta > link.length*(1+.5*assembly.tuning.hanging_net_strength):
			_break(link,true)
		if not link.broken and not (knots[link.a].sleeping and knots[link.b].sleeping and link.has("sag")):
			# Slack cloth sags between physical knots instead of looking like
			# straight rigid bars. Stop the sag at actual terrain/prop surfaces.
			var sag := minf(12,sqrt(maxf(0,link.length*link.length-edge.length_squared()))*.35)
			if sag > 1:
				var middle: Vector2 = (knots[link.a].global_position+knots[link.b].global_position)*.5
				var query := PhysicsRayQueryParameters2D.create(middle,middle+Vector2.DOWN*(sag+2),1|8)
				var hit := get_world_2d().direct_space_state.intersect_ray(query)
				if not hit.is_empty(): sag = minf(sag,maxf(0,middle.distance_to(hit.position)-1))
			link.sag = sag
	for tether in tethers:
		if not is_instance_valid(tether.joint): continue
		var extension: float = knots[tether.knot].global_position.distance_to(tether.piece.global_position)-tether.length
		if extension > tether.allowance*sqrt(assembly.tuning.hanging_net_strength):
			_detach_tether(tether)
			for link in links:
				if not link.broken and (link.a == tether.knot or link.b == tether.knot):
					_break(link,true)
					break
	queue_redraw()

func _draw() -> void:
	for link in links:
		var a := to_local(knots[link.a].global_position)
		var b := to_local(knots[link.b].global_position)
		if not link.broken:
			var strand := PackedVector2Array()
			for step in 7:
				var t := step/6.0
				strand.append(a.lerp(b,t)+Vector2.DOWN*float(link.get("sag",0))*4*t*(1-t))
			draw_polyline(strand,Color("b9a574"),1.1,true)
		else:
			_draw_frayed_end(a,link.axis,link.length,link.age)
			_draw_frayed_end(b,-link.axis,link.length,link.age)
	for fibre in fibres:
		var point := to_local(fibre.point)
		var axis := Vector2.from_angle(fibre.angle)*2.5
		draw_line(point-axis,point+axis,Color(.85,.79,.58,clampf(fibre.life/.15,0,1)),1,true)
	if assembly.debug_shapes:
		for knot in knots: draw_circle(to_local(knot.global_position),2,Color("f7d47a"))

func _draw_frayed_end(root: Vector2,axis: Vector2,length: float,age: float) -> void:
	var relax := 1-exp(-age*20)
	var tip := root+axis*length*lerpf(.46,.13,relax)+tear_normal*relax*3
	var middle := root.lerp(tip,.5)+tear_normal*sin(age*30)*exp(-age*8)*3
	draw_polyline(PackedVector2Array([root,middle,tip]),Color("c2af7a"),1.0,true)
	for index in 2:
		var direction := axis.rotated((index-.5)*.55)
		draw_line(tip,tip+direction*(1.3+index*.4)+tear_normal*.5,Color("c9b984"),.5,true)
