extends Area2D

#Drowns goons (and world props on the goon layer) that wander in. Its mask leaves out the car: the car
#is wrecked by World.lethalAt in its own _physics_process, so it can't be killed twice.

func _on_body_entered(body):
	if body is Walker: body.destroy(&"drown") #no crush decal on water
	elif body.has_method("destroy"):
		body.destroy()
