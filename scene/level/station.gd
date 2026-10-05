extends Node2D


func _ready():
	#lamps start off during the day
	setNighttime(is_instance_valid(Root.levelRoot) && not Root.levelRoot.isDaytime)

func setNighttime(isNighttime: bool):
	if isNighttime:	$Polygon2D/Lights.visible = true
	else: $Polygon2D/Lights.visible = false


func _on_driveway_body_entered(body):
	if body.has_method("getIsPlayer"):
		if SaveManager.playerData.gameMode == Root.gameModes.SPRINT ||  SaveManager.playerData.gameMode == Root.gameModes.MARATHON:
			Root.levelRoot.endLevel(true, Root.endCondition.SUCCESS )
		
