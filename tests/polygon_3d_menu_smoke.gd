extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 for filename in ["polygon_3d.gd","polygon_3d_combat.gd","stg_3d_parts.gd"]:
  var source := FileAccess.get_file_as_string("res://scripts/core/"+filename)
  for line in source.split("\n"):
   if line.begins_with(" ") and not line.strip_edges().is_empty():
    push_error("Mixed indentation in "+filename)
    quit(1)
    return
 var menu = load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings = false
 root.add_child(menu)
 await process_frame
 menu.launch(false)
 for i in 8: await process_frame
 var ok: bool = menu.game is Node3D and menu.game.player is CharacterBody3D
 print("POLYGON_3D_MENU ","PASS" if ok else "FAIL")
 menu.return_to_menu()
 for i in 8: await process_frame
 menu.launch(false,true)
 for i in 8: await process_frame
 ok = ok and menu.game is CoreMovementLab
 print("POLYGON_2D_PRESERVED ","PASS" if menu.game is CoreMovementLab else "FAIL")
 menu.return_to_menu()
 for i in 8: await process_frame
 quit(int(not ok))
