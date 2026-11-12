extends Node
var parts: Array[MeshInstance3D] = []
var proxy: MeshInstance3D
var dropped: Array[RigidBody3D] = []
var base_transforms: Array[Transform3D] = []
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
    var center := (vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
    center = asset.to_local(instance.to_global(center))
    var mag := center.x>-.17 and center.x<.025 and center.y<.255
    for j in 3:
     if mag: mag_indices.append(indices[i+j])
     else: body_indices.append(indices[i+j])
   for entry in [[body_mesh,body_indices],[magazine_mesh,mag_indices]]:
    if entry[1].is_empty(): continue
    var copy := arrays.duplicate()
    copy[Mesh.ARRAY_INDEX] = entry[1]
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
func set_attached(visible: bool) -> void:
 for part in parts: part.visible = visible
func drop(host: Node3D) -> void:
 if parts.is_empty(): return
 var body := RigidBody3D.new()
 body.mass = .25
 body.collision_layer = 0
 body.collision_mask = 1|8
 host.add_child(body)
 body.global_transform = parts[0].global_transform
 for part in parts:
  var copy := MeshInstance3D.new()
  copy.mesh = part.mesh
  body.add_child(copy)
  copy.global_transform = part.global_transform
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(.12,.23,.045)
 shape.shape = box
 shape.position = Vector3(-.07,.12,0)
 body.add_child(shape)
 body.linear_velocity = host.player.velocity
 body.angular_velocity = Vector3(randf_range(-1.5,1.5),randf_range(-1.5,1.5),randf_range(-1.5,1.5))
 dropped.append(body)
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
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("41464c")
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 proxy.material_override = material
func drop_proxy(host: Node3D) -> void:
 var body := RigidBody3D.new()
 body.mass = .25
 body.collision_layer = 0
 body.collision_mask = 1|8
 host.add_child(body)
 body.global_transform = proxy.global_transform
 var visual := MeshInstance3D.new()
 visual.mesh = proxy.mesh
 visual.material_override = proxy.material_override
 body.add_child(visual)
 var shape := CollisionShape3D.new()
 shape.shape = proxy.mesh.create_convex_shape()
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
