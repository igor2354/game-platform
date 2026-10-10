class_name DeadPlatformGame
extends Node2D

var level: StationLevel
var player: Soldier
var camera: Camera2D
var hud: StationHUD
var enemies: Array[StationZombie] = []
var state := "title"
var kills := 0
var mission_time := 0.0
var radio_active := false
var checkpoint_taken := false
var respawn_point := Vector2(220,StationLevel.LOWER)
var feel := GunFeel.new()
var tuner: FeelTuner
var trauma := 0.0
var camera_kick := Vector2.ZERO
var shake_noise := FastNoiseLite.new()
var hitstop_until_ms := 0
var injury := 0.0
var hit_marker := 0.0
var hit_kind := "hit"
var effects_enabled := true
var muted := false
var toast := ""
var toast_left := 0.0
var particles: Array[Dictionary] = []
var post_material: ShaderMaterial
var foreground_material: ShaderMaterial
var ambient: AudioStreamPlayer
var sounds: Dictionary = {}


func _ready() -> void:
	get_tree().auto_accept_quit = false
	feel.load_saved()
	shake_noise.frequency = 0.9
	_setup_input()
	camera = Camera2D.new()
	camera.position = Vector2(720,870)
	camera.position_smoothing_enabled = false
	add_child(camera)
	camera.make_current()
	var background_layer := CanvasLayer.new()
	background_layer.layer = -10
	add_child(background_layer)
	var background := StationAtmosphere.new()
	background.game = self
	background.mode = "background"
	background_layer.add_child(background)
	level = StationLevel.new()
	add_child(level)
	player = Soldier.new()
	player.game = self
	player.position = respawn_point
	player.z_index = 3
	add_child(player)
	_spawn_initial()
	_setup_visuals()
	_setup_audio()
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 30
	add_child(ui_layer)
	hud = StationHUD.new()
	hud.game = self
	ui_layer.add_child(hud)
	var tuner_layer := CanvasLayer.new()
	tuner_layer.layer = 31
	add_child(tuner_layer)
	tuner = FeelTuner.new()
	tuner.game = self
	tuner_layer.add_child(tuner)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_input() -> void:
	var bindings := {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"jump":[KEY_SPACE],"reload":[KEY_R],"interact":[KEY_E],"pause":[KEY_ESCAPE],"start":[KEY_ENTER],"effects":[KEY_F2],"tuner":[KEY_F3],"mute":[KEY_M]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	for binding in [["shoot",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]): InputMap.add_action(binding[0])
		var event := InputEventMouseButton.new()
		event.button_index = binding[1]
		InputMap.action_add_event(binding[0],event)

func _setup_visuals() -> void:
	var foreground_view := SubViewport.new()
	foreground_view.size = Vector2i(1440,900)
	foreground_view.transparent_bg = true
	foreground_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(foreground_view)
	var painter := StationAtmosphere.new()
	painter.game = self
	painter.mode = "foreground"
	foreground_view.add_child(painter)
	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 8
	add_child(weather_layer)
	var foreground := TextureRect.new()
	foreground.texture = foreground_view.get_texture()
	foreground.size = Vector2(1440,900)
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground_material = ShaderMaterial.new()
	foreground_material.shader = load("res://shaders/depth_blur.gdshader")
	foreground_material.set_shader_parameter("blur_pixels",4.5)
	foreground.material = foreground_material
	weather_layer.add_child(foreground)
	var weather := StationAtmosphere.new()
	weather.game = self
	weather_layer.add_child(weather)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 20
	add_child(post_layer)
	var post := ColorRect.new()
	post.size = Vector2(1440,900)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_material = ShaderMaterial.new()
	post_material.shader = load("res://shaders/post.gdshader")
	post.material = post_material
	post_layer.add_child(post)

func _setup_audio() -> void:
	for sound in ["shot","reload","hurt","kill","radio"]:
		sounds[sound] = load("res://assets/audio/"+sound+".wav")
	ambient = AudioStreamPlayer.new()
	ambient.stream = load("res://assets/audio/ambience.wav")
	ambient.volume_db = -22
	add_child(ambient)
	ambient.play()

func play_sound(sound: String, pitch := 1.0) -> void:
	if muted: return
	var audio := AudioStreamPlayer.new()
	audio.stream = sounds[sound]
	audio.pitch_scale = pitch
	audio.volume_db = -11 if sound == "shot" else -17
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func _spawn_initial() -> void:
	for p in [Vector2(785,1120),Vector2(1280,1120),Vector2(1900,1120),Vector2(2220,1120),Vector2(2930,1120),Vector2(3290,1120),Vector2(3650,1120),Vector2(1140,820),Vector2(1610,820),Vector2(2290,820),Vector2(2670,820),Vector2(3390,820),Vector2(1360,520),Vector2(1790,520),Vector2(2450,520),Vector2(2950,520),Vector2(3510,520),Vector2(4100,520)]:
		spawn_enemy(p)

func spawn_enemy(pos: Vector2) -> StationZombie:
	var enemy := StationZombie.new()
	enemy.game = self
	enemy.position = pos
	enemy.z_index = 2
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func start_game() -> void:
	state = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	show_toast("Найдите радиорубку на верхней галерее",4)

func restart() -> void:
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if state == "title": start_game()
		elif state in ["dead","won"]: restart()
		elif state == "paused": resume()
	if event.is_action_pressed("pause"):
		if state == "playing":
			state = "paused"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif state == "paused": resume()
	if event.is_action_pressed("effects"):
		effects_enabled = not effects_enabled
		post_material.set_shader_parameter("effects_enabled",effects_enabled)
		level.set_effects_enabled(effects_enabled)
		foreground_material.set_shader_parameter("blur_pixels",4.5 if effects_enabled else 0)
		show_toast("Эффекты: "+("включены" if effects_enabled else "выключены"))
	if event.is_action_pressed("tuner"):
		tuner.toggle()
	if event.is_action_pressed("mute"):
		muted = not muted
		ambient.volume_db = -80 if muted else -22
		show_toast("Звук: "+("выключен" if muted else "включён"))

func resume() -> void:
	state = "playing"
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta: float) -> void:
	if state == "playing":
		mission_time += delta
		injury = maxf(0,injury-delta*1.8)
		hit_marker = maxf(0,hit_marker-delta)
		toast_left = maxf(0,toast_left-delta)
		var desired := Vector2(clampf(player.position.x+160*player.facing,720,3600),clampf(player.position.y-230,640,870))
		camera.position = camera.position.lerp(desired,1-exp(-delta*4.0))
		_update_camera_feel(delta)
		if not checkpoint_taken and player.position.distance_to(level.checkpoint) < 65:
			checkpoint_taken = true
			respawn_point = level.checkpoint-Vector2(0,2)
			player.health = 100
			player.reserve += 96
			show_toast("Полевой запас · здоровье и 96 патронов · контрольная точка",4)
		for i in range(particles.size()-1,-1,-1):
			var p: Dictionary = particles[i]
			p.life -= delta
			p.pos += p.velocity*delta
			p.velocity.y += p.gravity*delta
			if p.life <= 0: particles.remove_at(i)
		if radio_active and player.position.distance_to(level.exit_point) < 85:
			state = "won"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			play_sound("radio")
	# Hitstop is timed in real milliseconds because time_scale also slows delta.
	Engine.time_scale = feel.hitstop_scale if state == "playing" and Time.get_ticks_msec() < hitstop_until_ms else 1.0
	post_material.set_shader_parameter("injury",injury)
	queue_redraw()

