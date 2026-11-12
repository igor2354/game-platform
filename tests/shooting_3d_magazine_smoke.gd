extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.set_process(false)
 scene.player.set_physics_process(false)
 scene.combat.set_process(false)
 scene.combat.set_physics_process(false)
 var combat = scene.combat
 var gun = combat.gun
 gun.set_physics_process(false)
 var failures := 0
 for entry in preload("res://scripts/campaign/catalog.gd").WEAPONS:
  combat.equip(entry.id)
  gun.tuning.sound_enabled = false
  combat.weapon_parts.clear()
  combat._process(.016)
  gun.magazine = 0
  combat.reload_start = Vector3.RIGHT
  if not gun.begin_reload(): failures += 1
  gun._physics_process(gun.reload_duration_active*.41)
  if combat.weapon_parts.dropped.size()!=0: failures += 1
  gun._physics_process(gun.reload_duration_active*.02)
  if combat.weapon_parts.dropped.size()!=1: failures += 1
  combat._process(.016)
  if entry.id=="stg44":
   if combat.weapon_parts.parts.is_empty() or combat.weapon_parts.parts[0].visible: failures += 1
  elif combat.weapon_parts.proxy.visible: failures += 1
  gun._physics_process(gun.reload_duration_active*.11)
  combat._process(.016)
  if entry.id=="stg44" and not combat.weapon_parts.parts[0].visible: failures += 1
  gun.cancel_reload()
  combat._process(.016)
  if gun.magazine!=0 or gun.reserve!=entry.values.starting_reserve: failures += 1
  combat.weapon_parts.clear()
  if combat.weapon_parts.dropped.size()!=0: failures += 1
 print("RELOAD_3D_VISUAL_LIFECYCLE failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
