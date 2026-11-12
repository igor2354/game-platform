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
 var failures := 0
 for route in [[-6400,-3400,false],[-2600,450,false],[450,-2600,false],[-3400,-2600,true],[-2600,-3400,true],[510,910,true],[910,510,true],[900,1230,true],[1220,880,true],[5750,6900,false],[6900,5750,false]]:
  player.reset()
  player.position = geometry.point(Vector2(route[0],760))+Vector3.UP*.02
  for i in 10: await physics_frame
  var action := "core_right" if route[1]>route[0] else "core_left"
  Input.action_press(action)
  if route[2]: Input.action_press("core_jump")
  var resets := 0
  var previous: Vector3 = player.position
  for i in 900:
   await physics_frame
   if absf(player.position.x-previous.x)>2.5: resets += 1
   previous = player.position
   if (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0: break
  Input.action_release(action)
  Input.action_release("core_jump")
  var ok: bool = (player.position.x*geometry.U-route[1])*signf(route[1]-route[0])>=0 and resets==0
  if not ok: failures += 1
  print("MAP ROUTE ",route," resets=",resets," end=",player.position," ","PASS" if ok else "FAIL")
 print("MAP_TRAVERSAL failures=",failures)
 world.queue_free()
 await process_frame
 quit(int(failures>0))
