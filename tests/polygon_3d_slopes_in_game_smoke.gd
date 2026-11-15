extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var world = load("res://scenes/core/polygon_3d.tscn").instantiate()
 world.load_user_settings = false
 root.add_child(world)
 var geometry = world.geometry
 var player = world.player
 for key in ["core_left","core_right","core_up","core_down","core_jump","core_crouch","core_dash","core_sprint","core_walk","core_reset"]:
  if not InputMap.has_action(key): InputMap.add_action(key)
 for i in 4: await physics_frame
 var failures := 0
 for route in [[3100,4000],[4000,3100],[3980,4760],[4760,3980]]:
  player.reset()
  player.position = geometry.point(Vector2(route[0],760))+Vector3.UP*.02
  for i in 10: await physics_frame
  var action := "core_right" if route[1]>route[0] else "core_left"
  Input.action_press(action)
  var max_y := 0.0
  for i in 600:
   world.combat.cursor_screen = world.camera.unproject_position(player.position+Vector3(signf(route[1]-route[0])*10,1,0))
   await physics_frame
   max_y = maxf(max_y,player.position.y)
   if (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0: break
  Input.action_release(action)
  var passed: bool = (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0 and max_y>.7
  if not passed: failures += 1
  print("ROUTE ",route," end=",player.position," high=",max_y," floor=",player.is_on_floor()," wall=",player.is_on_wall()," ","PASS" if passed else "FAIL")
 world.queue_free()
 await process_frame
 print("SLOPES_IN_GAME failures=",failures)
 quit(int(failures>0))
