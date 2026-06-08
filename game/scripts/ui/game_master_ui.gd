extends CanvasLayer

## Pannello "Game Master" (scena `ui/dialogue/game_master_ui.tscn`).
## Single-purpose: si apre/chiude con ESC, riceve l'accusa finale del giocatore
## (chi/cosa/perche), la inoltra all'agente `gamemaster` via il bridge ChatBDI e
## mostra il verdetto. Su `solved` aggiunge la storia completa scritta a mano.
## NON salva nulla nel Taccuino. Segue lo schema overlay di `notebook_ui.gd`.

const BUBBLE_SCENE := preload("res://ui/dialogue/chat_message_bubble.tscn")
const TYPING_SCENE := preload("res://ui/dialogue/typing_indicator_bubble.tscn")

## Bridge HTTP verso ChatBDI: instrada sempre al ruolo "gamemaster".
const BRIDGE_URL := "http://127.0.0.1:8090/dialogue"
const BRIDGE_ROLE_KEY := "gamemaster"
## Alto di proposito: su PC lenti le 3 passate LLM possono richiedere minuti.
const BRIDGE_TIMEOUT := 660.0

const INTRO_TEXT := "I am the Game Master. When you think you have solved the case, tell me who did it, with what, and why."

## TODO: testo autorale definitivo della soluzione (lo fornisce l'utente, in inglese).
## Mostrato in chat quando il verdetto e' "solved". Placeholder finche' non arriva il testo.
const STORY_SOLVED_TEXT := "[PLACEHOLDER - full story]\nAlberto Mori, Aurelio's childhood friend and the doctor managing his health foundation, had been embezzling its funds to cover gambling debts. That night Aurelio discovered it and, after reading his own diary, Alberto realised he would be reported to the police. To silence him he laced Aurelio's brandy with digitalis taken from the cellar, stole his heart pills, and tried to frame Evelina by tearing up the prenuptial contract in her room. (Replace this placeholder with the final authored text.)"

const SLIDE_DURATION := 0.45
const SLIDE_OFFSET := 460.0

@onready var _panel: Panel = %GMPanel
@onready var _scroll: ScrollContainer = %MessageScroll
@onready var _messages_vbox: VBoxContainer = %MessagesVBox
@onready var _input_line: LineEdit = %MessageInput
@onready var _send_button: Button = %SendButton

var _typing_node: Control = null
var _is_open: bool = false
var _waiting: bool = false
var _slide_tween: Tween = null
var _intro_shown: bool = false


func _ready() -> void:
	add_to_group("overlay_ui")
	layer = 10
	_panel.visible = false
	_panel.modulate.a = 1.0
	_reset_panel_offscreen()


func _is_currently_open() -> bool:
	return _is_open


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_input_line.release_focus()
	_hide_typing()
	_slide_to(SLIDE_OFFSET, false)
	if not _other_overlay_open():
		_unfreeze_player()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_open:
		get_viewport().set_input_as_handled()
		close()
	elif _can_open():
		get_viewport().set_input_as_handled()
		_open()


## Apri SOLO se non c'e' altro a schermo (tutorial, ispezione, dialogo NPC, altri overlay).
func _can_open() -> bool:
	if GameState.inspection_active:
		return false
	var tutorial := get_tree().root.find_child("TutorialOverlay", true, false) as CanvasLayer
	if tutorial != null and tutorial.visible:
		return false
	var chat := get_tree().root.find_child("DialogueChatUI", true, false)
	if chat != null and chat.has_method("is_open") and chat.is_open():
		return false
	return not _other_overlay_open()


func _other_overlay_open() -> bool:
	for node in get_tree().get_nodes_in_group("overlay_ui"):
		if node != self and node.has_method("_is_currently_open") and node._is_currently_open():
			return true
	return false


func _open() -> void:
	# Chiudi eventuali altri overlay del gruppo (coerente con notebook_ui).
	for node in get_tree().get_nodes_in_group("overlay_ui"):
		if node != self and node.has_method("_is_currently_open") and node._is_currently_open():
			node.close()

	_is_open = true
	_waiting = false
	if not _intro_shown:
		_add_bubble(INTRO_TEXT, false)
		_intro_shown = true

	_reset_panel_offscreen()
	_panel.visible = true
	_input_line.editable = true
	_input_line.text = ""
	_freeze_player()
	_input_line.grab_focus()
	_slide_to(0.0, true)


