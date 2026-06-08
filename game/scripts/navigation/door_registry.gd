class_name DoorRegistry
extends RefCounted

static var _physical_doors: Dictionary = {}


static func register(physical_name: String, controller: DoorController) -> void:
	_physical_doors[physical_name] = controller


static func get_controller(door_name: String) -> DoorController:
	return _physical_doors.get(door_name) as DoorController
