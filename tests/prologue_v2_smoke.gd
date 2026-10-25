extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
const FOREST = preload("res://scripts/campaign/forest_prologue_v2.gd")
var app
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var checks := 0
var failures := 0
const INPUTS := ["core_left","core_right","core_up","core_down","core_jump","core_crouch","core_walk","core_sprint"]
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks += 1
	if ok: print("PASS ",label)
	else: failures += 1;push_error("FAIL "+label)
func release() -> void:
	for a in INPUTS: Input.action_release(a)
func place(p: Vector2) -> void:
	release();hero.set_physics_process(true);hero.reset_to(p)
	hero.weapon.aim_override=p+Vector2(700,-100)
	await frames(8)
func walk_to(x: float,crouch := false,max_ticks := 600,steps := false) -> bool:
	release()
	if crouch:Input.action_press("core_crouch")
	var sign_x := signf(x-hero.position.x)
	Input.action_press("core_right" if sign_x>0 else "core_left")
	if steps: Input.action_press("core_sprint")
	var previous := hero.position.x
	var stalled := 0
	for tick in max_ticks:
		await frames(1)
		if hero.health<=0:return false
		if steps:
			stalled = stalled+1 if absf(hero.position.x-previous)<.1 else 0
			previous = hero.position.x
			if hero.mode=="ledge_hang":
				Input.action_release("core_jump");await frames(2);Input.action_press("core_jump")
			elif stalled>8 and hero.is_on_floor():Input.action_press("core_jump")
			elif hero.is_on_floor():Input.action_release("core_jump")
		if sign_x*(hero.position.x-x)>=-3 and (not steps or not hero.parkour_active()):
			release();return true
	release();return false
func traverse_main() -> bool:
	await place(lab.level.player_spawn())
	var navigation:=preload("res://tests/support/prologue_v2_navigation.gd").new(self,hero,lab.level.forest)
	var completed:bool=await navigation.complete()
	print("ROUTE SECONDS ",navigation.ticks/60.0," completed=",completed)
	return completed

