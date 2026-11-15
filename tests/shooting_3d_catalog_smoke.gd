extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var gun = load("res://scripts/core/shooting_3d.gd").new()
 world.add_child(gun)
 gun.set_physics_process(false)
 var failures := 0
 for entry in preload("res://scripts/campaign/catalog.gd").WEAPONS:
  gun.equip(entry.id)
  if gun.magazine!=entry.values.magazine_capacity or gun.reserve!=entry.values.starting_reserve: failures += 1
  if not gun.fire(Vector3.ZERO,Vector3.RIGHT): failures += 1
  if gun.magazine!=entry.values.magazine_capacity-1: failures += 1
  if gun.fire(Vector3.ZERO,Vector3.RIGHT): failures += 1
  if not gun.begin_reload(): failures += 1
  gun._physics_process(gun.tuning.reload_duration)
  if gun.magazine!=entry.values.magazine_capacity or gun.reserve!=entry.values.starting_reserve-1: failures += 1
 print("SHOOTING_3D_CATALOG failures=",failures)
 world.queue_free()
 await process_frame
 await process_frame
 quit(int(failures>0))
