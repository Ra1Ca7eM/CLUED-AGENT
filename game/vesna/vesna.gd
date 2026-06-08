extends CharacterBody3D

const IDLE_ANIM := "Player/Idle_A"
const WALK_ANIM := "Player/Walking_A"
const WALK_STATE := "Walk"
const IDLE_STATE := "Idle"

const NAV_ROOT := "/root/Main/NavigationRegion3D"

## JaCaMo region/POI name → Godot node under Regions/
const NAV_ALIASES := {
	"salone": "MapZone_salon",
	"corridoio": "MapZone_corridoio",
	"room1": "MapZone_room1",
	"room2": "MapZone_room2",
	"room3": "MapZone_room3",
	"room4": "MapZone_room4",
	"room5": "MapZone_room5",
	"room6": "MapZone_room6",
	"cucina": "MapZone_kitchen",
	"bagno": "MapZone_bathroom",
	"cantina": "MapZone_cantina",
	"giardino": "MapZone_giardino",
	"scalaEst_pt": "MapZone_scalaEstPT",
	"scalaEst_pp": "MapZone_scalaEstP1",
	"scalaOvest_pt": "MapZone_scalaOvestPT",
	"scalaOvest_pp": "MapZone_scalaOvestP1",
	"scalaOvest_cantina": "MapZone_scalaOvestCantina",
}

## JaCaMo zone name → Marker3D under Markers/ (POI default per center walk)
const ZONE_MARKERS := {
	"salone": "salone_camino",
	"cucina": "cucina_lavandino",
	"bagno": "bagno_lavandino",
	"cantina": "cantina_baule",
	"giardino": "giardino1",
	"room1": "evelinaRoom_contratto",
	"room2": "investigatoreRoom_chiave",
	"room3": "vittorioRoom_stivali",
	"room4": "clarissaRoom_chiave",
	"room5": "albertoRoom_chiave",
	"room6": "aurelioRoom_diario",
	"corridoio": "marker_corridoio",
	"scalaEst_pt": "marker_scalaEst_pt",
	"scalaEst_pp": "marker_scalaEst_pp",
	"scalaOvest_pt": "marker_scalaOvest_pt",
	"scalaOvest_pp": "marker_scalaOvest_pp",
	"scalaOvest_cantina": "marker_scalaOvest_cantina",
}

## Porta JaCaMo → marker lato zona corrente (Markers/)
const DOOR_MARKERS := {
	"doorway": {"salone": "salone_doorway", "bagno": "bagno_doorway"},
	"door_B3": {"salone": "salone_door_B3", "cucina": "cucina_door_B3"},
	"door_B2": {"cucina": "cucina_door_B2"},
	"door_B4": {"giardino": "giardino_door_B4"},
	"doorway2": {"corridoio": "corridoio_doorway2", "room6": "room6_doorway2"},
	"doorway3": {"corridoio": "corridoio_doorway3", "room4": "room4_doorway3"},
	"doorway4": {"corridoio": "corridoio_doorway4", "room2": "room2_doorway4"},
	"doorway5": {"corridoio": "corridoio_doorway5", "room1": "room1_doorway5"},
	"doorway6": {"corridoio": "corridoio_doorway6", "room3": "room3_doorway6"},
	"doorway7": {"corridoio": "corridoio_doorway7", "room5": "room5_doorway7"},
}

## Zona fisica dopo teleport portal (door_B2 → giardino, door_B4 → cucina)
const PORTAL_REGION := {
	"door_B2": "giardino",
	"door_B4": "cucina",
}

## JaCaMo target → path sotto NavigationRegion3D (marker missione grab)
const GRABBABLE_MARKERS := {
	"albertoRoom_digitalina_release": "Grabbable/AgentPosRelease",
}

const DIGITALINA_ART_NAME := "boccetta_digitalina"
const DIGITALINA_INSPECTABLE_PATH := "/root/Main/Inspectables/Digitalina"
const DIGITALINA_RELOCATED_DESCRIPTION := "qualcuno ha spostato la Digitalina"
const DIGITALINA_INSPECTABLE_MESH_NAMES := [
	"Sketchfab_Scene",
	"puddle_02_medium",
	"fingerprint_01",
	"CSGSphere3D",
]