func run() -> void:
	app=FRONTEND.new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("prologue-v2-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);await frames(3)
	app.buttons.campaign.pressed.emit()
	check(app.page=="levels" and app.buttons.has("prologue") and app.buttons.has("prologue_v2"),"Company opens two prologue choices")
	app.buttons.prologue.pressed.emit();app.buttons.sofia.pressed.emit();app.buttons.choose.pressed.emit();app.buttons.apply.pressed.emit()
	await frames(10)
	check(app.game.level.prologue_version==1 and app.game.level.right_bound()==33120,"original prologue remains the original 21120-unit forest")
	check(app.game.level.forest.panorama_strips.size()==11,"original prologue retains its panorama")
	check(is_equal_approx(app.game.player.character_scale(),1),"original prologue uses normalized Sofia baseline")
	app.return_to_menu();await frames(5)
	app.buttons.campaign.pressed.emit();app.buttons.prologue_v2.pressed.emit()
	check(app.page=="characters" and app.selected_level=="prologue_v2","new level choice precedes loadout")
	app.buttons.back.pressed.emit();check(app.page=="levels","character back returns to level choices")
	app.buttons.prologue_v2.pressed.emit();app.buttons.sofia.pressed.emit();app.buttons.choose.pressed.emit();app.buttons.apply.pressed.emit()
	await frames(10);lab=app.game;hero=lab.player
	hero.weapon.tuning.sound_enabled=false
	var f=lab.level.forest
	check(lab.level.prologue_version==2 and f.sections.size()==12,"separate prologue ver2 contains twelve V4 sections")
	check(is_equal_approx(lab.level.right_bound()-FOREST.ORIGIN.x,484*FOREST.UPM),"new bounds retain all 484 project meters")
	check(f.panorama.strips.size()==19,"ver2 loads nineteen strips of its own continuous panorama")
	check(is_equal_approx(hero.body_scale,2.85) and hero.is_on_floor(),"Sofia starts at reference 2.85x on solid ground")
	check(is_equal_approx(hero.tuning.run_speed,327.75) and is_equal_approx(hero.motion_value("run_speed"),327.75),"new level has reference base and derived run speed")
	check(hero.fall_limit>FOREST.point(0,-8).y and lab.level_map._world_x_bounds().y==lab.level.right_bound(),"deep terrain and full map use new level bounds")
	check(f.jump_catalog.size()==19 and f.ladders.size()==19,"nineteen transitions and all nineteen ladders connected")
	check(lab.camera_settings.zoom==lab.camera_overlay.defaults.zoom,"reference size does not change camera zoom")
	# Deep natural floor must not trigger the old polygon fall recovery.
	var recoveries=lab.respawns
	await place(FOREST.point(24+9.65,-4.8))
	await frames(20)
	check(hero.health>0 and lab.respawns==recoveries and hero.position.y>1120,"deep ravine stays playable below legacy fall limit")
	# Root clearance: actual crouch input through the unchanged low tunnel.
	await place(FOREST.point(58+13.8,2))
	Input.action_press("core_crouch");await frames(3)
	check(await walk_to(FOREST.point(58+22,0).x,true),"Sofia traverses the 1.45m root passage crouched")
	# Traverse each declared jump with actual input, from a short run-up.
	for n in FOREST.DATA.PLAN.nodes:
		for j in n.jumps:
			var a=FOREST.point(n.start_m+float(j.a[0]),float(j.a[1]))
			var b=FOREST.point(n.start_m+float(j.b[0]),float(j.b[1]))
			if j.id=="J18":
				var exit:Rect2=f.features.log_up_ladder
				await place(Vector2(exit.get_center().x,exit.end.y))
				Input.action_press("core_up")
				for t in 300:
					await frames(1)
					if hero.is_on_floor() and not hero.climbing and not hero.ladder_exit.is_finite() and absf(hero.position.y-exit.position.y)<3:break
				release()
			else:await place(a-Vector2(FOREST.UPM*(3.5 if j.id=="J11" else 2.0),0))
			# The last 0.5m before the edge is the launch point; enough capsule clearance.
			var running=true if j.id=="J18" else await walk_to(a.x-(1.5 if j.id=="J11" else .5)*FOREST.UPM,false,240,true)
			await frames(2)
			Input.action_press("core_right");Input.action_press("core_sprint")
			if j.id not in ["J07","J12","J18"]:Input.action_press("core_jump")
			var landed := false
			for tick in 150:
				await frames(1)
				if hero.health<=0:break
				# Existing mantle deliberately needs a second jump press after catching.
				if hero.mode == "ledge_hang":
					Input.action_release("core_jump");await frames(2);Input.action_press("core_jump")
				if tick>8 and hero.is_on_floor() and hero.position.x>b.x+.3*FOREST.UPM:
					landed=true;break
			release()
			check(running and landed,"actual input jump "+j.id+" / section "+n.id)
			if not landed:print("JUMP DETAIL ",j.id," final=",hero.position," target=",b," health=",hero.health," mode=",hero.mode)
	# Floors and stair openings of both two-storey structures.
	for record in [["house_inner",true],["house_outside",false],["basement_down",false],["basement_up",true],["bunker_roof",true]]:
		var r:Rect2=f.features[record[0]+"_ladder"]
		var up:bool=record[1]
		await place(Vector2(r.get_center().x,r.end.y if up else r.position.y))
		Input.action_press("core_up" if up else "core_down")
		var target_y=r.position.y if up else r.end.y
		var reached := false
		for tick in ceili(r.size.y/hero.motion_value("climb_speed")*60)+120:
			await frames(1)
			if absf(hero.position.y-target_y)<3 and not hero.climbing: reached=true;break
		release();check(reached,"two-storey route ladder "+record[0])
	# Deliberately miss the fatal jump; death must persist until explicit F8 recovery.
	await place(FOREST.point(244.9,1.5));await frames(110)
	check(hero.health==0 and lab.respawns==recoveries and not hero.is_physics_processing(),"fatal chasm kills without automatic recovery")
	lab._recover();await frames(10)
	check(hero.health>0 and hero.is_physics_processing() and hero.global_position.distance_to(lab.level.player_spawn())<3,"F8 restores Sofia at new prologue start")
	check(await traverse_main(),"continuous 484m main route with real input, no teleport between sections")
	release()
	lab._toggle_level_map();check(paused and lab.level_map.visible,"new level map opens and pauses")
	lab._toggle_level_map();check(not paused,"new level map closes")
	app.return_to_menu();await frames(5)
	check(app.page=="main" and not is_instance_valid(app.game),"new level returns to main menu")
	app.queue_free();await frames(3)
	print("PROLOGUE V2: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
