extends Node3D
var stage: Node3D
var gun: Node3D
var pivot: Node3D
var barrel: MeshInstance3D
var overlay: CoreMovementOverlay
var readout: Label
var targets: Array[Node3D] = []
var trigger_was_down := true
var aim_direction := Vector3.RIGHT
var aim_facing := 1.0
var mount_side := 1.0
var weapon_roll := 0.0
var stance_ads := 0.0
var stance_calm := 0.0
var alert_left := 0.0
var mount_player_position := Vector3.ZERO
var effects: Node3D
var reticle: Node2D
var cursor_projection := Transform2D.IDENTITY
var projection_ready := false
var cursor_active := false
var cursor_screen := Vector2.INF
var reload_facing := 1.0
var reload_start := Vector3.RIGHT
var weapon_parts: Node
var length := .85
var enemies: Array[Node3D] = []
var zombie_settings: CoreZombieSettings
var zombie_overlay: CoreMovementOverlay
var svt_model: Node3D
var pistol_model: Node3D
var pistol_animator: AnimationPlayer
var loadout: Node
var mp40_model: Node3D
var stg_parts: Node
var mp40_parts: Node
var stg_model: Node3D
var rear_grip := Vector3.ZERO
var front_grip := Vector3.ZERO
var muzzle := Vector3.ZERO
var reload_support := Vector3.ZERO
var reload_stance_ads := 0.0
var was_reloading := false
func _ready() -> void:
	stage = get_parent()
	gun = preload("res://scripts/core/shooting_3d.gd").new()
	stage.player.contact_hit.connect(func(enemy,damage,killed,direction):
		gun.hit_registered.emit(enemy,enemy.global_position+Vector3.UP*.12,damage)
		if damage>0:
			gun.audio.impact(killed)
			gun.impact_resolved.emit({"collider":enemy,"position":enemy.global_position+Vector3.UP*.12,"normal":-direction},direction,damage,true,killed)
		if killed: gun.target_killed.emit(direction))
	gun.shooter = stage.player
	gun.input_driven = true
	process_physics_priority = -10
	gun.process_physics_priority = -20
	var finisher := FireFinish.new()
	finisher.combat = self
	finisher.process_physics_priority = 20
	add_child(finisher)
	add_child(gun)
	if stage.load_user_settings: gun.tuning.load_saved(stage.shooting_settings_path)
	pivot = Node3D.new()
	add_child(pivot)
	barrel = MeshInstance3D.new()
	pivot.add_child(barrel)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("454d53")
	barrel.material_override = material
	stg_model = preload("res://resources/core/weapons_3d/STG44.glb").instantiate()
	stg_model.name = "STG44Model"
	pivot.add_child(stg_model)
	weapon_parts = preload("res://scripts/core/stg_3d_parts.gd").new()
	add_child(weapon_parts)
	weapon_parts.prepare(stg_model)
	stg_parts = weapon_parts
	mp40_model = preload("res://resources/core/weapons_3d/MP40.glb").instantiate()
	mp40_model.name = "MP40Model"
	pivot.add_child(mp40_model)
	mp40_model.scale = Vector3.ONE*(.833/4.622487)
	mp40_model.rotation.y = PI/2
	mp40_model.position = Vector3(.16,.010,0)
	mp40_parts = preload("res://scripts/core/stg_3d_parts.gd").new()
	add_child(mp40_parts)
	mp40_parts.prepare_named(mp40_model,"magazine")
	pistol_model = preload("res://resources/core/weapons_3d/M1911.glb").instantiate()
	pivot.add_child(pistol_model)
	preload("res://scripts/core/pistol_mesh_3d.gd").remove_embedded_round(pistol_model)
	svt_model = preload("res://resources/core/weapons_3d/SVT40.glb").instantiate()
	pivot.add_child(svt_model)
	svt_model.basis = Basis(Vector3.FORWARD,Vector3.UP,Vector3.RIGHT)*(1.226/1.196132)
	svt_model.position = Vector3(.30,-.18,0)
	pistol_model.scale = Vector3.ONE*(.218/23.95461)
	pistol_model.rotation.y = PI
	pistol_model.position = Vector3(.045,0,0)
	for a in pistol_model.find_children("*","AnimationPlayer",true,false): pistol_animator=a
	if pistol_animator:
		pistol_animator.get_animation("Fire").loop_mode=Animation.LOOP_NONE
		pistol_animator.stop()
	gun.magazine_dropped.connect(func():
		if gun.weapon_id in ["stg44","mp40"]: weapon_parts.drop(stage)
		else: weapon_parts.drop_proxy(stage))
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	readout = Label.new()
	readout.position = Vector2(24,175)
	layer.add_child(readout)
	reticle = preload("res://scripts/core/shooting_3d_reticle.gd").new()
	reticle.combat = self
	layer.add_child(reticle)
	overlay = CoreMovementOverlay.new()
	overlay.hosted = true
	overlay.settings = gun.tuning
	overlay.defaults = gun.tuning.duplicate(true)
	overlay.params = CoreShootingSettings.PARAMS
	overlay.groups = ["Оружие","От бедра","Прицел","Отдача","Звук","Урон","Магазин","Разброс в движении","Импакт","Вспышка","Трассеры"]
	overlay.heading_text = "ОРУЖИЕ 3D · F4"
	overlay.settings_path = stage.shooting_settings_path
	layer.add_child(overlay)
	for x in [2460,2690,2920]:
		var target = preload("res://scripts/core/target_3d.gd").new()
		target.position = stage.geometry.point(Vector2(x,760))
		stage.add_child(target)
		targets.append(target)
	zombie_settings = preload("res://resources/core/zombie.tres").duplicate(true)
	if stage.load_user_settings: zombie_settings.load_saved(stage.zombie_settings_path)
	zombie_overlay = CoreMovementOverlay.new()
	zombie_overlay.hosted = true
	zombie_overlay.settings = zombie_settings
	zombie_overlay.defaults = preload("res://resources/core/zombie.tres").duplicate(true)
	zombie_overlay.params = CoreZombieSettings.PARAMS
	zombie_overlay.groups = ["Зрение","Слух","Движение","Бой","Ползание","Сбрасывание","Попадания","Ошеломление","Освещение"]
	zombie_overlay.settings_path = stage.zombie_settings_path
	zombie_overlay.heading_text = "ВРАГИ 3D · F6"
	layer.add_child(zombie_overlay)
	for x in [5400,-5820,6660]:
		var enemy = preload("res://scripts/core/zombie_3d.gd").new()
		enemy.tuning = zombie_settings
		enemy.target = stage.player
		enemy.position = stage.geometry.point(Vector2(x,760))
		add_child(enemy)
		enemies.append(enemy)
	effects = preload("res://scripts/core/shooting_3d_effects.gd").new()
	add_child(effects)
	gun.recoil.shift_callback = shift_recoil
	gun.target_killed.connect(func(direction):
		if gun.tuning.recoil_enabled: stage.weapon_camera_impulse(direction,gun.tuning.camera_kick*gun.tuning.kill_camera_boost,gun.tuning.camera_shake*gun.tuning.kill_camera_boost))
	gun.shot_fired.connect(show_shot)
	equip("stg44")
	loadout = preload("res://scripts/core/weapon_loadout.gd").new()
	add_child(loadout)
	configure_loadout("stg44")
