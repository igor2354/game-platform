extends SceneTree
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab:CoreMovementLab
var hero:CoreMovementPlayer
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
	for a in ["core_left","core_right","core_up","core_down","core_jump","core_sprint","core_crouch","core_dash"]:Input.action_release(a)
func place(x:float,h:float) -> void:
	release();hero.reset_to(V2.point(x,h));hero.weapon.aim_override=hero.position+Vector2(700,-100);await frames(10)
func ray(a:Vector2,b:Vector2) -> Dictionary:
	return hero.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a,b,1))
func lateral(x:float,h:float,direction:float,boundary:float,action:String) -> bool:
	await place(x,h)
	Input.action_press("core_right" if direction>0 else "core_left")
	if action!="":Input.action_press(action)
	await frames(70);release()
	return direction*(hero.position.x-V2.point(boundary,0).x)<-hero.world_radius()+2
func climb_to_top(id:String) -> bool:
	var r:Rect2=lab.level.forest.features[id+"_ladder"]
	release();hero.reset_to(Vector2(r.get_center().x,r.end.y));await frames(2)
	Input.action_press("core_up");Input.action_press("core_right")
	for i in ceili(r.size.y/hero.motion_value("climb_speed")*60)+180:
		await frames(1)
		if hero.is_on_floor() and not hero.climbing and not hero.ladder_exit.is_finite() and absf(hero.position.y-r.position.y)<3:release();return true
	release();return false
func run() -> void:
	lab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-buildings-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12);hero=lab.player
	preload("res://scripts/campaign/catalog.gd").equip(hero.weapon,"stg44");hero.weapon.tuning.sound_enabled=false
	check(is_equal_approx(hero.character_scale(),1) and is_equal_approx(hero.motion_value("run_speed"),327.75) and is_equal_approx(hero.motion_value("gravity"),997.5),"Sofia baseline and movement remain unchanged")
	check(lab.level.forest.sections.size()==12 and is_equal_approx(lab.level.right_bound()-V2.ORIGIN.x,484*V2.UPM),"twelve sections and all 484m retained")
	var f=lab.level.forest
	var walls:=0
	for id in f.features:
		if id not in ["house_left_upper","house_window_sill","house_window_head","tower_left","tower_right"] and not id.begins_with("wagon_sill_") and not id.begins_with("wagon_head_"):continue
		var rect:Rect2=f.features[id]
		for direction in [-1.0,1.0]:
			if id.begins_with("wagon_sill_"):
				# The approach wedges intentionally join the sill; its sides are buried
				# in solid geometry, so a ray starting there cannot test an exposed face.
				var probe:=PhysicsPointQueryParameters2D.new()
				probe.position=rect.get_center()+Vector2(direction*rect.size.x*.25,0)
				probe.collision_mask=1
				check(not hero.get_world_2d().direct_space_state.intersect_point(probe).is_empty(),"solid joined wagon threshold "+id+" "+str(direction))
				continue
			var a:=rect.get_center()+Vector2(-direction*(rect.size.x*.5+30),0)
			var hit:=ray(a,a+Vector2(direction*(rect.size.x+60),0))
			check(not hit.is_empty() and absf(hit.normal.x)>.9 and hit.position.x>=rect.position.x-1 and hit.position.x<=rect.end.x+1,"physical wall both faces "+id+" "+str(direction))
		walls+=1
	check(walls==9,"all nine approved wall pieces exist")
	check(await lateral(306.8,3.8,-1,306,""),"house solid upper left blocks walking")
	check(await lateral(306.8,3.8,-1,306,"core_jump"),"house solid upper left blocks jumping")
	check(await lateral(306.8,3.8,-1,306,"core_dash"),"house solid upper left blocks dash")
	check(await lateral(205.5,9,1,207,""),"tower cabin blocks walking through its wall")
	check(await lateral(205.5,9,1,207,"core_jump"),"tower cabin blocks jumping through its wall")
	check(await climb_to_top("tower"),"closed tower cabin remains accessible by ladder hatch")
	check(await climb_to_top("house_inner"),"house upper floor remains accessible by internal ladder")
	var sill:Rect2=f.features.house_window_sill;var head:Rect2=f.features.house_window_head
	check(is_equal_approx((sill.position.y-head.end.y)/V2.UPM,2.2),"house window clear height is 2.20m")
	await place(318,3.8);Input.action_press("core_right");Input.action_press("core_sprint")
	for i in 180:
		await frames(1)
		if hero.position.x>=V2.point(320.5,0).x:break
	Input.action_press("core_jump");var landed:=false
	for i in 150:
		await frames(1)
		if hero.is_on_floor() and hero.position.x>V2.point(323.8,0).x and hero.position.y<V2.point(0,3.0).y:landed=true;break
	release();check(landed,"planned window exit lands on existing balcony")
	var nav=preload("res://tests/support/prologue_v2_navigation.gd").new(self,hero,f)
	await place(305,.6);check(await nav.move_to(330),"house ground floor can be crossed through both doorways")
	check(await nav.move_to(305),"house ground floor remains traversable in reverse")
	check(not ray(V2.point(397.3,-1),V2.point(396.7,-1)).is_empty() and not ray(V2.point(410.7,-1),V2.point(411.3,-1)).is_empty(),"bunker basement has physical soil boundaries")
	check(await climb_to_top("basement_up"),"bunker basement retains an exit through its hatch")
	check(await climb_to_top("bunker_roof"),"bunker roof is reached through its real hatch")
	await place(468.1,5.1);check(await nav.move_to(480),"damaged wagon traversed through intentional end breaches")
	check(await nav.move_to(468),"wagon end breaches are traversable in reverse")
	check(await climb_to_top("root_pit_exit"),"root pit new ladder gives stable forward exit")
	check(await climb_to_top("work_pit_exit"),"logging pit new ladder gives stable forward exit")
	var barrier:Rect2=f.features.work_barrier
	check(barrier.size.x>=hero.world_radius()*2+20,"work barrier offers a body-wide landing")
	await place(359.5,-2);check(await nav.move_to(367),"approach stone permits overcoming 1.4m cover with existing sprint parkour")
	check(lab.level.forest.ladders.size()==19,"nineteen ladders include two recovery exits")
	release();lab.queue_free();await frames(3);print("V2 BUILDINGS: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
