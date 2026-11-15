extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var geometry = load("res://scenes/core/polygon_3d_geometry.tscn").instantiate()
 world.add_child(geometry)
 var player = load("res://scripts/core/player_3d.gd").new()
 player.geometry = geometry
 world.add_child(player)
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
  for i in 400:
   await physics_frame
   max_y = maxf(max_y,player.position.y)
   if (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0: break
  Input.action_release(action)
  var passed: bool = (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0 and max_y>.7
  if not passed: failures += 1
  print("ROUTE ",route," end=",player.position," high=",max_y," floor=",player.is_on_floor()," wall=",player.is_on_wall()," ","PASS" if passed else "FAIL")
 player.set_physics_process(false)
 var old = load("res://scenes/main.tscn").instantiate()
 old.load_user_settings = false
 root.add_child(old)
 old.set_process(false)
 old.set_physics_process(false)
 old.player.request_body_scale(2.85)
 old.player.tuning.backward_enabled = false
 old.player.weapon.tuning.weapon_enabled = false
 for route in [[3100,4000],[4000,3100],[3980,4760],[4760,3980]]:
  old.player.global_position = Vector2(route[0],758)
  old.player.velocity = Vector2.ZERO
  old.player.ground_speed = 0
  for i in 10: await physics_frame
  var action := "core_right" if route[1]>route[0] else "core_left"
  Input.action_press(action)
  var high := 0.0
  for i in 400:
   await physics_frame
   high = maxf(high,(760-old.player.global_position.y)/geometry.U)
   if (old.player.global_position.x-route[1])*signf(route[1]-route[0])>=0: break
  Input.action_release(action)
  var ok: bool = (old.player.global_position.x-route[1])*signf(route[1]-route[0])>=0 and high>.7
  if not ok: failures += 1
  print("2D REFERENCE ",route," high=",high," ","PASS" if ok else "FAIL")
 old.queue_free()
 world.queue_free()
 await process_frame
 print("SLOPES failures=",failures)
 quit(int(failures>0))
