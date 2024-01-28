
class_name OverheadCarArea2D extends Area2D


@export var friction := 0.0
@export var drag: float = 0.0


signal car_body_entered(body: Node2D, area: OverheadCarArea2D)
signal car_body_exited(body: Node2D, area: OverheadCarArea2D)


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body is OverheadCarBody2D:
		body._on_overhead_car_area_2d_car_body_entered(self)


func _on_body_exited(body):
	if body is OverheadCarBody2D:
		body._on_overhead_car_area_2d_car_body_exited(self)
