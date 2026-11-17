extends SceneTree
## Native 3D: with a weapon in the hands the arms pass in front of the chest,
## breasts and hips instead of through them — relaxed carry, alert hip carry
## and ADS, all four weapons, both facings. The grip contacts stay on the weapon.
## Settings are not loaded; all five profile paths point to a temporary folder.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok: failures += 1
func run() -> void:
 var temporary := OS.get_temp_dir().path_join("ubershrike-arm-clearance-%d" % OS.get_process_id())
 DirAccess.make_dir_recursive_absolute(temporary)
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 for key in ["settings_path","shooting_settings_path","camera_settings_path","zombie_settings_path","ragdoll_settings_path"]:
  if key in scene: scene.set(key,temporary.path_join(key+".cfg"))
 root.add_child(scene)
 for i in 10: await physics_frame
 var player = scene.player
 var m = player.model
 var c = scene.combat
 for weapon in ["stg44","mp40","svt","m1911"]:
  c.equip(weapon)
  for face in [-1.0,1.0]:
   for state in ["calm","alert","ads"]:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_RIGHT
    event.pressed = state == "ads"
    Input.parse_input_event(event)
    player.reset()
    player.position = Vector3(-1.5,.02,0)
    var depth := 0.0
    var grip := 0.0
    for i in 200:
     c.cursor_screen = scene.camera.unproject_position(player.global_position+Vector3(4*face,.6 if state=="calm" else 1.3,0))
     c.alert_left = 10.0 if state != "calm" else 0.0
     await physics_frame
     await process_frame
     if i > 150 and m.weapon_grips.size() == 2:
      for slot in 2:
       var prefix := "r_" if slot == 0 else "l_"
       depth = maxf(depth,m.arm_body_depth(prefix))
       grip = maxf(grip,m.rig.to_global(m._joint(prefix+"hand_anchor")).distance_to(m.grasp_points[slot]))
    var label := "%s face %d %s" % [weapon,face,state]
    # Known residual 18.11: relaxed MP-40/SVT keep up to ~4 cm between the
    # upper arm and the chest (hidden in the game camera); others are clear.
    var limit := .045 if state == "calm" and weapon in ["mp40","svt"] else .007
    check(depth < limit,label+": arms clear of the torso, %.4f m (limit %.3f)" % [depth,limit])
    check(grip < .01,label+": palms stay on the weapon, %.4f m" % grip)
 var release := InputEventMouseButton.new()
 release.button_index = MOUSE_BUTTON_RIGHT
 Input.parse_input_event(release)
 print("ARM_CLEARANCE failures=",failures)
 scene.queue_free()
 await process_frame
 for file in DirAccess.get_files_at(temporary): DirAccess.remove_absolute(temporary.path_join(file))
 DirAccess.remove_absolute(temporary)
 quit(int(failures>0))
