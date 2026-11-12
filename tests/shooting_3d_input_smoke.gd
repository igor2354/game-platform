extends SceneTree
func _initialize() -> void: run.call_deferred()
func button(pressed: bool) -> void:
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 event.position = Vector2(800,500)
 Input.parse_input_event(event)
func frames(n: int) -> void:
 for i in n: await physics_frame
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.gun.tuning.sound_enabled = false
 await frames(5)
 button(true)
 await frames(61)
 button(false)
 await frames(2)
 var gun = scene.combat.gun
 var failures := 0
 if gun.shots_fired<8 or gun.shots_fired>9: failures += 1
 gun.magazine = 0
 var dry: int = gun.dry_clicks
 button(true)
 await frames(60)
 if gun.dry_clicks!=dry+1: failures += 1
 button(false)
 await frames(2)
 button(true)
 await frames(3)
 if gun.dry_clicks!=dry+2: failures += 1
 button(false)
 await frames(2)
 print("FIRE_3D_INPUT_PIPELINE failures=",failures," auto_shots=",gun.shots_fired," dry_clicks=",gun.dry_clicks)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