func _update_camera_feel(delta: float) -> void:
	trauma = maxf(0,trauma-feel.trauma_decay*delta)
	camera_kick *= exp(-feel.cam_kick_recovery*delta)
	if not effects_enabled:
		camera.offset = Vector2.ZERO
		return
	# Squared trauma keeps light fire subtle while heavy hits still land hard.
	var t := Time.get_ticks_msec()*0.06
	var amount := feel.shake_max*trauma*trauma
	camera.offset = camera_kick+Vector2(shake_noise.get_noise_2d(t,0),shake_noise.get_noise_2d(0,t))*amount

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma+amount,0,1)

func kick_camera(offset: Vector2) -> void:
	camera_kick += offset

func hitstop(ms: float) -> void:
	if ms <= 0: return
	hitstop_until_ms = maxi(hitstop_until_ms,Time.get_ticks_msec()+int(ms))

func register_hit(headshot: bool, killed: bool) -> void:
	hit_kind = "kill" if killed else ("head" if headshot else "hit")
	hit_marker = 0.26 if killed else 0.18
	if killed:
		hitstop(feel.hitstop_kill)
		add_trauma(0.12)
	elif headshot:
		hitstop(feel.hitstop_headshot)

func tuner_blocks_fire() -> bool:
	return tuner != null and tuner.blocks_fire()

