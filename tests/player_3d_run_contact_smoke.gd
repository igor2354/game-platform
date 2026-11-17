extends SceneTree
## Native 3D run contacts: the planted toe does not skate; a reversal steps on
## procedural contacts near a stop; mouse flips and trackpad flicks while
## running stay in the gait/backpedal without bone snaps or flip-flopping.
## Settings are not loaded; all five profile paths point to a temporary folder.
var failures := 0
class Holder extends Node3D:
 var grenades = null
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1

func median_slide(m: Node3D,holder: Node3D,mode: String,speed: float,base: float) -> float:
 var stride: float = base*2.85/100.97598*m.scale.x
 var phase := 0.0
 var dt := 1.0/120
 var previous := {}
 var speeds: Array[float] = []
 for i in 600:
  holder.position.x += speed*dt
  phase = fposmod(phase+speed*dt/stride,1)
  # Real frame time: the transition ends and the planted-toe lock is active.
  m.animate(mode,phase,1.0,dt)
  for prefix in ["r_","l_"]:
   var toe: Vector3 = m.rig.to_global(m._joint(prefix+"toes"))
   if toe.y-holder.position.y < .025:
    if previous.has(prefix) and i > 60: speeds.append(absf(toe.x-previous[prefix].x)/dt)
    previous[prefix] = toe
   else: previous.erase(prefix)
 speeds.sort()
 return speeds[speeds.size()/2]

func start_run(scene,player) -> void:
 player.reset()
 player.position = Vector3(-6.0,.02,0)
 for i in 10: await physics_frame
 Input.action_press("core_right")
 for i in 50:
  scene.combat.cursor_screen = scene.camera.unproject_position(player.global_position+Vector3(4,1.3,0))
  await physics_frame

func watch(scene,player,frames: int,side: float,flick: bool) -> Dictionary:
 # side: fixed cursor side; flick: sweep the cursor around the hero instead.
 var m = player.model
 var result := {"peak":0.0,"step":0.0,"bone":0.0,"flips":0}
 var thigh: float = m.rig.get_bone_global_rest(m.indices.r_thigh).origin.distance_to(m.rig.get_bone_global_rest(m.indices.r_shin).origin)
 var previous := {}
 var last_mode: String = player.visual_mode
 for i in frames:
  var t := i/60.0
  var angle := sin(t*TAU*1.6)*PI*1.1+sin(t*TAU*4.3)*.6
  var aim := Vector3(cos(angle),sin(angle)*.9,0)*3.5+Vector3(0,1.3,0) if flick else Vector3(4*side,1.3,0)
  scene.combat.cursor_screen = scene.camera.unproject_position(player.global_position+aim)
  await physics_frame
  await process_frame
  result.peak = maxf(result.peak,m.feet.weight)
  result.bone = maxf(result.bone,absf(m._joint("r_thigh").distance_to(m._joint("r_shin"))-thigh))
  if player.visual_mode != last_mode: result.flips += 1
  last_mode = player.visual_mode
  for bone in ["r_thigh","l_thigh","r_shin","l_shin","pelvis","spine1"]:
   var q: Quaternion = m.rig.get_bone_pose_rotation(m.indices[bone])
   if previous.has(bone): result.step = maxf(result.step,rad_to_deg(q.angle_to(previous[bone])))
   previous[bone] = q
 return result

func run() -> void:
 var holder := Holder.new()
 root.add_child(holder)
 var model = load("res://scripts/core/player_3d_model.gd").new()
 holder.add_child(model)
 await process_frame
 # 190 units is the run stride used by player_3d.gd.
 var slide := median_slide(model,holder,"run",3.25,190.0)
 check(slide < .15,"planted run toe slides %.3f m/s at 3.25 m/s (was ~0.98 before the lock)" % slide)
 # 85 units is the sprint stride: one atlas period per cycle (was 128).
 var sprint_slide := median_slide(model,holder,"sprint",5.5,85.0)
 check(sprint_slide < .2,"planted sprint toe slides %.3f m/s at 5.5 m/s (was ~2.2 at stride 128 without the lock)" % sprint_slide)
 holder.queue_free()
 await process_frame

 var temporary := OS.get_temp_dir().path_join("ubershrike-run-contact-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(temporary)
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
  if key in scene: scene.set(key,temporary.path_join(key+".cfg"))
 root.add_child(scene)
 for i in 10: await physics_frame
 for armed in [false,true]:
  scene.combat.gun.tuning.weapon_enabled = armed
  var player = scene.player
  var label := "armed" if armed else "unarmed"
  # Key reversal: braking from a run steps on planted contacts once slow.
  await start_run(scene,player)
  Input.action_release("core_right")
  Input.action_press("core_left")
  var reversal := await watch(scene,player,40,-1.0,false)
  Input.action_release("core_left")
  check(reversal.peak > .2,label+" reversal near a stop steps on contacts, weight %.2f" % reversal.peak)
  check(reversal.step < 20.0,label+" reversal has no bone snap, max %.1f deg/frame" % reversal.step)
  check(reversal.bone < .00001,label+" leg length unchanged during the turn")
  for i in 40: await physics_frame
  # Keep running right while the mouse jumps behind: turn in the gait, then backpedal.
  await start_run(scene,player)
  var flip := await watch(scene,player,40,-1.0,false)
  check(player.velocity.x > 1 and player.visual_mode == "walk" and player.model.rendered_lift < .001,label+" running away from the aim backpedals on the walk cycle without flight")
  check(flip.step < 20.0 and flip.peak < .05,label+" mouse flip at speed stays in the gait, max %.1f deg/frame" % flip.step)
  # Trackpad flicks: the cursor sweeps around the hero several times a second.
  var flicks := await watch(scene,player,150,0.0,true)
  Input.action_release("core_right")
  check(flicks.flips <= 3,label+" fast flicks do not flip run/backpedal every frame, %d flips" % flicks.flips)
  check(flicks.step < 20.0,label+" fast flicks have no bone snap, max %.1f deg/frame" % flicks.step)
  for i in 40: await physics_frame
 print("RUN_CONTACT failures=",failures)
 scene.queue_free()
 await process_frame
 for file in DirAccess.get_files_at(temporary): DirAccess.remove_absolute(temporary.path_join(file))
 DirAccess.remove_absolute(temporary)
 quit(int(failures>0))
