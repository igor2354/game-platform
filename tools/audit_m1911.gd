extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var model=load("res://resources/core/weapons_3d/M1911.glb").instantiate()
 root.add_child(model)
 for a in model.find_children("*","AnimationPlayer",true,false):
  print("LENGTH ",a.get_animation("Fire").length)
  a.play("Fire")
  a.advance(0)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  print(mesh.name," ",mesh.global_transform*mesh.get_aabb())
  var rig: Skeleton3D=mesh.get_node(mesh.skeleton)
  var lo:=Vector3.INF
  var hi:=-Vector3.INF
  for surf in mesh.mesh.get_surface_count():
   var arr=mesh.mesh.surface_get_arrays(surf)
   for i in arr[Mesh.ARRAY_VERTEX].size():
    var point:=Vector3.ZERO
    for k in 4:
     var bind: int=arr[Mesh.ARRAY_BONES][i*4+k]
     var bone: int=mesh.skin.get_bind_bone(bind)
     if bone<0: bone=rig.find_bone(mesh.skin.get_bind_name(bind))
     point+=(rig.global_transform*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind)*arr[Mesh.ARRAY_VERTEX][i])*arr[Mesh.ARRAY_WEIGHTS][i*4+k]
    lo=lo.min(point)
    hi=hi.max(point)
  print("SKIN BOUNDS ",lo," ",hi," size=",hi-lo)
 quit()
