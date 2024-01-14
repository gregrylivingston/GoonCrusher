extends CharacterBody2D

var alive: bool = true
var isPlayer: bool = false


@export var powerupDropChance: int = 90
@export var coinDropChance: int = 70
@export var speed: float = 1.0

var target: Vector2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if alive && is_instance_valid( Root.playerCar ):
		target.x = clamp( Root.playerCar.position.x - position.x , -speed , speed)
		target.y = clamp(  Root.playerCar.position.y - position.y , -speed , speed)	
		move_and_collide( target )


func destroy():
	$CollisionShape2D.queue_free()
	alive = false
	$Walker.animation = "death"
	$AudioStreamPlayer2D2.volume_db = randf_range(0.0,5.0) + SaveManager.getVolume("fx")
	$AudioStreamPlayer2D2.pitch_scale = randf_range(0.95,1.05)
	$AudioStreamPlayer2D2.play()
	$AudioStreamPlayer2D.volume_db = randf_range(0.0,8.0) + SaveManager.getVolume("fx")
	$AudioStreamPlayer2D.pitch_scale = randf_range(0.95,1.05)
	$AudioStreamPlayer2D.play()
	
	var diceRoll = randi_range(0,100) 
	if diceRoll > powerupDropChance:
		await get_tree().create_timer(0.5).timeout
		var newPowerup = Root.getPowerup()
		newPowerup.position = global_position
		Root.levelRoot.add_child(newPowerup)
	elif diceRoll > coinDropChance:
		await get_tree().create_timer(0.5).timeout
		pass


func _on_walker_animation_looped():
	if not alive:queue_free()

