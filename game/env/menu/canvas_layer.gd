extends CanvasLayer


@export var telecamera_menu: Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. '_delta' is intentionally unused.
func _process(_delta: float) -> void:
	pass


func _on_btn_start_pressed() -> void:
	# Nascondi l'interfaccia istantaneamente per un effetto più cinematografico
	$Control.hide() 
	# Fai partire lo zoom
	telecamera_menu.esegui_zoom_start()

func _on_btn_quit_pressed() -> void:
	get_tree().quit()
