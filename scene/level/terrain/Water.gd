extends Area2D


func _on_body_entered(body):
	if body is Walker: body.destroy(&"drown") #no crush decal on water
	elif body.has_method("destroy"):
		body.destroy()
