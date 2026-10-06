extends Node2D


func _ready():
	#lamps start off during the day
	setNighttime(is_instance_valid(Root.levelRoot) && not Root.levelRoot.isDaytime)

func setNighttime(isNighttime: bool):
	if isNighttime:	$Polygon2D/Lights.visible = true
	else: $Polygon2D/Lights.visible = false


#Reaching the station wins Sprint and Marathon. A car that ran out of fuel but is still rolling may
#coast in for the win (its NOGAS ending is still pending); a wrecked car (health <= 0, or water) may not.
func _on_driveway_body_entered(body):
	if body.has_method("getIsPlayer"):
		if not is_instance_valid(Root.levelRoot) || Root.levelRoot.hasEnded || body.health <= 0 || body.isWrecked: return
		if SaveManager.playerData.gameMode == Root.gameModes.SPRINT ||  SaveManager.playerData.gameMode == Root.gameModes.MARATHON:
			Root.levelRoot.endLevel(true, Root.endCondition.SUCCESS )
		elif body.has_method("repairAll"): body.repairAll() #in the other modes the station is a free repair shop
		
