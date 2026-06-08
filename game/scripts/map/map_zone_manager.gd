extends Node
class_name MapZoneManager

const CATALOG := preload("res://scripts/map/map_room_catalog.gd")
const PROJECTION := preload("res://scripts/map/map_projection.gd")
const PLAYER_COLLISION_MASK := 1048575
const INVALID_MAP_POS := Vector2(-1.0, -1.0)

var _player: Node3D = null
var _zones: Array[Dictionary] = []
var _active_stack: Array[Area3D] = []
var _zone_by_area: Dictionary = {}


func setup(host: Node3D, player: Node3D) -> void:
	_player = player
	_discover_zones(host)
	_sync_inspectable_map_positions(host)
	_sync_initial_overlaps()


func _discover_zones(host: Node3D) -> void:
	_zones.clear()
	_zone_by_area.clear()
	var mappa := host.get_node_or_null("House/Mappa") as Node3D
	if mappa == null:
		push_warning("MapZoneManager: House/Mappa non trovato.")
		return
	_collect_map_zones(mappa)


func _collect_map_zones(node: Node) -> void:
	if node is Area3D and node.name.begins_with("MapZone_"):
		_register_zone(node as Area3D)
	for child in node.get_children():
		_collect_map_zones(child)


func _register_zone(area: Area3D) -> void:
	var suffix := CATALOG.parse_zone_node_name(area.name)
	if suffix == "":
		return
	var floor_idx := _floor_idx_for_zone(area)
	var map_key := CATALOG.resolve_zone_suffix(suffix, floor_idx)
	if map_key == "" or CATALOG.get_room_rect(floor_idx, map_key) == Rect2():
		push_warning("MapZone senza rettangolo mappa: %s (floor %d key %s)" % [area.name, floor_idx, map_key])
		return

	area.monitoring = true
	area.monitorable = true
	area.collision_mask = PLAYER_COLLISION_MASK
	if not area.body_entered.is_connected(_on_zone_body_entered):
		area.body_entered.connect(_on_zone_body_entered.bind(area))
	if not area.body_exited.is_connected(_on_zone_body_exited):
		area.body_exited.connect(_on_zone_body_exited.bind(area))

	var entry: Dictionary = {
		"area": area,
		"floor_idx": floor_idx,
		"map_key": map_key,
	}
	_zones.append(entry)
	_zone_by_area[area] = entry


func _floor_idx_for_zone(area: Area3D) -> int:
	var n: Node = area.get_parent()
	while n != null:
		if n.name == CATALOG.FLOOR_FOLDER_GROUND:
			return CATALOG.MapFloor.GROUND
		if n.name == CATALOG.FLOOR_FOLDER_FIRST:
			return CATALOG.MapFloor.FIRST
		if n.name == CATALOG.FLOOR_FOLDER_BASEMENT:
			return CATALOG.MapFloor.BASEMENT
		if n.name == CATALOG.FLOOR_FOLDER_GARDEN:
			return CATALOG.MapFloor.GARDEN
		n = n.get_parent()
	return CATALOG.MapFloor.GROUND


func _sync_inspectable_map_positions(host: Node3D) -> void:
	if _zones.is_empty():
		return
	var inspectables := host.get_node_or_null("Inspectables")
	if inspectables == null:
		return
	for child in inspectables.get_children():
		if child is Area3D:
			_apply_clue_map_from_zone(child as Area3D)


func _apply_clue_map_from_zone(clue: Area3D) -> void:
	var clue_id := str(clue.get("map_clue_id")) if clue.get("map_clue_id") != null else ""
	if clue_id == "":
		return

	var use_zone: bool = true
	if clue.get("use_zone_map_position") != null:
		use_zone = bool(clue.get("use_zone_map_position"))
	if not use_zone:
		return

	var display_name := str(clue.get("display_name"))
	var fallback_floor := int(clue.get("map_floor"))
	var fallback_pos: Vector2 = clue.get("map_position")
	var metadata := _build_clue_metadata(clue_id, clue)

	var sample_pos := _clue_map_sample_position(clue)
	var floor_zones := _zones_for_floor(fallback_floor)
	var entry := PROJECTION.find_best_zone_for_point(sample_pos, floor_zones)
	if entry.is_empty():
		push_warning("Indizio '%s' fuori da MapZone (piano %d) — uso map_position dall'editor." % [clue_id, fallback_floor])
		GameState.register_map_clue(clue_id, display_name, fallback_floor, fallback_pos, metadata)
		return

	var design_pos := PROJECTION.world_to_design_from_entry(sample_pos, entry)
	if design_pos.x < 0.0:
		GameState.register_map_clue(clue_id, display_name, fallback_floor, fallback_pos, metadata)
		return

	GameState.register_map_clue(clue_id, display_name, fallback_floor, design_pos, metadata)

