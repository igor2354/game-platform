extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 s.combat.equip("svt")
 for m in s.combat.svt_model.find_children("*","MeshInstance3D",true,false):
  print("SVT_PIVOT ",s.combat.pivot.global_transform.affine_inverse()*m.global_transform*m.get_aabb())
 quit()
