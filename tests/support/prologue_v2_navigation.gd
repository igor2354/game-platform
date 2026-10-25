extends RefCounted
## Test navigation uses ordinary input, collisions and current tuning; no mid-route teleport.
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var tree:SceneTree
var hero:CoreMovementPlayer
var forest:Node2D
var ticks:=0
var last_error:=""
func _init(scene_tree:SceneTree,player:CoreMovementPlayer,level_forest:Node2D) -> void:
	tree=scene_tree;hero=player;forest=level_forest
func frames(n:int) -> void:
	for i in n:await tree.physics_frame;await tree.process_frame;ticks+=1
func release() -> void:
	for key in ["core_left","core_right","core_up","core_down","core_jump","core_crouch","core_walk","core_sprint"]:Input.action_release(key)
func fail(message:String) -> bool:
	release();last_error=message+" at "+str((hero.position-V2.ORIGIN)/V2.UPM)+" mode="+hero.mode;print("NAV FAIL ",last_error);return false
func move_to(x:float,limit:=3600) -> bool:
	var goal:=V2.point(x,0).x
	var previous:=hero.position.x;var stalled:=0;var jump_age:=100
	var sample_x:=hero.position.x;var sample_age:=0;var grounded_sample:=false
	for tick in limit:
		await frames(1);jump_age+=1
		if hero.health<=0:return fail("death en route to "+str(x))
		var dx:=goal-hero.position.x
		hero.weapon.aim_override=hero.position+Vector2(signf(dx)*700,-100)
		if absf(dx)<18 and hero.is_on_floor() and not hero.parkour_active() and not hero.ladder_exit.is_finite():
			release();await frames(10)
			if absf(goal-hero.position.x)<28:return true
		stalled=stalled+1 if absf(hero.position.x-previous)<.2 and hero.is_on_floor() and not hero.parkour_active() else 0
		previous=hero.position.x
		sample_age+=1;grounded_sample=grounded_sample or hero.is_on_floor()
		if sample_age>=30:
			if absf(hero.position.x-sample_x)<5 and grounded_sample and not hero.parkour_active():stalled=maxi(stalled,15)
			sample_x=hero.position.x;sample_age=0;grounded_sample=false
		var xm:float=(hero.position.x-V2.ORIGIN.x)/V2.UPM
		var low:=(xm>71.8 and xm<78.0) or (xm>415.7 and xm<419.7 and hero.position.y>V2.point(0,.5).y)
		var precision:=absf(dx)<150 and stalled<5
		Input.action_release("core_left" if dx>=0 else "core_right")
		if absf(dx)>18:Input.action_press("core_right" if dx>=0 else "core_left")
		else:Input.action_release("core_left");Input.action_release("core_right")
		if low:Input.action_press("core_crouch")
		else:Input.action_release("core_crouch")
		if low or precision or hero.sprint_exhausted:
			Input.action_release("core_sprint");Input.action_press("core_walk")
		else:
			Input.action_release("core_walk");Input.action_press("core_sprint")
		if stalled>5 and hero.sprint_exhausted:
			release();await frames(135);stalled=0;continue
		if hero.mode=="ledge_hang" and jump_age>6:
			Input.action_release("core_jump");await frames(2);Input.action_press("core_jump");jump_age=0
		elif hero.is_on_floor() and not hero.parkour_active():
			if jump_age>6:Input.action_release("core_jump")
			if stalled>12 and jump_age>12:
				Input.action_press("core_jump");jump_age=0
	return fail("timeout en route to "+str(x))
func climb(id:String) -> bool:
	var r:Rect2=forest.features[id+"_ladder"]
	if not await move_to((r.get_center().x-V2.ORIGIN.x)/V2.UPM):return false
	release();hero.weapon.aim_override=hero.position+Vector2(700,-100);Input.action_press("core_up");Input.action_press("core_right")
	for i in ceili(r.size.y/hero.motion_value("climb_speed")*60)+180:
		await frames(1)
		if hero.health<=0:return fail("death on ladder "+id)
		if not hero.climbing and not hero.ladder_exit.is_finite() and hero.is_on_floor() and absf(hero.position.y-r.position.y)<3:
			release();return true
	return fail("ladder exit "+id)
func chasm() -> bool:
	if not await move_to(241):return false
	release();await frames(135)
	Input.action_press("core_right");Input.action_press("core_sprint")
	for i in 150:
		await frames(1)
		if hero.position.x>=V2.point(243.3,0).x:break
	Input.action_press("core_jump")
	for i in 120:
		await frames(1)
		if hero.health<=0:return fail("fatal gap")
		if hero.is_on_floor() and hero.position.x>V2.point(246.2,0).x:
			release();return true
	return fail("fatal landing")
func complete() -> bool:
	# Lower branches deliberately exercise recovery paths, not only ideal jumps.
	for step in [["move",33.5],["climb","ravine_forward"],["move",79.0],["climb","root_pit_exit"],["move",107.2],["climb","wood_up"],["climb","work_pit_exit"],["move",223.0],["gap",0],["move",330.0],["move",383.0],["climb","basement_up"],["move",443.0],["climb","log_up"],["move",483.0]]:
		var ok:bool
		if step[0]=="move":ok=await move_to(step[1])
		elif step[0]=="climb":ok=await climb(step[1])
		else:ok=await chasm()
		print("NAV ",step," ok=",ok," ticks=",ticks)
		if not ok:return false
	release();return true