const PILLOLE_WC_CLUE_ID := "pillole_nadololo_wc"
const PILLOLE_WC_INSPECTABLE_PATH := "/root/Main/Inspectables/PilloleWC"
const PILLOLE_WC_FLUSHED_DESCRIPTION := "Qualcuno ha tirato lo sciacquone per nascondere le tracce"
const FLUSH_SOUND := preload("res://AUDIO/sciacquone.mp3")

const DEBUG_LOG_PATH := "C:/Users/Riccardo/Desktop/TIROCINIO/elaborato/debug-f48318.log"

const SPEED := 3.5
const ACCELERATION := 5.0
const JUMP_VELOCITY := 4.5

@export var PORT: int = 0
@export var separation_margin: float = CollisionLayers.CAPSULE_SEPARATION_MARGIN
@export var separation_weight: float = 5.0
@export var facing_turn_speed: float = 12.0
@export var facing_offset: float = PI

var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()
var _ws_logged_connected := false

var end_communication := true
var target_movement: String = "empty"

var _current_region := ""
var _movement_paused := false
var _pending_walk: Dictionary = {}

@onready var navigator: NavigationAgent3D = $NavigationAgent3D
@onready var body_pivot: Node3D = $Body


func _ready() -> void:
	CollisionLayers.configure_agent_body(self)
	if PORT > 0:
		var err := tcp_server.listen(PORT)
		if err != OK:
			push_error("vesna: unable to start WS server on port %d for %s (err %s)" % [PORT, name, err])
			set_process(false)
		else:
			print("vesna: [%s] WS server listening on port %d" % [name, PORT])
	_connect_nav_regions()
	if navigator != null:
		navigator.max_speed = SPEED
	play_idle()
	call_deferred("_sync_navigator")


func _sync_navigator() -> void:
	if navigator == null:
		return
	await get_tree().physics_frame
	navigator.target_position = global_position


func _connect_nav_regions() -> void:
	var regions := get_node_or_null(NAV_ROOT + "/Regions")
	if regions != null:
		for region in regions.get_children():
			if region is Area3D:
				region.body_entered.connect(
					func(body: Node3D) -> void: _on_area_body_entered(region.name, body)
				)
	var doors := get_node_or_null(NAV_ROOT + "/Doors")
	if doors != null:
		for door in doors.get_children():
			var area := door.get_node_or_null("Area3D")
			if area is Area3D:
				area.body_entered.connect(
					func(body: Node3D) -> void: _on_area_body_entered(door.name, body)
				)


func _process(_delta: float) -> void:
	if PORT <= 0:
		return

	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		if conn != null:
			ws.accept_stream(conn)

	ws.poll()

	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _ws_logged_connected:
			_ws_logged_connected = true
			print("vesna: [%s] JaCaMo client connected (port %d)" % [name, PORT])
		while ws.get_available_packet_count():
			var msg: String = ws.get_packet().get_string_from_ascii()
			print("vesna [%s] received: %s" % [name, msg])
			var intention: Variant = JSON.parse_string(msg)
			if intention is Dictionary:
				manage(intention)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if _movement_paused:
		play_idle()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if navigator.is_target_reached() or navigator.is_navigation_finished():
		play_idle()
		velocity.x = 0.0
		velocity.z = 0.0
		if not end_communication:
			signal_end_movement()
	elif not navigator.is_navigation_finished():
		play_walk()
		var direction := (navigator.get_next_path_position() - global_position).normalized()
		var avoidance_force := get_avoidance_force()
		var final_direction := (direction + avoidance_force).normalized()
		_apply_facing(final_direction, delta)
		velocity = velocity.lerp(final_direction * SPEED, ACCELERATION * delta)

	move_and_slide()


func pause_movement() -> void:
	_movement_paused = true
	_pending_walk.clear()
	target_movement = "empty"
	end_communication = true
	if navigator != null:
		navigator.target_position = global_position
	velocity = Vector3.ZERO
	play_idle()


func resume_movement() -> void:
	_movement_paused = false
	if not _pending_walk.is_empty():
		var target: String = str(_pending_walk.get("target", ""))
		var id: int = int(_pending_walk.get("id", -1))
		_pending_walk.clear()
		if not target.is_empty():
			walk(target, id)


