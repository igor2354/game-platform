extends SceneTree
const F = preload("res://scripts/campaign/forest_prologue.gd")
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
 for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String) -> void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error("FAIL "+label)
func release() -> void:
 for k in ["core_left","core_right","core_up","core_down","core_jump","core_sprint","core_crouch","core_walk"]:Input.action_release(k)
func place(x:float,h:float) -> void:
 release();hero.reset_to(F.point(x,h));hero.weapon.aim_override=hero.position+Vector2(700,-100);await frames(10)
func run() -> void:
 lab=load("res://scenes/campaign/prologue.tscn").instantiate();lab.load_user_settings=false
 var folder:=OS.get_environment("TEMP").path_join("p1r1-check-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(folder)
 for k in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(k,folder.path_join(k+".cfg"))
 lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
 root.add_child(lab);await frames(12);hero=lab.player;hero.weapon.tuning.sound_enabled=false
 for e in lab.level.enemies:
  e.test_frozen=true;e.collision_layer=0;e.collision_mask=0
 var f=lab.level.forest
 check(is_equal_approx(F.WIDTH/F.UPM,246),"246m blueprint length")
 check(lab.level.campaign_enemies.size()==7,"seven separately spawned blueprint zombies")
 check(f.ladders.size()==6,"six usable ladders at 51.3 world units")
 for r in f.ladders:check(is_equal_approx(r.size.x,51.3),"human-scaled ladder width")
 check(is_equal_approx(hero.character_scale(),1),"Sofia 1x unchanged")
 for n in F.DATA.PLAN.nodes:
  for p in n.enemies:
   await place(n.start_m+float(p[0]),float(p[1]))
   check(hero.is_on_floor() and absf(hero.position.y-F.point(0,p[1]).y)<3,"physical standing floor for encounter "+n.id)
 # Full-speed takeoff tests on actual supports; teleport only before each attempt.
 var jump_count:=0
 for n in F.DATA.PLAN.nodes:
  for j in n.jumps:
   jump_count+=1
   var start:float=n.start_m+float(j[0]);var end:float=n.start_m+float(j[2])
   if n.id == "03" and is_equal_approx(float(j[0]),6.6):end+=1.0
   await place(start-hero.world_radius()/F.UPM-.08,float(j[1]))
   hero.velocity.x=hero.motion_value("sprint_speed")
   Input.action_press("core_sprint");Input.action_press("core_right");Input.action_press("core_jump")
   var landed:=false
   for tick in 110:
    await frames(1)
    if hero.position.x>F.point(end,0).x+hero.world_radius() and hero.is_on_floor():landed=true;break
    if hero.mode=="ledge_hang":Input.action_release("core_jump");await frames(2);Input.action_press("core_jump")
    if hero.health<=0:break
   release();check(landed,"real jump "+n.id+" "+str(j))
   if not landed:print("JUMP STOP ",(hero.position-F.ORIGIN)/F.UPM," ",hero.mode)
 check(jump_count==13,"all thirteen blueprint jump edges tested")
 for i in f.ladders.size():
  var r:Rect2=f.ladders[i]
  await place((r.get_center().x-F.ORIGIN.x)/F.UPM,(F.ORIGIN.y-r.end.y)/F.UPM)
  Input.action_press("core_up")
  var climbed:=false
  for tick in 260:
   await frames(1)
   if not hero.climbing and not hero.ladder_exit.is_finite() and hero.is_on_floor() and absf(hero.position.y-r.position.y)<3:climbed=true;break
  release();check(climbed,"ladder bottom-to-top "+str(i))
  if not climbed:print("LADDER STOP ",(hero.position-F.ORIGIN)/F.UPM," ",hero.mode)
 # Ordinary forward movement through both building ground-floor doorways.
 for row in [[208.0,.4,216.0],[161.7,0,170.0]]:
  await place(row[0],row[1]);Input.action_press("core_right")
  for tick in 310:
   await frames(1)
   if hero.position.x>F.point(row[2],0).x:break
  release();check(hero.position.x>F.point(row[2],0).x,"building ground-floor route "+str(row[0]))
 # Solid ceilings are tested with ray queries, on both faces away from real hatches.
 var space:=lab.level.get_world_2d().direct_space_state
 for row in [[165.0,2.3,2.7],[165.0,4.9,5.3],[210.0,2.7,3.1],[241.0,4.5,4.85]]:
  var q:=PhysicsRayQueryParameters2D.create(F.point(row[0],row[1]),F.point(row[0],row[2]),1)
  check(not space.intersect_ray(q).is_empty(),"solid ceiling "+str(row[0])+" at "+str(row[1]))
 # Failed bridge jump permits a standing dry passage and ladder recovery.
 await place(124,-2.6);Input.action_press("core_right")
 for tick in 340:
  await frames(1)
  if hero.position.x>F.point(137,-2.6).x:break
 release();check(hero.position.x>F.point(137,-2.6).x and hero.health>0,"bridge lower passage remains open")
 # A continuous manual-input return from the pit, no teleports after the start.
 await place(49,-2)
 Input.action_press("core_left");Input.action_press("core_jump")
 var returned:=false
 var age:=0
 for tick in 1200:
  await frames(1);age+=1
  hero.weapon.aim_override=hero.position+Vector2(-700,-100)
  if hero.mode=="ledge_hang" and age>10:
   Input.action_release("core_jump");await frames(3);Input.action_press("core_jump");age=0
  elif hero.is_on_floor() and not hero.parkour_active() and age>35:
   Input.action_release("core_jump");await frames(2);Input.action_press("core_jump");age=0
  if hero.position.x<F.point(38,0).x and hero.is_on_floor():returned=true;break
 release();check(returned and hero.health>0,"continuous corpse pit return left with manual jump/parkour")
 print("RECOVERY STOP ",(hero.position-F.ORIGIN)/F.UPM," ",hero.mode)
 await place(233.7,-3)
 await frames(5)
 check(hero.health<=0 and not hero.is_physics_processing(),"rail chasm is lethal")
 lab._recover();await frames(12)
 check(hero.health>0 and hero.is_physics_processing() and hero.is_on_floor(),"F8 recovery returns to new start")
 release();lab.queue_free();await frames(3)
 print("P1R1 BLOCKING: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
