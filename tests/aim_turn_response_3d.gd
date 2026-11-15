extends SceneTree
var failures:=0
func _initialize(): run.call_deferred()
func check(ok: bool,label: String):
 if not ok: failures+=1; push_error("FAIL "+label)
 else: print("PASS "+label)
func run():
 var stage=load("res://scenes/core/polygon_3d.tscn").instantiate()
 stage.load_user_settings=false
 root.add_child(stage)
 for i in 4: await process_frame
 stage.paused=true
 var model=stage.player.model
 var combat=stage.combat
 combat.aim_direction=Vector3.RIGHT
 model.feet.weight=0
 model.feet.anchors.clear()
 model.rotation.y=0
 model.pose_initialized=true
 model.yaw_speed=-3
 model.animate("run",0,1,1.0/60)
 check(model.rotation.y>0,"right request reverses old left momentum immediately")
 model.rotation.y=0
 model.yaw_speed=3
 model.animate("run",0,-1,1.0/60)
 check(model.rotation.y<0,"left request reverses old right momentum immediately")
 for rate in [30,60,144]:
  model.rotation.y=PI/2
  model.yaw_speed=0
  for i in int(rate*.5): model.animate("run",0,-1,1.0/rate)
  check(absf(angle_difference(model.rotation.y,-PI/2))<deg_to_rad(2),"half-second turn at %d FPS" % rate)
 combat.cursor_active=true
 combat.gun.tuning.recoil_continuous_enabled=true
 combat.cursor_screen=Vector2(100,100)
 var motion:=InputEventMouseMotion.new()
 motion.relative=Vector2(100000,0)
 combat._input(motion)
 var edge: float=combat.cursor_screen.x
 check(edge<=root.get_visible_rect().size.x,"manual cursor cannot accumulate beyond screen")
 motion.relative=Vector2(-10,0)
 combat._input(motion)
 check(combat.cursor_screen.x<edge,"reverse mouse motion responds on first event")
 stage.queue_free()
 await process_frame
 print("TURN_RESPONSE failures=",failures)
 quit(int(failures>0))
