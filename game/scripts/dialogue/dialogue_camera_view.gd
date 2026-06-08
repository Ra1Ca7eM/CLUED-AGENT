extends Node3D

## Camera cinematografica del dialogo: inquadra giocatore (a sinistra) e NPC
## (al centro-destra), con tween di entrata/uscita e rotazione dei modelli.

const TWEEN_DURATION := 0.7
const ROTATE_DURATION := 0.5
const SIDE_OFFSET := 1.9
const BACK_OFFSET := 1.7
const EYE_HEIGHT := 1.55
const LOOK_HEIGHT := 1.35
const WALL_MARGIN := 0.4
const RAY_MASK := 0xFFFFF
const MIN_CAM_DISTANCE := 1.0
const UNBLOCKED_BONUS := 100.0

@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D

var _active: bool = false
var _player: Node3D = null
var _npc: Node3D = null
var _player_cam: Camera3D = null
var _tween: Tween = null
var _cam_from: Transform3D = Transform3D.IDENTITY
var _cam_to: Transform3D = Transform3D.IDENTITY
var _look_point: Vector3 = Vector3.ZERO
var _ray_exclude: Array[RID] = []


func _ready() -> void:
	visible = false
	if camera:
		camera.current = false


func is_active() -> bool:
	return _active


func start(player: Node3D, npc: Node3D) -> void:
	if _active or camera == null or player == null or npc == null:
		return
	_player = player
	_npc = npc
	_player_cam = player.get_node_or_null("Head/SpringArm3D/Camera3D") as Camera3D
	_ray_exclude = _build_ray_exclude(player, npc)

	var start_xform := _player_cam.global_transform if _player_cam else camera.global_transform
	_cam_from = start_xform
	_cam_to = _compute_dialogue_camera_transform(player, npc)
	var mid := (player.global_position + npc.global_position) * 0.5
	_look_point = mid + Vector3(0.0, LOOK_HEIGHT, 0.0)

	camera.global_transform = start_xform
	if _player_cam:
		camera.fov = _player_cam.fov
	camera.current = true
	visible = true
	_active = true

	_rotate_actors(player, npc)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply_camera_lerp, 0.0, 1.0, TWEEN_DURATION)


func end() -> void:
	if not _active:
		return
	_cam_from = camera.global_transform
	_cam_to = _player_cam.global_transform if _player_cam else _cam_from

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply_camera_lerp, 0.0, 1.0, TWEEN_DURATION)
	_tween.tween_callback(_finish_end)


func _finish_end() -> void:
	if _player_cam:
		_player_cam.current = true
	if camera:
		camera.current = false
	visible = false
	_active = false
	_player = null
	_npc = null
	_player_cam = null
	_ray_exclude.clear()


func _apply_camera_lerp(t: float) -> void:
	if camera == null:
		return
	var blended := _cam_from.interpolate_with(_cam_to, t)
	var safe_origin := blended.origin
	if _look_point != Vector3.ZERO and not _ray_exclude.is_empty():
		safe_origin = _clamp_position_to_geometry(_look_point, blended.origin, _ray_exclude)
	camera.global_transform = Transform3D(blended.basis, safe_origin)


func _compute_dialogue_camera_transform(player: Node3D, npc: Node3D) -> Transform3D:
	var p := player.global_position
	var n := npc.global_position
	var mid := (p + n) * 0.5
	var dir := n - p
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var look_point := mid + Vector3(0.0, LOOK_HEIGHT, 0.0)
	var exclude := _build_ray_exclude(player, npc)

	var best_pos := look_point + Vector3.FORWARD
	var best_score := -1.0
	for side_sign: float in [1.0, -1.0]:
		var side: Vector3 = Vector3.UP.cross(dir).normalized() * side_sign
		var raw_pos := mid + side * SIDE_OFFSET - dir * BACK_OFFSET + Vector3(0.0, EYE_HEIGHT, 0.0)
		var safe_pos := _clamp_position_to_geometry(look_point, raw_pos, exclude)
		var blocked := _is_segment_blocked(look_point, raw_pos, exclude)
		var dist := look_point.distance_to(safe_pos)
		var score := dist
		if not blocked:
			score += UNBLOCKED_BONUS
		if dist < MIN_CAM_DISTANCE:
			score -= 50.0
		if score > best_score:
			best_score = score
			best_pos = safe_pos

	var xform := Transform3D(Basis.IDENTITY, best_pos)
	return xform.looking_at(look_point, Vector3.UP)


func _build_ray_exclude(player: Node3D, npc: Node3D) -> Array[RID]:
	var exclude: Array[RID] = []
	_append_collision_rids(player, exclude)
	_append_collision_rids(npc, exclude)
	return exclude


func _append_collision_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid := (node as CollisionObject3D).get_rid()
		if not out.has(rid):
			out.append(rid)
	for child in node.get_children():
		_append_collision_rids(child, out)


func _get_space_state() -> PhysicsDirectSpaceState3D:
	var world := get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


func _clamp_position_to_geometry(from: Vector3, to: Vector3, exclude: Array[RID]) -> Vector3:
	var space := _get_space_state()
	if space == null:
		return to
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.collide_with_areas = false
	ray.collision_mask = RAY_MASK
	ray.exclude = exclude
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return to
	return hit.position + hit.normal * WALL_MARGIN


func _is_segment_blocked(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var space := _get_space_state()
	if space == null:
		return false
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.collide_with_areas = false
	ray.collision_mask = RAY_MASK
	ray.exclude = exclude
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return false
	return from.distance_to(hit.position) < from.distance_to(to) - 0.15


func _rotate_actors(player: Node3D, npc: Node3D) -> void:
	var pp := player.global_position
	var np := npc.global_position

	var d_to_player := pp - np
	var npc_yaw := atan2(d_to_player.x, d_to_player.z) + PI

	var d_to_npc := np - pp
	var player_yaw := atan2(d_to_npc.x, d_to_npc.z)

	var npc_rotate := NpcCast.get_facing_node(npc) if NpcCast.is_scene_npc(npc) else npc

	var t := create_tween()
	t.set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(npc_rotate, "rotation:y", npc_rotate.rotation.y + angle_difference(npc_rotate.rotation.y, npc_yaw), ROTATE_DURATION)

	var player_model := player.get("visual_model") as Node3D
	if player_model:
		t.tween_property(player_model, "rotation:y", player_model.rotation.y + angle_difference(player_model.rotation.y, player_yaw), ROTATE_DURATION)
