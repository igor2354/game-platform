extends SceneTree
const IMPACT = preload("res://scripts/core/enemy_impact.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func frames(n: int) -> void:
	for i in n: await physics_frame; await process_frame

class Preview extends Node2D:
	var effect: Dictionary
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for row in 2:
			for column in 4:
				var origin := Vector2(70+column*260,100+row*230)
				draw_rect(Rect2(origin-Vector2(60,75),Vector2(255,225)),Color("d3c9b6") if row else Color("242c2a"))
				var sample := effect.duplicate(true)
				sample.point = Vector2.ZERO
				sample.life = sample.duration-[0.0,.04,.09,.15][column]
				for polygon in IMPACT.polygons(sample):
					var points := PackedVector2Array()
					for p in polygon.points: points.append(origin+p*3)
					draw_colored_polygon(points,polygon.color)
				draw_string(font,origin+Vector2(-30,135),"%d ms / x3"%[int([0,.04,.09,.15][column]*1000)],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.BLACK if row else Color.WHITE)

func run() -> void:
	var app = preload("res://scripts/campaign/frontend.gd").new()
	app.load_user_settings = false
	app.test_settings_directory = OS.get_environment("TEMP").path_join("enemy-impact-%d"%OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(app.test_settings_directory)
	root.add_child(app); app.selected_level="polygon"; app.launch(false)
	await frames(12)
	var lab = app.game
	var gun = lab.player.weapon
	gun.tuning.sound_enabled=false
	gun.tuning.recoil_enabled=false
	var settings: CoreShootingSettings = gun.tuning
	check(lab.shooting_overlay.groups.has("Импакт") and lab.shooting_overlay.rows.has("enemy_impact_count"),"F2 impact controls exist")
	lab.shooting_overlay.rows.enemy_impact_count.slider.value=31
	check(settings.enemy_impact_count==31 and lab.shooting_overlay.rows.enemy_impact_count.number.value==31,"slider and numeric input control real settings")
	settings.enemy_impact_count=26
	settings.enemy_impact_reach=1.35
	settings.enemy_impact_enabled=false
	settings.save_saved(app.test_settings_directory.path_join("roundtrip.cfg"))
	var restored := CoreShootingSettings.new()
	restored.load_saved(app.test_settings_directory.path_join("roundtrip.cfg"))
	check(not restored.enemy_impact_enabled and is_equal_approx(restored.enemy_impact_reach,1.35),"CFG switch and parameters survive disabled")
	var imported := CoreShootingSettings.new()
	imported.apply_values(JSON.parse_string(JSON.stringify(restored.as_dictionary())))
	check(not imported.enemy_impact_enabled and is_equal_approx(imported.enemy_impact_reach,1.35),"JSON values roundtrip")
	settings.enemy_impact_reach=1
	gun.effects.clear();gun._on_impact(Vector2(500,300),true,false,Vector2.RIGHT)
	check(gun.effects.is_empty(),"disabled effect emits nothing")
	settings.enemy_impact_enabled=true
	gun.effects.clear()
	var enemy = lab.level.enemies[0]
	var health: float = enemy.health
	CoreProjectile.resolve_impact({"collider":enemy,"position":enemy.aim_point_for_part("torso")},25,Vector2.RIGHT,gun._on_impact,Vector2.ZERO)
	check(enemy.health<health and gun.effects.size()==1 and gun.effects[0].kind=="enemy_impact","real impact resolution applies damage and creates blood")
	var first: Dictionary = gun.effects[0].duplicate(true)
	check(first.drops.size()==26 and is_equal_approx(first.duration,.15),"default count and duration")
	var forward := 0
	for drop in first.drops:
		if drop.velocity.x>0: forward+=1
	check(forward>first.drops.size()*.65,"main spray follows bullet")
	var shot_rng: int = gun.rng.state
	var recoil_rng: int = gun.recoil_rng.state
	gun._on_impact(Vector2(500,300),true,true,Vector2.LEFT)
	check(gun.rng.state==shot_rng and gun.recoil_rng.state==recoil_rng,"cosmetics do not consume ballistic or recoil RNG")
	check(gun.effects[-1].duration==first.duration and gun.effects[-1].drops.size()==first.drops.size(),"kill does not enlarge burst")
	check(gun.effects[-1].drops[1].velocity.x<0,"left shot mirrors spray")
	gun.effects.clear();gun._on_impact(Vector2(500,300),false,false)
	check(gun.effects.is_empty(),"surface impact emits no yellow marker")
	gun.effects.clear()
	for i in 100: gun._on_impact(Vector2(500,300),true,false)
	check(gun.effects.size()==IMPACT.MAX_BURSTS,"bounded bursts during repeated impacts")
	var anchored: Vector2 = gun.effects[0].point
	lab.player.position.x+=100
	check(gun.effects[0].point==anchored,"world anchor independent of shooter movement")
	var frozen: float = gun.effects[0].life
	paused=true; await frames(3)
	check(gun.effects[0].life==frozen,"pause freezes droplets")
	paused=false;await frames(15)
	check(gun.effects.is_empty(),"expired droplets removed")
	for t in [0.0,.04,.09,.15]:
		var sample := first.duplicate(true);sample.life=sample.duration-t
		var polygons: Array = IMPACT.polygons(sample)
		check(polygons.is_empty() if t>=.15 else not polygons.is_empty(),"geometry at %.2f seconds"%t)
	gun._on_impact(Vector2(500,300),true,false);gun.reset_state()
	check(gun.effects.is_empty(),"reset clears blood")
	if "--capture" in OS.get_cmdline_user_args():
		var folder := preload("res://tools/media_paths.gd").path("docs/core/no_yellow_markers_20261103" if "--no-markers" in OS.get_cmdline_user_args() else "docs/core/enemy_impact_20261102")
		enemy.reset_target()
		lab.player.reset_to(enemy.global_position-Vector2(220,0))
		await frames(50)
		if "--no-markers" in OS.get_cmdline_user_args():
			gun.tuning.aim_beam_enabled=false
			gun.aim_override=enemy.aim_point_for_part("torso")
			await frames(3)
			gun._on_impact(enemy.global_position+Vector2(80,-40),false,false)
			await frames(1);await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder.path_join("surface_no_marker.png"))
		gun._on_impact(enemy.aim_point_for_part("torso"),true,false,Vector2.RIGHT)
		gun.effects[-1].life=.11
		lab.process_mode=Node.PROCESS_MODE_DISABLED
		await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("gameplay.png"))
		var viewport := SubViewport.new()
		viewport.size=Vector2i(1100,500)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.world_2d=World2D.new()
		root.add_child(viewport)
		var preview := Preview.new();preview.effect=first;viewport.add_child(preview)
		await frames(2);await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder.path_join("phases.png"))
		viewport.queue_free()
	app.queue_free();await frames(3)
	print("ENEMY IMPACT ",checks-failures,"/",checks)
	quit(1 if failures else 0)

