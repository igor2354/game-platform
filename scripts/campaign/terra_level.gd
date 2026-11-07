extends CoreMovementLevel
const ORIGIN:=Vector2(32000,760)
var ground: Node2D
func player_spawn() -> Vector2: return ORIGIN+Vector2(128,0)
func right_bound() -> float: return ORIGIN.x+6144
func campaign_bounds() -> Rect2: return Rect2(ORIGIN-Vector2(0,700),Vector2(6144,2400))
func map_landmarks() -> Array[Dictionary]: return []
func _ready() -> void:
	call_deferred("blocking_only")
	floors.clear();platforms.clear();obstacles.clear();ladders.clear();side_ladders.clear();slopes.clear()
	for rect in [Rect2(ORIGIN.x-32,0,32,2500),Rect2(right_bound(),0,32,2500)]:
		_solid(rect,false)
		get_child(-1).set_meta("surface_boundary",true)
	fuel_field=CoreFuelField.new();add_child(fuel_field)
	ground=preload("res://scripts/core/terra_grid.gd").new()
	ground.local_collision_mode=true;ground.CHUNK=4
	ground.position=ORIGIN;ground.tuning=get_parent().get_node("Player").tuning;add_child(ground)
	forest=ground

func prepare_shovel_crater() -> void:
	# A repeatable 224-unit practice pit wholly inside the earth sector.
	for y in 14:
		for x in range(86, 112):
			var index: int = y * ground.W + x
			if ground.health[index] <= 0.0: continue
			ground.health[index] = 0.0
			ground.dirty_at(Vector2i(x, y))
	while not ground.pending.is_empty():
		await get_tree().process_frame
	var player: CoreMovementPlayer = get_parent().get_node("Player")
	player.reset_to(ORIGIN + Vector2(1706, 219))
	player.weapon.shovel.issue()

func blocking_only() -> void:
	# This laboratory intentionally shows the complete unmasked blocking.
	get_parent().get_parent().camera_settings.fog_enabled=false
	get_parent().get_parent().fog_of_war.apply_settings()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or get_tree().paused: return
	var hero=get_parent().get_node("Player")
	if hero.input_blocker.is_valid() and hero.input_blocker.call(): return
	if event.keycode==KEY_BRACKETLEFT or event.keycode==KEY_BRACKETRIGHT:
		var profile:=CoreExplosionSettings.new();profile.explosion_audio_enabled=false
		profile.explosion_radius=260 if event.keycode==KEY_BRACKETLEFT else 600
		profile.explosion_damage=100 if event.keycode==KEY_BRACKETLEFT else 250
		CoreExplosion.spawn(self,get_global_mouse_position(),profile)
	if event.keycode==KEY_HOME: get_parent().get_node("Player").reset_to(player_spawn())
	if event.keycode==KEY_BACKSPACE: ground.reset_ground()
func _draw() -> void:
	draw_string(ThemeDB.fallback_font,ORIGIN+Vector2(20,-260),"ТЕРРА · [ / ] — подрыв у курсора · Home — на старт · Backspace — восстановить грунт",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
