extends Node2D
## A physical pouch: pinned rope capsules support rigid contents from startup.
## Only the front weave ignores its own contents in this side-view projection;
## the side and bottom ropes really collide with, and carry, the stones.
const STRAND = preload("res://scripts/core/hanging_net_strand.gd")
const REFERENCE_PAYLOAD_MASS := 35.0*140.0*110.0/(120.0*90.0)
var assembly: Node2D
var knots: Array[RigidBody2D] = []
var strands: Array[RigidBody2D] = []
var links: Array[Dictionary] = []
var frozen: Array[Dictionary] = []
var broken_links := 0
var impact_breaks := 0
var age := 0.0
var fibres: Array[Dictionary] = []
var warmup_ticks := 3
var ready_for_load := false
var has_struck := false
var weave: Array[Dictionary] = []

func build(pose: Transform2D,size: Vector2) -> void:
	assembly.body.mass = 8*_mass_scale()
	var total_area := 0.0
	for chunk in assembly.body.chunks: total_area += chunk.area
	for chunk in assembly.body.chunks:
		var piece = assembly.FRAGMENT.new()
		piece.assembly = assembly
		piece.dimensions = chunk.size
		piece.polygon = chunk.polygon
		piece.shade = chunk.shade
		piece.mass_share = chunk.area/total_area
		piece.mass = assembly.payload_mass*piece.mass_share
		piece.freeze = true
		piece.transform = assembly.body.transform*Transform2D(chunk.angle,chunk.position)
		assembly.add_child(piece)
		piece.held_transform = piece.global_transform
		assembly.fragments.append(piece)
	for row in 4:
		for column in 5:
			var local_point := Vector2((column/4.0-.5)*size.x*[.9,1.05,1.05,.86][row],(row/3.0-.5)*size.y)
			_add_knot(pose*local_point)
	for row in 4:
		for column in 5:
			var index := row*5+column
			if column < 4: _connect(knots[index],knots[index+1],knots[index].global_position,knots[index+1].global_position,row in [0,3])
			if row < 3: _connect(knots[index],knots[index+5],knots[index].global_position,knots[index+5].global_position,column in [0,4])
	var hook: Vector2 = assembly.body.to_global(Vector2(0,-size.y*.65))
	for corner in [0,4]:
		var endpoint := knots[corner]
		var start := endpoint.global_position
		for step in 3:
			var finish: Vector2 = start.lerp(hook,(step+1)/3.0)
			var next: RigidBody2D = assembly.body if step == 2 else _add_knot(finish)
			_connect(endpoint,next,endpoint.global_position if step == 0 else start.lerp(hook,step/3.0),finish,false)
			endpoint = next

func _mass_scale() -> float:
	return assembly.payload_mass/REFERENCE_PAYLOAD_MASS

func _add_knot(point: Vector2) -> RigidBody2D:
	var knot := RigidBody2D.new()
	knot.mass = .75*_mass_scale()
	knot.freeze = true
	knot.collision_layer = 0
	knot.collision_mask = 0
	knot.linear_damp = 1.2
	knot.angular_damp = 3.0
	knot.position = to_local(point)
	add_child(knot)
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 1
	collider.shape = shape
	knot.add_child(collider)
	knots.append(knot)
	return knot

func _connect(a: RigidBody2D,b: RigidBody2D,start: Vector2,end: Vector2,boundary: bool) -> void:
	var delta := end-start
	var rod = STRAND.new()
	rod.net = self
	rod.freeze = true
	rod.strand_index = links.size()
	rod.mass = (2.0 if links.size() >= 31 else .7 if boundary else .35)*_mass_scale()
	rod.collision_layer = 32|64
	rod.collision_mask = 1|8
	rod.max_contacts_reported = 8
	rod.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	rod.linear_damp = 1.2
	rod.angular_damp = 4.5
	rod.transform = Transform2D(Vector2.DOWN.angle_to(delta),to_local((start+end)*.5))
	var material := PhysicsMaterial.new()
	material.friction = .7
	material.bounce = .02
	rod.physics_material_override = material
	add_child(rod)
	var collider := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 3.0 if boundary else 1.2
	shape.height = maxf(shape.radius*2,delta.length()+(6 if boundary else 1))
	collider.shape = shape
	rod.add_child(collider)
	if not boundary:
		for piece in assembly.fragments: rod.add_collision_exception_with(piece)
	strands.append(rod)
	links.append({"rod":rod,"a":a,"b":b,"anchor_a":a.to_local(start),"anchor_b":b.to_local(end),"joints":[],"length":delta.length(),"boundary":boundary,"broken":false,"stress":0.0,"health":15.0,"previous_velocity":Vector2.ZERO,"born":age})

