extends SceneTree
const V2=preload("res://scripts/campaign/forest_prologue_v2.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func frames(n:int) -> void:
	for i in n:await physics_frame;await process_frame
func run() -> void:
	var lab:CoreMovementLab=load("res://scenes/campaign/prologue_v2.tscn").instantiate();lab.load_user_settings=false
	var temp:=OS.get_environment("TEMP").path_join("v2-art-test-%d"%OS.get_process_id());DirAccess.make_dir_recursive_absolute(temp)
	for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:lab.set(key,temp.path_join(key+".cfg"))
	lab.get_node("World/Player").character_id="sofia";lab.get_node("World/Player").sofia_cel_variant=true
	root.add_child(lab);await frames(12)
	var f=lab.level.forest;var p=f.panorama
	check(p.strips.size()==19,"nineteen imported GPU strips load from portable res resources")
	check(p.manifest.size==[38720,2240],"continuous master dimensions")
	check(p.position.is_equal_approx(V2.point(0,16)),"art world origin matches fixed physical reference")
	check(is_equal_approx(p.scale.x,1.0/(80.0/V2.UPM)),"art calibration is eighty image pixels per physical meter")
	for i in p.strips.size():
		var sprite:Sprite2D=p.strips[i];var region:AtlasTexture=sprite.texture
		check(region.atlas.get_height()==2240 and region.region.position.x==2,"strip %d retains native height and filtering gutters"%i)
		if i>0:
			var previous:Sprite2D=p.strips[i-1]
			check(is_equal_approx(previous.position.x+previous.texture.get_width(),sprite.position.x),"strip %d has no world-coordinate gap"%i)
	var positions:=[]
	for sprite in p.strips:positions.append(sprite.global_position)
	var camera_zoom:=lab.camera.zoom
	lab.player.request_character_scale(1.2);await frames(3)
	var unchanged:=true
	for i in p.strips.size():unchanged=unchanged and positions[i].is_equal_approx(p.strips[i].global_position)
	check(unchanged,"changing hero scale never moves or scales the environment")
	check(lab.camera.zoom.is_equal_approx(camera_zoom),"hero scale leaves camera independent")
	lab.player.request_character_scale(1.0)
	check(f.sections.size()==12 and f.ladders.size()==19 and is_equal_approx(V2.WIDTH,484*V2.UPM),"twelve sections, nineteen ladders, 484m preserved")
	check(f.features.house_window_sill.size.is_equal_approx(Vector2(.18,.35)*V2.UPM),"house physical window sill unchanged")
	f.set_debug_geometry(true);await frames(2);check(f.debug_geometry,"F1 physical geometry remains available over the art")
	f.set_debug_geometry(false);await frames(2);check(not f.debug_geometry and p.visible,"clean panorama restored after physical overlay")
	lab.queue_free();await frames(3);print("V2 ART: %d/%d"%[checks-failures,checks]);quit(1 if failures else 0)
