@tool
extends Panel

@export var myIcon: Texture2D

# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/icon.texture = myIcon



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func setValue(value):
	$HBoxContainer/Label2.text = str(value)
