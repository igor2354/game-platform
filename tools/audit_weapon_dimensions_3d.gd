extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 var c=s.combat
 var box:=AABB()
 var first:=true
 for mesh in c.stg_model.find_children("*","MeshInstance3D",true,false):
  var a: AABB=c.pivot.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
  box=a if first else box.merge(a)
  first=false
 var bins: Dictionary={}
 for mesh in c.stg_model.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    var p: Vector3=c.pivot.to_local(mesh.to_global(v))
    if p.x<.65: continue
    var key:=floori(p.x*1000)
    if not bins.has(key): bins[key]=[]
    bins[key].append(p)
 for key in bins:
  var low:=Vector3.INF
  var high:=-Vector3.INF
  for p: Vector3 in bins[key]:
   low=low.min(p)
   high=high.max(p)
  print("MUZZLE_BIN ",key," ",low," ",high)
 print("WEAPON_BOUNDS ",box," length=",box.size.x)
 var m=s.player.model
 var bodybox:=AABB()
 first=true
 for mesh in m.model.find_children("*","MeshInstance3D",true,false):
  var a: AABB=m.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
  bodybox=a if first else bodybox.merge(a)
  first=false
 print("BODY_REST_BOUNDS ",bodybox," height=",bodybox.size.y)
 for name in ["r_upperarm","r_eye","head","neck1"]: print(name," ",m.rig.get_bone_global_rest(m.indices[name]).origin)
 quit()
