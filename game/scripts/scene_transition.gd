extends CanvasLayer

const FloorSnap := preload("res://scripts/map/floor_snap.gd")

var _rect: ColorRect
var _return_spawn: Variant = null
var _busy: bool = false

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

func fade_teleport(
	player: Node3D,
	world_pos: Vector3,
	host: Node3D,
	duration: float = 0.5,
	lock_movement: bool = true,
) -> void:
	if _busy or player == null or host == null:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if lock_movement:
		_set_player_locked(player, true)
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished
	var pos: Vector3 = FloorSnap.snap_feet_to_floor(host, world_pos)
	player.global_position = pos
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	if lock_movement:
		var zone_mgr := host.get_node_or_null("MapZoneManager") as MapZoneManager
		if zone_mgr != null:
			zone_mgr.resync_player_zones()
	await host.get_tree().process_frame
	var tween2 := create_tween()
	tween2.tween_property(_rect, "color:a", 0.0, duration)
	await tween2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lock_movement:
		_set_player_locked(player, false)
	_busy = false


func instant_teleport(body: Node3D, world_pos: Vector3, host: Node3D) -> void:
	if body == null or host == null:
		return
	var pos: Vector3 = FloorSnap.snap_feet_to_floor(host, world_pos)
	body.global_position = pos
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO


func _set_player_locked(player: Node3D, locked: bool) -> void:
	if not player.has_method("set"):
		return
	player.set("can_move", not locked)
	player.set("can_jump", not locked)
	player.set("can_sprint", not locked)


func fade_to(scene_path: String, duration: float = 0.5) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, duration)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tween2 := create_tween()
	tween2.tween_property(_rect, "color:a", 0.0, duration)
	await tween2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func set_return_spawn(pos: Vector3) -> void:
	_return_spawn = pos

func get_return_spawn() -> Variant:
	return _return_spawn

func clear_return_spawn() -> void:
	_return_spawn = null
