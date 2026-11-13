extends RefCounted
static func remove_embedded_round(model: Node3D) -> void:
 for instance in model.find_children("*","MeshInstance3D",true,false):
  if instance.skin==null: continue
  var rig: Skeleton3D=instance.get_node(instance.skeleton)
  var excluded := {}
  for bind in instance.skin.get_bind_count():
   var bone: int=instance.skin.get_bind_bone(bind)
   var name: String=rig.get_bone_name(bone) if bone>=0 else String(instance.skin.get_bind_name(bind))
   if "bullet" in name.to_lower(): excluded[bind]=true
  var removed:=0
  var result:=ArrayMesh.new()
  for surface in instance.mesh.get_surface_count():
   var arrays: Array=instance.mesh.surface_get_arrays(surface)
   var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var kept:=PackedInt32Array()
   for i in range(0,indices.size(),3):
    var round_face:=false
    for k in 3:
     var v:=indices[i+k]
     for w in 4:
      if arrays[Mesh.ARRAY_WEIGHTS][v*4+w]>.001 and excluded.has(arrays[Mesh.ARRAY_BONES][v*4+w]): round_face=true
    if not round_face:
     for k in 3: kept.append(indices[i+k])
   removed+=(indices.size()-kept.size())/3
   arrays[Mesh.ARRAY_INDEX]=kept
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   result.surface_set_material(surface,instance.mesh.surface_get_material(surface))
  instance.mesh=result
  instance.set_meta("removed_round_faces",removed)
