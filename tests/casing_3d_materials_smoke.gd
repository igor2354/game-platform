extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i in n: await physics_frame
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.set_process(false)
 scene.combat.set_physics_process(false)
 var fx = scene.combat.effects
 var bodies: Array[RigidBody3D] = []
 var supports: Array[StaticBody3D] = []
 for kind in [1,3,4,5]:
  var support := StaticBody3D.new()
  support.set_meta("terra_material",kind)
  var collider := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(1.4,1,1.4)
  collider.shape = box
  support.add_child(collider)
  scene.add_child(support)
  support.position = Vector3(-15+kind*2,2,0)
  supports.append(support)
  var body = preload("res://scripts/core/casing_3d.gd").new()
  body.prepare(fx,"stg44",support.position+Vector3.UP*.9,Vector3.RIGHT)
  body.linear_velocity = Vector3.ZERO
  body.angular_velocity = Vector3.ZERO
  fx.casings.append(body)
  bodies.append(body)
 await frames(100)
 for i in bodies.size():
  var body := bodies[i]
  var expected := int(supports[i].get_meta("terra_material"))
  if body.last_contact<0 or body.kind!=expected:
   failures += 1
   print("FAIL material ",expected," actual=",body.kind," contact=",body.last_contact)
  if body.last_normal.dot(Vector3.UP)<.99 or absf(body.last_contact_point.y-2.5)>.03: failures += 1
  if not is_equal_approx(body.physics_material_override.bounce,body.SOURCE.BOUNCE[expected]): failures += 1
 # Resting cases must wake when their physical support is removed/moved.
 var body := bodies[0]
 body.sleeping = true
 var before: float = body.position.y
 supports[0].queue_free()
 await frames(16)
 if body.position.y>=before-.02:
  failures += 1
  print("FAIL support removal ",body.position.y," from ",before)
 bodies[1].sleeping = true
 before = bodies[1].position.y
 supports[1].position.x += 3
 await frames(16)
 if bodies[1].position.y>=before-.02: failures += 1
 fx.clear()
 scene.player.position = Vector3(-4,0,0)
 scene.combat.gun.tuning.sound_enabled = true
 scene.combat.gun.tuning.casing_volume = -10
 for kind in [1,3,4,5]:
  fx.casing_contact(null,kind,scene.player.position+Vector3.UP*.1)
  var expected: String = ["soil","stone","wood","metal"][[1,3,4,5].find(kind)]
  if not str(fx.last_casing_contact.get("source","")).ends_with(expected+".wav"): failures += 1
 var previous_gain: float = fx.last_casing_contact.gain
 scene.camera.position.x += 100
 fx.casing_contact(null,5,scene.player.position+Vector3.UP*.1)
 if fx.last_casing_contact.gain!=previous_gain: failures += 1
 for i in 10: fx.casing_contact(null,5,scene.player.position)
 if fx.voices.size()!=6: failures += 1
 print("CASING_3D_MATERIALS failures=",failures," materials=4 support_remove/move audio/listener/6voices checked")
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
