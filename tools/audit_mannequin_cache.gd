extends SceneTree
class Probe extends Node2D:
	const ART = preload("res://scripts/core/mannequin_art.gd")
	func _draw() -> void:
		ART.silhouette_cache.clear()
		for i in 1000:
			ART.silhouette(self,Vector2(30,40),[Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)],Color.WHITE,Transform2D(0,Vector2(100,100)))
			var size: int = ART.silhouette_cache.values()[0].size()
			if size != 16:
				push_error("FAIL contour grew at draw "+str(i+1))
				get_tree().quit(1)
				return
		print("CACHE AUDIT PASS: 1000 draws, 16 cached points unchanged")
		get_tree().call_deferred("quit")
func _initialize() -> void: root.call_deferred("add_child",Probe.new())
