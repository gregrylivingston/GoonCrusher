extends TextureRect

#One slot reel symbol, with its name tag (Pickups.shortName) under it in the gap between symbols, so it
#scrolls with the reel. STAR and coins need no tag.

var type = "coin": #a pickup id (scripts/global/pickups.gd) or SlotSymbols.STAR
	set(value):
		type = value
		queue_redraw()

func _draw() -> void:
	if type == SlotSymbols.STAR || type == "coin": return
	HudTheme.text(self, Vector2(size.x * 0.5, size.y + 20.0), Pickups.shortName(type), Pickups.TAG_SIZE + 3, HudTheme.OUTLINE, HORIZONTAL_ALIGNMENT_CENTER, 4, Color(1, 1, 1, 0.85)) #dark on the reel's white face
