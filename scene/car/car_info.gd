class_name CarInfo extends Resource

#What the main menu needs to show a car, plus its base stats. Each car scene points at its own
#<car>_info.tres through `info`, and the car copies these values when it is created, so the menu can
#browse cars without loading their scenes (sprites, lights and ~35 voice lines each).
#Edit a car's stats and menu art here, not on the car scene.

@export var carId: String
@export var charName: String = "Hi"
@export var profilePic: Texture2D
@export var backgroundPic: Texture2D
#The weathered side view (art/<car>_side.png, 256×96, facing right), baked by scripts/art/bake_cars.py --job side.
#The menu's car strips draw it small, and a dark modulate of it as the car's silhouette. docs/CAR_ART.md, "Side views".
@export var sidePic: Texture2D
@export var introAudio: Array[AudioStreamMP3] = []

@export_group("Base stats")
@export var engine: int = 25    # Forward acceleration force.
@export var steering: int = 12  # Amount that front wheel turns, in degrees
@export var traction: int = 4   #grip, slides and brakes
@export var armor: int = 1
@export var luck: int = 1
@export var clover: int = 1
@export var oil: int = 1
@export var headlights: int = 1
@export var traits: Array[StringName] = [] #the car's signature features (CarTraits), shown on its garage card
@export var weight: int = 50 #0-100, never upgraded: heavy cars turn in slower, slide wider, brake longer (CarHandling)
@export var redline: float = 6.5 #the tach's redline, in thousands of rpm: where the needle is as a gear runs out (HudDial)
@export var hudSkin: StringName = &"" #the car's dashboard (HudSkin.SKINS, docs/HUD.md "Dashboards"); empty is the house look
@export var gears: int = 0 #forward gears of a manual gearbox (OverheadCarBody2D, "the gearbox"); 0 is an automatic

#res://scene/car/sedan/sedan.tscn -> res://scene/car/sedan/sedan_info.tres
static func pathFor(carScene: String) -> String:
	return carScene.get_basename() + "_info.tres"

const FIELDS =["carId", "charName", "profilePic", "backgroundPic", "introAudio", "engine", "steering", "traction", "armor", "luck", "clover", "oil", "headlights", "weight", "traits", "gears", "redline", "hudSkin"]
