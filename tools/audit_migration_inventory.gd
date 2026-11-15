extends SceneTree
var results: Array=[]
func _initialize(): run.call_deferred()
func visit(node: Node,row: Dictionary):
 if node is Node2D: row.node2d+=1
 if node is Node3D: row.node3d+=1
 if node is PhysicsBody2D: row.physics2d+=1
 if node is PhysicsBody3D: row.physics3d+=1
 var script=node.get_script()
 if script is Script:
  var p: String=script.resource_path
  if not p.is_empty() and not row.scripts.has(p): row.scripts.append(p)
 for child in node.get_children(): visit(child,row)
func run():
 var menu=load("res://scenes/frontend.tscn").instantiate()
 menu.load_user_settings=false
 menu.test_settings_directory=OS.get_environment("TEMP").path_join("migration_inventory_profiles")
 root.add_child(menu)
 await process_frame
 for route in ["native_polygon","legacy_polygon","prologue","prologue_v2","terra","hub"]:
  menu.selected_weapon="stg44"
  menu.selected_level=route
  menu.launch(route not in ["native_polygon","legacy_polygon"],route=="legacy_polygon")
  for i in 4: await process_frame
  var row={"route":route,"root_type":menu.game.get_class(),"root_script":menu.game.get_script().resource_path,"node2d":0,"node3d":0,"physics2d":0,"physics3d":0,"scripts":[]}
  visit(menu.game,row)
  results.append(row)
  print("MIGRATION_ROUTE ",route," root=",row.root_type," physics2d=",row.physics2d," physics3d=",row.physics3d)
  menu.return_to_menu()
  for i in 4: await process_frame
 var destination=preload("res://tools/media_paths.gd").path("docs/core/full_migration_audit_2026-11-13/runtime_inventory.json")
 var file=FileAccess.open(destination,FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "))
 file.close()
 print("MIGRATION_INVENTORY ",destination)
 menu.queue_free()
 await process_frame
 quit()
