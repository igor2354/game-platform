extends SceneTree
const FRONTEND = preload("res://scripts/campaign/frontend.gd")
const CATALOG = preload("res://scripts/campaign/catalog.gd")
const ART = preload("res://scripts/campaign/art.gd")
var checks := 0
var failures := 0
var app: Node

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

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await frames(1)

func run() -> void:
	app = FRONTEND.new()
	app.load_user_settings = false
	root.add_child(app)
	await frames(3)
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/frontend.tscn","application boots into the main menu")
	check(app.page == "main" and app.buttons.settings.disabled and app.buttons.quit.disabled,"only campaign and polygon are enabled on the main menu")
	await click(app.buttons.campaign)
	check(app.page == "characters","campaign button opens character selection")
	await click(app.buttons.sofia)
	check(app.selected_character == "sofia","Sofia is selectable through her actual button")
	await click(app.buttons.choose)
	check(app.page == "weapons","choose opens the weapon screen")
	await click(app.buttons.mp40)
	check(app.selected_weapon == "mp40","weapon card changes the selected loadout")
	app.buttons.back.pressed.emit()
	check(app.page == "characters" and app.selected_character == "sofia" and app.selected_weapon == "mp40","back preserves the character and weapon")
	app.buttons.harry.pressed.emit()
	app.buttons.choose.pressed.emit()
	for id in ["harry","sofia"]:
		for weapon in CATALOG.WEAPONS:
			app.selected_character = id
			app.selected_weapon = weapon.id
			app.launch(true)
			await frames(6)
			var lab: CoreMovementLab = app.game
			lab.player.weapon.tuning.sound_enabled = false
			lab.player.weapon.aim_override = lab.player.global_position+Vector2(300,-40)
			check(lab.campaign_mode and lab.level.prologue_mode and lab.player.is_on_floor() and lab.player.global_position.x > 12000,"prologue starts on its separate long platform: "+id+"/"+weapon.id)
			check(lab.player.character_id == id and not lab.player.body.sprite.visible and lab.player.body.near_arm.character_id == id,"selected character uses the new body and articulated sleeves: "+id)
			check(lab.player.weapon.equipped_weapon_id == weapon.id and lab.player.weapon.capacity() == int(weapon.values.magazine_capacity),"equipped model and magazine match the selected weapon: "+weapon.id)
			check(lab.player.weapon.tuning.fire_mode == weapon.values.fire_mode and lab.player.weapon.tuning.rounds_per_minute == weapon.values.rounds_per_minute and lab.player.weapon.reserve_ammo == weapon.values.starting_reserve,"selected fire mode, rate and reserve are functional: "+weapon.id)
			check(ART.weapon(CATALOG.index_for(weapon.id)).get_size().x > 100 and is_equal_approx(lab.player.weapon.muzzle_distance(),weapon.length*(1.0-weapon.grip)),"weapon image and muzzle geometry match the selected model: "+weapon.id)
			var before := lab.player.weapon.shots_fired
			lab.player.weapon._fire()
			await frames(1)
			check(lab.player.weapon.shots_fired == before+1,"chosen weapon actually fires: "+weapon.id)
			lab.player.weapon.magazine_ammo = 0
			check(lab.player.weapon.request_reload(),"chosen weapon accepts reload: "+weapon.id)
			lab.player.weapon.cancel_reload()
			lab.player.weapon.refill_ammunition()
			lab._recover()
			check(lab.player.global_position.is_equal_approx(lab.level.PROLOGUE_START) and lab.player.weapon.equipped_weapon_id == weapon.id,"F8 returns to prologue and retains the loadout")
			if weapon.id == "stg44":
				lab.developer_mode.toggle()
				check(lab.developer_mode.visible and lab.shooting_overlay.settings == lab.player.weapon.tuning,"same developer window and live settings are connected")
				lab.player.tuning.set_parameter("run_speed",410)
				lab._player_settings_changed()
				check(lab.player.tuning.run_speed == 410,"movement tuning applies in the prologue")
				lab.developer_mode.toggle()
				lab._teleport_zombie()
				check(lab.player.position.is_equal_approx(CoreMovementLevel.ZOMBIE_TEST_SPAWN),"developer test zones remain reachable")
				lab._respawn_enemies()
				lab._recover()
				lab.player.blast_ragdoll.start(Vector2(40,-30),.2,.12)
				await frames(3)
				check(lab.player.blast_ragdoll.active and lab.player.character_id == id,"selected character survives the physical-ragdoll path")
			await app.return_to_menu()
			await frames(3)
			check(app.page == "main" and app.game == null and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"return frees gameplay and restores interactive menu")
	app.buttons.polygon.pressed.emit()
	check(app.page == "characters" and app.selected_mode == "polygon" and app.game == null,"polygon now opens character selection before gameplay")
	app.buttons.harry.pressed.emit()
	app.buttons.choose.pressed.emit()
	app.buttons.stg44.pressed.emit()
	app.buttons.apply.pressed.emit()
	await frames(6)
	check(not app.game.campaign_mode and not app.game.level.prologue_mode and app.game.player.character_id == "harry" and app.game.player.weapon.equipped_weapon_id == "stg44","polygon equips the selected character and weapon on its original level")
	check(app.game.level.enemies.size() == 6 and app.game.level.floors.size() == 2,"polygon keeps all six enemies and original geometry")
	await app.return_to_menu()
	app.queue_free()
	await frames(4)
	print("CAMPAIGN FLOW: %d/%d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
