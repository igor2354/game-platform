extends SceneTree
class Reference extends Node2D:
	var cases: Array = []
	var motion = preload("res://scripts/core/weapon_casing.gd").new()
	func _draw() -> void:
		for effect in cases:
			draw_set_transform(effect.point,effect.rotation)
			motion.draw_case(self,effect,effect.size_world)
		draw_set_transform_matrix(Transform2D.IDENTITY)
func _initialize() -> void: call_deferred("run")
func viewport() -> SubViewport:
	var result := SubViewport.new()
	result.size = Vector2i(800,500)
	result.world_2d = World2D.new()
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(result)
	return result
func run() -> void:
	var a := viewport()
	var b := viewport()
	var reference := Reference.new()
	a.add_child(reference)
	var batch = preload("res://scripts/core/casing_batch.gd").new()
	var moving_host := Node2D.new()
	moving_host.position=Vector2(80,40); moving_host.scale=Vector2(2.85,2.85)
	b.add_child(moving_host); moving_host.add_child(batch)
	for row in 4:
		for variant in 4:
			var effect := {"weapon_id":["stg44","mp40","svt","m1911"][row],"state":"rest","rest_variant":variant,"rotation":-.4+variant*.25,"point":Vector2(100+variant*180,60+row*95),"size_world":Vector2(120,38)}
			reference.cases.append(effect)
			batch.update_case(batch.allocate(),effect)
	for i in 24:
		var effect := {"weapon_id":["stg44","mp40","svt","m1911"][i%4],"state":"air","rest_variant":i%4,"rotation":i*.38,"point":Vector2(30+i*31,455),"size_world":Vector2(16,5)}
		reference.cases.append(effect)
		batch.update_case(batch.allocate(),effect)
	reference.queue_redraw()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var before := a.get_texture().get_image()
	var after := b.get_texture().get_image()
	var error := 0.0
	var count_a := 0
	var count_b := 0
	var changed := 0
	var background := before.get_pixel(0,0)
	for y in before.get_height():
		for x in before.get_width():
			var ca := before.get_pixel(x,y)
			var cb := after.get_pixel(x,y)
			if ca != background: count_a += 1
			if cb != background: count_b += 1
			var d := absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)+absf(ca.a-cb.a)
			error += d
			if d > .1: changed += 1
	var mean := error/(before.get_width()*before.get_height()*4)
	print("BATCH IMAGE reference_pixels=",count_a," batch_pixels=",count_b," mean_error=",mean," changed=",changed)
	var folder := preload("res://tools/media_paths.gd").path("docs/core/casing_pool_20261105")
	before.save_png(folder.path_join("reference.png"))
	after.save_png(folder.path_join("batch.png"))
	var passed: bool = count_a > 5000 and count_b > count_a*.98 and count_b < count_a*1.02 and mean < .001
	print("PASS batch preserves weapon, rest variant, rotation and crop" if passed else "FAIL batch image mismatch")
	a.queue_free(); b.queue_free()
	await process_frame
	quit(0 if passed else 1)

