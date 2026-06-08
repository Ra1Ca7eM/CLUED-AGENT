extends RefCounted

const MAP_ZONE_MANAGER := preload("res://scripts/map/map_zone_manager.gd")
const DOOR_PORTAL_SERVICE := preload("res://scripts/navigation/door_portal_service.gd")
const DIALOGUE_CAMERA_SCENE := preload("res://ui/dialogue/dialogue_camera_view.tscn")
const DIALOGUE_CHAT_UI_SCENE := preload("res://ui/dialogue/dialogue_chat_ui.tscn")
const GAMEPLAY_UI_SCENE := preload("res://ui/gameplay/gameplay_ui.tscn")
const NOTEBOOK_UI_SCENE := preload("res://ui/notebook/notebook_ui.tscn")
const GAME_MASTER_UI_SCENE := preload("res://ui/dialogue/game_master_ui.tscn")
const DOOR_RAY_LEN := 3.2
const VICTIM_HEIGHT_OFFSET := 0.75
const SHOW_INSPECTION_DETAILS := true
const ALBERTO_ROLE_KEY := "alberto"
const DIGITALINA_CLUE_ID := "boccetta_digitalina"
const PILLOLE_WC_CLUE_ID := "pillole_nadololo_wc"
const ALBERTO_WATCH_ZONES := {
	"room5": "room5",
	"basement_hall": "cantina",
}

var host: Node3D
var player: Node
var salon: Node3D
var npc_root: Node3D
var inspectables_root: Node3D
var inspection_view: Node3D
var interaction_prompt: Label
var inspection_panel: PanelContainer
var inspection_title: Label
var inspection_description: Label

var current_npc: Area3D = null
var current_inspectable: Area3D = null
var current_door: Node = null
var victim_id: String = ""
var _map_zone_manager: MapZoneManager = null
var dialogue_camera: Node3D = null
var dialogue_chat_ui: CanvasLayer = null
var _dialogue_active: bool = false
var _prev_map_key: String = ""

func setup(owner_node: Node3D) -> void:
	host = owner_node
	player = host.get_node_or_null("ProtoController")
	salon = host.get_node_or_null("House/Salon") as Node3D
	if salon == null:
		return

	_cleanup_salon_runtime_nodes()
	ensure_roots()
	ensure_ui()

	inspection_view = host.get_node_or_null("InspectionView") as Node3D
	interaction_prompt = host.get_node_or_null("GameplayUI/InteractionPrompt") as Label
	inspection_panel = host.get_node_or_null("GameplayUI/InspectionPanel") as PanelContainer
	inspection_title = host.get_node_or_null("GameplayUI/InspectionPanel/MarginContainer/VBoxContainer/TitleLabel") as Label
	inspection_description = host.get_node_or_null("GameplayUI/InspectionPanel/MarginContainer/VBoxContainer/DescriptionLabel") as Label

	if interaction_prompt:
		interaction_prompt.hide()
	if inspection_panel:
		inspection_panel.hide()
	place_dead_victim_center()
	setup_scene_npcs()
	register_inspectables()
	register_doors()
	_setup_overlay_uis()
	_setup_map_zones()
	_setup_uv_torch()
	_setup_agent_triggers()


func _setup_map_zones() -> void:
	if host == null or player == null:
		return
	if host.get_node_or_null("MapZoneManager") != null:
		return
	_map_zone_manager = MAP_ZONE_MANAGER.new() as MapZoneManager
	_map_zone_manager.name = "MapZoneManager"
	host.add_child(_map_zone_manager)
	_map_zone_manager.setup(host, player as Node3D)


func _setup_agent_triggers() -> void:
	_prev_map_key = GameState.current_map_key
	if not GameState.map_context_changed.is_connected(_on_map_context_changed):
		GameState.map_context_changed.connect(_on_map_context_changed)
	call_deferred("_sync_alberto_inspection_beliefs")


