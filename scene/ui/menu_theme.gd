class_name MenuTheme

#The menus' Theme, built in code from HudTheme's colors and fonts so the menus and the in-run HUD
#can't drift apart (docs/UI.md). Give a menu's root Control `theme = MenuTheme.theme()`.
#  Button            list row: faint fill, orange rim and gold text when focused or hovered
#  PrimaryButton     the one solid orange action per screen
#  Panel, PanelContainer   smoked glass with an orange rim; variations InfoPanel (blue rim),
#                    QuietPanel (faint rim), CardPanel (thick orange frame), KeyChip, PriceChip
#  Label variations  TitleLabel, GoldLabel, MutedLabel, BodyLabel, HintLabel, DarkLabel

const DARK_TEXT := Color(0.165, 0.051, 0.031)    #text on solid orange
const DEEP_ORANGE := Color(0.478, 0.122, 0.039)  #the primary button's edge
const BODY_TEXT := Color(0.91, 0.863, 0.776)

static var cached: Theme

static func theme() -> Theme:
	if cached: return cached
	var t = Theme.new()
	t.default_font = HudTheme.BOLD
	t.default_font_size = 22

	t.set_color("font_color", "Label", HudTheme.TEXT)
	t.set_color("font_outline_color", "Label", HudTheme.OUTLINE)
	t.set_constant("outline_size", "Label", 6)
	label(t, "TitleLabel", 44, HudTheme.TEXT, 10)
	label(t, "GoldLabel", 30, HudTheme.GOLD, 10, HudTheme.DEEP)
	label(t, "MutedLabel", 17, HudTheme.MUTED, 0, HudTheme.OUTLINE, HudTheme.BODY)
	label(t, "BodyLabel", 20, BODY_TEXT, 0, HudTheme.OUTLINE, HudTheme.BODY)
	label(t, "HintLabel", 16, BODY_TEXT, 4, HudTheme.OUTLINE, HudTheme.BODY)
	label(t, "DarkLabel", 30, DARK_TEXT, 0)

	#list buttons
	t.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 10))
	t.set_stylebox("hover", "Button", box(Color(HudTheme.RIM, 0.16), HudTheme.RIM, 10))
	t.set_stylebox("pressed", "Button", box(Color(HudTheme.RIM, 0.3), HudTheme.RIM, 10))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.02), Color(0, 0, 0, 0), 10))
	t.set_stylebox("focus", "Button", box(Color(HudTheme.RIM, 0.16), HudTheme.RIM, 10))
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]: t.set_color(state, "Button", HudTheme.GOLD)
	t.set_color("font_color", "Button", HudTheme.TEXT)
	t.set_color("font_disabled_color", "Button", Color(HudTheme.MUTED, 0.45))
	t.set_color("font_outline_color", "Button", HudTheme.OUTLINE)
	t.set_constant("outline_size", "Button", 5)
	t.set_constant("h_separation", "Button", 12)
	t.set_font_size("font_size", "Button", 24)

	#the primary action
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", primaryBox(HudTheme.RIM))
	t.set_stylebox("hover", "PrimaryButton", primaryBox(Color(1.0, 0.71, 0.3)))
	t.set_stylebox("pressed", "PrimaryButton", primaryBox(Color(0.85, 0.52, 0.12)))
	t.set_stylebox("disabled", "PrimaryButton", primaryBox(Color(0.42, 0.33, 0.24)))
	var focus = box(Color(0, 0, 0, 0), HudTheme.GOLD, 15, 3)
	focus.draw_center = false
	focus.set_expand_margin_all(5)
	t.set_stylebox("focus", "PrimaryButton", focus)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]: t.set_color(state, "PrimaryButton", DARK_TEXT)
	t.set_color("font_disabled_color", "PrimaryButton", Color(0.15, 0.12, 0.1))
	t.set_constant("outline_size", "PrimaryButton", 0)
	t.set_font_size("font_size", "PrimaryButton", 28)

	#settings tabs: pills, solid orange when selected
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 24, 0, Vector4(20, 8, 20, 8)))
	t.set_stylebox("hover", "TabButton", box(Color(HudTheme.RIM, 0.18), HudTheme.RIM, 24, 2, Vector4(20, 8, 20, 8)))
	t.set_stylebox("pressed", "TabButton", box(HudTheme.RIM, Color(0, 0, 0, 0), 24, 0, Vector4(20, 8, 20, 8)))
	t.set_stylebox("hover_pressed", "TabButton", box(Color(1.0, 0.71, 0.3), Color(0, 0, 0, 0), 24, 0, Vector4(20, 8, 20, 8)))
	t.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	t.set_color("font_color", "TabButton", BODY_TEXT)
	t.set_color("font_hover_color", "TabButton", HudTheme.GOLD)
	t.set_color("font_pressed_color", "TabButton", DARK_TEXT)
	t.set_color("font_hover_pressed_color", "TabButton", DARK_TEXT)
	t.set_constant("outline_size", "TabButton", 0)
	t.set_font_size("font_size", "TabButton", 22)

	#sliders: a dark track that fills orange
	t.set_stylebox("slider", "HSlider", box(Color(0.33, 0.3, 0.27), Color(0, 0, 0, 0), 5, 0, Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area", "HSlider", box(HudTheme.RIM, Color(0, 0, 0, 0), 5, 0, Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color(1.0, 0.71, 0.3), Color(0, 0, 0, 0), 5, 0, Vector4(0, 4, 0, 4)))

	var smoked = box(HudTheme.PANEL, Color(HudTheme.RIM, 0.55), 12)
	t.set_stylebox("panel", "Panel", smoked)
	t.set_stylebox("panel", "PanelContainer", smoked)
	panel(t, "InfoPanel", box(HudTheme.PANEL, Color(HudTheme.SKY, 0.45), 12))
	panel(t, "QuietPanel", box(HudTheme.PANEL, Color(1, 1, 1, 0.18), 12))
	panel(t, "CardPanel", box(Color(0.082, 0.067, 0.059, 0.97), HudTheme.RIM, 18, 5))
	panel(t, "SideCardPanel", box(Color(0.082, 0.067, 0.059, 0.97), Color(1, 1, 1, 0.22), 18, 3))
	panel(t, "KeyChip", box(Color(0.165, 0.145, 0.133), Color(0.478, 0.431, 0.384), 7, 2, Vector4(8, 1, 8, 1)))
	panel(t, "KeyChipHot", box(Color(HudTheme.RIM, 0.35), HudTheme.RIM, 7, 2, Vector4(8, 1, 8, 1)))
	panel(t, "PriceChip", box(Color(HudTheme.RIM, 0.2), Color(HudTheme.RIM, 0.7), 7, 2, Vector4(5, 1, 8, 1)))
	panel(t, "BandPanel", box(HudTheme.RIM, Color(0, 0, 0, 0), 0, 0, Vector4(12, 4, 12, 4)))
	cached = t
	return t

static func label(t: Theme, type: String, size: int, color: Color, outline: int, outlineColor := HudTheme.OUTLINE, font: Font = HudTheme.BOLD) -> void:
	t.set_type_variation(type, "Label")
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)
	t.set_color("font_outline_color", type, outlineColor)
	t.set_constant("outline_size", type, outline)
	t.set_font("font", type, font)

static func panel(t: Theme, type: String, style: StyleBox) -> void:
	t.set_type_variation(type, "PanelContainer")
	t.set_stylebox("panel", type, style)

static func box(bg: Color, border: Color, radius: int, width := 2, margins := Vector4(18, 10, 18, 10)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 6
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style

static func primaryBox(fill: Color) -> StyleBoxFlat:
	var style = box(fill, DEEP_ORANGE, 12, 2, Vector4(22, 10, 22, 14))
	style.shadow_color = DEEP_ORANGE
	style.shadow_size = 1
	style.shadow_offset = Vector2(0, 5)
	return style

#a key or button name in a small dark chip, for KeyHint
static func chip(text: String, size := 15) -> PanelContainer:
	var chipPanel = PanelContainer.new()
	chipPanel.theme_type_variation = "KeyChip"
	chipPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = size * 1.3
	chipPanel.add_child(label)
	return chipPanel

#---------- symbols in place of words ----------
#Prices and amounts read as numbers with the game's own symbols ("1,500 (coin)  3 (gem)"), not words.
#A part is a String (a label), a Texture2D (an icon at the text's height) or a cost Dictionary {"coin": n,
#"gem": n} (each amount followed by its symbol). `color` null keeps the label theme's color.

## The parts of a cost: [amount, icon, amount, icon]. `short` writes 10,000 and up as "10k" (tile corners).
static func costParts(cost: Dictionary, short := false) -> Array:
	var out := []
	if int(cost.get("coin", 0)) > 0: out.append_array([shortAmount(int(cost.coin)) if short else DriverCard.formatCoins(int(cost.coin)), HudTheme.COIN_ICON])
	if int(cost.get("gem", 0)) > 0: out.append_array([str(int(cost.gem)), HudTheme.GEM_ICON])
	return out

## 40000 -> "40k", 12500 -> "12.5k"; below 10,000 the usual "9,000"
static func shortAmount(n: int) -> String:
	if n < 10000: return DriverCard.formatCoins(n)
	return ("%dk" % (n / 1000)) if n % 1000 == 0 else ("%.1fk" % (n / 1000.0))

## A row of text and symbols that ignores the mouse
static func symbolRow(parts: Array, fontSize := 18, color = null, outline := -1) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", maxi(3, fontSize / 5))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var flat := []
	for part in parts:
		if part is Dictionary: flat.append_array(costParts(part))
		else: flat.push_back(part)
	for i in flat.size():
		var part = flat[i]
		if part is Texture2D:
			var icon := iconRect(part, roundf(fontSize * 1.25))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
			if i + 1 < flat.size() && not flat[i + 1] is Texture2D: #a little air before the next amount
				var gap = Control.new()
				gap.custom_minimum_size.x = fontSize * 0.35
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(gap)
			continue
		var label = Label.new()
		label.text = str(part)
		label.add_theme_font_size_override("font_size", fontSize)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if color != null: label.add_theme_color_override("font_color", color)
		if outline >= 0: label.add_theme_constant_override("outline_size", outline)
		row.add_child(label)
	return row

## Shows `parts` centered on a button in place of its text (its key hint stays at the right end), in the
## button's own font color: dark on a primary button, dimmer while disabled
static func setButtonParts(b: Button, parts: Array, fontSize := 22) -> void:
	var old = b.get_node_or_null("parts")
	if old:
		b.remove_child(old)
		old.queue_free()
	b.text = ""
	var primary := b.theme_type_variation == "PrimaryButton"
	var color: Color = (Color(0.15, 0.12, 0.1) if primary else Color(HudTheme.MUTED, 0.6)) if b.disabled else (DARK_TEXT if primary else HudTheme.TEXT)
	var row := symbolRow(parts, fontSize, color, 0 if primary else -1)
	row.name = "parts"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_right = -56 if b.get_child_count() > 0 else 0 #clear of the key hint
	if b.disabled: row.modulate = Color(1, 1, 1, 0.75)
	b.add_child(row)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, row.get_combined_minimum_size().x + 96)

#a plain icon at a fixed size, resampled to its exact screen pixels so it stays sharp (CrispIcon)
static func iconRect(texture: Texture2D, size: float) -> TextureRect:
	return CrispIcon.new(texture, size)

const HOVER_SOUND := preload("res://sound/ui/click_2.wav")
const PRESS_SOUND := preload("res://sound/ui/click.wav")

#the menu clicks, on the UI bus: one on focus, one on press
static func addSounds(b: BaseButton) -> void:
	var player = AudioStreamPlayer.new()
	player.bus = &"UI"
	b.add_child(player)
	b.focus_entered.connect(func(): player.stream = HOVER_SOUND; player.play())
	b.pressed.connect(func(): player.stream = PRESS_SOUND; player.play())

static var clickPlayer: AudioStreamPlayer

#the press click for things that aren't Buttons (clickable key hints), from one shared player
static func click() -> void:
	if not is_instance_valid(clickPlayer):
		clickPlayer = AudioStreamPlayer.new()
		clickPlayer.bus = &"UI"
		clickPlayer.stream = PRESS_SOUND
		clickPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).root.add_child(clickPlayer)
	clickPlayer.play()

#a button with an icon, text and a key hint at its right end
static func button(text: String, actions := PackedStringArray(), primary := false, icon: Texture2D = null) -> Button:
	var b = Button.new()
	addSounds(b)
	b.text = text
	b.theme_type_variation = "PrimaryButton" if primary else ""
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER if primary else HORIZONTAL_ALIGNMENT_LEFT
	if icon:
		b.icon = icon
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 28)
	if not actions.is_empty():
		var hint = KeyHint.make(actions, "", 14)
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		hint.offset_left = -60
		hint.offset_right = -12
		hint.alignment = BoxContainer.ALIGNMENT_END
		b.add_child(hint)
		#keep the text clear of the chip: the right margin grows by the chip's width
		var variation = "PrimaryButton" if primary else "Button"
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = theme().get_stylebox(state, variation).duplicate()
			style.content_margin_right += 52
			if primary: style.content_margin_left += 26
			b.add_theme_stylebox_override(state, style)
	return b
