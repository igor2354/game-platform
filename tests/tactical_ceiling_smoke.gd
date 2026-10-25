extends SceneTree
const V2 = preload("res://scripts/campaign/forest_prologue_v2.gd")
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1; push_error("FAIL "+label)
func release() -> void:
	for a in ["core_left","core_right","core_up","core_down","core_jump","core_walk","core_crouch","core_sprint"]: Input.action_release(a)
func create(scene: String) -> void:
	lab = load(scene).instantiate(); lab.load_user_settings = false
	var temp := OS.get_environment("TEMP").path_join("tactical-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]: lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id = "sofia"
	lab.get_node("World/Player").sofia_cel_variant = true
	root.add_child(lab); await frames(10); hero=lab.player
	hero.request_body_scale(2.85); hero.weapon.tuning.sound_enabled=false
func probe_surfaces() -> void:
	var count := 0
	var one_way := 0
	for body in lab.level.get_children():
		if body is StaticBody2D:
			for shape in body.get_children():
				if shape is CollisionShape2D and shape.one_way_collision: one_way+=1
	check(one_way==0,"level has no one-way physical ceilings")
	for rect in lab.level.solid_platforms:
		if lab.level.prologue_mode and rect.position.x < 12000: continue
		if rect.size.x < hero.world_radius()*2+12: continue
		release(); hero.reset_to(Vector2(rect.get_center().x,rect.end.y+hero.world_height()+2))
		if not hero.parkour._clear_at(hero.global_position):
			print("PROBE OCCLUDED by adjacent geometry: ",rect); continue
		Input.action_press("core_jump"); hero.jump_buffer=0; hero.coyote=0; hero.velocity.y=-1100
		var contact := false
		for tick in 16:
			await frames(1)
			contact = contact or hero.is_on_ceiling()
		check(contact,"solid ceiling contact "+str(rect)); count+=1
	check(count>0,"active ceiling probes executed")
func jump(tap: bool) -> float:
	release(); hero.reset_to(Vector2(100,760)); await frames(12)
	Input.action_press("core_jump")
	var minimum := hero.position.y
	for tick in 80:
		await frames(1)
		minimum=minf(minimum,hero.position.y)
		if tap and tick==1: Input.action_release("core_jump")
		if tick>5 and hero.is_on_floor(): break
	release(); return 760-minimum
func run() -> void:
	for scene in ["res://scenes/main.tscn","res://scenes/campaign/prologue.tscn","res://scenes/campaign/prologue_v2.tscn"]:
		await create(scene); await probe_surfaces()
		if lab.level.prologue_version==2:
			for i in lab.level.forest.ladders.size():
				var r: Rect2=lab.level.forest.ladders[i]
				release(); hero.reset_to(Vector2(r.get_center().x,r.end.y)); await frames(1)
				Input.action_press("core_up")
				for tick in ceili(r.size.y/hero.motion_value("climb_speed")*60)+180:
					await frames(1)
					if not hero.climbing and not hero.ladder_exit.is_finite() and absf(hero.position.y-r.position.y)<2: break
				release(); await frames(12)
				check(absf(hero.position.y-r.position.y)<3 and hero.is_on_floor(),"ladder %02d stable upper exit"%(i+1))
				if absf(hero.position.y-r.position.y)>3: print("DETAIL ",i+1," ",hero.position," ",r)
				Input.action_press("core_down")
				for tick in ceili(r.size.y/hero.motion_value("climb_speed")*60)+180:
					await frames(1)
					if not hero.climbing and absf(hero.position.y-r.end.y)<3: break
				release(); check(absf(hero.position.y-r.end.y)<3,"ladder %02d descent from actual landing"%(i+1))
		else:
			var full := await jump(false); var tap := await jump(true)
			print("JUMP full_m=",CoreWorldUnits.meters(full)," tap_m=",CoreWorldUnits.meters(tap))
			check(CoreWorldUnits.meters(full)>.5 and CoreWorldUnits.meters(full)<.65,"grounded full jump")
			check(tap<full*.65 and tap>5,"short tap still produces weaker jump")
			release(); hero.reset_to(Vector2(100,760)); await frames(12)
			for gait in [["",115.0],["core_walk",45.0],["core_sprint",195.0],["core_crouch",34.5]]:
				release(); hero.reset_to(Vector2(100,760)); hero.weapon.aim_override=Vector2(1000,700); await frames(5)
				Input.action_press("core_right")
				if gait[0]!="": Input.action_press(gait[0])
				await frames(55)
				print("GAIT ",gait[0]," ",hero.velocity.x," wanted ",gait[1]*2.85)
				check(absf(hero.velocity.x-gait[1]*2.85)<2,"gait "+gait[0]+" measured speed")
			release()
		lab.queue_free(); await frames(3)
	print("TACTICAL CEILINGS: %d/%d"%[checks-failures,checks]); quit(1 if failures else 0)
