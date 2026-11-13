extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var model=load("res://resources/core/weapons_3d/MP40.glb").instantiate()
 root.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  print(mesh.name," ",mesh.global_transform*mesh.get_aabb())
 quit()