func reset_test_world() -> void:
	stg_parts.clear()
	mp40_parts.clear()
	gun.cancel_reload()
	gun.projectiles.clear()
	gun.effects_reset.emit()
	for target in targets+enemies: target.reset()

func configure_loadout(id: String) -> void:
	equip(id)
	loadout.configure(gun,func(next): equip(next,true),id,func(): return stage.paused or (is_instance_valid(stage.developer) and stage.developer.developer_mode.enabled) or (is_instance_valid(stage.game_hud) and stage.game_hud.editing) or stage.player.health<=0 or (stage.player.grenades and stage.player.grenades.busy()))
func equip(id: String,preserve_projectiles := false) -> void:
	gun.equip(id,preserve_projectiles)
	weapon_parts = mp40_parts if id=="mp40" else stg_parts
	weapon_parts.prepare_proxy(id,pivot)
	var catalog = preload("res://scripts/campaign/catalog.gd")
	var data: Dictionary = catalog.WEAPONS[catalog.index_for(id)]
	length = float(data.length)*2.85/stage.geometry.U
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length,.08,.065)
	barrel.mesh = mesh
	barrel.position.x = length*.4
	barrel.visible = false
	svt_model.visible = id=="svt"
	pistol_model.visible = id=="m1911"
	pistol_model.process_mode = Node.PROCESS_MODE_INHERIT if id=="m1911" else Node.PROCESS_MODE_DISABLED
	mp40_model.visible = id=="mp40"
	stg_model.visible = id == "stg44"
	rear_grip = Vector3(length*.05,-.05,0)
	front_grip = Vector3(length*.45,0,0)
	muzzle = Vector3(length*.9,0,0)
	if id == "stg44":
		length = .94
		var factor := length/1.152458
		stg_model.scale = Vector3.ONE*factor
		stg_model.rotation.y = PI
		stg_model.position = Vector3(.2,-.27,0)
		rear_grip = Vector3(.045,-.107,.022)
		front_grip = Vector3(.22,-.035,-.022)
		muzzle = Vector3(.689,.008,.001)
		weapon_parts.cache_collision()
	if id=="mp40":
		length = .833
		rear_grip = Vector3(.06,-.10,.020)
		front_grip = Vector3(.295,-.035,-.020)
		muzzle = Vector3(.585,0,0)
		weapon_parts.cache_collision()
	if id=="svt":
		length=1.226
		rear_grip=Vector3(.09,-.035,.020)
		front_grip=Vector3(.32,-.02,-.020)
		muzzle=Vector3(.941,0,0)
	if id=="m1911":
		length=.218
		rear_grip=Vector3(0,-.024,.014)
		front_grip=Vector3(.002,-.030,-.016)
		muzzle=Vector3(.155,.045,0)
	overlay.defaults = preload("res://resources/core/shooting.tres").duplicate(true)
	overlay.defaults.apply_values(data.values)
	overlay._sync()
	trigger_was_down = true
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if stage.player.grenades and stage.player.grenades.busy(): return
	if is_instance_valid(stage.developer):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit or stage.developer.settings_dialog_open: return
		if event.physical_keycode in [KEY_F4,KEY_F6,KEY_F7,KEY_F8,KEY_F9]: return
	if event.physical_keycode == KEY_F9:
		stage.player.position = stage.geometry.point(Vector2(4980,760))+Vector3.UP*.02
		stage.player.velocity = Vector3.ZERO
	if event.physical_keycode == KEY_F6: zombie_overlay.visible = not zombie_overlay.visible
	if event.physical_keycode == KEY_F4: overlay.visible = not overlay.visible
	if event.physical_keycode == KEY_R:
		if not stage.paused and gun.begin_reload():
			reload_start = aim_direction
			reload_facing = aim_facing
	if event.physical_keycode == KEY_F8:
		stg_parts.clear()
		mp40_parts.clear()
		gun.cancel_reload()
		gun.projectiles.clear()
		gun.effects_reset.emit()
	if event.physical_keycode == KEY_F7 or event.physical_keycode == KEY_F8:
		for target in targets: target.reset()
		for enemy in enemies: enemy.reset()
	if event.physical_keycode == KEY_B:
		gun.tuning.fire_mode = 1 if gun.tuning.fire_mode==0 else 0
