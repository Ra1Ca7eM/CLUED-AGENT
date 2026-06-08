class_name CollisionLayers
extends RefCounted

const WORLD := 1
const PLAYER := 1
const AGENT_BODY := 2
const NPC_INTERACT := 4

# Gli agenti NON collidono tra loro (evita che si incastrino/spingano a vicenda):
# mask = solo WORLD (e il player, che sta sul layer 1). La separazione morbida tra
# agenti e' gestita da get_avoidance_force in vesna.gd.
const AGENT_COLLISION_MASK := WORLD
const PLAYER_COLLISION_MASK := WORLD | AGENT_BODY

const DEFAULT_CAPSULE_RADIUS := 0.4
const CAPSULE_SEPARATION_MARGIN := 0.15


static func configure_agent_body(body: CharacterBody3D) -> void:
	body.collision_layer = AGENT_BODY
	body.collision_mask = AGENT_COLLISION_MASK


static func configure_player_body(body: CharacterBody3D) -> void:
	body.collision_layer = PLAYER
	body.collision_mask = PLAYER_COLLISION_MASK


static func configure_npc_interact_area(area: Area3D) -> void:
	area.collision_layer = NPC_INTERACT
	area.collision_mask = PLAYER


static func get_body_capsule_radius(body: CharacterBody3D) -> float:
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return DEFAULT_CAPSULE_RADIUS


static func capsule_separation_threshold(
	self_body: CharacterBody3D,
	other_body: CharacterBody3D,
	margin: float = CAPSULE_SEPARATION_MARGIN
) -> float:
	return get_body_capsule_radius(self_body) + get_body_capsule_radius(other_body) + margin
