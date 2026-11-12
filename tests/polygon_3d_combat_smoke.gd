extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var scene = load("res://scenes/core/polygon_3d.tscn").instantiate()
 scene.load_user_settings = false
 root.add_child(scene)
 scene.combat.set_process(false)
 var failures := 0
 var target = scene.combat.targets[0]
 var gun = scene.combat.gun
 for entry in preload("res://scripts/campaign/catalog.gd").WEAPONS:
  target.reset()
  scene.combat.equip(entry.id)
  var start: Vector3 = target.position+Vector3(-1,.9,0)
  if not gun.fire(start,Vector3.RIGHT): failures += 1
  for i in 12: await physics_frame
  if absf(target.health-(100-entry.values.damage))>.01: failures += 1
  if gun.magazine!=entry.values.magazine_capacity-1: failures += 1
 print("COMBAT_3D_IN_GAME failures=",failures)
 scene.queue_free()
 await process_frame
 quit(int(failures>0))