func _process(dt: float) -> void:
	gun.apply_tuning()
	if gun.reload_left>0 and not was_reloading: reload_stance_ads = stance_ads
	was_reloading = gun.reload_left>0
	var wanted: bool = not stage.paused and not (is_instance_valid(stage.developer) and stage.developer.developer_mode.enabled) and not (is_instance_valid(stage.game_hud) and stage.game_hud.editing)
	if wanted != cursor_active:
		cursor_active = wanted
		if wanted:
			if not cursor_screen.is_finite(): cursor_screen = get_viewport().get_mouse_position()
			if not stage.get_meta("ubertest_virtual_input",false): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if cursor_screen.is_finite() and not stage.get_meta("ubertest_virtual_input",false): Input.warp_mouse(cursor_screen.clamp(Vector2.ONE,get_viewport().get_visible_rect().size-Vector2.ONE))
	# Freeze the complete attachment, not only the animated skeleton.
	gun.set_physics_process(not stage.paused)
	if pistol_animator: pistol_animator.active=not stage.paused
	if stage.paused: return
	var blocked: bool = not cursor_active if not is_instance_valid(stage.developer) else stage.developer.blocks_mouse()
	sync_recoil_projection()
	var mouse := cursor_screen if cursor_screen.is_finite() else stage.get_viewport().get_mouse_position()
	var origin: Vector3 = stage.camera.project_ray_origin(mouse)
	var direction: Vector3 = stage.camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.BACK,0).intersects_ray(origin,direction)
	if hit!=null:
		var side_delta: Vector3 = hit-(stage.player.position+Vector3(0,1.4,0))
		if absf(side_delta.x)>.3: aim_facing = signf(side_delta.x)
	mount_side = lerpf(mount_side,aim_facing,1-exp(-dt/.09))
	pivot.position = stage.player.position+Vector3(mount_side*.25,1.4,0)
	if hit!=null:
		var delta: Vector3 = hit-pivot.position
		delta.z = 0
		if delta.length()>.01: aim_direction = delta.normalized()
	gun.aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and gun.tuning.ads_enabled and gun.tuning.weapon_enabled and gun.reload_left<=0 and not blocked
	var face := aim_facing
	gun.recoil.pivot_point = world2(pivot.global_position)
	if hit!=null: gun.recoil.point = world2(hit)
	gun.recoil.screen_scale = stage.camera_settings.zoom
	stage.player.weapon_look_facing = aim_facing
	stage.player.weapon_aiming = gun.aiming
	stage.player.weapon_movement_multiplier = stage.ragdoll_settings.grenade_move_multiplier if stage.player.grenades and stage.player.grenades.busy() else gun.movement_multiplier
	stage.player.weapon_busy = (stage.player.grenades and stage.player.grenades.busy()) or gun.aiming or gun.firing or gun.reload_left>0
	stage.player.weapon_visual_facing = stage.player.facing if stage.player.sprinting else aim_facing
	if not stage.player.sprinting and gun.reload_left<=0: set_weapon_direction(aim_direction,face,dt)
	if stage.player.sprinting:
		var carry := Vector3(stage.player.facing,-.25,0).normalized()
		pivot.position = stage.player.position+Vector3(stage.player.facing*.18,1.25+.025*sin(stage.player.phase*TAU*2),0)
		set_weapon_direction(carry,stage.player.facing,dt)
	var disabled: bool = (stage.player.grenades and stage.player.grenades.busy()) or stage.player.model.death_ragdoll.active or not gun.tuning.weapon_enabled or stage.player.health<=0 or stage.player.climbing or stage.player.parkour.active or stage.player.dash_left>0 or stage.player.slide_left>0
	pivot.visible = not disabled
	if gun.weapon_id in ["stg44","mp40","m1911","svt"] and not disabled and not stage.player.sprinting:
		if gun.aiming or gun.firing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): alert_left = gun.tuning.relaxed_carry_3d_delay
		alert_left = maxf(0,alert_left-dt)
		var danger := false
		for enemy in enemies:
			if enemy.health>0 and enemy.global_position.distance_squared_to(stage.player.global_position)<pow(gun.tuning.relaxed_carry_3d_radius,2): danger = true
		var quiet: bool = gun.tuning.relaxed_carry_3d_enabled and not danger and alert_left<=0 and not gun.aiming and gun.reload_left<=0
		var weight := 1-exp(-dt/maxf(.05,gun.tuning.weapon_pose_3d_blend))
		stance_ads = lerpf(stance_ads,1.0 if gun.aiming else 0.0,weight)
		stance_calm = lerpf(stance_calm,1.0 if quiet else 0.0,weight)
		var carry := Vector3(aim_facing*cos(deg_to_rad(48)),-sin(deg_to_rad(48)),0)
		set_weapon_direction(aim_direction.lerp(carry,0.0 if gun.firing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else stance_calm).normalized(),face,dt)
	var support := front_grip
	if gun.reload_left>0:
		var progress: float = 1-gun.reload_left/gun.reload_duration_active
		var raised := Vector3(aim_facing*cos(deg_to_rad(38)),sin(deg_to_rad(38)),0)
		var reload_direction := reload_start.lerp(raised,smoothstep(0,.16,progress)).normalized()
		if progress>.9: reload_direction = reload_direction.lerp(aim_direction if aim_direction.x*reload_start.x>=0 else reload_start,smoothstep(.9,1,progress)).normalized()
		set_weapon_direction(reload_direction,aim_facing,dt)
		var mag := Vector3(0,-.065,0) if gun.weapon_id=="m1911" else Vector3(.22,-.16,0)
		var pouch := Vector3(-.2,-.55,0)
		var bolt := Vector3(.18,.03,0)
		if progress<.17: support = front_grip.lerp(mag,smoothstep(0,.17,progress))
		elif progress<=.42: support = mag+Vector3(-.08,-.35,0)*smoothstep(.24,.42,progress)
		elif progress<.52: support = (mag+Vector3(-.08,-.35,0)).lerp(pouch,smoothstep(.42,.52,progress))
		elif progress<.7: support = pouch.lerp(mag,smoothstep(.52,.7,progress))
		elif progress<.8: support = mag.lerp(bolt,smoothstep(.73,.8,progress))
		elif progress<.9: support = bolt+Vector3(-.12*sin(smoothstep(.8,.9,progress)*PI),0,0)
		else: support = bolt.lerp(front_grip,smoothstep(.9,1,progress))
		var mag_offset := Vector3.ZERO
		if progress>=.24 and progress<=.42: mag_offset = Vector3(-.08,-.35,0)*smoothstep(.24,.42,progress)
		elif progress<.52 and progress>.42: mag_offset = Vector3(-.08,-.35,0).lerp(pouch-mag,smoothstep(.42,.52,progress))
		elif progress>=.52 and progress<.7: mag_offset = (pouch-mag).lerp(Vector3.ZERO,smoothstep(.52,.7,progress))
		weapon_parts.set_offset(pivot,mag_offset)
		weapon_parts.proxy.position = mag+mag_offset
		weapon_parts.proxy.visible = gun.weapon_id not in ["stg44","mp40"] and (not gun.magazine_detached or progress>=.52)
		weapon_parts.set_attached(not gun.magazine_detached or progress>=.52)
	else:
		weapon_parts.set_attached(true)
		weapon_parts.set_offset(pivot,Vector3.ZERO)
		weapon_parts.proxy.position = Vector3(.22,-.16,0)
		weapon_parts.proxy.visible = gun.weapon_id not in ["stg44","mp40","m1911","svt"]
	pivot.position -= aim_direction*gun.recoil.recoil_back*2.85/stage.geometry.U
	reload_support = support
	stage.player.model.weapon_grips = [] if disabled else [pivot.to_global(rear_grip),pivot.to_global(support)]
	stage.player.model.weapon_pose = {"combat":self,"ads":reload_stance_ads if gun.reload_left>0 else stance_ads,"calm":stance_calm,"support":pivot.to_global(support)} if gun.weapon_id in ["stg44","mp40","m1911","svt"] and not disabled else {}
	gun.set_physics_process(not stage.paused)
	if disabled: gun.cancel_reload()
	if stage.player.grenades and stage.player.grenades.busy() and stage.player.health>0 and gun.tuning.weapon_enabled:
		pivot.visible=true
		pivot.global_position=stage.player.model.to_global(Vector3(0,.95,-.23))
		var axis=Vector3.DOWN
		var up=stage.player.model.global_basis.x.normalized()
		pivot.global_basis=Basis(axis,up,axis.cross(up)).orthonormalized()
	var trigger := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Trigger scheduling runs only on physics ticks; rendering never fires.
	readout.text = "HP %d · %s · %d / %d · %s%s\n1 основное · 2 пистолет · ЛКМ огонь · мышь направление · R перезарядка · B режим · F4 настройки · F7 мишени" % [stage.player.health,gun.weapon_id,gun.magazine,gun.reserve,"АВТО" if gun.tuning.fire_mode==0 else "ОДИНОЧНЫЙ"," · ПЕРЕЗАРЯДКА" if gun.reload_left>0 else ""]