func _get_vesna_agent(role_key: String) -> Node:
	if npc_root == null:
		return null
	var node_name := role_key.capitalize()
	var agent := npc_root.get_node_or_null(node_name)
	if agent != null and agent.has_method("send_mind_signal"):
		return agent
	for child in npc_root.get_children():
		if child is CharacterBody3D and child.has_method("send_mind_signal"):
			if str(child.name).to_lower() == role_key:
				return child
	return null


func _notify_alberto_mind(event_type: String, room: String) -> void:
	var agent := _get_vesna_agent(ALBERTO_ROLE_KEY)
	if agent == null:
		return
	agent.call("send_mind_signal", event_type, room, "")


func _sync_alberto_inspection_beliefs() -> void:
	if GameState.is_clue_inspected(DIGITALINA_CLUE_ID):
		_notify_alberto_mind("digitalina_inspected", "")
	if GameState.is_clue_inspected(PILLOLE_WC_CLUE_ID):
		_notify_alberto_mind("pillole_wc_inspected", "")


func _on_map_context_changed() -> void:
	var key := GameState.current_map_key
	var prev_zone: String = ALBERTO_WATCH_ZONES.get(_prev_map_key, "")
	var curr_zone: String = ALBERTO_WATCH_ZONES.get(key, "")

	if curr_zone != "" and key != _prev_map_key:
		_notify_alberto_mind("player_entered", curr_zone)
	if prev_zone != "" and key != _prev_map_key:
		_notify_alberto_mind("player_exited", prev_zone)
	_prev_map_key = key

func _setup_uv_torch() -> void:
	if player == null:
		return
	var head := player.get_node_or_null("Head") as Node3D
	if head == null:
		return
	if head.get_node_or_null("UVTorch") != null:
		return
	var torch := UVTorch.new()
	torch.name = "UVTorch"
	head.call_deferred("add_child", torch)

func handle_unhandled_input(event: InputEvent, tutorial_visible: bool) -> void:
	if tutorial_visible:
		return
	if inspection_view and inspection_view.call("is_active"):
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			host.get_viewport().set_input_as_handled()
			_close_inspection()
			return
		if event.is_action_pressed("uv_torch"):
			host.get_viewport().set_input_as_handled()
			_set_inspection_uv(true)
			return
		if event.is_action_released("uv_torch"):
			host.get_viewport().set_input_as_handled()
			_set_inspection_uv(false)
			return
		return

	if _dialogue_active or (dialogue_chat_ui and dialogue_chat_ui.has_method("is_open") and dialogue_chat_ui.is_open()):
		if event.is_action_pressed("ui_cancel"):
			host.get_viewport().set_input_as_handled()
			_close_dialogue_session()
		return

	# UV hold mode — takes priority over doors
	if event.is_action_pressed("uv_torch"):
		if current_door == null and player and player.has_method("set_uv_mode"):
			host.get_viewport().set_input_as_handled()
			player.call("set_uv_mode", true)
			return
	if event.is_action_released("uv_torch"):
		if player and player.has_method("set_uv_mode"):
			host.get_viewport().set_input_as_handled()
			player.call("set_uv_mode", false)
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if current_door != null:
			host.get_viewport().set_input_as_handled()
			current_door.toggle(player.global_position, player as Node3D)
			return

	if event.is_action_pressed("interact"):
		if current_inspectable != null:
			host.get_viewport().set_input_as_handled()
			current_inspectable.call("interact")
			return
		if current_npc != null:
			host.get_viewport().set_input_as_handled()
			current_npc.call("interact")
			return

