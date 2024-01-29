@tool
extends roadButton

@export var myIcon: Texture2D

# Called when the node enters the scene tree for the first time.
func _ready():
	icon = myIcon
	super()
	add_theme_stylebox_override("hover", get_theme_stylebox("normal"))
	add_theme_stylebox_override("pressed", get_theme_stylebox("normal"))
	add_theme_stylebox_override("focus", get_theme_stylebox("normal"))
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func setValue(value):
	if value<10:
		updateText( " " + str(value) )
	else:updateText(str(value))