func show_shot(origin: Vector3,direction: Vector3) -> void:
	if gun.weapon_id=="m1911" and pistol_animator:
		pistol_animator.stop()
		var clip: Animation=pistol_animator.get_animation("Fire")
		var cycle := minf(.12,60.0/maxf(1,gun.tuning.rounds_per_minute)*.8)
		pistol_animator.speed_scale=clip.length/cycle
		pistol_animator.play("Fire")
		pistol_animator.advance(0)
	if gun.tuning.recoil_enabled and gun.tuning.body_recoil_3d_enabled:
		var impulse: float = {"stg44":.07,"mp40":.035,"m1911":.045,"svt":.11}.get(gun.weapon_id,.07)
		stage.player.model.recoil_speed += impulse*gun.tuning.body_recoil_3d_strength*gun.tuning.body_recoil_3d_ammo*lerpf(gun.tuning.body_recoil_3d_hip_multiplier,1.0,stance_ads)
	if gun.tuning.recoil_enabled:
		var multiplier: float = gun.tuning.ads_recoil_camera_multiplier if gun.aiming else 1.0
		stage.weapon_camera_impulse(direction,gun.tuning.camera_kick*multiplier,gun.tuning.camera_shake*multiplier)
	for enemy in enemies: enemy.hear(origin,zombie_settings.shot_noise_multiplier)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_instance_valid(stage.developer) and stage.developer.developer_mode.enabled:
		cursor_screen = event.position
	if event is InputEventMouseMotion and cursor_active:
		var before: Vector2 = cursor_screen if cursor_screen.is_finite() else event.position-event.relative
		cursor_screen = before+event.relative*gun.tuning.aim_mouse_sensitivity
		cursor_screen = cursor_screen.clamp(Vector2.ONE,get_viewport().get_visible_rect().size-Vector2.ONE)
		var motion := screen_world(cursor_screen)-screen_world(before)
		gun.recoil.consume_manual_recoil(motion)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		gun.queued_single_press = true
