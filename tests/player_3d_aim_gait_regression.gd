extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  if failures<15: print("FAIL ",label)
func hand(model: Node,side: String) -> Vector3: return model.rig.to_global(model._joint(side+"hand"))
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 await process_frame
 var combat = scene.combat
 var player = scene.player
 var model = player.model
 scene.set_process(false)
 combat.set_process(false)
 combat.set_physics_process(false)
 player.set_physics_process(false)
 player.set_process(false)
 combat.zombie_settings.movement_enabled = false
 combat.zombie_settings.combat_enabled = false
 combat.gun.tuning.recoil_enabled = false
 combat.gun.tuning.sound_enabled = false
 player.position = Vector3(-4,0,0)
 scene.camera.position = Vector3(-4,1.2,15)
 scene.camera.look_at(Vector3(-4,1.2,0))
 combat.cursor_active = true
 var previous := Vector3.INF
 var max_jump := 0.0
 for step in 720:
  var angle := TAU*step/720
  var point: Vector3 = player.position+Vector3(0,1.4,0)+Vector3(cos(angle),sin(angle),0)*3
  combat.cursor_screen = scene.camera.unproject_position(point)
  combat._process(1.0/120)
  player._process(1.0/120)
  combat.reticle._process(0)
  if combat.reticle.beam_points.size()>0:
   var ray_end: Vector3 = combat.reticle.beam_points[combat.reticle.beam_points.size()/2]
   check((ray_end-combat.reticle.origin).normalized().dot(combat.pivot.global_basis.x)>.9999,"beam follows current barrel")
  check(combat.pivot.global_basis.x.dot(combat.aim_direction)>.9999,"barrel direction "+str(step))
  var current := hand(model,"r_")
  if previous.is_finite():
   var jump := current.distance_to(previous)
   if jump>.15: print("HAND_STEP ",step," jump=",jump," face=",combat.aim_facing," yaw=",model.rotation.y)
   max_jump = maxf(max_jump,jump)
  previous = current
 check(max_jump<.15,"continuous arm sweep max="+str(max_jump))
 combat.aim_facing = 1
 var flips := 0
 for step in 120:
  var point: Vector3 = player.position+Vector3(sin(step)*.08,3.4,0)
  combat.cursor_screen = scene.camera.unproject_position(point)
  combat._process(1.0/120)
  player._process(1.0/120)
  if combat.aim_facing!=1: flips += 1
 check(flips==0,"vertical side chatter")
 # Backpedal while firing: heading stays at the weapon, phase runs backwards.
 combat.cursor_screen = scene.camera.unproject_position(player.position+Vector3(5,1.4,0))
 var mouse := InputEventMouseButton.new()
 mouse.button_index = MOUSE_BUTTON_LEFT
 mouse.pressed = true
 Input.parse_input_event(mouse)
 Input.action_press("core_left")
 var backwards_ticks := 0
 for step in 60:
  await physics_frame
  combat._process(1.0/60)
  combat._physics_process(1.0/60)
  var old_phase: float = player.phase
  player._physics_process(1.0/60)
  player._process(1.0/60)
  combat.finish_tick()
  if player.velocity.x<-.1:
   backwards_ticks += 1
   check(player.weapon_visual_facing==1 and fposmod(player.phase-old_phase+.5,1)-.5<0,"backpedal cycle")
 check(backwards_ticks>30,"backpedal active")
 Input.action_release("core_left")
 mouse.pressed = false
 Input.parse_input_event(mouse)
 combat.gun.tuning.weapon_enabled = false
 Input.action_press("core_right")
 Input.action_press("core_sprint")
 var sprint_ticks := 0
 for step in 60:
  await physics_frame
  combat._process(1.0/60)
  combat._physics_process(1.0/60)
  player._physics_process(1.0/60)
  player._process(1.0/60)
  if player.mode=="sprint":
   sprint_ticks += 1
   check(model.weapon_grips.is_empty(),"unarmed sprint has no stale IK grips")
   check(model.last_mode=="sprint","sprint uses sprint clip")
 check(sprint_ticks>30,"sprint active")
 Input.action_release("core_right")
 Input.action_release("core_sprint")
 print("AIM_GAIT_REGRESSION checks=",checks," failures=",failures," max_hand_step=",max_jump)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
