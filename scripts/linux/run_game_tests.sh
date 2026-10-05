# Must be called from project root folder
# Runs only the game tests (tests/game), headless, and exits with the result code
godot4 --headless -d -s --path $PWD addons/gut/gut_cmdln.gd -gdir=res://tests/game -gexit -glog=1
