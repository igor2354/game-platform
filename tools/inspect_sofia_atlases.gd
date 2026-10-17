extends SceneTree
func _initialize() -> void:
	for name in ["walk","run","actions","arms"]:
		var texture := load("res://resources/campaign/sofia_%s_v3.png" % name) as Texture2D
		var image := texture.get_image()
		var width := image.get_width()/3
		var height := image.get_height()/3
		var visited := PackedByteArray()
		visited.resize(width*height)
		var regions: Array = []
		for y in height:
			for x in width:
				var index := y*width+x
				if visited[index] != 0: continue
				visited[index] = 1
				if image.get_pixel(x*3,y*3).a < .5: continue
				var queue := PackedInt32Array([index])
				var head := 0
				var box := Rect2i(x*3,y*3,3,3)
				while head < queue.size():
					var current := queue[head]
					head += 1
					var p := Vector2i(current%width,current/width)
					box = box.expand(p*3)
					for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var n: Vector2i = p+offset
						if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height: continue
						var next: int = n.y*width+n.x
						if visited[next] != 0: continue
						visited[next] = 1
						if image.get_pixel(n.x*3,n.y*3).a >= .5: queue.append(next)
				if queue.size() > 300: regions.append([box.position.x,box.position.y,box.size.x,box.size.y])
		print(name," ",image.get_size()," ",JSON.stringify(regions))
	quit()
