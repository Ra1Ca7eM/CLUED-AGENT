extends PanelContainer

signal pressed(role_key: String)

const CIRCLE_SHADER := preload("res://ui/notebook/shaders/circle_avatar.gdshader")
const AVATAR_SIZE := 104

var _role_key: String = ""
var _display_name: String = ""
var _model_id: String = ""

@onready var _avatar: TextureRect = %Avatar
@onready var _name_label: Label = %NameLabel

func _ready() -> void:
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = CIRCLE_SHADER
	_avatar.material = shader_mat
	gui_input.connect(_on_gui_input)
	_apply_display()

func setup(role_key: String, display_name: String, model_id: String) -> void:
	_role_key = role_key
	_display_name = display_name
	_model_id = model_id
	_apply_display()

func _apply_display() -> void:
	if not is_node_ready():
		return
	_name_label.text = _display_name
	var path := GameState.get_npc_profile_image_path(_model_id)
	if ResourceLoader.exists(path):
		_avatar.texture = load(path) as Texture2D
	else:
		_avatar.texture = null

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(_role_key)
