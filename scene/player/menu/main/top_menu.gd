extends HBoxContainer


func _on_quit_button_pressed():
	get_tree().quit()

func _on_settings_button_pressed():
	Root.mainMenu.add_child(load("res://scene/player/menu/settings/settings.tscn").instantiate())

func _on_discord_button_pressed():
	OS.shell_open("https://discord.gg/CRwgEe4Gve")

func _on_steam_button_pressed():
	OS.shell_open("https://store.steampowered.com/app/1941650/GOONCRUSHER/")