func interact() -> void:
	if not radio_active and player.position.distance_to(level.radio) < 95:
		radio_active = true
		level.radio_active = true
		level.queue_redraw()
		player.reserve += 72
		play_sound("radio")
		show_toast("Связь установлена. Спускайтесь к восточному выходу →",5)
		for p in [Vector2(2780,1120),Vector2(3000,1120),Vector2(3200,1120),Vector2(3450,820),Vector2(4070,820),Vector2(3850,1120)]:
			var enemy := spawn_enemy(p)
			enemy.alerted = true
	elif player.position.distance_to(level.exit_point) < 100:
		show_toast("Выход закрыт. Сначала вызовите эвакуацию по радио.")

func fall_recover() -> void:
	player.position = respawn_point-Vector2(0,10)
	player.velocity = Vector2.ZERO
	player.climbing = false
	player.drop_left = 0
	player.set_collision_mask_value(1,true)
	player.take_damage(25)
	if state == "playing": show_toast("Падение · −25 здоровья · возвращение к укрытию")

func die() -> void:
	state = "dead"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func continue_checkpoint() -> void:
	player.health = 100
	player.ammo = Soldier.MAGAZINE
	player.reserve = maxi(player.reserve,72)
	player.position = respawn_point-Vector2(0,10)
	player.velocity = Vector2.ZERO
	player.climbing = false
	player.drop_left = 0
	player.reload_left = 0
	player.set_collision_mask_value(1,true)
	player.invulnerable = 2
	injury = 0
	resume()

func show_toast(message: String, duration := 3.0) -> void:
	toast = message
	toast_left = duration

func burst(pos: Vector2, color: Color, count: int, speed: float, life := 0.6) -> void:
	if not effects_enabled: return
	for i in count:
		particles.append({"pos":pos,"velocity":Vector2.from_angle(randf()*TAU)*randf_range(speed*0.2,speed),"life":randf_range(life*0.4,life),"max_life":life,"color":color,"gravity":190.0,"size":randf_range(1.0,2.8)})
	while particles.size() > 550: particles.pop_front()

# Directional burst: particles fly along dir within a cone (radians, half-angle).
func spray(pos: Vector2, dir: Vector2, color: Color, count: int, speed: float, cone: float, life := 0.6) -> void:
	if not effects_enabled: return
	for i in count:
		var velocity := dir.rotated(randf_range(-cone,cone))*randf_range(speed*0.3,speed)
		particles.append({"pos":pos,"velocity":velocity,"life":randf_range(life*0.4,life),"max_life":life,"color":color,"gravity":420.0,"size":randf_range(1.2,3.2)})
	while particles.size() > 550: particles.pop_front()

func add_casing(pos: Vector2) -> void:
	if effects_enabled:
		particles.append({"pos":pos,"velocity":Vector2(randf_range(-80,-25),-130),"life":1.2,"max_life":1.2,"color":Color("b39a61"),"gravity":420.0,"size":2.4})

func _draw() -> void:
	for p in particles:
		var col: Color = p.color
		col.a = clampf(p.life/p.max_life,0,1)
		draw_line(p.pos,p.pos-p.velocity.normalized()*p.size*2,col,p.size,true)
	# Objective rings are diegetic markers, separate from the weapon crosshair.
	var target := level.exit_point if radio_active else level.radio
	var col := Color("d4bd80")
	col.a = 0.55+sin(Time.get_ticks_msec()*0.003)*0.2
	draw_arc(target-Vector2(0,85),17,0,TAU,24,col,1.5,true)
	draw_colored_polygon(PackedVector2Array([target+Vector2(0,-110),target+Vector2(-5,-117),target+Vector2(5,-117)]),col)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_tree()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()
