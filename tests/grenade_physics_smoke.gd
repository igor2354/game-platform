extends SceneTree
var lab: CoreMovementLab
var checks := 0
var failures := 0
var fixtures: Array[Node] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if ok: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame
func grenade(point: Vector2,velocity: Vector2) -> CoreGrenade:
	var body: CoreGrenade = load("res://scenes/core/grenade.tscn").instantiate()
	body.tuning = lab.ragdoll_settings
	body.instigator = lab.player
	lab.level.add_child(body)
	body.start_fuse()
	body.launch(point,velocity)
	fixtures.append(body)
	return body
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	lab.player.weapon.tuning.sound_enabled = false
	lab.ragdoll_settings.apply_values({"explosion_audio_enabled":false,"grenade_fuse":12.0,"explosion_ragdoll_enabled":false})
	await frames(10)
	var controller := lab.player.grenades
	var profile := lab.ragdoll_settings
	var point := Vector2(2700,140)
	var speed := Vector2(620,-130)
	var path := controller.predict_path(point,speed,.5)
	var body := grenade(point,speed)
	var error := 0.0
	for index in 20:
		await frames(1)
		error = maxf(error,body.position.distance_to(path[mini(index,path.size()-1)]))
	check(error < 3,"free flight follows the displayed ballistic samples (max error %.3f px)" % error)
	body.queue_free()
	var soft := grenade(Vector2(2300,500),Vector2.ZERO)
	soft.physics_material_override.bounce = 0
	var springy := grenade(Vector2(2350,500),Vector2.ZERO)
	springy.physics_material_override.bounce = .85
	var soft_after := 760.0
	var springy_after := 760.0
	var touched := false
	for index in 110:
		await frames(1)
		if springy.bounces > 0: touched = true
		if touched:
			soft_after = minf(soft_after,soft.position.y)
			springy_after = minf(springy_after,springy.position.y)
	check(touched and springy_after < soft_after-80,"bounce coefficient changes the actual rebound height (soft %.1f / springy %.1f)" % [soft_after,springy_after])
	var enemy := CoreEnemyDummy.new()
	enemy.position = Vector2(-1210,760)
	lab.level.add_child(enemy)
	fixtures.append(enemy)
	var missile := grenade(Vector2(-1390,726),Vector2(1100,0))
	await frames(18)
	check(enemy.health < 100 and is_instance_valid(missile) and not missile.detonated,"a fast physical grenade hit damages an enemy before detonation (HP %.1f)" % enemy.health)
	var last_hp := enemy.health
	await frames(10)
	check(enemy.health == last_hp,"resting and repeated contact do not drain HP every frame")
	profile.grenade_impact_enabled = false
	var protected := CoreEnemyDummy.new()
	protected.position = Vector2(-960,760)
	lab.level.add_child(protected)
	fixtures.append(protected)
	grenade(Vector2(-1140,726),Vector2(1100,0))
	await frames(18)
	check(protected.health == 100,"direct-impact damage has an independent working switch")
	profile.grenade_impact_enabled = true
	var wall := StaticBody2D.new()
	wall.position = Vector2(2030,540)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20,400)
	collider.shape = rectangle
	wall.add_child(collider)
	lab.level.add_child(wall)
	fixtures.append(wall)
	path = controller.predict_path(Vector2(1900,450),Vector2(600,-100),2)
	check(controller.trajectory_hit and path[-1].x < 2020 and path[-1].x > 2010,"preview uses the grenade radius and stops at the first real wall contact")
	var bouncing := grenade(Vector2(1900,450),Vector2(600,-100))
	await frames(25)
	check(bouncing.position.x < 2020 and bouncing.linear_velocity.x < 0,"the actual grenade rebounds from the wall indicated by the preview")
	profile.grenades_enabled = false
	lab._ragdoll_settings_changed()
	var pose := bouncing.global_transform
	var fuse := bouncing.fuse_left
	await frames(20)
	check(bouncing.global_transform.is_equal_approx(pose) and bouncing.fuse_left == fuse,"disabling grenades pauses flying bodies and their fuse")
	profile.grenades_enabled = true
	lab._ragdoll_settings_changed()
	await frames(5)
	check(bouncing.global_position.distance_to(pose.origin) > 1 and bouncing.fuse_left < fuse,"reenabling resumes the existing throw and countdown")
	for fixture in fixtures:
		if is_instance_valid(fixture): fixture.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