func ensure_roots() -> void:
	npc_root = host.get_node_or_null("NPC") as Node3D
	if npc_root == null:
		npc_root = host.get_node_or_null("NPCs") as Node3D
	if npc_root == null:
		npc_root = Node3D.new()
		npc_root.name = "NPC"
		host.add_child(npc_root)

	inspectables_root = host.get_node_or_null("Inspectables") as Node3D
	if inspectables_root == null:
		inspectables_root = Node3D.new()
		inspectables_root.name = "Inspectables"
		host.add_child(inspectables_root)

	inspection_view = host.get_node_or_null("InspectionView") as Node3D
	if inspection_view == null:
		inspection_view = Node3D.new()
		inspection_view.name = "InspectionView"
		var inspection_script := load("res://scripts/inspection_view.gd")
		inspection_view.set_script(inspection_script)
		var camera := Camera3D.new()
		camera.name = "Camera3D"
		camera.near = 0.04
		camera.fov = 55.0
		inspection_view.add_child(camera)
		host.add_child(inspection_view)

	dialogue_camera = host.get_node_or_null("DialogueCameraView") as Node3D
	if dialogue_camera == null:
		dialogue_camera = DIALOGUE_CAMERA_SCENE.instantiate() as Node3D
		dialogue_camera.name = "DialogueCameraView"
		host.add_child(dialogue_camera)

func ensure_ui() -> void:
	var gameplay_ui := host.get_node_or_null("GameplayUI") as CanvasLayer
	if gameplay_ui != null:
		return
	gameplay_ui = GAMEPLAY_UI_SCENE.instantiate() as CanvasLayer
	gameplay_ui.name = "GameplayUI"
	host.add_child(gameplay_ui)

func _setup_overlay_uis() -> void:
	var nb := host.get_node_or_null("NotebookUI") as CanvasLayer
	if nb == null:
		nb = NOTEBOOK_UI_SCENE.instantiate() as CanvasLayer
		nb.name = "NotebookUI"
		host.add_child(nb)

	dialogue_chat_ui = host.get_node_or_null("DialogueChatUI") as CanvasLayer
	if dialogue_chat_ui == null:
		dialogue_chat_ui = DIALOGUE_CHAT_UI_SCENE.instantiate() as CanvasLayer
		dialogue_chat_ui.name = "DialogueChatUI"
		host.add_child(dialogue_chat_ui)
	if not dialogue_chat_ui.is_connected("close_requested", Callable(self, "_close_dialogue_session")):
		dialogue_chat_ui.connect("close_requested", Callable(self, "_close_dialogue_session"))

	# Game Master overlay (ESC): final-accusation panel, self-contained input handling.
	var gm := host.get_node_or_null("GameMasterUI") as CanvasLayer
	if gm == null:
		gm = GAME_MASTER_UI_SCENE.instantiate() as CanvasLayer
		gm.name = "GameMasterUI"
		host.add_child(gm)

func _cleanup_salon_runtime_nodes() -> void:
	var salon_player := salon.get_node_or_null("Player")
	if salon_player:
		salon_player.queue_free()
	var salon_ui := salon.get_node_or_null("UI")
	if salon_ui:
		salon_ui.queue_free()
	var salon_npcs := salon.get_node_or_null("NPCs")
	if salon_npcs:
		salon_npcs.queue_free()
	var salon_inspection := salon.get_node_or_null("InspectionView")
	if salon_inspection:
		salon_inspection.queue_free()

func place_dead_victim_center() -> void:
	victim_id = GameState.get_victim_character_id()
	var scene_path := GameState.get_character_scene_path(victim_id)
	var victim_scene := load(scene_path) as PackedScene
	if victim_scene == null:
		return
	var existing := salon.get_node_or_null("VictimBody")
	if existing:
		existing.queue_free()
	var victim_body := victim_scene.instantiate() as Node3D
	if victim_body == null:
		return
	victim_body.name = "VictimBody"
	victim_body.position = Vector3(0.0, 0.0, 0.0)
	victim_body.rotation_degrees = Vector3(0, 180, 0)
	salon.add_child(victim_body)
	var animation_tree := victim_body.get_node_or_null("AnimationTree") as AnimationTree
	var animation_player := victim_body.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_tree:
		animation_tree.active = false
	if animation_player:
		animation_player.play("Player/Death_B")
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var anim_len: float = animation_player.get_current_animation_length()
		if anim_len <= 0.05:
			anim_len = 2.85
		var blend: float = 0.42
		var wait_sec: float = maxf(anim_len - blend - 0.05, 0.15)
		await host.get_tree().create_timer(wait_sec).timeout
		animation_player.play("Player/Death_B_Pose", blend)

