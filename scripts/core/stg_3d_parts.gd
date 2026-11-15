extends Node
var parts: Array[MeshInstance3D] = []
var proxy: MeshInstance3D
var dropped: Array[RigidBody3D] = []
var base_transforms: Array[Transform3D] = []
var cached_shape: BoxShape3D
var mag_center := Vector3.ZERO
var proxy_center := Vector3.ZERO
var proxy_shape: ConvexPolygonShape3D
func prepare(asset: Node3D) -> void:
	for instance in asset.find_children("*","MeshInstance3D",true,false):
		var body_mesh := ArrayMesh.new()
		var magazine_mesh := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var body_indices := PackedInt32Array()
			var mag_indices := PackedInt32Array()
			for i in range(0,indices.size(),3):
				var mag := true
				for j in 3:
					var v: Vector3 = asset.to_local(instance.to_global(vertices[indices[i+j]]))
					mag = mag and v.x>-.17 and v.x<.025 and v.y<.248
				for j in 3:
					if mag: mag_indices.append(indices[i+j])
					else: body_indices.append(indices[i+j])
			var selected: Dictionary = largest_component(vertices,mag_indices)
			var clean := PackedInt32Array()
			for face in mag_indices.size()/3:
				for k in 3:
					if selected.has(face): clean.append(mag_indices[face*3+k])
					else: body_indices.append(mag_indices[face*3+k])
			mag_indices = clean
			for entry in [[body_mesh,body_indices],[magazine_mesh,mag_indices]]:
				if entry[1].is_empty(): continue
				var copy := arrays.duplicate()
				copy[Mesh.ARRAY_INDEX] = entry[1]
				if entry[0]==magazine_mesh: copy = compact(arrays,entry[1])
				entry[0].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy)
				entry[0].surface_set_material(entry[0].get_surface_count()-1,instance.mesh.surface_get_material(surface))
		if magazine_mesh.get_surface_count()>0:
			var magazine := MeshInstance3D.new()
			magazine.mesh = magazine_mesh
			instance.get_parent().add_child(magazine)
			magazine.transform = instance.transform
			parts.append(magazine)
			base_transforms.append(magazine.transform)
			instance.mesh = body_mesh
func prepare_named(asset: Node3D,fragment: String) -> void:
	for instance in asset.find_children("*","MeshInstance3D",true,false):
		if not String(instance.name).begins_with(fragment): continue
		parts.append(instance)
		base_transforms.append(instance.transform)
func set_attached(visible: bool) -> void:
	for part in parts: part.visible = visible
func drop(host: Node3D) -> void:
	if parts.is_empty(): return
	if cached_shape==null: cache_collision()
	var source := parts[0]
	var frame := source.global_basis.orthonormalized()
	var center := source.to_global(mag_center)
	var body = preload("res://scripts/core/dropped_magazine_3d.gd").new()
	body.mass = .25
	body.collision_layer = 32
	body.collision_mask = 1|8|32
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.linear_damp = .15
	body.angular_damp = .6
	var material := PhysicsMaterial.new()
	material.friction = .65
	material.bounce = .06
	body.physics_material_override = material
	host.add_child(body)
	body.global_transform = Transform3D(frame,center)
	for part in parts:
		var copy := MeshInstance3D.new()
		copy.mesh = part.mesh
		copy.material_override = part.material_override
		body.add_child(copy)
		copy.global_transform = part.global_transform
	var shape := CollisionShape3D.new()
	shape.shape = cached_shape
	body.half_size = cached_shape.size*.5
	body.add_child(shape)
	body.linear_velocity = host.player.velocity+Vector3(randf_range(-.12,.12),-.08,randf_range(-.12,.12))
	body.angular_velocity = Vector3(randf_range(-2.5,2.5),randf_range(-2.5,2.5),randf_range(-2.5,2.5))
	dropped.append(body)


func cache_collision() -> void:
	if parts.is_empty(): return
	var part := parts[0]
	mag_center = part.mesh.get_aabb().get_center()
	cached_shape = BoxShape3D.new()
	cached_shape.size = part.mesh.get_aabb().size*part.global_basis.get_scale().abs()
	cached_shape.margin = .001

