extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func f1() -> void:
	var event := InputEventAction.new()
	event.action = "core_debug"
	event.pressed = true
	root.push_input(event,true)
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.reset_to(Vector2(4800,760))
	lab.player.set_invulnerable(true)
	var enemy := CoreEnemyDummy.new()
	enemy.identifier = "TRACE"
	enemy.position = Vector2(5100,760)
	enemy.set_invulnerable(true)
	lab.level.add_child(enemy)
	await frames(5)
	var debug = lab.explosion_debug
	check(not debug.visible and not lab.explosion_telemetry.visible,"blast measurements start hidden with F1 off")
	var profile := CoreExplosionSettings.new()
	profile.apply_values({"explosion_radius":240,"explosion_shockwave_radius":380,"explosion_audio_enabled":false,"explosion_camera_enabled":false,"explosion_ragdoll_enabled":false,"explosion_sever_enabled":false,"explosion_character_push":0,"explosion_shockwave_push":0,"explosion_stun_duration":0})
	var blast := CoreExplosion.spawn(lab.level,Vector2(5000,728),profile)
	check(debug.report.radius == 240 and debug.report.wave == 380 and debug.report.origin == Vector2(5000,728),"the snapshot records the actual blast and shockwave radii")
	var player_targets: Array = debug.report.targets.filter(func(target): return target.player)
	var enemy_targets: Array = debug.report.targets.filter(func(target): return target.label == "Враг TRACE")
	check(player_targets.size() == 1 and is_equal_approx(player_targets[0].distance,186) and player_targets[0].point == Vector2(4814,728),"player distance uses the same nearest collision-surface sample as damage")
	check(enemy_targets.size() == 1 and is_equal_approx(enemy_targets[0].distance,84),"enemy distance matches its collision surface and is counted once")
	var saved_distance: float = player_targets[0].distance
	lab.player.reset_to(Vector2(4700,760))
	await frames(90)
	check(not is_instance_valid(blast) and debug.report.targets.filter(func(target): return target.player)[0].distance == saved_distance,"measurements survive the effect and do not follow movement after the explosion")
	f1()
	await frames(2)
	check(debug.visible and lab.explosion_telemetry.visible and lab.explosion_telemetry.text.contains("186.0 px") and lab.explosion_telemetry.text.contains("84.0 px"),"F1 shows the saved distances and HUD telemetry even when enabled after the blast")
	lab.developer_mode.set_enabled(true)
	lab.developer_mode.set_enabled(false)
	await frames(2)
	check(debug.visible and lab.explosion_telemetry.visible,"closing the developer window preserves the F1 measurements")
	paused = true
	f1()
	await frames(2)
	check(not debug.visible and not lab.explosion_telemetry.visible and not debug.report.is_empty(),"F1 hides the overlay on pause without deleting its snapshot")
	f1()
	await frames(2)
	check(debug.visible and lab.explosion_telemetry.visible,"F1 can restore blast telemetry while paused")
	paused = false
	var wall := StaticBody2D.new()
	wall.position = Vector2(5050,700)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,120)
	collider.shape = shape
	wall.add_child(collider)
	lab.level.add_child(wall)
	await frames(2)
	blast = CoreExplosion.spawn(lab.level,Vector2(5000,728),profile)
	enemy_targets = debug.report.targets.filter(func(target): return target.label == "Враг TRACE")
	check(enemy_targets.size() == 1 and enemy_targets[0].covered and not blast.affected.has(enemy.get_instance_id()) and debug.target_text(enemy_targets[0]).contains("укрытие"),"covered targets retain a measured distance and are marked as shielded")
	CoreExplosion.spawn(lab.level,Vector2(7000,700),profile)
	player_targets = debug.report.targets.filter(func(target): return target.player)
	check(player_targets.size() == 1 and player_targets[0].outside and player_targets[0].distance > 1000 and debug.summary().contains("вне зоны"),"the player's distance is also available outside the explosion's influence")
	var grenade: CoreGrenade = load("res://scenes/core/grenade.tscn").instantiate()
	grenade.tuning = lab.ragdoll_settings
	grenade.tuning.apply_values({"explosion_audio_enabled":false,"grenade_blast_radius":330,"grenade_shockwave_radius":440})
	lab.level.add_child(grenade)
	grenade.global_position = Vector2(7000,700)
	grenade.explode()
	check(debug.report.radius == 330 and debug.report.wave == 440,"grenades report their own configured explosion and shockwave radii")
	lab._recover()
	await frames(2)
	check(debug.report.is_empty() and lab.explosion_telemetry.text.contains("данных пока нет"),"F8 clears stale blast distances and geometry")
	wall.queue_free()
	enemy.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
