extends HBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass




func _on_quit_button_pressed():
	get_tree().quit()

func _on_settings_button_pressed():
	Root.mainMenu.add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())

func _on_discord_button_pressed():
	OS.shell_open("https://discord.gg/4m6mENxu")

func _on_steam_button_pressed():
	OS.shell_open("https://store.steampowered.com/app/1941650/Gregry_Boyds_RidenPrize_Goon_Crusher/")