func _physics_process(dt: float) -> void:
	if stage.paused: return
	var focus := get_viewport().gui_get_focus_owner()
	var blocked: bool = (stage.player.grenades and stage.player.grenades.busy()) or stage.player.model.death_ragdoll.active or stage.player.health<=0 or (stage.developer.blocks_mouse() if is_instance_valid(stage.developer) else not cursor_active) or focus is LineEdit or focus is TextEdit or stage.player.climbing or stage.player.parkour.active or stage.player.dash_left>0 or stage.player.slide_left>0
	gun.aiming = gun.tuning.weapon_enabled and gun.tuning.ads_enabled and gun.reload_left<=0 and not blocked and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	gun.tick_trigger(dt,Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),blocked,pivot.to_global(muzzle),shot_direction(),pivot.global_position,true)
	stage.player.weapon_movement_multiplier = stage.ragdoll_settings.grenade_move_multiplier if stage.player.grenades and stage.player.grenades.busy() else gun.movement_multiplier
	stage.player.weapon_busy = (stage.player.grenades and stage.player.grenades.busy()) or gun.aiming or gun.firing or gun.reload_left>0

func world2(p: Vector3) -> Vector2: return Vector2(p.x,-p.y)*stage.geometry.U
func screen_world(p: Vector2) -> Vector2:
	var hit = Plane(Vector3.BACK,0).intersects_ray(stage.camera.project_ray_origin(p),stage.camera.project_ray_normal(p))
	return world2(hit) if hit!=null else Vector2.ZERO
