class_name CoreEnemyDummy
extends StaticBody2D

@export var body_size := Vector2(32,64)
@export var identifier := "01"
const MAX_HEALTH := 100.0
var health := MAX_HEALTH
var hit_flash := 0.0
var received_hits := 0
var reaction_offset := Vector2.ZERO
var death_progress := 0.0
var hit_side := 1.0

func take_damage(amount: float,direction := Vector2.RIGHT) -> bool:
	if health <= 0: return false
	health = maxf(0,health-amount)
	received_hits += 1
	hit_flash = .12
	hit_side = 1 if direction.x >= 0 else -1
	reaction_offset = (reaction_offset+direction*5).limit_length(9)
	if health <= 0: collision_layer = 0
	queue_redraw()
	return health <= 0

func reset_target() -> void:
	health = MAX_HEALTH
	received_hits = 0
	hit_flash = 0
	reaction_offset = Vector2.ZERO
	death_progress = 0
	collision_layer = 4
	queue_redraw()

func _physics_process(delta: float) -> void:
	hit_flash = maxf(0,hit_flash-delta)
	reaction_offset *= exp(-22*delta)
	if health <= 0: death_progress = minf(1,death_progress+delta/.20)
	queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = body_size
	shape.shape = rectangle
	shape.position.y = -body_size.y/2
	add_child(shape)

func _draw() -> void:
	var color := Color("ffcfb6") if hit_flash > 0 else Color("be6d70") if health > 0 else Color("52606b")
	var squash := hit_flash/.12
	draw_set_transform(reaction_offset-Vector2(0,body_size.x*.5*death_progress),hit_side*PI*.5*death_progress,Vector2(1-squash*.07,1+squash*.07))
	draw_rect(Rect2(-body_size.x/2,-body_size.y,body_size.x,body_size.y),color)
	draw_line(Vector2(-7,-body_size.y*.65),Vector2(7,-body_size.y*.65),Color("f0d9d4"),2)
	draw_line(Vector2(0,-body_size.y*.65-7),Vector2(0,-body_size.y*.65+7),Color("f0d9d4"),2)
	draw_set_transform(Vector2.ZERO)
	if health > 0:
		draw_rect(Rect2(-body_size.x/2,-body_size.y-5,body_size.x,3),Color("273742"))
		draw_rect(Rect2(-body_size.x/2,-body_size.y-5,body_size.x*health/MAX_HEALTH,3),Color("81c6a7"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-12,-body_size.y-10),identifier,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d0b8b7"))
