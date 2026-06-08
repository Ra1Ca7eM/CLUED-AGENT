class_name NpcCast
extends RefCounted

const HOODED_NODE_NAME := "Rogue_Hooded"
const KAYKIT_VISUAL_BASIS := Basis(Vector3.UP, PI)


static func is_scene_npc(node: Node) -> bool:
	if node.has_method("get_interaction_area"):
		return true
	if node is CharacterBody3D:
		return (
			node.get_node_or_null("InteractionArea") != null
			and node.get_node_or_null("Body") != null
		)
	return false


static func get_interaction_area(agent: Node) -> Area3D:
	if agent.has_method("get_interaction_area"):
		return agent.call("get_interaction_area") as Area3D
	return agent.get_node_or_null("InteractionArea") as Area3D


static func get_agent_body(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node as CharacterBody3D
	var parent := node.get_parent()
	if parent is CharacterBody3D:
		return parent as CharacterBody3D
	return null


static func get_facing_node(agent: Node) -> Node3D:
	var body := agent.get_node_or_null("Body") as Node3D
	return body if body != null else agent as Node3D


static func align_feet_to_salon(agent: CharacterBody3D, salon: Node3D) -> void:
	## Allinea i piedi al piano del salone usando la Y del nodo Salon (XZ da editor,
	## senza raycast globale — in un hotel multi-piano il raycast colpirebbe il piano sbagliato).
	if salon == null:
		return
	var foot_local_y := _capsule_bottom_local_y(agent)
	var pos := agent.global_position
	agent.global_position = Vector3(pos.x, salon.global_position.y - foot_local_y, pos.z)
	agent.velocity = Vector3.ZERO


static func _capsule_bottom_local_y(agent: CharacterBody3D) -> float:
	for child in agent.get_children():
		if child is CollisionShape3D:
			var collision := child as CollisionShape3D
			if collision.shape is CapsuleShape3D:
				var capsule := collision.shape as CapsuleShape3D
				return collision.transform.origin.y - capsule.height * 0.5
	return 0.0


static func apply_cast(agent: CharacterBody3D) -> void:
	_ensure_kaykit_facing(agent)
	var role_key := agent.name.to_lower()
	var role := _narrative_role_from_key(role_key)
	var model_id := GameState.resolve_model_for_role(role)
	var show_hooded := model_id == "rogue_hooded"
	_apply_body_visibility(agent, show_hooded)
	var display_name := GameState.get_role_display_name(role)
	var dialogue := str(NpcDialogues.DIALOGUES.get(model_id, "Non so ancora cosa dire."))
	var interaction := get_interaction_area(agent)
	if interaction != null and interaction.has_method("setup"):
		interaction.call("setup", model_id, display_name, dialogue, role_key)
	_sync_name_label(agent, display_name)


static func _apply_body_visibility(agent: CharacterBody3D, show_hooded: bool) -> void:
	var body := agent.get_node_or_null("Body") as Node3D
	if body == null:
		return
	for child in body.get_children():
		if child.name == HOODED_NODE_NAME:
			child.visible = show_hooded
		else:
			child.visible = not show_hooded


static func _ensure_kaykit_facing(agent: CharacterBody3D) -> void:
	var body := agent.get_node_or_null("Body") as Node3D
	if body == null or body.get_meta("kaykit_facing_applied", false):
		return
	for child in body.get_children():
		if child is Node3D:
			(child as Node3D).transform = Transform3D(KAYKIT_VISUAL_BASIS, Vector3.ZERO)
	body.set_meta("kaykit_facing_applied", true)


static func _sync_name_label(agent: CharacterBody3D, display_name: String) -> void:
	var label := agent.get_node_or_null("Label3D") as Label3D
	if label == null:
		return
	label.text = display_name


static func _narrative_role_from_key(key: String) -> GameState.NarrativeRole:
	for role in GameState.NPC_ROLES:
		if GameState.ROLE_KEYS[role] == key:
			return role
	push_warning("NpcCast: role_key sconosciuto '%s', uso ALBERTO." % key)
	return GameState.NarrativeRole.ALBERTO
