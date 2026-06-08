extends Node3D

## Camera di ispezione: inquadratura configurabile sul baricentro visivo dell'oggetto.

const DEFAULT_CAM_DISTANCE := 0.85
const DEFAULT_LIGHT_SPOT_ANGLE_DEG := 28.0
const DEFAULT_LIGHT_ENERGY := 6.0
const DEFAULT_UV_LIGHT_SCALE := 8.0 / 6.0

@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D

var _active: bool = false
var _inspected_item: Node3D = null
var _player_ref: Node = null
var _uv_overlay: bool = false
var _spot: SpotLight3D = null
var _cam_distance: float = DEFAULT_CAM_DISTANCE
var _cam_rotation_degrees: Vector3 = Vector3.ZERO
var _light_spot_angle_deg: float = DEFAULT_LIGHT_SPOT_ANGLE_DEG
var _light_energy: float = DEFAULT_LIGHT_ENERGY
var _uv_light_energy_scale: float = DEFAULT_UV_LIGHT_SCALE


func _ready() -> void:
	visible = false
	if camera:
		camera.current = false
	_build_inspection_spot()


func _build_inspection_spot() -> void:
	if camera == null:
		return
	_spot = SpotLight3D.new()
	_spot.name = "InspectionSpot"
	_spot.light_color = Color(1, 0.97, 0.85)
	_spot.light_energy = DEFAULT_LIGHT_ENERGY
	_spot.spot_range = 4.0
	_spot.spot_angle = DEFAULT_LIGHT_SPOT_ANGLE_DEG
	_spot.spot_angle_attenuation = 0.5
	_spot.shadow_enabled = false
	_spot.visible = false
	camera.add_child(_spot)


func is_active() -> bool:
	return _active


func start(item: Node, player: Node = null) -> void:
	if _active:
		return
	if item == null or not (item is Node3D):
		return
	if camera == null:
		return

	GameState.inspection_active = true

	_inspected_item = item as Node3D
	_player_ref = player
	_load_inspection_tuning_from_item(item)

	var focus := _approx_visual_center(_inspected_item)
	var cam_xform := _compute_camera_global_transform(focus)
	camera.global_transform = cam_xform

	_sync_spotlight(false)

	if _player_ref and _player_ref.has_method("capture_mouse"):
		_player_ref.capture_mouse()

	_uv_overlay = false
	if _inspected_item and _inspected_item.has_method("apply_uv_highlight"):
		_inspected_item.call("apply_uv_highlight", false)
	_active = true
	visible = true
	camera.current = true


func stop() -> void:
	if not _active:
		return

	if _uv_overlay:
		set_uv_mode(false)

	if _spot:
		_spot.visible = false

	if _player_ref and _player_ref.has_method("release_mouse"):
		_player_ref.release_mouse()

	_active = false
	visible = false
	if camera:
		camera.current = false

	if _inspected_item and _inspected_item.has_method("apply_uv_highlight"):
		_inspected_item.call("apply_uv_highlight", false)

	_inspected_item = null
	_player_ref = null
	_uv_overlay = false
	GameState.inspection_active = false


func set_uv_mode(active: bool) -> void:
	if _uv_overlay == active or not _active:
		return
	_uv_overlay = active
	_sync_spotlight(active)
	if active and _inspected_item and _inspected_item.has_method("reveal_under_uv"):
		_inspected_item.call("reveal_under_uv")
	if _inspected_item and _inspected_item.has_method("apply_uv_highlight"):
		_inspected_item.call("apply_uv_highlight", active)


func handle_mouse_motion(_relative: Vector2) -> void:
	pass


func _load_inspection_tuning_from_item(item: Node) -> void:
	_cam_distance = DEFAULT_CAM_DISTANCE
	_cam_rotation_degrees = Vector3.ZERO
	_light_spot_angle_deg = DEFAULT_LIGHT_SPOT_ANGLE_DEG
	_light_energy = DEFAULT_LIGHT_ENERGY
	_uv_light_energy_scale = DEFAULT_UV_LIGHT_SCALE

	if item == null or not item.has_method("get_inspection_tuning"):
		return
	var tuning: Dictionary = item.call("get_inspection_tuning")
	if tuning.has("cam_distance"):
		_cam_distance = float(tuning["cam_distance"])
	if tuning.has("cam_rotation_degrees"):
		_cam_rotation_degrees = tuning["cam_rotation_degrees"]
	if tuning.has("light_spot_angle_deg"):
		_light_spot_angle_deg = float(tuning["light_spot_angle_deg"])
	if tuning.has("light_energy"):
		_light_energy = float(tuning["light_energy"])
	if tuning.has("uv_light_energy_scale"):
		_uv_light_energy_scale = float(tuning["uv_light_energy_scale"])


func _sync_spotlight(uv_mode: bool) -> void:
	if _spot == null:
		return
	_spot.spot_angle = _light_spot_angle_deg
	_spot.light_color = Color(0.55, 0.1, 1.0) if uv_mode else Color(1, 0.97, 0.85)
	_spot.light_energy = _light_energy * _uv_light_energy_scale if uv_mode else _light_energy
	_spot.visible = true


func _approx_visual_center(item: Node3D) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	var stack: Array[Node] = [item]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh and mi.visible:
				sum += mi.global_transform * mi.get_aabb().get_center()
				count += 1
	if count > 0:
		return sum / float(count)

	var col := item.find_child("CollisionShape3D", true, false)
	if col is CollisionShape3D:
		var csh := col as CollisionShape3D
		if csh.shape is BoxShape3D:
			var half := (csh.shape as BoxShape3D).size * 0.5
			return item.global_transform * (csh.position + Vector3(0.0, half.y * 0.2, 0.0))

	return item.global_position + Vector3(0.0, 0.1, 0.0)


func _compute_camera_global_transform(focus: Vector3) -> Transform3D:
	if _cam_rotation_degrees.length_squared() < 0.0001:
		camera.global_position = focus + Vector3(0.0, _cam_distance, 0.0)
	else:
		var pitch := deg_to_rad(_cam_rotation_degrees.x)
		var yaw := deg_to_rad(_cam_rotation_degrees.y)
		var forward := Vector3(
			-sin(yaw) * cos(pitch),
			-sin(pitch),
			-cos(yaw) * cos(pitch)
		).normalized()
		camera.global_position = focus - forward * _cam_distance

	var up := Vector3.UP
	if abs(camera.global_position.direction_to(focus).dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD
	camera.look_at(focus, up)

	var roll := _cam_rotation_degrees.z
	if abs(roll) > 0.001:
		camera.rotate(camera.global_transform.basis.z, deg_to_rad(roll))

	return camera.global_transform