func compact(arrays: Array,selected: PackedInt32Array) -> Array:
	var output := []
	output.resize(Mesh.ARRAY_MAX)
	var remap := {}
	var mapped := PackedInt32Array()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var tangents := PackedFloat32Array()
	for original in selected:
		if not remap.has(original):
			remap[original] = positions.size()
			positions.append(arrays[Mesh.ARRAY_VERTEX][original])
			if arrays[Mesh.ARRAY_NORMAL]!=null: normals.append(arrays[Mesh.ARRAY_NORMAL][original])
			if arrays[Mesh.ARRAY_TEX_UV]!=null: uv.append(arrays[Mesh.ARRAY_TEX_UV][original])
			if arrays[Mesh.ARRAY_TANGENT]!=null:
				for k in 4: tangents.append(arrays[Mesh.ARRAY_TANGENT][original*4+k])
		mapped.append(remap[original])
	output[Mesh.ARRAY_VERTEX] = positions
	output[Mesh.ARRAY_INDEX] = mapped
	if not normals.is_empty(): output[Mesh.ARRAY_NORMAL] = normals
	if not uv.is_empty(): output[Mesh.ARRAY_TEX_UV] = uv
	if not tangents.is_empty(): output[Mesh.ARRAY_TANGENT] = tangents
	return output
func clear() -> void:
	for body in dropped:
		if is_instance_valid(body): body.queue_free()
	dropped.clear()
	set_attached(true)

func set_offset(pivot: Node3D, offset: Vector3) -> void:
	for i in parts.size():
		parts[i].transform = base_transforms[i]
		parts[i].global_position += pivot.global_basis*offset

func prepare_proxy(id: String,pivot: Node3D) -> void:
	if is_instance_valid(proxy): proxy.free()
	proxy = MeshInstance3D.new()
	pivot.add_child(proxy)
	proxy.visible = id!="stg44"
	var outline: PackedVector2Array = preload("res://scripts/campaign/catalog.gd").magazine_shape(id)
	var vertices := PackedVector3Array()
	var triangles := Geometry2D.triangulate_polygon(outline)
	for z in [-.018,.018]:
		for index in triangles:
			var p := outline[index]*2.85/100.97598
			vertices.append(Vector3(p.x,-p.y,z))
	for i in outline.size():
		var a := outline[i]*2.85/100.97598
		var b := outline[(i+1)%outline.size()]*2.85/100.97598
		for p in [Vector3(a.x,-a.y,-.018),Vector3(b.x,-b.y,-.018),Vector3(b.x,-b.y,.018),Vector3(a.x,-a.y,-.018),Vector3(b.x,-b.y,.018),Vector3(a.x,-a.y,.018)]: vertices.append(p)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	proxy.mesh = mesh
	proxy_center = mesh.get_aabb().get_center()
	proxy_shape = ConvexPolygonShape3D.new()
	var centered := PackedVector3Array()
	for vertex: Vector3 in vertices: centered.append(vertex-proxy_center)
	proxy_shape.points = centered
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("41464c")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	proxy.material_override = material
func drop_proxy(host: Node3D) -> void:
	var body := preload("res://scripts/core/dropped_magazine_3d.gd").new()
	body.mass = .25
	body.collision_layer = 0
	body.collision_mask = 1|8
	host.add_child(body)
	body.global_transform = Transform3D(proxy.global_basis.orthonormalized(),proxy.to_global(proxy_center))
	var visual := MeshInstance3D.new()
	visual.mesh = proxy.mesh
	visual.material_override = proxy.material_override
	body.add_child(visual)
	visual.global_transform = proxy.global_transform
	var shape := CollisionShape3D.new()
	shape.shape = proxy_shape
	body.half_size = proxy.mesh.get_aabb().size*.5
	body.add_child(shape)
	body.linear_velocity = host.player.velocity
	body.angular_velocity = Vector3(randf_range(-1.5,1.5),randf_range(-1.5,1.5),randf_range(-1.5,1.5))
	dropped.append(body)


func set_paused(paused: bool) -> void:
	for body in dropped:
		if not is_instance_valid(body): continue
		if paused:
			body.set_meta("pause_linear",body.linear_velocity)
			body.set_meta("pause_angular",body.angular_velocity)
		body.freeze = paused
		if not paused:
			body.linear_velocity = body.get_meta("pause_linear",Vector3.ZERO)
			body.angular_velocity = body.get_meta("pause_angular",Vector3.ZERO)

func _ready() -> void: set_physics_process(false)
func largest_component(vertices: PackedVector3Array,triangles: PackedInt32Array) -> Dictionary:
	var touching := {}
	for face in triangles.size()/3:
		for k in 3:
			var point := Vector3i((vertices[triangles[face*3+k]]*10000).round())
			if not touching.has(point): touching[point] = []
			touching[point].append(face)
	var visited := {}
	var largest := {}
	for seed in triangles.size()/3:
		if visited.has(seed): continue
		var component := {}
		var stack: Array[int] = [seed]
		visited[seed] = true
		while not stack.is_empty():
			var face: int = stack.pop_back()
			component[face] = true
			for k in 3:
				var point := Vector3i((vertices[triangles[face*3+k]]*10000).round())
				for neighbor: int in touching[point]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						stack.append(neighbor)
		if component.size()>largest.size(): largest = component
	return largest
