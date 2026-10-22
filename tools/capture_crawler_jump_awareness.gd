extends SceneTree
const MEDIA = preload("res://tools/media_paths.gd")
func _initialize() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func capture() -> void:
	var lab: CoreMovementLab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	var zombie := lab.level.zombie
	var hero := lab.player
	zombie.tuning.apply_values({"hearing_enabled":false,"shove_enabled":false,"movement_enabled":false,"combat_enabled":false,"attack_recovery":.2})
	zombie.facing = 1
	hero.reset_to(zombie.home+Vector2(35,0))
	hero.set_invulnerable(true)
	hero.tuning.air_acceleration = 4000
	hero.weapon.aim_override = zombie.home-Vector2(0,17)
	await frames(5)
	for part in ["left_leg","right_leg"]:
		zombie.take_projectile_hit(50,part,Vector2.LEFT,hero.weapon.pivot())
	await frames(3)
	zombie.tuning.combat_enabled = true
	await frames(2)
	Input.action_press("core_jump")
	Input.action_press("core_left")
	await frames(3)
	zombie.contact_memory_left = 0
	zombie.contact_followup = false
	for i in 45:
		await frames(1)
		if hero.global_position.x-zombie.global_position.x <= -27: break
	Input.action_release("core_left")
	await frames(25)
	Input.action_release("core_jump")
	await frames(62)
	hero.set_invulnerable(false)
	var hit := false
	for i in 240:
		await frames(1)
		if zombie.attacks_landed > 0:
			hit = true
			break
	if not hit:
		push_error("No real melee strike after jumping over crawler")
		quit(1)
		return
	zombie.debug_zones = true
	hero.debug_shape = true
	zombie.queue_redraw()
	lab.camera_settings.apply_values({"zoom":2.5,"offset_x":0,"offset_y":-100,"look_ahead":0,"follow_speed":0,"limit_to_level":false})
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(MEDIA.path("docs/core/crawler_jump_awareness.png"))
	print("CAPTURE: melee after jump; HP ",hero.health," facing ",zombie.facing)
	lab.queue_free()
	await process_frame
	quit()
