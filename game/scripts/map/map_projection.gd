extends RefCounted
class_name MapProjection

const CATALOG := preload("res://scripts/map/map_room_catalog.gd")
const INVALID_MAP_POS := Vector2(-1.0, -1.0)


static func global_xz_bounds(area: Area3D) -> Dictionary:
	var col := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null or col.shape == null:
		return {}
	var box := col.shape as BoxShape3D
	if box == null:
		return {}

	var gt := col.global_transform
	var half := box.size * 0.5
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var local := Vector3(sx * half.x, 0.0, sz * half.z)
			var g: Vector3 = gt * local
			min_x = minf(min_x, g.x)
			max_x = maxf(max_x, g.x)
			min_z = minf(min_z, g.z)
			max_z = maxf(max_z, g.z)

	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


static func point_inside_bounds(world_pos: Vector3, bounds: Dictionary) -> bool:
	if bounds.is_empty():
		return false
	return (
		world_pos.x >= bounds["min_x"]
		and world_pos.x <= bounds["max_x"]
		and world_pos.z >= bounds["min_z"]
		and world_pos.z <= bounds["max_z"]
	)


static func world_to_design_from_entry(world_pos: Vector3, zone_entry: Dictionary) -> Vector2:
	var area: Area3D = zone_entry.get("area") as Area3D
	if area == null:
		return INVALID_MAP_POS
	return world_to_design(
		world_pos,
		area,
		int(zone_entry.get("floor_idx", CATALOG.MapFloor.GROUND)),
		str(zone_entry.get("map_key", ""))
	)


static func world_to_design(world_pos: Vector3, area: Area3D, floor_idx: int, map_key: String) -> Vector2:
	var bounds := global_xz_bounds(area)
	if bounds.is_empty() or map_key == "":
		return INVALID_MAP_POS

	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_z: float = bounds["min_z"]
	var max_z: float = bounds["max_z"]
	var span_x: float = max_x - min_x
	var span_z: float = max_z - min_z
	if span_x < 0.001 or span_z < 0.001:
		return INVALID_MAP_POS

	var t_x := clampf((world_pos.x - min_x) / span_x, 0.0, 1.0)
	var t_z := clampf((world_pos.z - min_z) / span_z, 0.0, 1.0)
	if CATALOG.projection_invert_x(floor_idx):
		t_x = 1.0 - t_x
	if CATALOG.projection_invert_z(floor_idx):
		t_z = 1.0 - t_z

	var rect: Rect2 = CATALOG.get_room_rect(floor_idx, map_key)
	if rect == Rect2():
		return INVALID_MAP_POS
	# Giardino: footprint catalogo = grafica tab (non ruotare in canvas).
	# Z mondo -> larghezza, X mondo -> altezza; 180° nel rect per player/indizi.
	if floor_idx == CATALOG.MapFloor.GARDEN and map_key == "garden":
		return rect.position + Vector2((1.0 - t_z) * rect.size.x, t_x * rect.size.y)
	return rect.position + Vector2(t_x * rect.size.x, t_z * rect.size.y)


## Zona più piccola che contiene il punto (preferisce stanze strette vs corridoio largo).
static func find_best_zone_for_point(world_pos: Vector3, zones: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_span := INF
	for entry in zones:
		var area: Area3D = entry.get("area") as Area3D
		if area == null:
			continue
		var bounds := global_xz_bounds(area)
		if not point_inside_bounds(world_pos, bounds):
			continue
		var span_x: float = bounds["max_x"] - bounds["min_x"]
		var span_z: float = bounds["max_z"] - bounds["min_z"]
		var span: float = span_x * span_z
		if span < best_span:
			best_span = span
			best = entry
	return best
