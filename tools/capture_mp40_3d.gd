extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var scene=load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings=false
 root.add_child(scene)
 scene.set_process(false)
 var c=scene.combat
 c.equip("mp40")
 var p=scene.player
 c.set_process(false)
 c.set_process_input(false)
 c.set_physics_process(false)
 p.set_process(false)
 p.set_physics_process(false)
 p.position=Vector3.ZERO
 scene.camera.position=Vector3(0,1.35,6)
 scene.camera.look_at(Vector3(0,1.35,0))
 scene.camera.size=1.25
 for layer in scene.find_children("*","CanvasLayer",true,false): layer.hide()
 c.cursor_active=true
 c.gun.tuning.sound_enabled=false
 for state in ["ads","hip","calm","ads_left","hip_left","calm_left"]:
  var base: String = state.trim_suffix("_left")
  var face := -1.0 if state.ends_with("_left") else 1.0
  c.alert_left=10 if base!="calm" else 0
  var event=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_RIGHT
  event.pressed=base=="ads"
  Input.parse_input_event(event)
  c.cursor_screen=scene.camera.unproject_position(Vector3(face*4,1.5,0))
  for i in 90:
   c.cursor_screen=scene.camera.unproject_position(Vector3(face*1.8,1.5,0))
   c._process(1.0/60)
   p._process(1.0/60)
   await process_frame
  await RenderingServer.frame_post_draw
  var path=preload("res://tools/media_paths.gd").path("docs/core/mp40_integration_2026-11-13/"+state+".png")
  root.get_texture().get_image().save_png(path)
  print("STANCE ",state," face=",c.aim_facing," yaw=",p.model.rotation.y," ",path)
  if state=="ads":
   scene.camera.position=Vector3(3,1.4,5)
   scene.camera.look_at(Vector3(.1,1.1,0))
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/mp40_integration_2026-11-13/ads_three_quarter.png"))
   scene.camera.position=Vector3(0,1.35,6)
   scene.camera.look_at(Vector3(0,1.35,0))

 scene.queue_free()
 await process_frame
 quit()
