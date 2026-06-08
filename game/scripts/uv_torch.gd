class_name UVTorch
extends Node3D

var _light: SpotLight3D
var _was_active: bool = false

const SPOT_ANGLE_DEG := 22.0
const SPOT_RANGE := 20.0

func _ready() -> void:
	_light = SpotLight3D.new()
	_light.name = "UVLight"
	_light.light_color = Color(0.5, 0.0, 1.0)
	_light.light_energy = 3.0
	_light.spot_range = SPOT_RANGE
	_light.spot_angle = SPOT_ANGLE_DEG
	_light.spot_angle_attenuation = 0.7
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)

func _process(_delta: float) -> void:
	# In ispezione la UV è gestita da inspection_view (spot viola + highlight sull'oggetto).
	if GameState.inspection_active:
		_light.visible = false
		if _was_active:
			_clear_all_highlights()
			_was_active = false
		return

	var active := Input.is_action_pressed("uv_torch")
	_light.visible = active

	if active:
		_scan_uv_reactive()
		_was_active = true
	elif _was_active:
		_clear_all_highlights()
		_was_active = false

func _scan_uv_reactive() -> void:
	var head_pos := global_position
	var forward := -global_transform.basis.z
	var cos_angle := cos(deg_to_rad(SPOT_ANGLE_DEG))
	var space := get_world_3d().direct_space_state

	for node in get_tree().get_nodes_in_group("uv_reactive"):
		var target_points := _resolve_target_points(node)
		if target_points.is_empty():
			if node.has_method("apply_uv_highlight"):
				node.call("apply_uv_highlight", false)
			continue
		var primary_target: Vector3 = target_points[0]
		var to_node: Vector3 = primary_target - head_pos
		var dist := to_node.length()

		if dist > SPOT_RANGE or dist < 0.01:
			node.call("apply_uv_highlight", false)
			continue

		var dir := to_node / dist
		if dir.dot(forward) < cos_angle:
			node.call("apply_uv_highlight", false)
			continue

		# Raycast LoS: prova più punti (centro + offset in alto) per indizi a terra.
		var has_los := _has_line_of_sight(space, head_pos, target_points, node)

		if has_los:
			node.call("reveal_under_uv")
			node.call("apply_uv_highlight", true)
		else:
			node.call("apply_uv_highlight", false)

func _resolve_target_points(node: Node) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is Node3D:
		var node3d := node as Node3D
		var col := node3d.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			var base := col.global_position
			points.append(base)
			points.append(base + Vector3(0.0, 0.25, 0.0))
			points.append(base + Vector3(0.0, 0.55, 0.0))
			return points
		var pos := node3d.global_position
		points.append(pos + Vector3(0.0, 0.2, 0.0))
		points.append(pos + Vector3(0.0, 0.5, 0.0))
	return points

func _has_line_of_sight(space: PhysicsDirectSpaceState3D, from_pos: Vector3, targets: Array[Vector3], node: Node) -> bool:
	for target in targets:
		var query := PhysicsRayQueryParameters3D.create(from_pos, target)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = []
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		if hit.has("collider"):
			var col: Object = hit["collider"]
			if col == node:
				return true
			if col is Node:
				var hit_node := col as Node
				if hit_node == node or node.is_ancestor_of(hit_node):
					return true
		# Se il primo impatto è molto vicino al target, evita falsi negativi su tracce rasoterra.
		if hit.has("position") and (hit["position"] as Vector3).distance_to(target) < 0.35:
			return true
	return false

func _clear_all_highlights() -> void:
	for node in get_tree().get_nodes_in_group("uv_reactive"):
		node.call("apply_uv_highlight", false)
