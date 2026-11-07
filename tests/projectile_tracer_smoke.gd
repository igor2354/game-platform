extends SceneTree
const TRACER = preload("res://scripts/core/projectile_tracer.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const IDS := ["stg44","mp40","svt","m1911"]
var checks := 0
var failures := 0
var impacts: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func impact(point: Vector2,_hit: bool,_killed: bool,_direction: Vector2) -> void: impacts.append({"point":point})

class Wall extends StaticBody2D:
	var hits := 0
	var damage := 0.0
	func take_projectile_damage(amount: float,_attacker: Node) -> void:
		hits+=1;damage+=amount

class Preview extends Node2D:
	var weapon_id := "stg44"
	var light := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1050,520),Color("c9c7bf") if light else Color("202b30"))
		var settings := CoreShootingSettings.new()
		var key: String=TRACER.prefix(weapon_id)
		settings.set(key+"_length",2.6);settings.set(key+"_width",.07)
		for row in 3:
			for phase in 3:
				var tracer=TRACER.new();tracer.configure(weapon_id,settings,12,Vector2.RIGHT)
				tracer.rows=PackedInt32Array([row,row,row]);tracer.age=0 if phase==0 else .05
				if phase==0: tracer.age=tracer.ignition*.8
				tracer.fading=phase==2;tracer.flight_distance=1000
				var data: Dictionary=tracer.geometry();var head := Vector2(310+phase*345,85+row*165)
				draw_texture_rect_region(data.texture,Rect2(data.destination.position+head,data.destination.size),data.source,Color(1,1,1,data.opacity))
				draw_line(head-Vector2(0,10),head+Vector2(0,10),Color("6d828a"),1)
				draw_string(ThemeDB.fallback_font,head+Vector2(-260,55),"%s %d.%d / enlarged"%[weapon_id,row+1,phase+1],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.BLACK if light else Color.WHITE)
				tracer.free()

