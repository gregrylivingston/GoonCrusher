class_name Landscape extends Resource
## Where a level is (docs/WORLD.md, "Landscapes"): the layout generator, the ground materials, walls, water,
## natural props and district name words. One per res://world/landscapes/<id>.tres, listed by Landscapes. A new
## landscape re-skins an existing generator: it maps terrains to its own materials, so needles drive like grass
## and lava kills like deep water, with no new terrain physics. Until its art exists in world/art it borrows
## its fallback landscape's skin (Landscapes.skinOf) and keeps its own generator, features and props.

@export var id: StringName
@export var displayName: String
## The layout generator (WorldField grammar): meadow, bayou, canyon, quarry, mountain, highway, city or yard
@export var grammar: StringName = &"meadow"
## What the landscape means for the player, for the Goonopedia
@export_multiline var text: String

@export_group("World")
## Generator parameters a level that sets none uses (LevelDef.features)
@export var features: Dictionary = {}
## Root.terrain ids by noise band, low to high, for a level that sets none (LevelDef.baseTerrain)
@export var baseTerrain: Array = []
## Root.terrain accents for a level that sets none (LevelDef.accents)
@export var accents: Array = []
## Terrains the generator adds to a level's base and accents (the ocean's water and shallows are always in)
@export var terrains: Array = []

@export_group("Skin")
## Root.terrain id -> ground material name (world/art/ground/<name>.png), over WorldSkin.MATERIAL_OF
@export var materials: Dictionary = {}
## The material on top of walls (rock; roofs in a town)
@export var roofMaterial: String = "rock"
## The edge strip along walls (world/art/edges/<name>.png)
@export var wallStrip: String = "cliff_lip"
@export var wallTint := Color.WHITE
## How far borders between surfaces wander (ground.gdshader `organic`): crisper on built-up landscapes
@export var organic := 1.0
## Decor laid on rooftops (BUILDING cells), or none
@export var roofDecor: StringName = &""
## "water" or "lava": lava glows (waterGlow, emission added to the water layer) and its shore foam is waterFoam
@export var waterLook: StringName = &"water"
@export var waterGlow := Color(0, 0, 0, 0)
@export var waterFoam := Color.WHITE

@export_group("Dressing")
## Natural props: {prop id: weight} (props.json; DECOR ones as MultiMesh decor), on every zone, under the
## region's own (Territories dressing)
@export var dressing: Dictionary = {}
## Natural set pieces: {motif id: weight} (WorldSkin.MOTIFS)
@export var motifs: Dictionary = {}
## District names' second words ("Flats", "Gulch"); the region gives the first
@export var nameSecond: Array[String] = []

## The landscape whose skin this one borrows while its art is missing; none for today's eight
@export var fallback: StringName = &""

## The ground material for a terrain id
func materialOf(t: int) -> String:
	return String(materials.get(t, WorldSkin.MATERIAL_OF[t] if t >= 0 && t < WorldSkin.MATERIAL_OF.size() else "grass"))
