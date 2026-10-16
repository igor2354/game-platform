extends SceneTree
var lab: CoreMovementLab
var hero: CoreMovementPlayer
var zombie: CoreZombie
var overlay: CoreMovementOverlay
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
	for i in count:
		await physics_frame
		await process_frame
func switch(key: String,enabled: bool) -> void:
	(overlay.zombie_toggles[key] as CheckButton).button_pressed = enabled
func reset_case(offset := -200.0,prone := false) -> void:
	zombie.tuning.apply_values(overlay.defaults.as_dictionary())
	overlay._sync()
	zombie.reset_target()
	if prone: zombie.take_projectile_hit(50,"left_leg")
	hero.reset_to(zombie.home+Vector2(offset,0))
func run() -> void:
	lab = load("res://scenes/main.tscn").instantiate()
	lab.load_user_settings = false
	root.add_child(lab)
	hero = lab.player
	zombie = lab.level.zombie
	overlay = lab.zombie_overlay
	hero.set_physics_process(false)
	await frames(8)
	check(overlay.zombie_toggles.size() == 8 and zombie.tuning.as_dictionary().size() == 38,"F6 exposes eight switches with all zombie values")
	for entry in CoreZombieSettings.SWITCHES:
		var button := overlay.zombie_toggles[entry[0]] as CheckButton
		check(button.button_pressed and button.get_parent().get_parent().name == entry[2],"enabled switch belongs to its tab: "+entry[2])
	reset_case()
	await frames(4)
	check(zombie.state == CoreZombie.State.CHASE,"vision first establishes a pursuit")
	switch("vision_enabled",false)
	check(not zombie.sees_player(1000) and zombie.state != CoreZombie.State.CHASE,"disabling vision immediately ends visual awareness and its memory")
	check(zombie.hear_noise(hero.global_position-Vector2(0,32),1,"shot"),"hearing still works with vision disabled")
	await frames(5)
	check(zombie.state == CoreZombie.State.INVESTIGATE and zombie.velocity.x < 0,"hearing alone drives a search")
	switch("hearing_enabled",false)
	check(zombie.noise_memory_left == 0 and zombie.state != CoreZombie.State.INVESTIGATE and not zombie.hear_noise(hero.global_position,10,"shot"),"disabling hearing cancels search memory and rejects fresh noise")
	zombie.take_projectile_hit(1,"torso",Vector2.LEFT,hero.global_position)
	check(zombie.damage_pursuit and zombie.state == CoreZombie.State.CHASE,"damage reaction works with both senses disabled")
	switch("damage_reaction_enabled",false)
	check(not zombie.damage_pursuit and zombie.state != CoreZombie.State.CHASE,"damage switch cancels its own source pursuit")
	reset_case()
	switch("movement_enabled",false)
	await frames(6)
	var anchor := zombie.global_position
	await frames(12)
	check(zombie.state == CoreZombie.State.CHASE and zombie.velocity.x == 0 and zombie.global_position.distance_to(anchor) < .3,"disabled movement leaves visual detection active but stops pursuit")
	switch("movement_enabled",true)
	await frames(6)
	check(zombie.global_position.x < anchor.x-5,"re-enabling movement resumes the remembered pursuit")
	reset_case(-45)
	switch("movement_enabled",false)
	await frames(4)
	check(zombie.state == CoreZombie.State.WINDUP,"combat can start while independent movement is disabled")
	switch("combat_enabled",false)
	await frames(35)
	check(zombie.state != CoreZombie.State.WINDUP and zombie.attacks_landed == 0 and hero.health == 100,"combat switch cancels a committed strike without damage")
	switch("combat_enabled",true)
	await frames(30)
	check(zombie.attacks_landed == 1 and hero.health == 85,"re-enabling combat permits a fresh attack")
	reset_case(-45)
	switch("vision_enabled",false)
	switch("hearing_enabled",false)
	switch("movement_enabled",false)
	zombie.take_projectile_hit(1,"torso",Vector2.LEFT,hero.global_position)
	await frames(30)
	check(zombie.attacks_landed == 1 and hero.health == 85,"damage awareness permits isolated combat without sight or hearing")
	reset_case(-45)
	switch("vision_enabled",false)
	switch("damage_reaction_enabled",false)
	switch("movement_enabled",false)
	zombie.hear_noise(hero.global_position-Vector2(0,32),1,"shot")
	await frames(30)
	check(zombie.attacks_landed == 1 and hero.health == 85,"heard presence permits combat without sight or damage reaction")
	reset_case(-200,true)
	switch("crawl_enabled",false)
	await frames(8)
	anchor = zombie.global_position
	await frames(10)
	check(zombie.is_prone() and zombie.state == CoreZombie.State.CHASE and zombie.global_position.distance_to(anchor) < .3,"disabled crawling preserves prone anatomy and awareness but stops travel")
	switch("crawl_enabled",true)
	await frames(8)
	check(zombie.global_position.x < anchor.x-2,"re-enabling crawl resumes the prone pursuit")
	switch("movement_enabled",false)
	anchor = zombie.global_position
	await frames(8)
	check(zombie.global_position.distance_to(anchor) < .3,"movement master also stops voluntary crawling")
	# Real body support tests cancellation of an already pending shove.
	reset_case(80,true)
	switch("movement_enabled",false)
	switch("combat_enabled",false)
	hero.set_physics_process(true)
	hero.reset_to(zombie.home-Vector2(0,80))
	var supported := false
	for i in 90:
		await frames(1)
		if zombie._player_on_top() and zombie.shove_left > 0:
			supported = true
			break
	check(supported,"shove remains independent of normal combat and voluntary movement")
	switch("shove_enabled",false)
	await frames(40)
	check(zombie.shove_left == 0 and zombie.shoves_landed == 0 and hero.health == 100 and zombie._player_on_top(),"shove switch cancels the pending push and leaves the supported player unharmed")
	switch("shove_enabled",true)
	await frames(35)
	check(zombie.shoves_landed == 1 and hero.health == 90,"re-enabling shove starts a new warning and permits the push")
	hero.set_physics_process(false)
	reset_case()
	paused = true
	anchor = zombie.global_position
	for entry in CoreZombieSettings.SWITCHES:
		switch(entry[0],false)
	await frames(3)
	check(zombie.global_position == anchor,"all switches remain editable on pause without moving the enemy")
	var path := "/private/tmp/zombie-switches-%d.cfg" % OS.get_process_id()
	var loaded := CoreZombieSettings.new()
	var saved := zombie.tuning.save_saved(path) == OK and loaded.load_saved(path) == OK
	for entry in CoreZombieSettings.SWITCHES: saved = saved and not loaded.get(entry[0])
	check(saved,"all eight disabled switches persist in the zombie profile")
	overlay.settings_path = path
	overlay.reset_button.pressed.emit()
	var enabled := true
	for entry in CoreZombieSettings.SWITCHES: enabled = enabled and zombie.tuning.get(entry[0]) and overlay.zombie_toggles[entry[0]].button_pressed
	check(enabled,"Reset restores enabled defaults in all tabs")
	overlay.load_button.pressed.emit()
	var disabled := true
	for entry in CoreZombieSettings.SWITCHES: disabled = disabled and not zombie.tuning.get(entry[0]) and not overlay.zombie_toggles[entry[0]].button_pressed
	check(disabled,"Load refreshes all eight switches together")
	var hp := zombie.health
	zombie.take_projectile_hit(50,"left_leg",Vector2.LEFT,hero.global_position)
	check(zombie.health < hp and not zombie.has_part("left_leg") and not zombie.damage_pursuit,"disabled modules do not block damage or anatomical limb loss")
	var legacy := ConfigFile.new()
	legacy.set_value("zombie","damage_reaction_enabled",false)
	legacy.save(path)
	loaded = CoreZombieSettings.new()
	loaded.load_saved(path)
	enabled = not loaded.damage_reaction_enabled
	for entry in CoreZombieSettings.SWITCHES:
		if entry[0] != "damage_reaction_enabled": enabled = enabled and loaded.get(entry[0])
	check(enabled,"legacy profiles preserve their reaction switch and enable the new modules")
	DirAccess.remove_absolute(path)
	paused = false
	lab.queue_free()
	await process_frame
	print("RESULT: %d/%d checks passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
