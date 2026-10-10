class_name RifleBullet
extends Node2D
var game: Node2D
var direction := Vector2.RIGHT
var speed := 2350.0
var lifetime := 1.0
var travelled := 0.0

func _physics_process(delta: float) -> void:
	if game.state != "playing": return
	var end := global_position+direction*speed*delta
	var query := PhysicsRayQueryParameters2D.create(global_position,end,5)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider.has_method("receive_shot"):
			var headshot: bool = hit.position.y < hit.collider.global_position.y-91
			var killed: bool = hit.collider.receive_shot(76 if headshot else 36,direction,headshot)
			game.register_hit(headshot,killed)
			if headshot: game.spray(hit.position,direction,Color("6e3a2b"),24,220,0.7,0.75)
			else: game.spray(hit.position,direction,Color("804c37"),14,150,0.9)
		else:
			game.burst(hit.position,Color("d8bd80"),7,130,0.3)
		queue_free()
		return
	global_position = end
	travelled += speed*delta
	lifetime -= delta
	if lifetime <= 0: queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2.ZERO,-direction*minf(travelled,65),Color(1,0.79,0.44,0.7),2,true)
	draw_line(Vector2.ZERO,-direction*minf(travelled,22),Color("fff5c2"),1.2,true)