func shift_recoil(motion: Vector2) -> Vector2:
	if not cursor_screen.is_finite(): cursor_screen = get_viewport().get_mouse_position()
	var before := screen_world(cursor_screen)
	var world := Vector3((before.x+motion.x)/stage.geometry.U,-(before.y+motion.y)/stage.geometry.U,0)
	var screen: Vector2 = stage.camera.unproject_position(world)
	if not gun.tuning.recoil_continuous_enabled:
		var size := get_viewport().get_visible_rect().size
		screen = screen.clamp(Vector2.ONE,size-Vector2.ONE)
	cursor_screen = screen
	return screen_world(cursor_screen)-before


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

class FireFinish extends Node:
	var combat: Node3D
	func _physics_process(_dt: float) -> void: combat.finish_tick()
func finish_tick() -> void:
	if stage.paused: return
	if (stage.player.grenades and stage.player.grenades.busy()) or stage.player.health<=0 or stage.player.model.death_ragdoll.active or stage.player.climbing or stage.player.parkour.active or stage.player.dash_left>0 or stage.player.slide_left>0:
		gun.cancel_reload()
		gun.aiming = false
		gun.firing = false
		gun.burst_time = 0
		return
	if gun.firing:
		if gun.weapon_id in ["stg44","mp40","m1911","svt"]:
			if stance_calm>.01 and not stage.player.model.weapon_pose.is_empty():
				preload("res://scripts/core/player_weapon_pose_3d.gd").mount(stage.player.model,stage.player.visual_mode,0)
			pivot.position += stage.player.position-mount_player_position
			mount_player_position = stage.player.position
		else: pivot.position = stage.player.position+Vector3(mount_side*.25,1.4,0)-aim_direction*gun.recoil.recoil_back*2.85/stage.geometry.U
		if gun.weapon_id not in ["stg44","mp40"]:
			var up := Vector3(-aim_direction.y,aim_direction.x,0).rotated(aim_direction,weapon_roll)
			pivot.basis = Basis(aim_direction,up,aim_direction.cross(up)).orthonormalized()
	gun.finish_trigger(pivot.to_global(muzzle),shot_direction(),pivot.global_position)