func send_mind_signal(event_type: String, status: String, reason: String = "") -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var signal_payload := {
		"sender": "body",
		"receiver": "vesna",
		"type": "signal",
		"data": {
			"type": event_type,
			"status": status,
			"reason": reason,
		},
	}
	ws.send_text(JSON.stringify(signal_payload))
	print("vesna [%s] mind signal sent: %s(%s, %s)" % [name, event_type, status, reason])


func _region_from_zone_name(zone_name: String) -> String:
	for region_name in NAV_ALIASES:
		if NAV_ALIASES[region_name] == zone_name:
			return region_name
	if zone_name.begins_with("MapZone_"):
		return zone_name.trim_prefix("MapZone_")
	return zone_name


func _apply_facing(final_direction: Vector3, delta: float) -> void:
	if body_pivot == null or final_direction.length_squared() <= 0.001:
		return
	var target_y := atan2(final_direction.x, final_direction.z) + facing_offset
	body_pivot.rotation.y = lerp_angle(body_pivot.rotation.y, target_y, delta * facing_turn_speed)


func _on_area_body_entered(region_name: String, body: Node3D) -> void:
	if body.name != name:
		return
	if region_name.begins_with("MapZone_"):
		var prev := _current_region
		_current_region = _region_from_zone_name(region_name)
		#region agent log
		if prev != _current_region:
			_debug_log("H-B", "vesna.gd:_on_area_body_entered", "region_updated", {
				"agent": name, "zone": region_name, "from": prev, "to": _current_region,
			})
		#endregion
	print("vesna: agent %s entered region %s" % [name, region_name])
	if _target_uses_marker(target_movement):
		return
	if _region_matches(target_movement, region_name) and not end_communication:
		signal_end_movement()
		navigator.set_target_position(global_position)


func _region_matches(target: String, region_name: String) -> bool:
	if target == "empty" or target.is_empty():
		return false
	if region_name == target:
		return true
	var alias: String = NAV_ALIASES.get(target, "")
	return not alias.is_empty() and region_name == alias


func _exit_tree() -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close()
	if PORT > 0 and tcp_server.is_listening():
		tcp_server.stop()


func get_avoidance_force() -> Vector3:
	var force := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self or not (other is CharacterBody3D):
			continue
		var other_body := other as CharacterBody3D
		var diff := global_position - other_body.global_position
		diff.y = 0.0
		var distance := diff.length()
		var threshold := CollisionLayers.capsule_separation_threshold(self, other_body, separation_margin)
		if distance < threshold and distance > 0.0:
			force += diff.normalized() / distance
	return force * separation_weight


func manage(intention: Dictionary) -> void:
	var type: String = intention.get("type", "")
	var data: Dictionary = intention.get("data", {})
	if type == "walk" and data.get("type", "") == "goto":
		var target: String = data.get("target", "")
		var id: int = int(data["id"]) if data.has("id") else -1
		walk(target, id)
		return
	if _movement_paused:
		return
	if type == "interact":
		match data.get("type", ""):
			"use":
				use_artifact(str(data.get("art_name", "")))
			"free":
				free_artifact(str(data.get("art_name", "")))
			"grab":
				grab_artifact(str(data.get("art_name", "")))
			"release":
				release_artifact(str(data.get("art_name", "")))
			"wc_flush_pillole":
				_apply_pillole_wc_flush()


func get_obj_from_group(art_name: String, group_name: String) -> Node:
	for group_obj in get_tree().get_nodes_in_group(group_name):
		if art_name == group_obj.name:
			return group_obj
	return null


func grab_artifact(art_name: String) -> void:
	var art := get_obj_from_group(art_name, "GrabbableArtifact")
	if art == null:
		push_warning("vesna [%s] grab: object not found: %s" % [name, art_name])
		return
	if art_name == DIGITALINA_ART_NAME:
		art.visible = true
	var right_hand := _get_right_hand()
	if right_hand == null:
		push_warning("vesna [%s] grab: RightHand not found" % name)
		return
	_reparent_preserve_scale(art as Node3D, right_hand)
	print("vesna [%s] grabbed %s" % [name, art_name])
	if art_name == DIGITALINA_ART_NAME:
		_apply_digitalina_inspectable_hidden()


