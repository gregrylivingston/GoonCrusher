class_name Walker extends Enemy

enum mode { MOVE , ATTACK , IDLE , DEAD , PREPAREATTACK}
var myMode: mode = mode.MOVE

@export var speed: int = 6000
@export var prepareAttackDistance: int = 300
@export var attackSpeedMultiplier: float = 3.0
@export var attackDamage: float = 1
@export var powerupDropDict: Dictionary = {
	Root.upgrade.GEM:4,
	Root.upgrade.COIN:100,
	Root.upgrade.PURSE:4,
	Root.upgrade.SLOTMACHINE:1,
	Root.upgrade.HEALTH:10,
	Root.upgrade.FUEL:20,
	Root.upgrade.TRACTION:4,
	Root.upgrade.STEERING:4,
	Root.upgrade.ARMOR:4,
	Root.upgrade.ENGINE:4,
	Root.upgrade.OIL:4,
	Root.upgrade.CLOVER:4,
	Root.upgrade.HEADLIGHTS:4,
	Root.upgrade.LUCK:4
}

var isGiant: bool = false
var target: Vector2

func _ready():
	if isGiant:
		scale = Vector2(1.6,1.9)
		speed *= 4.0
		attackDamage *= 2
	else: 
		$Walker.set_material(null)


func checkDestroyDistance():
	if global_position.distance_to( Root.playerCar.global_position ) > 8000: queue_free()

	


func _physics_process(delta):
	match myMode:
		mode.MOVE:moveTowardsPlayer(delta)
		mode.ATTACK:attack(delta)
		mode.IDLE:idle()
		mode.PREPAREATTACK:prepareAttack(delta)

var idleTime = 0
@export var myIdleLength: int = 5
func _on_walker_animation_looped():
	match myMode:
		mode.DEAD:queue_free()
		mode.PREPAREATTACK:
			myMode = mode.ATTACK
			preparingAttack = false
		mode.ATTACK:
			myMode = mode.IDLE
			#$CollisionShape2D.scale = Vector2(1,1)
			idleTime = 0
			$Walker.animation = "prepare_attack"
			hitSuccess = false
		mode.IDLE:
			idleTime += 1
			if idleTime > myIdleLength:
				idleTime = 0
				myMode = mode.MOVE
				$Walker.animation = "default"
				checkDestroyDistance()
				
				

var chargeAudioRequest = false
var preparingAttack = false
func prepareAttack(delta):
	look_at(  Root.playerCar.position )
	if not preparingAttack:
		preparingAttack = true
		if randi()%3 == 0:Audio.queueRequest( audio_charge )
		$Walker.animation = "prepare_attack"

	

var hitSuccess = false
func attack(delta):
	$Walker.animation = "attack"
	#$CollisionShape2D.scale = Vector2(2,1)
	var directionToPlayer =  position.direction_to( Root.playerCar.position )
	look_at(  Root.playerCar.position )
	velocity =  directionToPlayer * speed * attackSpeedMultiplier * delta
	move_and_slide()
	#var collision = move_and_collide( directionToPlayer * speed * attackSpeedMultiplier * delta )
	#if collision:
	for i in get_slide_collision_count():
		var collider = get_slide_collision( i ).get_collider()
		if collider.has_method("damage"):
			collider.damage(attackDamage)
			if not hitSuccess:
				Audio.queueRequest( audio_hit )
				hitSuccess = true
	#In your player's set block function or something.


func idle():
	look_at(  Root.playerCar.position )

var moveCounter = randi_range(-100,100)
func moveTowardsPlayer(delta):
	moveCounter += 1
	if moveCounter > 1000:
		myMode = mode.IDLE
		moveCounter = randi_range(-100,100)
		$Walker.animation = "prepare_attack"
	else:
		var directionToPlayer =  position.direction_to( Root.playerCar.position )
		look_at(  Root.playerCar.position )
		velocity =  directionToPlayer * speed * delta
		move_and_slide()
		if position.distance_to( Root.playerCar.position ) < prepareAttackDistance:
			myMode = mode.PREPAREATTACK


	

func destroy():
	$Walker.set_material(null)
	$CollisionShape2D.queue_free()
	$LightOccluder2D.queue_free()
	myMode = mode.DEAD
	$Walker.animation = "death"
	get_tree().create_tween().tween_property($Walker , "modulate" , Color(1.0,1.0,1.0,0.3) , 20 )
	z_index -= 1
	$AudioStreamPlayer2D2.volume_db = randf_range(0.0,5.0) + SaveManager.getVolume("fx")
	$AudioStreamPlayer2D2.pitch_scale = randf_range(0.95,1.05)
	$AudioStreamPlayer2D2.play()
	$AudioStreamPlayer2D.volume_db = randf_range(0.0,8.0) + SaveManager.getVolume("fx")
	$AudioStreamPlayer2D.pitch_scale = randf_range(0.95,1.05)
	$AudioStreamPlayer2D.play()
	
	if randi_range(0,200) + Root.playerCar.clover > 190:
		await get_tree().create_timer(0.5).timeout
		var newPowerup = Root.getPowerupFromWeights(powerupDropDict)
		newPowerup.position = global_position
		Root.levelRoot.add_child(newPowerup)


				
			
		

