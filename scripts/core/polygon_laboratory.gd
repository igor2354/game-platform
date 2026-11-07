extends Node2D
## User-authorized laboratory composite; physics remains in CoreMovementLevel.
const ORIGIN=Vector2(-6600,-200)
const PIXELS_PER_WORLD_UNIT=2.0
const ROCK=preload("res://resources/core/polygon_laboratory/rock.png")
const TEXTURES=[
preload("res://resources/core/polygon_laboratory/strip_00.png"),
preload("res://resources/core/polygon_laboratory/strip_01.png"),
preload("res://resources/core/polygon_laboratory/strip_02.png"),
preload("res://resources/core/polygon_laboratory/strip_03.png"),
preload("res://resources/core/polygon_laboratory/strip_04.png"),
preload("res://resources/core/polygon_laboratory/strip_05.png"),
preload("res://resources/core/polygon_laboratory/strip_06.png"),
preload("res://resources/core/polygon_laboratory/strip_07.png"),
preload("res://resources/core/polygon_laboratory/strip_08.png"),
preload("res://resources/core/polygon_laboratory/strip_09.png"),
preload("res://resources/core/polygon_laboratory/strip_10.png"),
preload("res://resources/core/polygon_laboratory/strip_11.png"),
preload("res://resources/core/polygon_laboratory/strip_12.png"),
preload("res://resources/core/polygon_laboratory/strip_13.png"),
]
const RECORDS=[[0, 2048, 0], [2048, 2048, 2], [4096, 2048, 2], [6144, 2048, 2], [8192, 2048, 2], [10240, 2048, 2], [12288, 2048, 2], [14336, 2048, 2], [16384, 2048, 2], [18432, 2048, 2], [20480, 2048, 2], [22528, 2048, 2], [24576, 2048, 2], [26624, 1056, 2]]
func _ready() -> void:
	z_index=-10
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	position=ORIGIN;scale=Vector2.ONE/PIXELS_PER_WORLD_UNIT
	for i in TEXTURES.size():
		var atlas:=AtlasTexture.new();atlas.atlas=TEXTURES[i]
		atlas.region=Rect2(RECORDS[i][2],0,RECORDS[i][1],2900);atlas.filter_clip=false
		var sprite:=Sprite2D.new();sprite.texture=atlas;sprite.centered=false
		sprite.position=Vector2(RECORDS[i][0],0);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
	var ladder_art:=preload("res://scripts/core/polygon_laboratory_ladders.gd").new()
	ladder_art.position=-ORIGIN*PIXELS_PER_WORLD_UNIT;ladder_art.scale=Vector2.ONE*PIXELS_PER_WORLD_UNIT
	add_child(ladder_art)
func _draw() -> void:
	draw_texture_rect(ROCK,Rect2(-ROCK.get_width()*10,-ROCK.get_height()*10,ROCK.get_width()*50,ROCK.get_height()*40),true)