func release_artifact(art_name: String) -> void:
	var art := get_obj_from_group(art_name, "GrabbableArtifact")
	if art == null:
		push_warning("vesna [%s] release: object not found: %s" % [name, art_name])
		return
	var release_parent: Node3D = null
	if art_name == DIGITALINA_ART_NAME:
		release_parent = get_node_or_null(NAV_ROOT + "/Grabbable/ReleasePoint") as Node3D
	else:
		release_parent = _find_nearest_release_point()
	if release_parent == null:
		push_warning("vesna [%s] release: no ReleasePoint for %s" % [name, art_name])
		return
	_reparent_preserve_scale(art as Node3D, release_parent)
	print("vesna [%s] released %s at %s" % [name, art_name, release_parent.name])
	if art_name == DIGITALINA_ART_NAME:
		_apply_digitalina_relocated_description()


func _reparent_preserve_scale(node: Node3D, new_parent: Node) -> void:
	var preserved_scale := node.global_transform.basis.get_scale()
	if preserved_scale.is_equal_approx(Vector3.ZERO):
		preserved_scale = node.scale
	node.reparent(new_parent)
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = preserved_scale


func _find_nearest_release_point() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := 1000.0
	for release_point in get_tree().get_nodes_in_group("ReleasePoint"):
		if not release_point is Node3D:
			continue
		var dist := (release_point as Node3D).global_position.distance_to(global_position)
		if dist < nearest_dist:
			nearest = release_point as Node3D
			nearest_dist = dist
	return nearest


func _get_right_hand() -> BoneAttachment3D:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return null
	for child in body.get_children():
		if not child.visible:
			continue
		var hand := child.get_node_or_null("Rig_Medium/Skeleton3D/RightHand") as BoneAttachment3D
		if hand != null:
			return hand
	for child in body.get_children():
		var hand := child.get_node_or_null("Rig_Medium/Skeleton3D/RightHand") as BoneAttachment3D
		if hand != null:
			return hand
	return null


func _apply_digitalina_inspectable_hidden() -> void:
	var inspectable := get_node_or_null(DIGITALINA_INSPECTABLE_PATH)
	if inspectable == null:
		push_warning("vesna: Inspectables/Digitalina not found")
		return
	for mesh_name in DIGITALINA_INSPECTABLE_MESH_NAMES:
		var mesh_node := inspectable.get_node_or_null(mesh_name)
		if mesh_node is Node3D:
			(mesh_node as Node3D).visible = false


func _apply_digitalina_relocated_description() -> void:
	var inspectable := get_node_or_null(DIGITALINA_INSPECTABLE_PATH)
	if inspectable != null and inspectable.has_method("set_description"):
		inspectable.call("set_description", DIGITALINA_RELOCATED_DESCRIPTION)
	elif inspectable != null:
		inspectable.set("description", DIGITALINA_RELOCATED_DESCRIPTION)
	GameState.update_clue_description(DIGITALINA_ART_NAME, DIGITALINA_RELOCATED_DESCRIPTION)


func _apply_pillole_wc_flush() -> void:
	var inspectable := get_node_or_null(PILLOLE_WC_INSPECTABLE_PATH)
	if inspectable == null:
		push_warning("vesna: Inspectables/PilloleWC not found")
		return
	for child in inspectable.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if inspectable.has_method("set_description"):
		inspectable.call("set_description", PILLOLE_WC_FLUSHED_DESCRIPTION)
	else:
		inspectable.set("description", PILLOLE_WC_FLUSHED_DESCRIPTION)
	GameState.update_clue_description(PILLOLE_WC_CLUE_ID, PILLOLE_WC_FLUSHED_DESCRIPTION)
	_play_wc_flush_sound()
	print("vesna [%s] pillole WC flush applied" % name)


func _play_wc_flush_sound() -> void:
	if FLUSH_SOUND == null:
		return
	var wc_marker := get_node_or_null(NAV_ROOT + "/Markers/bagno_wc") as Node3D
	var player := AudioStreamPlayer3D.new()
	player.stream = FLUSH_SOUND
	player.max_distance = 25.0
	add_child(player)
	if wc_marker != null:
		player.global_position = wc_marker.global_position
	player.play()
	player.finished.connect(player.queue_free)


func use_artifact(art_name: String) -> void:
	print("vesna [%s] use artifact %s" % [name, art_name])


func free_artifact(art_name: String) -> void:
	print("vesna [%s] free artifact %s" % [name, art_name])


