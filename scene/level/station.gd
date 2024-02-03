extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func setNighttime(isNighttime: bool):
	if isNighttime:	$Polygon2D/Lights.visible = true
	else: $Polygon2D/Lights.visible = false


func _on_driveway_body_entered(body):
	if body.has_method("getIsPlayer"):
		if SaveManager.playerData.gameMode == Root.gameModes.SPRINT ||  SaveManager.playerData.gameMode == Root.gameModes.MARATHON:
			Root.levelRoot.endLevel(true, Root.endCondition.SUCCESS )
		
