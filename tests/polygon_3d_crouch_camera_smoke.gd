extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.player.set_physics_process(false)
 scene.set_process(false)
 var model = scene.player.model
 var failures := 0
 for frame in 180:
  model.animate("crouch_walk" if frame%2==0 else "run",frame/64.0,1,1.0/60)
  for side in ["r_","l_"]:
   if model._joint(side+"hand").y>model._joint("neck1").y: failures += 1
 scene.camera_settings.follow_speed = 0
 scene.camera_settings.limit_to_level = false
 scene.player.position.x = 30
 scene.update_camera(.016)
 var expected: float = 30+(scene.camera_settings.offset_x+scene.look_direction*scene.camera_settings.look_ahead)/scene.geometry.U/scene.camera_settings.zoom
 if absf(scene.camera.position.x-expected)>.001: failures += 1
 scene.camera_settings.limit_to_level = true
 scene.camera_settings.follow_speed = 8
 for direction in [-1,1]:
  scene.player.position.x = direction*200
  for i in 100: scene.update_camera(.016)
  var half_width: float = scene.get_viewport().get_visible_rect().size.x*.5/scene.geometry.U/scene.camera_settings.zoom
  if scene.camera.position.x < -6500/scene.geometry.U+half_width-.001 or scene.camera.position.x > 7100/scene.geometry.U-half_width+.001: failures += 1
 var before: Vector3 = scene.camera.position
 scene.camera_settings.camera_enabled = false
 scene.player.position.x = 0
 scene.update_camera(.1)
 if scene.camera.position!=before: failures += 1
 print("CROUCH_SPAM_CAMERA failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