func walk(target: String, _id: int) -> void:
	if _movement_paused:
		_pending_walk = {"target": target, "id": _id}
		print("vesna [%s] walk deferred while paused: %s" % [name, target])
		return
	if DOOR_MARKERS.has(target):
		_refresh_current_region_from_zones()
	var target_node := _resolve_nav_target(target)
	if target_node == null:
		push_warning("vesna: nav target not found: %s" % target)
		return

	navigator.target_position = _nav_target_position(target_node)
	target_movement = target
	end_communication = false
	play_walk()
	print("vesna [%s] walking to %s at %s (node %s)" % [name, target, navigator.target_position, target_node.name])
	#region agent log
	if DOOR_MARKERS.has(target):
		_debug_log("H-A", "vesna.gd:walk", "door_walk_start", {
			"agent": name,
			"door": target,
			"current_region": _current_region,
			"marker_node": target_node.name,
			"target_pos": str(navigator.target_position),
			"agent_pos": str(global_position),
		})
	#endregion


func notify_portal_teleport(door_name: String) -> void:
	var prev := _current_region
	if PORTAL_REGION.has(door_name):
		_current_region = PORTAL_REGION[door_name]
	else:
		_refresh_current_region_from_zones()
	#region agent log
	_debug_log("H-B", "vesna.gd:notify_portal_teleport", "portal_region_sync", {
		"agent": name, "door": door_name, "from": prev, "to": _current_region,
		"pos": str(global_position),
	})
	#endregion


func _refresh_current_region_from_zones() -> void:
	var regions := get_node_or_null(NAV_ROOT + "/Regions")
	if regions == null:
		return
	# Stabilità: se la regione corrente è ancora valida (il corpo la sovrappone ancora), mantienila.
	# Vicino a una porta condivisa (es. salone↔cucina su door_B3) le due Area3D possono sovrapporsi:
	# senza questa preferenza si sceglierebbe il lato sbagliato solo perché un'altra zona compare
	# prima nell'ordine dei figli → marker errato (cucina_door_B3 invece di salone_door_B3).
	if not _current_region.is_empty():
		var cur_zone_name: String = NAV_ALIASES.get(_current_region, "")
		if not cur_zone_name.is_empty():
			var cur_area := regions.get_node_or_null(cur_zone_name) as Area3D
			if cur_area != null and cur_area.overlaps_body(self):
				return
	for child in regions.get_children():
		if not child is Area3D:
			continue
		var area := child as Area3D
		if area.overlaps_body(self):
			_current_region = _region_from_zone_name(area.name)
			return


func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var entry := {
		"sessionId": "f48318",
		"timestamp": Time.get_ticks_msec(),
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
	}
	var file := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	else:
		file.seek_end()
	if file != null:
		file.store_line(JSON.stringify(entry))
		file.close()


func _resolve_nav_target(target: String) -> Node3D:
	if GRABBABLE_MARKERS.has(target):
		var grabbable_marker := get_node_or_null(
			NAV_ROOT + "/" + GRABBABLE_MARKERS[target]
		) as Node3D
		if grabbable_marker != null:
			return grabbable_marker

	var poi := get_node_or_null(NAV_ROOT + "/Markers/" + target) as Node3D
	if poi != null:
		return poi

	if ZONE_MARKERS.has(target):
		var zone_marker := get_node_or_null(
			NAV_ROOT + "/Markers/" + ZONE_MARKERS[target]
		) as Node3D
		if zone_marker != null:
			return zone_marker
		push_warning("vesna: zone marker missing for %s (%s)" % [target, ZONE_MARKERS[target]])

	if DOOR_MARKERS.has(target):
		var marker_name := _resolve_door_marker_name(target)
		if not marker_name.is_empty():
			var door_marker := get_node_or_null(NAV_ROOT + "/Markers/" + marker_name) as Node3D
			if door_marker != null:
				return door_marker
			push_warning(
				"vesna: door marker missing for %s in region %s (%s)"
				% [target, _current_region, marker_name]
			)
		var door_node := get_node_or_null(NAV_ROOT + "/Doors/" + target) as Node3D
		if door_node != null:
			print(
				"vesna [%s] door %s fallback to Doors/ node (region: %s)"
				% [name, target, _current_region]
			)
			return door_node
		push_warning("vesna: door target not found: %s (region: %s)" % [target, _current_region])
		return null

	return _resolve_mapzone_target(target)


