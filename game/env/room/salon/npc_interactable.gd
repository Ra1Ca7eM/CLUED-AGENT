extends Area3D

signal interacted(character_id: String, display_name: String, dialogue: String)
signal player_entered(npc: Area3D)
signal player_exited(npc: Area3D)

var character_id: String = ""
var display_name: String = ""
var dialogue: String = ""
var narrative_role_key: String = ""
var _player_inside: bool = false
var _collision_shape: CollisionShape3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_ray_pickable = true
	monitoring = true
	monitorable = true
	CollisionLayers.configure_npc_interact_area(self)
	_cache_collision_shape()

func setup(
	new_character_id: String,
	new_display_name: String,
	new_dialogue: String,
	new_role_key: String = ""
) -> void:
	character_id = new_character_id
	display_name = new_display_name
	dialogue = new_dialogue
	narrative_role_key = new_role_key

func interact() -> void:
	emit_signal("interacted", character_id, display_name, dialogue)

func _cache_collision_shape() -> void:
	_collision_shape = get_node_or_null("InteractionCollision") as CollisionShape3D
	if _collision_shape == null:
		for child in get_children():
			if child is CollisionShape3D:
				_collision_shape = child as CollisionShape3D
				break
	if _collision_shape == null:
		push_warning("npc_interactable: nessun CollisionShape3D su %s — aggiungi InteractionCollision in scena." % get_path())

func _on_body_entered(body: Node) -> void:
	if _is_player_body(body):
		_player_inside = true
		emit_signal("player_entered", self)

func _on_body_exited(body: Node) -> void:
	if _is_player_body(body):
		_player_inside = false
		emit_signal("player_exited", self)

func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	if body.name == "Player" or body.name == "ProtoController":
		return true
	return body.is_in_group("player")
