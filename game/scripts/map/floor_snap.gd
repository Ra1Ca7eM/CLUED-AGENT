extends RefCounted
class_name FloorSnap

const MIN_FLOOR_NORMAL_Y := 0.65


static func snap_feet_to_floor(world_node: Node, feet_pos: Vector3, ray_up: float = 0.35, ray_down: float = 3.0) -> Vector3:
	var w3d: World3D = world_node.get_world_3d()
	if w3d == null:
		return feet_pos
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state
	var from_g := feet_pos + Vector3(0.0, ray_up, 0.0)
	var to_g := feet_pos + Vector3(0.0, -ray_down, 0.0)
	var ray := PhysicsRayQueryParameters3D.create(from_g, to_g)
	ray.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return feet_pos
	var n: Vector3 = hit.get("normal", Vector3.UP)
	if n.y < MIN_FLOOR_NORMAL_Y:
		return feet_pos
	var hit_pos: Vector3 = hit.get("position", feet_pos)
	if hit_pos.y > feet_pos.y + 0.45:
		return feet_pos
	var out := feet_pos
	out.y = hit_pos.y + 0.02
	return out
