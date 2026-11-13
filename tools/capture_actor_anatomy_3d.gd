extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var s=load("res://scenes/core/polygon_3d.tscn").instantiate()
 s.load_user_settings=false
 root.add_child(s)
 s.set_process(false)
 var c=s.combat
 var p=s.player
 c.set_process(false)
 c.set_process_input(false)
 c.set_physics_process(false)
 p.set_process(false)
 p.set_physics_process(false)
 p.position=Vector3.ZERO
 for e in c.enemies: e.set_physics_process(false)
 s.camera.position=Vector3(0,1.1,6)
 s.camera.look_at(Vector3(0,1.1,0))
 s.camera.size=3.1
 for l in s.find_children("*","CanvasLayer",true,false): l.hide()
 c.cursor_active=true
 c.gun.tuning.sound_enabled=false
 var states := ["down","up"] if OS.get_cmdline_user_args().has("--vertical") else ["right","left","down","up","hip","calm","reload_right","reload_left","turn_mid","flash"]
 for state in states:
  var angle: float = {"right":0,"left":180,"down":-90,"up":90,"hip":0,"calm":0,"reload_right":0,"reload_left":180,"turn_mid":0,"flash":0}[state]
  var event=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_RIGHT
  event.pressed=state not in ["hip","calm"]
  Input.parse_input_event(event)
  c.alert_left=0 if state=="calm" else 10
  if state.begins_with("reload"):
   if c.gun.reload_left<=0:
    c.gun.magazine=15
    c.gun.begin_reload()
  else: c.gun.cancel_reload()
  var count:=12 if state=="turn_mid" else 100
  for i in count:
   if c.gun.reload_left>0: c.gun.reload_left=c.gun.reload_duration_active*.55
   c.cursor_screen=s.camera.unproject_position(Vector3(cos(deg_to_rad(angle))*1.6,1.4+sin(deg_to_rad(angle))*1.6,0))
   c._process(1.0/60)
   c.gun.set_physics_process(false)
   p._process(1.0/60)
   await process_frame
  if state=="flash":
   c.effects.flash.start(c.gun.tuning,"stg44")
   c.effects.flash.age=.025
   c.effects.draw_flash()
  await RenderingServer.frame_post_draw
  var path=preload("res://tools/media_paths.gd").path("docs/core/actor_anatomy_2026-11-13/"+state+".png")
  root.get_texture().get_image().save_png(path)
  print("SHOULDER_CAPTURE ",state," yaw=",p.model.rotation.y," ",path)
 p.visual_mode="walk"
 for direction in [1.0,-1.0]:
  p.velocity=Vector3(direction*.8,0,0)
  for i in 100:
   p.position+=p.velocity/60
   p.visual_phase=float(i)/60
   s.camera.position.x=p.position.x
   c.cursor_screen=s.camera.unproject_position(p.position+Vector3(0,-1.5,0))
   c._process(1.0/60)
   c.gun.set_physics_process(false)
   p._process(1.0/60)
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/actor_anatomy_2026-11-13/walk_down_"+str(int(direction))+".png"))
 p.velocity=Vector3.ZERO
 p.hide()
 c.pivot.hide()
 for i in 8:
  c.pivot.position=Vector3(-1+i*.3,1.4,0)
  c.weapon_parts.drop(s)
 s.camera.position=Vector3(.1,.45,6)
 s.camera.look_at(Vector3(.1,.45,0))
 s.camera.size=1.4
 for i in 600: await physics_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(preload("res://tools/media_paths.gd").path("docs/core/actor_anatomy_2026-11-13/dropped_magazines.png"))
 print("MAGAZINE_CAPTURE complete")
 s.queue_free()
 await process_frame
 quit()