func _clue_map_sample_position(clue: Area3D) -> Vector3:
	var col := clue.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null:
		return col.global_position
	return clue.global_position


func _build_clue_metadata(clue_id: String, clue: Area3D) -> Dictionary:
	var image_root := "res://MODELLI3D/INDIZI_IMAGES/"
	var meta: Dictionary = {
		"normal_desc": str(clue.get("description")),
		"uv_desc": str(clue.get("uv_description")),
		"image_path": image_root + clue_id + ".png",
		"uv_image_path": image_root + clue_id + "_uv.png",
		"requires_inspection_uv_reveal": _clue_requires_inspection_uv_reveal(clue),
	}
	if clue.has_method("is_inspection_uv_detail_revealed") and clue.call("is_inspection_uv_detail_revealed"):
		meta["uv_detail_revealed"] = true
	return meta


func _clue_requires_inspection_uv_reveal(clue: Area3D) -> bool:
	if clue.has_method("requires_inspection_uv_reveal"):
		return bool(clue.call("requires_inspection_uv_reveal"))
	var paths: Variant = clue.get("uv_required_to_reveal_only_inspection_mode_meshes")
	if paths is Array:
		return not (paths as Array).is_empty()
	return false


func _zones_for_floor(floor_idx: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _zones:
		if int(entry.get("floor_idx", -1)) == floor_idx:
			out.append(entry)
	return out


func _sync_initial_overlaps() -> void:
	resync_player_zones()


func resync_player_zones() -> void:
	_active_stack.clear()
	if _player == null:
		GameState.clear_map_context()
		return

	var overlapping: Array[Area3D] = []
	for entry in _zones:
		var area: Area3D = entry["area"] as Area3D
		if area.overlaps_body(_player):
			overlapping.append(area)

	if overlapping.is_empty():
		GameState.clear_map_context()
		if GameState.player_map_position != INVALID_MAP_POS:
			GameState.set_player_map_position(INVALID_MAP_POS)
		return

	overlapping.sort_custom(_sort_areas_by_zone_span)
	for area in overlapping:
		_active_stack.append(area)
	_apply_active_zone()


func _sort_areas_by_zone_span(a: Area3D, b: Area3D) -> bool:
	return _zone_span(a) < _zone_span(b)


func _zone_span(area: Area3D) -> float:
	var entry: Dictionary = _zone_by_area.get(area, {})
	if entry.is_empty():
		return INF
	var bounds := PROJECTION.global_xz_bounds(area)
	if bounds.is_empty():
		return INF
	var span_x: float = bounds["max_x"] - bounds["min_x"]
	var span_z: float = bounds["max_z"] - bounds["min_z"]
	return span_x * span_z


func _on_zone_body_entered(body: Node3D, area: Area3D) -> void:
	if body != _player:
		return
	_push_zone(area)


func _on_zone_body_exited(body: Node3D, area: Area3D) -> void:
	if body != _player:
		return
	_pop_zone(area)


func _push_zone(area: Area3D) -> void:
	if area in _active_stack:
		_active_stack.erase(area)
	_active_stack.append(area)
	_apply_active_zone()


func _pop_zone(area: Area3D) -> void:
	_active_stack.erase(area)
	_apply_active_zone()


func _apply_active_zone() -> void:
	if _active_stack.is_empty():
		GameState.clear_map_context()
		return
	var area: Area3D = _active_stack[_active_stack.size() - 1]
	var entry: Dictionary = _zone_by_area.get(area, {})
	if entry.is_empty():
		return
	var floor_idx: int = entry["floor_idx"]
	var map_key: String = entry["map_key"]
	var display_name: String = CATALOG.get_display_name(map_key)
	GameState.set_map_context(map_key, floor_idx, display_name)


func _process(_delta: float) -> void:
	if _player == null or _active_stack.is_empty():
		if GameState.player_map_position != INVALID_MAP_POS:
			GameState.set_player_map_position(INVALID_MAP_POS)
		return

	var area: Area3D = _active_stack[_active_stack.size() - 1]
	var entry: Dictionary = _zone_by_area.get(area, {})
	if entry.is_empty():
		return

	var design_pos := PROJECTION.world_to_design_from_entry(_player.global_position, entry)
	GameState.set_player_map_position(design_pos)