func setup_scene_npcs() -> void:
	if npc_root == null:
		return
	for child in npc_root.get_children():
		if child is Marker3D:
			child.queue_free()
			continue
		if not NpcCast.is_scene_npc(child):
			continue
		if child is CharacterBody3D:
			var agent := child as CharacterBody3D
			NpcCast.apply_cast(agent)
			if agent.has_method("play_idle"):
				agent.call("play_idle")
			if salon != null:
				Callable(NpcCast, "align_feet_to_salon").call_deferred(agent, salon)
		elif child.has_method("apply_cast"):
			child.call("apply_cast")
		var interaction := NpcCast.get_interaction_area(child)
		if interaction == null:
			continue
		if not interaction.is_connected("interacted", Callable(self, "_on_npc_interacted")):
			interaction.connect("interacted", Callable(self, "_on_npc_interacted"))
		if not interaction.is_connected("player_entered", Callable(self, "_on_npc_player_entered")):
			interaction.connect("player_entered", Callable(self, "_on_npc_player_entered"))
		if not interaction.is_connected("player_exited", Callable(self, "_on_npc_player_exited")):
			interaction.connect("player_exited", Callable(self, "_on_npc_player_exited"))


func register_inspectables() -> void:
	if inspectables_root == null:
		return
	for child in inspectables_root.get_children():
		if not (child is Area3D):
			continue
		var map_id := str(child.get("map_clue_id"))
		if map_id != "":
			var use_zone: bool = bool(child.get("use_zone_map_position")) if child.get("use_zone_map_position") != null else true
			if not use_zone:
				GameState.register_map_clue(
					map_id,
					str(child.get("display_name")),
					int(child.get("map_floor")),
					child.get("map_position"),
					_build_clue_metadata(map_id, child)
				)
		if child.has_signal("player_entered") and not child.is_connected("player_entered", Callable(self, "_on_inspectable_player_entered")):
			child.connect("player_entered", Callable(self, "_on_inspectable_player_entered"))
		if child.has_signal("player_exited") and not child.is_connected("player_exited", Callable(self, "_on_inspectable_player_exited")):
			child.connect("player_exited", Callable(self, "_on_inspectable_player_exited"))
		if child.has_signal("interacted") and not child.is_connected("interacted", Callable(self, "_on_inspectable_interacted")):
			child.connect("interacted", Callable(self, "_on_inspectable_interacted"))

func _on_npc_player_entered(npc: Area3D) -> void:
	current_npc = npc
	if interaction_prompt and current_inspectable == null and (inspection_view == null or not inspection_view.call("is_active")):
		interaction_prompt.text = "Premi E per dialogare con " + str(npc.get("display_name"))
		interaction_prompt.show()

func _on_npc_player_exited(npc: Area3D) -> void:
	if current_npc != npc:
		return
	current_npc = null
	if interaction_prompt and current_inspectable == null:
		interaction_prompt.hide()

func _on_npc_interacted(character_id: String, display_name: String, intro_dialogue: String) -> void:
	if _dialogue_active:
		return
	if inspection_view and inspection_view.call("is_active"):
		return
	if dialogue_camera == null or dialogue_chat_ui == null:
		return

	_dialogue_active = true
	if interaction_prompt:
		interaction_prompt.hide()

	if player and player.has_method("set_dialogue_mode"):
		player.call("set_dialogue_mode", true)

	var npc_node: Node3D = NpcCast.get_agent_body(current_npc) if current_npc != null else null
	var role_key := ""
	if current_npc != null:
		role_key = str(current_npc.get("narrative_role_key"))
	if npc_node == null:
		_dialogue_active = false
		return
	dialogue_camera.call("start", player as Node3D, npc_node)
	dialogue_chat_ui.call("open", character_id, display_name, intro_dialogue, role_key)

