class_name DoorPortalService
extends RefCounted

const GARDEN_SPAWN := Vector3(412.0, 2.25, 50.95)
const KITCHEN_SPAWN := Vector3(-5.2, 0.6, 3.55)

const PORTAL_SPAWNS := {
	"door_B2": GARDEN_SPAWN,
	"door_B4": KITCHEN_SPAWN,
}

static var _busy := false


static func is_portal(door_name: String) -> bool:
	return PORTAL_SPAWNS.has(door_name)


static func get_spawn(door_name: String) -> Vector3:
	return PORTAL_SPAWNS.get(door_name, Vector3.ZERO)


static func setup(host: Node3D) -> void:
	if host == null:
		return
	for door_name in PORTAL_SPAWNS:
		var door := host.get_node_or_null("Door/" + door_name)
		if door == null:
			push_warning("DoorPortalService: door not found: Door/%s" % door_name)
			continue
		for child in door.get_children():
			if not child is DoorController:
				continue
			var ctrl := child as DoorController
			if ctrl.has_meta("portal_toggled_connected"):
				break
			ctrl.set_meta("portal_toggled_connected", true)
			var scene_host := host
			ctrl.toggled.connect(func(c: Node, is_open: bool) -> void:
				_on_door_toggled(scene_host, c, is_open)
			)
			break


static func _on_door_toggled(host: Node3D, ctrl: Node, is_open: bool) -> void:
	if not is_open or not (ctrl is DoorController):
		return
	var door_ctrl := ctrl as DoorController
	var interactor := door_ctrl.get_interactor()
	if interactor != null and interactor.is_in_group("agents"):
		return
	_run_portal_teleport(host, door_ctrl)


static func _run_portal_teleport(host: Node3D, ctrl: DoorController) -> void:
	await teleport_interactor(ctrl, host)


static func _door_name(ctrl: DoorController) -> String:
	if ctrl == null or ctrl.get_parent() == null:
		return ""
	return ctrl.get_parent().name


static func _lock_movement_for(body: Node3D) -> bool:
	return not body.is_in_group("agents")


static func teleport_interactor(ctrl: DoorController, host: Node3D) -> void:
	if ctrl == null or host == null:
		return
	var door_name := _door_name(ctrl)
	if not is_portal(door_name):
		return
	if _busy:
		await _wait_until_idle(host)
		return
	var body := ctrl.get_interactor()
	if body == null:
		return
	_busy = true
	var spawn: Vector3 = PORTAL_SPAWNS[door_name]
	if body.is_in_group("agents"):
		SceneTransition.instant_teleport(body, spawn, host)
		if body.has_method("notify_portal_teleport"):
			body.notify_portal_teleport(door_name)
	else:
		await SceneTransition.fade_teleport(
			body,
			spawn,
			host,
			0.5,
			_lock_movement_for(body)
		)
	ctrl.force_close(true)
	ctrl.clear_interactor()
	_busy = false


static func _wait_until_idle(host: Node3D) -> void:
	while _busy:
		await host.get_tree().process_frame