func _reset_panel_offscreen() -> void:
	_panel.offset_left = SLIDE_OFFSET
	_panel.offset_right = SLIDE_OFFSET


func _slide_to(target_offset: float, opening: bool) -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_panel, "offset_left", target_offset, SLIDE_DURATION)
	_slide_tween.tween_property(_panel, "offset_right", target_offset, SLIDE_DURATION)
	if not opening:
		_slide_tween.finished.connect(func() -> void:
			_panel.visible = false
			_reset_panel_offscreen()
		, CONNECT_ONE_SHOT)


func _on_close_pressed() -> void:
	close()


func _on_send_pressed() -> void:
	_submit(_input_line.text)


func _on_text_submitted(_text: String) -> void:
	_submit(_input_line.text)


func _submit(text: String) -> void:
	if _waiting:
		return
	var msg := text.strip_edges()
	if msg == "":
		return
	_add_bubble(msg, true)
	_input_line.text = ""
	_input_line.grab_focus()
	_show_typing()
	_waiting = true
	_request_bridge_reply(msg)


func _request_bridge_reply(player_text: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = BRIDGE_TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			_on_bridge_reply(result, code, body)
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := JSON.stringify({ "role_key": BRIDGE_ROLE_KEY, "player_text": player_text })
	var err := http.request(BRIDGE_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_deliver_error("(The Game Master is unreachable - is the MAS running?)")


func _on_bridge_reply(result: int, code: int, body: PackedByteArray) -> void:
	if not _is_open:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_deliver_error("(The Game Master is not responding - make sure the MAS is running.)")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not bool(parsed.get("ok", false)):
		_deliver_error("(The Game Master is not responding - make sure the MAS is running.)")
		return
	var reply := str(parsed.get("reply_nl", "")).strip_edges()
	if reply == "":
		_deliver_error("(The Game Master had nothing to say.)")
		return
	_hide_typing()
	# Il GM segnala il successo con la sentinella di testo "[SOLVED]" all'inizio della risposta
	# (il bridge Java non espone un campo "verdict"). La rileviamo, la rimuoviamo dalla bolla
	# mostrata, e poi alleghiamo la storia completa (testo autorale, fedele al 100%).
	var solved := reply.to_upper().contains("[SOLVED]")
	if solved:
		reply = reply.replace("[SOLVED]", "").replace("[solved]", "").strip_edges()
		if reply == "":
			reply = "You have cracked the case."
	_add_bubble(reply, false)
	if solved:
		_add_bubble(STORY_SOLVED_TEXT, false)
	# Comportamento "continue": l'input resta attivo anche dopo aver risolto.
	_waiting = false


func _deliver_error(text: String) -> void:
	_hide_typing()
	_add_bubble(text, false)
	_waiting = false


func _add_bubble(text: String, is_player: bool) -> void:
	var bubble: PanelContainer = BUBBLE_SCENE.instantiate() as PanelContainer
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_vbox.add_child(bubble)
	bubble.call("setup", text, is_player)
	_scroll_to_bottom()


func _show_typing() -> void:
	if _typing_node != null:
		return
	_typing_node = TYPING_SCENE.instantiate() as Control
	_messages_vbox.add_child(_typing_node)
	_scroll_to_bottom()


func _hide_typing() -> void:
	if _typing_node != null:
		_typing_node.queue_free()
		_typing_node = null


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var sb := _scroll.get_v_scroll_bar()
	if sb:
		_scroll.scroll_vertical = int(sb.max_value)


func _freeze_player() -> void:
	var p := get_tree().root.find_child("ProtoController", true, false)
	if p == null:
		return
	p.set("can_move", false)
	p.set("can_jump", false)
	p.set("can_sprint", false)
	if p.has_method("release_mouse"):
		p.call("release_mouse")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unfreeze_player() -> void:
	var p := get_tree().root.find_child("ProtoController", true, false)
	if p == null:
		return
	p.set("can_move", true)
	p.set("can_jump", true)
	p.set("can_sprint", true)
	if p.has_method("capture_mouse"):
		p.call("capture_mouse")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