func run() -> void:
	var character := "mannequin_v6"
	var capture := "--capture" in OS.get_cmdline_user_args()
	var app=preload("res://scripts/campaign/frontend.gd").new();app.load_user_settings=false
	app.test_settings_directory=OS.get_environment("TEMP").path_join("projectile-tracer-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app);app.selected_level="polygon";app.launch(false)
	await frames(12)
	var lab=app.game;var gun=lab.player.weapon
	var settings: CoreShootingSettings=gun.tuning
	settings.sound_enabled=false;settings.recoil_enabled=false;settings.magazine_enabled=false
	var world=lab.get_node("World")
	var wall := Wall.new();wall.position=Vector2(200,-2500)
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(12,120);shape.shape=box;wall.add_child(shape);world.add_child(wall)
	await frames(2)
	for id in IDS:
		var key: String=TRACER.prefix(id)
		check(lab.shooting_overlay.groups.has("Трассеры") and lab.shooting_overlay.rows.has(key+"_length"),id+" F2 controls exist")
		lab.shooting_overlay.rows[key+"_length"].slider.value=.81
		check(is_equal_approx(float(settings.get(key+"_length")),.81) and is_equal_approx(lab.shooting_overlay.rows[key+"_length"].number.value,.81),id+" slider and number synchronise")
		settings.set(key+"_enabled",false);settings.save_saved(app.test_settings_directory.path_join(id+".cfg"))
		var loaded := CoreShootingSettings.new();loaded.load_saved(app.test_settings_directory.path_join(id+".cfg"))
		var restored := CoreShootingSettings.new();restored.apply_values(JSON.parse_string(JSON.stringify(loaded.as_dictionary())))
		check(not restored.get(key+"_enabled") and is_equal_approx(float(restored.get(key+"_length")),.81),id+" disabled CFG and JSON preserve values")
		settings.set(key+"_enabled",true);settings.set(key+"_length",CoreShootingSettings.new().get(key+"_length"))
		var reached := {};var mixed := false
		for seed_value in 120:
			var tracer=TRACER.new();tracer.configure(id,settings,seed_value,Vector2.RIGHT)
			if tracer.rows[0]!=tracer.rows[1] or tracer.rows[1]!=tracer.rows[2]: mixed=true
			for phase in 3:
				tracer.age=0 if phase==0 else tracer.ignition+.001;tracer.fading=phase==2
				reached[str(tracer.frame())]=true
			tracer.free()
		check(reached.size()==9 and mixed,id+" all9 frames via independent per-stage choices")
		for row in 3:
			for phase in 3:
				var tracer=TRACER.new();tracer.configure(id,settings,12,Vector2.RIGHT)
				tracer.rows=PackedInt32Array([row,row,row]);tracer.age=tracer.ignition*.5 if phase==0 else tracer.ignition+.001;tracer.fading=phase==2;tracer.flight_distance=3
				var data: Dictionary=tracer.geometry()
				var frame: Vector2i=tracer.frame()
				for repeat in 3: tracer.geometry()
				check(not data.is_empty() and data.destination.position.x>=-3.001 and data.destination.end.x<=.001 and tracer.frame()==frame,id+" frame %d/%d stable and clipped to travelled segment"%[row,phase])
				tracer.free()
		# Same real swept ray, speed, wall and damage with rendering disabled/enabled.
		var reference_point := Vector2.INF
		var reference_ticks := 0
		for visible in [false,true]:
			settings.set(key+"_enabled",visible);impacts.clear();wall.hits=0;wall.damage=0
			var bullet := CoreProjectile.new();bullet.visual_weapon_id=id;bullet.tracer_seed=912
			bullet.direction=Vector2.RIGHT;bullet.speed=2400;bullet.damage=25;bullet.damage_settings=settings;bullet.impact_callback=impact;bullet.position=Vector2(0,-2500)
			world.add_child(bullet);bullet.add_to_group("core_projectiles")
			var ticks := 0
			var fading_visual: Node2D
			if visible: fading_visual=bullet.tracer
			while is_instance_valid(bullet) and ticks<10:
				await frames(1);ticks+=1
				if visible and ticks==1 and is_instance_valid(bullet) and bullet.distance_travelled>0:
					check(bullet.tracer.geometry().destination.end.x<=.001,id+" moving trace never passes bullet head")
			check(impacts.size()==1 and wall.hits==1 and wall.damage==25,id+" real wall hit applies damage once, visible="+str(visible))
			if not visible:
				reference_point=impacts[0].point;reference_ticks=ticks
			else:
				check(impacts[0].point.is_equal_approx(reference_point) and ticks==reference_ticks,id+" visual does not change collision point or flight time")
				check(is_instance_valid(fading_visual) and fading_visual.fading and fading_visual.stage()==2 and fading_visual.global_position.is_equal_approx(impacts[0].point),id+" impact detaches stationary third phase")
				var position: Vector2=fading_visual.global_position
				var fade_age: float=fading_visual.fade_age
				paused=true;await frames(3)
				check(fading_visual.global_position==position and fading_visual.fade_age==fade_age,id+" pause freezes stationary fade")
				paused=false
			await frames(12)
			check(get_nodes_in_group("core_tracer_residuals").is_empty(),id+" residual expires without repeated damage")
		settings.set(key+"_enabled",true)
		var expired := CoreProjectile.new();expired.visual_weapon_id=id;expired.damage_settings=settings;expired.life=.03;expired.speed=1000;expired.position=Vector2(0,-2700)
		world.add_child(expired)
		var expiry_visual: Node2D=expired.tracer
		for tick in 5:
			if not is_instance_valid(expired): break
			await frames(1)
		check(not is_instance_valid(expired) and is_instance_valid(expiry_visual) and expiry_visual.fading,id+" projectile lifetime ends with stationary visual fade")
		await frames(12)
		CATALOG.equip(gun,id);gun.aim_override=lab.player.global_position+Vector2(700,-50)
		await frames(3);gun._fire()
		var bullets := get_nodes_in_group("core_projectiles")
		check(bullets.size()==1 and bullets[0].visual_weapon_id==id and is_instance_valid(bullets[0].tracer),id+" actual shot uses own tracer sheet")
		var airborne=bullets[0]
		CATALOG.equip(gun,"mp40" if id!="mp40" else "stg44")
		check(airborne.visual_weapon_id==id and airborne.tracer.weapon_id==id,id+" gun switch preserves airborne source")
		paused=true;var bullet_point: Vector2=airborne.global_position;var flight_age: float=airborne.tracer.age
		await frames(3);check(airborne.global_position==bullet_point and airborne.tracer.age==flight_age,id+" pause freezes flight and animation");paused=false
		lab._clear_projectiles();await frames(2)
		check(get_nodes_in_group("core_projectiles").is_empty() and get_nodes_in_group("core_tracer_residuals").is_empty(),id+" reset clears all visual nodes")
		if capture:
			var folder := preload("res://tools/media_paths.gd").path("docs/core/tracers_20261105")
			if not folder.is_empty():
				var viewport := SubViewport.new();viewport.size=Vector2i(1050,520);viewport.world_2d=World2D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
				var preview := Preview.new();preview.weapon_id=id;viewport.add_child(preview)
				for light in [false,true]:
					preview.light=light;preview.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
					viewport.get_texture().get_image().save_png(folder.path_join(id+("_light.png" if light else "_dark.png")))
				viewport.queue_free()
			CATALOG.equip(gun,id)
			for label in ["right","left","up"]:
				gun.aim_override=lab.player.global_position+(Vector2(700,-50) if label=="right" else Vector2(-700,-50) if label=="left" else Vector2(500,-500))
				await frames(35);gun._fire();await frames(2)
				lab.process_mode=Node.PROCESS_MODE_DISABLED
				await frames(2);await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder.path_join(character+"_"+id+"_"+label+".png"))
				lab.process_mode=Node.PROCESS_MODE_INHERIT;lab._clear_projectiles();await frames(2)
	var holder := Node2D.new();world.add_child(holder)
	for index in 110:
		var residual=TRACER.new();residual.configure("stg44",settings,index,Vector2.RIGHT);holder.add_child(residual);residual.finish(Vector2(0,-2500),60,Vector2.RIGHT)
	var active := get_nodes_in_group("core_tracer_residuals").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	check(active.size()<=TRACER.MAX_RESIDUALS,"simultaneous impact burst respects visual budget")
	lab._clear_projectiles();await frames(2)
	check(get_nodes_in_group("core_tracer_residuals").is_empty(),"F8 cleanup removes fading traces immediately")
	holder.queue_free();wall.queue_free();app.queue_free();await frames(3)
	print("PROJECTILE TRACER ",character," ",checks-failures,"/",checks)
	quit(1 if failures else 0)

