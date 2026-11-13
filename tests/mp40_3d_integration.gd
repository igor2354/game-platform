extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 await process_frame
 s.set_process(false)
 s.player.set_physics_process(false)
 s.combat.set_process(false)
 s.combat.set_physics_process(false)
 var c=s.combat
 c.equip("mp40")
 c.gun.tuning.sound_enabled=false
 c.gun.set_physics_process(false)
 var failures:=0
 if not c.mp40_model.visible or c.barrel.visible or c.stg_model.visible: failures+=1
 c.cursor_active=true
 c.cursor_screen=s.camera.unproject_position(s.player.position+Vector3(3,1.4,0))
 c._process(.016)
 s.player._process(.016)
 if s.player.model.weapon_pose.is_empty(): failures+=1
 if c.weapon_parts.parts.size()!=1: failures+=1
 var muzzle: Vector3=c.pivot.to_global(c.muzzle)
 var barrel=c.mp40_model.find_child("barrel_Base_0",true,false)
 var bounds: AABB=barrel.global_transform*barrel.get_aabb()
 if muzzle.distance_to(bounds.get_center())>.3: failures+=1
 c.weapon_parts.drop(s)
 await physics_frame
 if c.weapon_parts.dropped.size()!=1: failures+=1
 var body=c.weapon_parts.dropped[0]
 if not body.global_transform.is_finite(): failures+=1
 var before: Transform3D=body.global_transform
 c.stg_parts.set_paused(true)
 c.mp40_parts.set_paused(true)
 await physics_frame
 if body.global_position.distance_to(before.origin)>.01: failures+=1
 c.mp40_parts.set_paused(false)
 c.equip("stg44")
 if c.mp40_model.visible or not c.stg_model.visible: failures+=1
 c.stg_parts.clear()
 c.mp40_parts.clear()
 print("MP40_INTEGRATION failures=",failures," length=",.833)
 s.queue_free()
 await process_frame
 quit(int(failures>0))
