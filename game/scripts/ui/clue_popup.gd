extends PanelContainer
class_name CluePopupPanel

const CLUE_LOCKED_MSG := "Dettagli forensi non ancora sbloccati. Ispeziona l'oggetto e usa la torcia UV (tasto destro) in modalità ispezione."

@onready var _title: Label = %CluePopupTitle
@onready var _normal_text: Label = %CluePopupNormalText
@onready var _uv_text: Label = %CluePopupUvText
@onready var _uv_block: VBoxContainer = %CluePopupUvBlock
@onready var _uv_header: Label = %UvHeader
@onready var _column_separator: VSeparator = %ColumnSeparator
@onready var _normal_image: TextureRect = %CluePopupNormalImage
@onready var _uv_image: TextureRect = %CluePopupUvImage
@onready var _normal_aspect: AspectRatioContainer = %NormalImageAspect
@onready var _uv_aspect: AspectRatioContainer = %UvImageAspect

func _ready() -> void:
	%CloseButton.pressed.connect(hide_popup)

func show_clue(clue_id: String) -> void:
	var clue := GameState.get_map_clue(clue_id)
	if clue.is_empty():
		return
	_title.text = str(clue.get("name", "Indizio"))
	var has_uv := false
	if not GameState.can_show_clue_map_details(clue_id):
		_normal_text.text = CLUE_LOCKED_MSG
		_uv_text.text = ""
		_normal_image.texture = null
		_uv_image.texture = null
		has_uv = false
	else:
		_normal_text.text = str(clue.get("normal_desc", "Informazioni non disponibili."))
		_uv_text.text = str(clue.get("uv_desc", ""))
		var normal_tex := _load_texture(str(clue.get("image_path", "")))
		var uv_tex := _load_texture(str(clue.get("uv_image_path", "")))
		_normal_image.texture = normal_tex
		_uv_image.texture = uv_tex
		has_uv = _uv_text.text.strip_edges() != "" or uv_tex != null
	_apply_layout(has_uv)
	visible = true

func hide_popup() -> void:
	visible = false

func _apply_layout(has_uv: bool) -> void:
	# Colonna normale (sempre presente)
	_configure_aspect(_normal_aspect, _normal_image)

	# Colonna UV: visibile solo se ci sono dettagli UV
	_column_separator.visible = has_uv
	_uv_block.visible = has_uv
	if has_uv:
		var has_uv_text := _uv_text.text.strip_edges() != ""
		var has_uv_image := _uv_image.texture != null
		_uv_header.visible = has_uv_text or has_uv_image
		_uv_text.visible = has_uv_text
		_configure_aspect(_uv_aspect, _uv_image)

func _configure_aspect(aspect: AspectRatioContainer, image: TextureRect) -> void:
	var tex := image.texture
	aspect.visible = tex != null
	if tex == null:
		return
	if tex.get_height() > 0:
		aspect.ratio = float(tex.get_width()) / float(tex.get_height())
	else:
		aspect.ratio = aspect.custom_minimum_size.x / maxf(aspect.custom_minimum_size.y, 1.0)

func _load_texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var loaded := load(path)
	if loaded is Texture2D:
		return loaded as Texture2D
	return null
