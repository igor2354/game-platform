extends Node2D
## One continuous master, split only for GPU limits. No physical geometry here.
const DIRECTORY="res://resources/campaign/prologue_v2_panorama"
const DATA=preload("res://scripts/campaign/prologue_v2_art_data.gd")
var strips:Array[Sprite2D]=[]
var manifest:Dictionary={}
func _ready() -> void:
	var directory:=OS.get_environment("UBERSHRIKE_V2_ART_PREVIEW")
	var external:=not directory.is_empty()
	if external:
		var file:=directory.path_join("manifest.json")
		if not FileAccess.file_exists(file):return
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary:return
		manifest=parsed
	else:directory=DIRECTORY;manifest=DATA.MANIFEST
	var origin:Array=manifest.world_origin
	position=Vector2(origin[0],origin[1]);scale=Vector2.ONE/float(manifest.pixels_per_world_unit)
	for record in manifest.tiles:
		var path:=directory.path_join(record.name)
		if not FileAccess.file_exists(path):path=directory.path_join("strips").path_join(record.name)
		var texture:Texture2D
		if not external:texture=DATA.TEXTURES[strips.size()]
		else:
			var image:=Image.load_from_file(path)
			if image==null or image.is_empty():push_error("Missing ver2 art strip: "+path);continue
			texture=ImageTexture.create_from_image(image)
		var atlas:=AtlasTexture.new();atlas.atlas=texture
		atlas.region=Rect2(int(manifest.gutter),0,int(record.width),int(manifest.size[1]));atlas.filter_clip=false
		var sprite:=Sprite2D.new();sprite.name="Strip%02d"%strips.size();sprite.texture=atlas;sprite.centered=false
		sprite.position=Vector2(record.x,0);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite);strips.append(sprite)
