extends PanelContainer
class_name InspectionHudPanel

const MAX_DESC_WIDTH := 380.0
const SCREEN_MARGIN := 16.0
const TOP_MARGIN_RATIO := 0.03

@onready var _margin: MarginContainer = $MarginContainer
@onready var _vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var _title: Label = %TitleLabel
@onready var _description: Label = %DescriptionLabel

func fit_to_content() -> void:
	if not is_inside_tree():
		return

	var title_w: float = _text_width(_title)
	var desc_natural_w: float = _text_width(_description)
	var wrap_w: float = minf(desc_natural_w, MAX_DESC_WIDTH)
	var content_w: float = maxf(title_w, wrap_w)

	_title.custom_minimum_size = Vector2(content_w, 0)
	_description.custom_minimum_size = Vector2(wrap_w, 0)

	var title_sz := _title.get_minimum_size()
	var desc_sz := _description.get_minimum_size()

	var sep := float(_vbox.get_theme_constant("separation"))
	var ml := float(_margin.get_theme_constant("margin_left"))
	var mr := float(_margin.get_theme_constant("margin_right"))
	var mt := float(_margin.get_theme_constant("margin_top"))
	var mb := float(_margin.get_theme_constant("margin_bottom"))
	var panel_w := content_w + ml + mr
	var panel_h := title_sz.y + sep + desc_sz.y + mt + mb
	custom_minimum_size = Vector2(panel_w, panel_h)
	reset_size()
	var top_y := get_viewport_rect().size.y * TOP_MARGIN_RATIO
	offset_top = top_y
	offset_bottom = top_y + panel_h
	offset_right = -SCREEN_MARGIN
	offset_left = -SCREEN_MARGIN - panel_w

func _text_width(label: Label) -> float:
	if label.text.is_empty():
		return 0.0
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	if font == null:
		return label.get_minimum_size().x
	return font.get_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x