func sync_recoil_projection() -> void:
	var origin := screen_world(Vector2.ZERO)
	var dx := screen_world(Vector2.RIGHT)-origin
	var dy := screen_world(Vector2.DOWN)-origin
	var projection := Transform2D(dx,dy,origin).affine_inverse()
	if projection_ready and not projection.is_equal_approx(cursor_projection):
		var conversion := projection.affine_inverse()*cursor_projection
		gun.recoil.recoil_kick_offset = conversion.basis_xform(gun.recoil.recoil_kick_offset)
		gun.recoil.recoil_drift_offset = conversion.basis_xform(gun.recoil.recoil_drift_offset)
		gun.recoil.recoil_retarget_motion = conversion.basis_xform(gun.recoil.recoil_retarget_motion)
	cursor_projection = projection
	projection_ready = true
	gun.recoil.screen_projection = projection

func set_weapon_direction(direction: Vector3,face: float,dt: float) -> void:
	# Explicit barrel axis avoids the mirrored Euler pitch reversal on the left.
	var axis := direction.normalized()
	var target_roll := 0.0 if face>0 else PI
	weapon_roll = lerp_angle(weapon_roll,target_roll,1-exp(-dt/.09)) if dt>0 else target_roll
	var up := Vector3(-axis.y,axis.x,0).rotated(axis,weapon_roll)
	pivot.basis = Basis(axis,up,axis.cross(up)).orthonormalized()

func shot_direction() -> Vector3:
	return pivot.global_basis.x.normalized()
