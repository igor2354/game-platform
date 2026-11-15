extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var path := preload("res://tools/media_paths.gd").path("docs/core/shooting_fx_3d_2026-11-12/"+name+".png")
 root.get_texture().get_image().save_png(path)
 print("FX_CAPTURE ",path)
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.set_process(false)
 scene.combat.set_physics_process(false)
 scene.set_process(false)
 scene.combat.zombie_settings.movement_enabled = false
 scene.combat.zombie_settings.combat_enabled = false
 scene.player.position = Vector3(-5,0,0)
 scene.camera.position = Vector3(-3.6,1.2,9)
 scene.camera.look_at(Vector3(-3.6,1.2,0))
 scene.camera.size = 3.0
 for layer in scene.find_children("*","CanvasLayer",true,false): layer.hide()
 var target = preload("res://scripts/core/target_3d.gd").new()
 target.position = Vector3(-1.8,0,0)
 scene.add_child(target)
 target.label.hide()
 await frames(12)
 var gun = scene.combat.gun
 gun.input_driven = false
 var origin := Vector3(-4.1,1.16,0)
 if "--beam" in OS.get_cmdline_user_args():
  scene.combat.pivot.position = origin-scene.combat.muzzle
  scene.combat.aim_direction = Vector3.RIGHT
  var reticle = scene.combat.reticle
  reticle.get_parent().show()
  for child in reticle.get_parent().get_children():
   if child is CanvasItem and child!=reticle: child.hide()
  scene.combat.cursor_active = true
  scene.combat.cursor_screen = scene.camera.unproject_position(target.position+Vector3.UP*1.16)
  gun.tuning.hip_spread = 8
  gun.tuning.hip_max_spread = 8
  gun.tuning.aim_beam_enabled = true
  await frames(3)
  await capture("aim_beam")
  gun.aiming = true
  gun.tuning.ads_spread = 0
  gun.tuning.movement_spread_enabled = false
  await frames(3)
  await capture("aim_ads")
  scene.queue_free()
  await process_frame
  quit()
  return
 for id in ["stg44","mp40","svt","m1911"]:
  scene.combat.effects.clear()
  target.reset()
  scene.combat.equip(id)
  gun.tuning.hip_spread = 0
  gun.tuning.hip_max_spread = 0
  gun.tuning.movement_spread_enabled = false
  gun.tuning.recoil_enabled = false
  gun.tuning.bullet_speed = 500
  scene.combat.aim_direction = Vector3.RIGHT
  scene.combat.pivot.position = origin-scene.combat.muzzle
  scene.player.model.weapon_grips = [scene.combat.pivot.to_global(scene.combat.rear_grip),scene.combat.pivot.to_global(scene.combat.front_grip)]
  await frames(12)
  gun.fire(origin,Vector3.RIGHT)
  await frames(1)
  await capture(id+"_flash")
  await frames(8)
  await capture(id+"_flight")
  while gun.projectiles.size()>0: await physics_frame
  await frames(2)
  await capture(id+"_blood")
  await frames(40)
 # Surface dust and shards, actual bullet normal against a wooden block.
 var surface := StaticBody3D.new()
 surface.set_meta("terra_material",4)
 surface.position = Vector3(-2.5,1.1,0)
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(.3,.9,.6)
 shape.shape = box
 surface.add_child(shape)
 var mesh := MeshInstance3D.new()
 var box_mesh := BoxMesh.new()
 box_mesh.size = box.size
 mesh.mesh = box_mesh
 surface.add_child(mesh)
 scene.add_child(surface)
 await frames(2)
 gun.cooldown = 0
 gun.fire(origin,Vector3.RIGHT)
 while gun.projectiles.size()>0: await physics_frame
 await frames(2)
 await capture("surface_wood")
 scene.queue_free()
 await process_frame
 quit()