func _close_dialogue_session() -> void:
	if dialogue_chat_ui and dialogue_chat_ui.has_method("is_readonly") and dialogue_chat_ui.is_readonly():
		dialogue_chat_ui.call("close")
		return
	if not _dialogue_active:
		return
	_dialogue_active = false
	if dialogue_chat_ui:
		dialogue_chat_ui.call("close")
	if dialogue_camera:
		dialogue_camera.call("end")
	if player and player.has_method("set_dialogue_mode"):
		player.call("set_dialogue_mode", false)
	if player and player.has_method("capture_mouse"):
		player.call("capture_mouse")
	if interaction_prompt and current_npc != null:
		interaction_prompt.text = "Premi E per dialogare con " + str(current_npc.get("display_name"))
		interaction_prompt.show()

func _on_inspectable_player_entered(item: Area3D) -> void:
	current_inspectable = item
	if inspection_view and inspection_view.call("is_active"):
		return
	if interaction_prompt:
		interaction_prompt.text = "Premi E per ispezionare " + str(item.get("display_name"))
		interaction_prompt.show()

func _on_inspectable_player_exited(item: Area3D) -> void:
	if current_inspectable != item:
		return
	current_inspectable = null
	if inspection_view and inspection_view.call("is_active"):
		return
	if interaction_prompt:
		if current_npc != null:
			interaction_prompt.text = "Premi E per dialogare con " + str(current_npc.get("display_name"))
			interaction_prompt.show()
		else:
			interaction_prompt.hide()

func _on_inspectable_interacted(item: Area3D) -> void:
	if inspection_view == null:
		return
	if inspection_view.call("is_active"):
		return
	var normal_desc: String = str(item.get("description"))
	if inspection_title:
		inspection_title.text = str(item.get("display_name"))
	if inspection_description:
		inspection_description.visible = SHOW_INSPECTION_DETAILS
		inspection_description.text = normal_desc if SHOW_INSPECTION_DETAILS else ""
	if inspection_panel:
		if SHOW_INSPECTION_DETAILS:
			inspection_panel.show()
			_fit_inspection_panel()
		else:
			inspection_panel.hide()
	if interaction_prompt:
		interaction_prompt.hide()
	inspection_view.call("start", item, player)
	var map_id := str(item.get("map_clue_id"))
	if map_id != "":
		GameState.mark_clue_inspected(map_id)
		if map_id == DIGITALINA_CLUE_ID:
			_notify_alberto_mind("digitalina_inspected", "")
		elif map_id == PILLOLE_WC_CLUE_ID:
			_notify_alberto_mind("pillole_wc_inspected", "")
	if inspection_view.call("is_active"):
		_set_player_inspection_mode(true)

func _close_inspection() -> void:
	if inspection_view == null or not inspection_view.call("is_active"):
		return
	inspection_view.call("set_uv_mode", false)
	inspection_view.call("stop")
	_set_player_inspection_mode(false)
	if inspection_panel:
		inspection_panel.hide()
	if interaction_prompt:
		if current_inspectable != null:
			interaction_prompt.text = "Premi E per ispezionare " + str(current_inspectable.get("display_name"))
			interaction_prompt.show()
		elif current_npc != null:
			interaction_prompt.text = "Premi E per dialogare con " + str(current_npc.get("display_name"))
			interaction_prompt.show()
		else:
			interaction_prompt.hide()

func _set_player_inspection_mode(active: bool) -> void:
	GameState.inspection_active = active
	if player == null or not player.has_method("set_inspection_mode"):
		return
	player.call("set_inspection_mode", active)
	if active:
		if player.has_method("release_mouse"):
			player.call("release_mouse")
	else:
		if player.has_method("capture_mouse"):
			player.call("capture_mouse")


func _refresh_inspection_description(item: Area3D) -> void:
	if inspection_description == null or item == null:
		return
	if not SHOW_INSPECTION_DETAILS:
		inspection_description.text = ""
		return
	if item.has_method("get_active_description"):
		inspection_description.text = item.call("get_active_description")
	else:
		inspection_description.text = str(item.get("description"))
	_fit_inspection_panel()


func _fit_inspection_panel() -> void:
	if inspection_panel == null or not inspection_panel.visible:
		return
	if inspection_panel is InspectionHudPanel:
		(inspection_panel as InspectionHudPanel).call_deferred("fit_to_content")
	elif inspection_panel.has_method("fit_to_content"):
		inspection_panel.call_deferred("fit_to_content")


