# Must be called from project root folder
# Runs the game tests in tests/game headless; the exit code is the number of failures.
godot4 --headless --path $PWD -s res://tests/game/run_tests.gd
