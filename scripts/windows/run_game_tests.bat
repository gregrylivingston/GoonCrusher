REM Must be called from project root folder
REM Godot must be in system path
REM Runs only the game tests (tests/game), headless, and exits with the result code
godot --headless -d -s --path %CD% addons/gut/gut_cmdln.gd -gdir=res://tests/game -gexit -glog=1
