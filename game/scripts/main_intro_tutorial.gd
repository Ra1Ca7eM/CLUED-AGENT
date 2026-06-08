extends Node3D

const MainGameRuntime := preload("res://scripts/main_game_runtime.gd")
const FloorSnap := preload("res://scripts/map/floor_snap.gd")
const BRIEFING_TITLE_SIZE := 20
const BRIEFING_BODY_SIZE := 16
const BRIEFING_BUTTON_SIZE := 15

const TUTORIAL_STEPS: Array[String] = [
	"Benvenuto, investigatore.\nSei stato chiamato in un hotel di lusso da poco inaugurato dal suo proprietario, Aurelio Valtieri. Dopo i festeggiamenti Aurelio e stato trovato morto sul pavimento del salone. In casa c'erano quattro ospiti, ognuno con i propri segreti, e tu sei l'investigatore mandato a fare luce sull'accaduto.",
	"Gli ospiti in questione sono: Alberto medico di famiglia e CEO della fondazione di Aurelio, Evelina è la moglie di aurelio, Vittorio è l'architetto e Clarissa è la direttrice dell'hotel",
	"Il tuo compito e scoprire CHI ha ucciso Aurelio, COME (l'arma o il metodo usato) e PERCHE (il movente). Interroga i sospettati, raccogli gli indizi e confronta le loro versioni per smascherare le bugie.",
	"Muoviti con W A S D, corri con SHIFT. Avvicinati a un sospettato o a un oggetto e premi E per chattare o ispezionare gli indizi. Premi ESC per parlare con il GAME MASTER e dare la tua soluzione nella chat.",
	"Premi TAB per aprire il taccuino con la Mappa e i Dialoghi. Gli oggetti che scopri compariranno sulla mappa, potrei cliccarli per riprendere la loro descrizione, per aiutarti a ricostruire dove si trova ogni indizio.",
	"ATTENZIONE NON TUTTI GLI OGGETTI RIMARRANNO AL LORO POSTO!",
	"Con il tasto destro del mouse apri le porte e accendi la torcia UV. La torcia UV rivela dettagli nascosti e puo essere usata anche in modalita ispezione per far emergere tracce invisibili a occhio nudo."
]

@onready var player: Node = $ProtoController
@onready var overlay: CanvasLayer = $TutorialOverlay
@onready var panel: Panel = $TutorialOverlay/TutorialPanel
@onready var body_label: RichTextLabel = $TutorialOverlay/TutorialPanel/MarginContainer/VBoxContainer/BodyLabel
@onready var step_label: Label = $TutorialOverlay/TutorialPanel/MarginContainer/VBoxContainer/StepLabel
@onready var btn_prev: Button = $TutorialOverlay/TutorialPanel/MarginContainer/VBoxContainer/ButtonRow/BtnPrev
@onready var btn_next: Button = $TutorialOverlay/TutorialPanel/MarginContainer/VBoxContainer/ButtonRow/BtnNext
@onready var btn_close: Button = $TutorialOverlay/TutorialPanel/MarginContainer/VBoxContainer/ButtonRow/BtnClose
@onready var fade_rect: ColorRect = $TutorialOverlay/FadeRect

var current_step: int = 0
var _runtime: RefCounted = MainGameRuntime.new()

func _ready() -> void:
	_runtime.call("setup", self)
	_handle_return_spawn()
	_bind_buttons()
	_apply_investigative_style()
	_lock_player()
	_show_step(0)
	_play_scene_intro()

func _unhandled_input(event: InputEvent) -> void:
	_runtime.call("handle_unhandled_input", event, overlay.visible)

func _process(_delta: float) -> void:
	if not overlay.visible:
		_runtime.call("update_door_aim")

func _bind_buttons() -> void:
	btn_prev.pressed.connect(_on_prev_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_close.pressed.connect(_on_close_pressed)

func _apply_investigative_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	panel_style.border_color = Color(0.58, 0.54, 0.44, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.14, 0.14, 0.16, 0.97)
	button_style.border_color = Color(0.58, 0.54, 0.44, 0.95)
	button_style.set_border_width_all(1)
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_left = 6
	button_style.corner_radius_bottom_right = 6
	for button in [btn_prev, btn_next, btn_close]:
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82, 1))
		button.add_theme_font_size_override("font_size", BRIEFING_BUTTON_SIZE)

	step_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76, 1))
	step_label.add_theme_font_size_override("font_size", BRIEFING_TITLE_SIZE)
	body_label.add_theme_color_override("default_color", Color(0.93, 0.91, 0.85, 1))
	body_label.add_theme_font_size_override("normal_font_size", BRIEFING_BODY_SIZE)

func _play_scene_intro() -> void:
	fade_rect.show()
	fade_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		fade_rect.hide()
	)

func _show_step(step: int) -> void:
	current_step = clamp(step, 0, TUTORIAL_STEPS.size() - 1)
	step_label.text = "DOSSIER " + str(current_step + 1) + " / " + str(TUTORIAL_STEPS.size())
	body_label.text = "[center]" + TUTORIAL_STEPS[current_step] + "[/center]"
	btn_prev.disabled = current_step == 0
	btn_next.disabled = current_step == TUTORIAL_STEPS.size() - 1

func _on_prev_pressed() -> void:
	_show_step(current_step - 1)

func _on_next_pressed() -> void:
	_show_step(current_step + 1)

func _on_close_pressed() -> void:
	overlay.hide()
	_unlock_player()

func _lock_player() -> void:
	if player == null:
		return
	player.set("can_move", false)
	player.set("can_jump", false)
	player.set("can_sprint", false)
	if player.has_method("release_mouse"):
		player.call("release_mouse")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unlock_player() -> void:
	if player == null:
		return
	player.set("can_move", true)
	player.set("can_jump", true)
	player.set("can_sprint", true)
	if player.has_method("capture_mouse"):
		player.call("capture_mouse")

func _handle_return_spawn() -> void:
	var spawn_pos: Variant = SceneTransition.get_return_spawn()
	if spawn_pos == null:
		return
	var pos: Vector3 = spawn_pos as Vector3
	pos = FloorSnap.snap_feet_to_floor(self, pos)
	player.global_position = pos
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var zone_mgr := get_node_or_null("MapZoneManager") as MapZoneManager
	if zone_mgr != null:
		zone_mgr.resync_player_zones()
	SceneTransition.clear_return_spawn()
