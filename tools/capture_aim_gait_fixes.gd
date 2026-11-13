extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 var path := preload("res://tools/media_paths.gd").path("docs/core/aim_gait_fixes_2026-11-12/"+label+".png")
 root.get_texture().get_image().save_png(path)
 print("AIM_CAPTURE ",path)
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.set_process(false)
 var combat = scene.combat
 var player = scene.player
 combat.set_process(false)
 combat.set_physics_process(false)
 player.set_process(false)
 player.set_physics_process(false)
 player.position = Vector3(0,0,0)
 scene.camera.position = Vector3(-.4,1.3,12)
 scene.camera.look_at(Vector3(-.4,1.3,0))
 scene.camera.size = 3.2
 combat.gun.tuning.sound_enabled = false
 combat.gun.tuning.recoil_enabled = false
 combat.cursor_active = true
 for layer in scene.find_children("*","CanvasLayer",true,false): layer.hide()
 combat.reticle.get_parent().show()
 for child in combat.reticle.get_parent().get_children():
  if child is CanvasItem and child!=combat.reticle: child.hide()
 for angle in [145.0,215.0,90.0]:
  var point := Vector3(cos(deg_to_rad(angle)),sin(deg_to_rad(angle)),0)*3+Vector3(0,1.4,0)
  combat.cursor_screen = scene.camera.unproject_position(point)
  for i in 60:
   combat._process(1.0/60)
   player._process(1.0/60)
   await physics_frame
  await capture("aim_"+str(int(angle)))
 combat.gun.tuning.weapon_enabled = false
 for phase in [.15,.4,.65,.9]:
  player.visual_mode = "sprint"
  player.visual_phase = phase
  player.sprinting = true
  player.phase = phase
  combat._process(1.0/60)
  player.model.animate("sprint",phase,1.0)
  await capture("sprint_unarmed_"+str(int(phase*100)))
 combat.gun.tuning.weapon_enabled = true
 for i in 30:
  combat._process(1.0/60)
  player._process(1.0/60)
  await physics_frame
 await capture("sprint_carry")
 scene.queue_free()
 await process_frame
 quit()