func _set_inspection_uv(active: bool) -> void:
	if inspection_view == null or not inspection_view.call("is_active"):
		return
	inspection_view.call("set_uv_mode", active)
	if current_inspectable != null:
		_refresh_inspection_description(current_inspectable)
	if active and current_inspectable != null:
		var uv_desc := str(current_inspectable.get("uv_description"))
		if uv_desc != "":
			pass

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


func register_doors() -> void:
	var door_root := host.get_node_or_null("Door") as Node3D
	if door_root == null:
		return
	for door_node in door_root.get_children():
		var ctrl := DoorController.new()
		var panel: Node3D = null
		var bodies: Array = []
		var name_label: String = "porta"
		if door_node.name.begins_with("door_B"):
			panel = door_node.get_node_or_null("door_B") as Node3D
			var body := door_node.get_node_or_null("door_B/StaticBody3D") as StaticBody3D
			if body != null:
				bodies.append(body)
			match door_node.name:
				"door_B2":
					name_label = "porta principale"
				"door_B4":
					name_label = "porta giardino"
				_:
					name_label = "porta"
		else:
			# doorway, doorway2 ... doorway7
			var clone := door_node.get_node_or_null("doorway(Clone)") as Node3D
			if clone == null:
				door_node.add_child(ctrl)
				continue
			panel = clone.get_node_or_null("door") as Node3D
			var door_body := clone.get_node_or_null("door/StaticBody3D") as StaticBody3D
			var frame_body := clone.get_node_or_null("StaticBody3D") as StaticBody3D
			if door_body != null:
				bodies.append(door_body)
			if frame_body != null:
				bodies.append(frame_body)
		if panel == null:
			door_node.add_child(ctrl)
			continue
		# Fallback: se nessun body trovato col path hardcoded, cerca tutti i StaticBody3D
		if bodies.is_empty():
			var found := door_node.find_children("*", "StaticBody3D", true, false)
			for b in found:
				bodies.append(b)
			if not bodies.is_empty():
				push_warning("DoorController: path hardcoded vuoto per '%s', uso fallback find_children (%d bodies)" % [door_node.name, bodies.size()])
		ctrl.setup(panel, bodies, name_label)
		# Tutte le porte si aprono a 180° (default in DoorController.open_angle_deg).
		door_node.add_child(ctrl)
		DoorRegistry.register(door_node.name, ctrl)
	DOOR_PORTAL_SERVICE.setup(host)

func _get_player_camera() -> Camera3D:
	if player == null:
		return null
	var head := player.get_node_or_null("Head") as Node3D
	if head == null:
		return null
	# Layout standard proto_controller: Head/SpringArm3D/Camera3D
	var cam := head.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	if cam != null:
		return cam
	# Fallback: Head/Camera3D
	cam = head.get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		return cam
	# Ultimo fallback: cerca in tutta la gerarchia player
	return player.find_child("Camera3D", true, false) as Camera3D

func update_door_aim() -> void:
	if player == null:
		return
	if _dialogue_active:
		return
	var cam := _get_player_camera()
	if cam == null:
		return
	var from: Vector3 = cam.global_position
	var forward: Vector3 = -cam.global_transform.basis.z
	var to: Vector3 = from + forward * 4.0
	var space := host.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 1048575
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.has("collider"):
		var col: Object = hit["collider"] as Object
		if col != null and col.has_meta("door_controller"):
			var ctrl: DoorController = col.get_meta("door_controller") as DoorController
			current_door = ctrl
			if interaction_prompt and current_inspectable == null and current_npc == null:
				var action: String = "chiudi" if ctrl.is_open else "apri"
				interaction_prompt.text = "Clic destro per " + action + " la " + str(ctrl.display_name)
				interaction_prompt.show()
			return
	# Nessuna porta mirata
	if current_door != null:
		current_door = null
		if interaction_prompt and current_inspectable == null and current_npc == null:
			interaction_prompt.hide()