func _resolve_door_marker_name(door: String) -> String:
	if not DOOR_MARKERS.has(door):
		return ""
	var sides: Dictionary = DOOR_MARKERS[door]
	if not _current_region.is_empty() and sides.has(_current_region):
		return str(sides[_current_region])
	var best_marker := ""
	var best_dist := INF
	for region in sides:
		var marker_name := str(sides[region])
		var marker := get_node_or_null(NAV_ROOT + "/Markers/" + marker_name) as Node3D
		if marker == null:
			continue
		var dist := global_position.distance_to(marker.global_position)
		if dist < best_dist:
			best_dist = dist
			best_marker = marker_name
	if not best_marker.is_empty():
		#region agent log
		_debug_log("H-A", "vesna.gd:_resolve_door_marker_name", "closest_side_marker", {
			"door": door,
			"current_region": _current_region,
			"chosen_marker": best_marker,
			"distance": best_dist,
		})
		#endregion
	return best_marker


func _is_door_target(target: String) -> bool:
	return DOOR_MARKERS.has(target)


func _resolve_mapzone_target(target: String) -> Node3D:
	var region_name: String = NAV_ALIASES.get(target, target)
	if target.begins_with("MapZone_"):
		region_name = target

	var region := get_node_or_null(NAV_ROOT + "/Regions/" + region_name) as Node3D
	if region != null:
		return region

	return get_node_or_null(NAV_ROOT + "/Doors/" + target) as Node3D


func _target_uses_marker(target: String) -> bool:
	if target == "empty" or target.is_empty():
		return false
	if get_node_or_null(NAV_ROOT + "/Markers/" + target) != null:
		return true
	if ZONE_MARKERS.has(target):
		return get_node_or_null(NAV_ROOT + "/Markers/" + ZONE_MARKERS[target]) != null
	if _is_door_target(target):
		var marker_name := _resolve_door_marker_name(target)
		return not marker_name.is_empty() and get_node_or_null(NAV_ROOT + "/Markers/" + marker_name) != null
	return false


func _nav_target_position(node: Node3D) -> Vector3:
	var pos := node.global_position
	if node is Area3D:
		var shape := (node as Area3D).get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null:
			pos = shape.global_transform.origin
	var nav_region := get_node_or_null(NAV_ROOT) as NavigationRegion3D
	if nav_region != null:
		pos = NavigationServer3D.map_get_closest_point(nav_region.get_navigation_map(), pos)
	return pos


func signal_end_movement(reason: String = "destination_reached") -> void:
	target_movement = "empty"
	end_communication = true
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var signal_payload := {
		"sender": "body",
		"receiver": "vesna",
		"type": "signal",
		"data": {
			"type": "movement",
			"status": "completed",
			"reason": reason,
		},
	}
	ws.send_text(JSON.stringify(signal_payload))
	print("vesna [%s] movement completed signal sent (%s)" % [name, reason])


func _get_anim_state_machine() -> AnimationNodeStateMachinePlayback:
	var tree := _get_animation_tree()
	if tree == null:
		return null
	tree.active = true
	return tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback


func play_idle() -> void:
	var sm := _get_anim_state_machine()
	if sm != null:
		sm.travel(IDLE_STATE)
		return
	var player := _get_animation_player()
	if player == null:
		return
	if player.has_animation(IDLE_ANIM):
		player.play(IDLE_ANIM)


func play_walk() -> void:
	var sm := _get_anim_state_machine()
	if sm != null:
		sm.travel(WALK_STATE)
		return
	var player := _get_animation_player()
	if player == null:
		return
	if player.has_animation(WALK_ANIM):
		player.play(WALK_ANIM)


func _get_animation_tree() -> AnimationTree:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return null
	for child in body.get_children():
		if not child.visible:
			continue
		var tree := child.get_node_or_null("AnimationTree") as AnimationTree
		if tree:
			return tree
	for child in body.get_children():
		var tree := child.get_node_or_null("AnimationTree") as AnimationTree
		if tree:
			return tree
	return null


func _get_animation_player() -> AnimationPlayer:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return null
	for child in body.get_children():
		if not child.visible:
			continue
		var anim_player := child.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			return anim_player
	for child in body.get_children():
		var anim_player := child.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			return anim_player
	return null
