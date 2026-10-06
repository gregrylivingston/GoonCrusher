class_name CarArtSet extends Resource

#A car's baked art (scripts/art/bake_cars.py, docs/CAR_ART.md). Each paint has three sheets drawn from
#the same geometry, so they line up pixel for pixel: like new, dented and wrecked. car_damage.gdshader
#blends them per system using zoneMask. Sheets are authored at 2x; the car shows them at scale 0.5.

@export var weathered: Array[Texture2D] = []  #the default paint
@export var showroom: Array[Texture2D] = []   #the clean cosmetic paint (Settings "gameplay/car_paint")
@export var zoneMask: Texture2D               #R = system id * 51, G = how far damage must spread to reach the pixel
@export var shadow: Texture2D

@export_group("Damage FX anchors (car space)")
@export var hood := Vector2.ZERO        #engine smoke and fire
@export var tank := Vector2.ZERO        #fuel filler: drips and fire
@export var frontWheel := Vector2.ZERO  #right front wheel; mirrored for the left one

func sheets(paint: String) -> Array[Texture2D]:
	return showroom if paint == "showroom" && showroom.size() == 3 else weathered
