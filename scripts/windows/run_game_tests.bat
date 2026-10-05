REM Must be called from project root folder
REM Godot must be in system path
REM Runs the game tests in tests/game headless; the exit code is the number of failures.
godot --headless --path %CD% -s res://tests/game/run_tests.gd