func _finish_build() -> void:
	# Joint offsets must use committed physics-server transforms, including
	# capsule COM/inertia after shapes enter the space. Building pins in the
	# spawn frame otherwise gives stretched, incorrect local anchors.
	for body in knots+strands+assembly.fragments: body.freeze = false
	for link in links:
		for pair in [[link.a,link.anchor_a],[link.b,link.anchor_b]]:
			var pin := PinJoint2D.new()
			add_child(pin)
			pin.global_position = pair[0].to_global(pair[1])
			pin.node_a = pin.get_path_to(pair[0])
			pin.node_b = pin.get_path_to(link.rod)
			# Perfectly rigid pins fight the other closed loops and cargo
			# contacts, continually injecting correction energy. A little
			# compliance lets the loaded weave settle and sleep naturally.
			pin.softness = .01/_mass_scale()
			pin.bias = .15
			link.joints.append(pin)
	for row in 3:
		for column in 4:
			var index := row*5+column
			for pair in [[index,index+6],[index+1,index+5]]:
				var offset := knots[pair[1]].global_position-knots[pair[0]].global_position
				var spring := DampedSpringJoint2D.new()
				add_child(spring)
				spring.global_position = knots[pair[0]].global_position
				spring.global_rotation = Vector2.DOWN.angle_to(offset)
				spring.length = offset.length()
				spring.rest_length = spring.length
				spring.stiffness = 30*assembly.tuning.hanging_net_strength*_mass_scale()
				spring.damping = .9
				spring.node_a = spring.get_path_to(knots[pair[0]])
				spring.node_b = spring.get_path_to(knots[pair[1]])
				weave.append({"a":pair[0],"b":pair[1],"joint":spring,"length":spring.length,"broken":false})
	ready_for_load = true

func apply_tuning() -> void:
	# Keep the solver's mass ratios consistent when the payload/size sliders
	# change. Heavy stones on virtually massless rope cannot settle reliably.
	assembly.body.mass = 8*_mass_scale()
	for knot in knots: knot.mass = .75*_mass_scale()
	for index in links.size():
		var link := links[index]
		link.rod.mass = (2.0 if index >= 31 else .7 if link.boundary else .35)*_mass_scale()
		for pin in link.joints:
			if is_instance_valid(pin): pin.softness = .01/_mass_scale()
	for thread in weave:
		if is_instance_valid(thread.joint): thread.joint.stiffness = 30*assembly.tuning.hanging_net_strength*_mass_scale()

func damage_strand(index: int,amount: float) -> bool:
	if not ready_for_load or not assembly.tuning.hanging_net_tear_enabled or not is_finite(amount) or amount <= 0: return false
	var link := links[index]
	if link.broken: return false
	link.health -= amount
	if link.health > 0: return false
	_break(link,0,link.rod.global_position)
	return true

func _break(link: Dictionary,end: int,point: Vector2) -> bool:
	if link.broken or not assembly.tuning.hanging_net_tear_enabled: return false
	link.broken = true
	link.free_end = end
	link.broken_age = 0.0
	broken_links += 1
	assembly.ruptured = true
	var pin: PinJoint2D = link.joints[end]
	pin.node_a = NodePath()
	pin.node_b = NodePath()
	pin.queue_free()
	link.joints[end] = null
	# Released elastic energy acts on the light rope alone, not the cargo.
	link.rod.apply_central_impulse(Vector2((1 if end == 0 else -1)*5,-3)*link.rod.mass)
	for index in 5:
		var phase := index*2.399+broken_links
		fibres.append({"point":point,"velocity":Vector2(sin(phase)*35,-20-absf(cos(phase))*35),"life":.35})
	assembly.queue_redraw()
	return true

func set_simulation_enabled(enabled: bool) -> void:
	var bodies: Array[RigidBody2D] = knots+strands
	if enabled:
		if not ready_for_load:
			frozen.clear()
			return
		for index in frozen.size():
			bodies[index].freeze = false
			bodies[index].linear_velocity = frozen[index].velocity
			bodies[index].angular_velocity = frozen[index].spin
		frozen.clear()
	elif frozen.is_empty():
		for body in bodies:
			frozen.append({"pose":body.global_transform,"velocity":body.linear_velocity,"spin":body.angular_velocity})
			body.freeze = true

