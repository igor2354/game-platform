class_name CoreBreakableLamp
extends StaticBody2D
## Bullet target on a back wall; it does not block actor movement or vision.
signal light_changed
var tuning: CoreZombieSettings
var health := 25.0
var broken := false
var spark_left := 0.0

func _ready() -> void:
	collision_layer = 64
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(58,26)
	shape.shape = rectangle
	add_child(shape)
	reset_lamp()

func reset_lamp() -> void:
	health = tuning.lamp_health if tuning else 25.0
	broken = false
	spark_left = 0
	queue_redraw()
	light_changed.emit()

func apply_tuning() -> void:
	if tuning: health = minf(health,tuning.lamp_health)
	queue_redraw()
	light_changed.emit()

func take_projectile_damage(amount: float,_attacker: Node = null) -> bool:
	if broken or not is_finite(amount) or amount <= 0: return false
	health = maxf(0,health-amount)
	if health <= 0:
		broken = true
		spark_left = .22
	queue_redraw()
	light_changed.emit()
	return broken

func _process(delta: float) -> void:
	if spark_left > 0:
		spark_left = maxf(0,spark_left-delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-34,-17,68,34),Color("1a2229"))
	draw_rect(Rect2(-29,-13,58,26),Color("77858c"),false,3)
	draw_rect(Rect2(-25,-9,50,18),Color("352f2b") if broken else Color("ffe7a3"))
	for x in [-17,0,17]: draw_line(Vector2(x,-12),Vector2(x,12),Color("65747a"),2)
	if broken:
		draw_line(Vector2(-22,-7),Vector2(5,5),Color("131c22"),3)
		draw_line(Vector2(5,5),Vector2(18,-6),Color("131c22"),3)
	if spark_left > 0:
		for i in 9:
			var axis := Vector2.from_angle(TAU*i/9.0)
			draw_line(axis*18,axis*(24+(1-spark_left/.22)*24),Color(1,.72,.28,spark_left/.22),2)
