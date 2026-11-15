extends SceneTree
var failures := 0
var checks := 0
func _initialize(): run.call_deferred()
func check(ok: bool,text: String):
 checks+=1
 if not ok:
  failures+=1
  push_error("FAIL "+text)
 else: print("PASS ",text)
func run():
 var directory:=OS.get_environment("TEMP").path_join("developer-routes-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(directory)
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=false
 menu.test_settings_directory=directory
 root.add_child(menu)
 await process_frame
 var exported=directory.path_join("native.json")
 var expected: Dictionary={}
 for route in ["native_polygon","legacy_polygon","prologue","prologue_v2","terra","hub"]:
  menu.selected_level=route
  menu.launch(route not in ["native_polygon","legacy_polygon"],route=="legacy_polygon")
  for i in 3: await process_frame
  var game=menu.game
  var adapter=game.developer if game is Node3D else game
  var ui=adapter.developer_mode
  ui.set_enabled(true)
  for section in 5:
   ui.show_section(section)
   check(ui.current_section==section and ui.visible,"workspace "+route+" section "+str(section))
  if game is Node3D:
   check(adapter.export_settings_file(exported),"native profile export")
   for key in adapter._resources(): expected[key]=adapter._resources()[key].as_dictionary()
  else:
   check(adapter.import_settings_file(exported),"native profile import on "+route)
   var actual=adapter._settings_resources()
   for key in expected: check(actual[key].as_dictionary()==expected[key],route+" profile "+key)
  ui.set_enabled(false)
  menu.return_to_menu()
  for i in 3: await process_frame
 print("DEVELOPER_ROUTES checks=",checks," failures=",failures)
 menu.queue_free()
 await process_frame
 quit(int(failures>0))
