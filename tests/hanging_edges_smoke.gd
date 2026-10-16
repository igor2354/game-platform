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
	for frame in count:
		await physics_frame
		await process_frame
func fixture(point: Vector2,kind := 0) -> CoreHangingLoad:
	var item: CoreHangingLoad = load("res://scenes/core/hanging_load.tscn").instantiate()
	item.position = point
	item.contents = kind
	item.tuning = lab.ragdoll_settings
	lab.level.add_child(item)
	fixtures.append(item)
	return item
func dummy(point: Vector2) -> CoreEnemyDummy:
	var target := CoreEnemyDummy.new()
	target.position = point
	target.damage_tuning = lab.player.weapon.tuning
	lab.level.add_child(target)
	fixtures.append(target)
	return target
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	load("res://tests/hanging_legacy_fixtures.gd").install(lab)
	lab.ragdoll_settings.hanging_net_tear_enabled = false
	lab.level.enemies.erase(lab.level.hanging_target)
	lab.level.hanging_target.queue_free()
	lab.player.weapon.tuning.sound_enabled = false
	lab.player.reset_to(Vector2(160,760))
	await frames(8)
	var low := fixture(Vector2(-1250,390))
	var high := fixture(Vector2(-900,160))
	var low_target := dummy(Vector2(-1250,760))
	var high_target := dummy(Vector2(-900,760))
	await frames(12)
	low.release_load(lab.player)
	high.release_load(lab.player)
	await frames(90)
	check(low.impact_count > 0 and high.impact_count > 0,"both high and low suspended loads contact their actual target bodies")
	check(high.last_impact_speed > low.last_impact_speed*1.5 and high.last_damage > low.last_damage*2,"a greater actual fall height yields greater measured speed and damage")
	check(low_target.health > high_target.health,"real target HP reflects the difference in fall energy")
	var trap := lab.level.hanging_loads[0]
	var stable := true
	for attempt in 8:
		trap.release_load(lab.player)
		await frames(45)
		trap.reset_load()
		await frames(12)
		stable = stable and is_instance_valid(trap.joint) and trap.body.global_position.distance_to(trap.body.rest_transform.origin) < 3 and trap.body.linear_velocity.length() < 5
	check(stable,"eight complete fall/restore cycles never reuse a stale joint anchor or launch cargo sideways")
	trap.release_load(lab.player)
	await frames(5)
	lab.ragdoll_settings.hanging_enabled = false
	lab._ragdoll_settings_changed()
	trap.reset_load()
	await frames(12)
	check(not trap.released and trap.body.freeze and trap.body.global_position.distance_to(trap.body.rest_transform.origin) < .01,"restoring while disabled holds the new home pose rather than the previous fallen pose")
	lab.ragdoll_settings.hanging_enabled = true
	lab._ragdoll_settings_changed()
	await frames(12)
	check(is_instance_valid(trap.joint) and not trap.released and trap.body.global_position.distance_to(trap.body.rest_transform.origin) < 3,"reenabling a restored trap rebuilds the committed home suspension")
	trap.release_load(lab.player)
	await frames(3)
	var enemy := dummy(Vector2(-4600,760))
	enemy.set_invulnerable(true)
	var contact := {"speed":600.0,"direction":Vector2.DOWN,"point":enemy.position}
	trap.hit_body(enemy,contact)
	var hits := enemy.received_hits
	trap.hit_body(enemy,contact)
	check(enemy.health == 100 and enemy.received_hits == hits and hits == 1,"enemy immortality and per-target contact cooldown prevent duplicate manifold damage")
	check(enemy.is_knocked_down(),"enemy immortality does not erase the physical knockdown")
	var before := trap.impact_count
	trap.hit_body(enemy,{"speed":20.0,"direction":Vector2.DOWN})
	check(trap.impact_count == before,"slow contacts do not create damage events")
	lab.ragdoll_settings.hanging_max_damage = 40
	check(trap.damage_for_speed(2000) == 40,"impact damage is capped even for extreme speed or mass")
	lab.ragdoll_settings.hanging_max_damage = 500
	# A wall shields the support because it uses the same swept bullet query.
	var wall := StaticBody2D.new()
	wall.position = Vector2(-1350,500)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12,480)
	collider.shape = shape
	wall.add_child(collider)
	lab.level.add_child(wall)
	fixtures.append(wall)
	low.reset_load()
	await frames(10)
	var bullet := CoreProjectile.new()
	bullet.damage = 100
	bullet.damage_settings = lab.player.weapon.tuning
	bullet.instigator = lab.player
	bullet.shooter = lab.player.get_rid()
	bullet.direction = Vector2.RIGHT
	bullet.position = Vector2(-1450,low.rope.global_position.y)
	lab.level.add_child(bullet)
	await frames(12)
	check(not low.released and low.rope.hits == 0,"a solid wall blocks a fast bullet before it can cut the cable")
	var settled := fixture(Vector2(-2450,310))
	await frames(8)
	settled.release_load()
	await frames(180)
	lab.player.reset_to(Vector2(-2670,760))
	Input.action_press("core_right")
	await frames(60)
	Input.action_release("core_right")
	check(absf(lab.player.position.x-settled.body.global_position.x) < 110 and lab.player.health == 100 and settled.impact_count == 0,"running into an already resting load does not turn player movement into falling-object damage (HP %s hits %s distance %s)" % [lab.player.health,settled.impact_count,absf(lab.player.position.x-settled.body.global_position.x)])
	for node in fixtures:
		if is_instance_valid(node): node.queue_free()
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
