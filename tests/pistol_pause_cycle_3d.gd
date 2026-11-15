extends SceneTree
var failures:=0
func check(ok: bool,label: String):
 if not ok:
  failures+=1
  print("FAIL ",label)
func _initialize(): run.call_deferred()
func run():
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=false
 root.add_child(menu)
 await process_frame
 menu.selected_weapon="m1911"
 menu.launch(false)
 for i in 8: await process_frame
 var s=menu.game
 var c=s.combat
 c.gun.tuning.sound_enabled=false
 c.cursor_active=true
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 s.paused=true
 c._process(.016)
 check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"pause releases cursor")
 s.paused=false
 c.overlay.hide()
 c.zombie_overlay.hide()
 s.movement_overlay.hide()
 s.camera_overlay.hide()
 s.ragdoll_overlay.hide()
 c._process(.016)
 if DisplayServer.get_name()!="headless":
  check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"resume captures cursor")
 c.show_shot(Vector3.ZERO,Vector3.RIGHT)
 var a: AnimationPlayer=c.pistol_animator
 check(a.get_animation("Fire").length/a.speed_scale<=.121,"short fire cycle")
 a.advance(.02)
 c.show_shot(Vector3.ZERO,Vector3.RIGHT)
 check(a.current_animation_position<.001,"each shot restarts animation")
 check(absf(c.pistol_model.scale.x*23.95461-.218)<.0001,"posed size 218 mm")
 s.paused=true
 c._process(.016)
 check(not a.active,"animation paused")
 menu.return_to_menu()
 await process_frame
 check(not is_instance_valid(menu.game),"return from paused game")
 print("PISTOL_PAUSE_CYCLE failures=",failures)
 menu.queue_free()
 await process_frame
 quit(int(failures>0))
