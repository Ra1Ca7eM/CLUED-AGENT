extends Node

const PORT := 8096
const DOOR_PORTAL_SERVICE := preload("res://scripts/navigation/door_portal_service.gd")
const OPEN_LOCK_SEC := 12.0

var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()
## Lock PER-PORTA: door_name -> ticks_msec di inizio apertura.
## Porte diverse si aprono in parallelo; la stessa porta non viene aperta due volte insieme.
var _opening_doors: Dictionary = {}


func _ready() -> void:
	if tcp_server.listen(PORT) != OK:
		push_error("door_artifact_bridge: unable to start WS server on port %d" % PORT)
		set_process(false)
	else:
		print("door_artifact_bridge: listening on port %d" % PORT)


func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		if conn == null:
			continue
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
			ws.close()
		var err := ws.accept_stream(conn)
		if err != OK:
			push_warning("door_artifact_bridge: accept_stream failed (%s)" % err)

	ws.poll()

	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var msg: String = ws.get_packet().get_string_from_ascii()
			print("door_artifact_bridge received: ", msg)
			var intention: Variant = JSON.parse_string(msg)
			if intention is Dictionary:
				manage(intention)


func manage(intention: Dictionary) -> void:
	if intention.get("type", "") != "interaction":
		return
	var data: Dictionary = intention.get("data", {})
	if data.get("type", "") != "open":
		return
	var door_name: String = intention.get("sender", "")
	var agent_name: String = data.get("agent", "")
	if door_name.is_empty() or agent_name.is_empty():
		push_warning("door_artifact_bridge: missing door or agent in open request")
		return
	if _opening_doors.has(door_name):
		var elapsed_sec := (Time.get_ticks_msec() - int(_opening_doors[door_name])) / 1000.0
		if elapsed_sec >= OPEN_LOCK_SEC:
			push_warning(
				"door_artifact_bridge: resetting stuck lock for %s after %.1fs" % [door_name, elapsed_sec]
			)
			_opening_doors.erase(door_name)
		else:
			# Stessa porta gia' in apertura: la prima apertura inviera' "completed" e il Door
			# aggiornera' status=open per TUTTI gli agenti in attesa. Ignorare e' sicuro.
			push_warning("door_artifact_bridge: %s already opening, skipping duplicate" % door_name)
			return
	_open_door(door_name, agent_name)


func _begin_opening(door_name: String) -> void:
	_opening_doors[door_name] = Time.get_ticks_msec()


func _end_opening(door_name: String) -> void:
	_opening_doors.erase(door_name)


func _open_door(door_name: String, agent_name: String) -> void:
	_begin_opening(door_name)
	var agent := _find_agent(agent_name)
	if agent == null:
		push_warning("door_artifact_bridge: agent not found: %s" % agent_name)
		_send_completed(door_name, false)
		_end_opening(door_name)
		return

	var ctrl: DoorController = DoorRegistry.get_controller(door_name)
	if ctrl == null:
		push_warning("door_artifact_bridge: door not registered: %s" % door_name)
		_send_completed(door_name, false)
		_end_opening(door_name)
		return

	var host := get_tree().current_scene as Node3D

	# Porta portata in stato APERTO in modo robusto (chiusa, in chiusura o gia' aperta).
	ctrl.open_for_agent(agent)

	# Attende che l'eventuale animazione finisca, con timeout di sicurezza.
	# NB: niente piu' "await ctrl.opened" (non si emette se la porta stava chiudendo -> hang).
	var deadline := Time.get_ticks_msec() + int(OPEN_LOCK_SEC * 1000.0)
	while ctrl.is_animating() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	if DOOR_PORTAL_SERVICE.is_portal(door_name):
		await DOOR_PORTAL_SERVICE.teleport_interactor(ctrl, host)

	_send_completed(door_name, true)
	_end_opening(door_name)


func _find_agent(agent_name: String) -> Node3D:
	var key := agent_name.to_lower()
	for node in get_tree().get_nodes_in_group("agents"):
		if node.name.to_lower() == key and node is Node3D:
			return node as Node3D
	return null


func _send_completed(door_name: String, _ok: bool) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var payload := {
		"sender": "artifact",
		"receiver": door_name,
		"type": "signal",
		"data": {
			"type": "interaction",
			"status": "completed",
			"reason": "door_opened",
		},
	}
	ws.send_text(JSON.stringify(payload))
	print("door_artifact_bridge: door_opened signal sent for %s" % door_name)


func _exit_tree() -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close()
	if tcp_server.is_listening():
		tcp_server.stop()