func _physics_process(delta: float) -> void:
	if not frozen.is_empty():
		var bodies: Array[RigidBody2D] = knots+strands
		for index in bodies.size(): bodies[index].global_transform = frozen[index].pose
		return
	if not ready_for_load:
		warmup_ticks -= 1
		if warmup_ticks <= 0: _finish_build()
		return
	age += delta
	for link in links:
		var rod: RigidBody2D = link.rod
		var state := PhysicsServer2D.body_get_direct_state(rod.get_rid())
		if link.broken:
			link.broken_age += delta
			continue
		if not assembly.tuning.hanging_net_tear_enabled:
			link.stress = 0
			link.previous_velocity = rod.linear_velocity
			continue
		# Pin separation and contact impulse measure load on the actual rope.
		# A quiet hanging load does not accumulate the gravity-support force.
		var point_a: Vector2 = rod.to_global(Vector2(0,-link.length*.5))
		var point_b: Vector2 = rod.to_global(Vector2(0,link.length*.5))
		var error_a := point_a.distance_to(link.a.to_global(link.anchor_a))
		var error_b := point_b.distance_to(link.b.to_global(link.anchor_b))
		var limit: float = maxf(5,link.length*.25)*assembly.tuning.hanging_net_strength
		if has_struck and assembly.released and age > .5 and maxf(error_a,error_b) > limit:
			link.stress += (maxf(error_a,error_b)/limit-1)*delta*8
		else: link.stress = maxf(0,link.stress-delta)
		if assembly.released and state:
			for contact in state.get_contact_count():
				var surface := state.get_contact_collider_object(contact)
				var normal := state.get_contact_local_normal(contact)
				var incoming: Vector2 = link.previous_velocity-state.get_contact_collider_velocity_at_position(contact)
				var speed := maxf(0,-incoming.dot(normal))
				var threshold: float = assembly.tuning.hanging_net_tear_speed*sqrt(assembly.tuning.hanging_net_strength)
				var own_cargo: bool = surface is RigidBody2D and surface in assembly.fragments
				if speed > threshold and not own_cargo:
					has_struck = true
					var impulse := state.get_contact_impulse(contact).length()
					link.stress += pow(speed/threshold,2)*clampf(impulse/maxf(1,rod.mass*speed),.25,2)
					if link.stress >= 1:
						var point := state.get_contact_collider_position(contact)
						if _break(link,0 if point.distance_squared_to(point_a) < point.distance_squared_to(point_b) else 1,point):
							impact_breaks += 1
							assembly.queue_floor_impact(point,speed)
						break
		if link.stress >= 1 and not link.broken: _break(link,0 if error_a > error_b else 1,rod.global_position)
		link.previous_velocity = rod.linear_velocity
	for thread in weave:
		if thread.broken or not has_struck or not assembly.tuning.hanging_net_tear_enabled: continue
		var extension: float = knots[thread.a].global_position.distance_to(knots[thread.b].global_position)/thread.length
		if extension > 1+.35*assembly.tuning.hanging_net_strength:
			thread.broken = true
			thread.joint.node_a = NodePath()
			thread.joint.node_b = NodePath()
			thread.joint.queue_free()
			thread.joint = null
	for fibre in fibres:
		fibre.life -= delta
		fibre.velocity += Vector2.DOWN*400*delta
		fibre.point += fibre.velocity*delta
	fibres = fibres.filter(func(fibre): return fibre.life > 0)
	queue_redraw()

func _draw() -> void:
	for thread in weave:
		if thread.broken: continue
		draw_line(to_local(knots[thread.a].global_position),to_local(knots[thread.b].global_position),Color("9f916d"),.7,true)
	for link in links:
		var a := to_local(link.rod.to_global(Vector2(0,-link.length*.5)))
		var b := to_local(link.rod.to_global(Vector2(0,link.length*.5)))
		draw_line(a,b,Color("b9a574"),1.8 if link.boundary else 1.0,true)
		if link.broken:
			var tip: Vector2 = a if link.free_end == 0 else b
			var direction := (a-b).normalized() if link.free_end == 0 else (b-a).normalized()
			for strand in 2: draw_line(tip,tip+direction.rotated((strand-.5)*.5)*3,Color("d2c38d"),.7,true)
	for fibre in fibres:
		var point := to_local(fibre.point)
		draw_line(point,point+Vector2(2,-1),Color(.8,.74,.54,fibre.life/.35),1,true)
	if assembly.debug_shapes:
		for knot in knots: draw_circle(to_local(knot.global_position),2,Color("f7d47a"))
