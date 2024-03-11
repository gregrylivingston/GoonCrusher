@tool
extends roadButton

@export var myIcon: Texture2D

func _ready():
	icon = myIcon
	super()


func setValue(value):
	#if value<10:
	#	updateText( " " + str(value) )
	#else:
		updateText(str(value))

