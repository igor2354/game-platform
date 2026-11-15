extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.player.position = Vector3(-5,.01,0)
 scene.combat.gun.tuning.magazine_enabled = false
 scene.combat.gun.tuning.sound_enabled = false
 var mouse := InputEventMouseButton.new()
 mouse.button_index = MOUSE_BUTTON_LEFT
 mouse.pressed = true
 Input.parse_input_event(mouse)
 Input.action_press("core_right")
 var failures := 0
 var previous: Vector3 = scene.player.position
 var min_speed := INF
 for i in 180:
  scene.combat.cursor_screen = scene.camera.unproject_position(scene.player.position+Vector3(10 if i<90 else -10,1.4,0))
  await physics_frame
  if i>30:
   min_speed = minf(min_speed,scene.player.velocity.x)
   if scene.player.velocity.x<-.01 or scene.player.position.distance_to(previous)>.3: failures += 1
  previous = scene.player.position
 Input.action_release("core_right")
 mouse.pressed = false
 Input.parse_input_event(mouse)
 var effects = scene.combat.find_child("*",false,false)
 for child in scene.combat.get_children():
  if "casings" in child:
   for casing in child.casings:
    if casing.collision_layer & scene.player.collision_mask: failures += 1
 print("SHOOT_MOVE_REVERSE failures=",failures," min_forward_speed=",min_speed," progress=",scene.player.position.x+5)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
