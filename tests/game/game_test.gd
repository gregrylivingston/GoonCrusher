class_name GameTest extends Node

#The game's small test base. The assert names match GUT's (GUT 9.0.0 does not parse on Godot 4.7,
#so it is not in the repo).

var failures: Array[String] = []
var currentTest := ""
var autofree: Array[Node] = []

func before_each(): pass
func after_each(): pass

func fail(message: String) -> void:
	failures.push_back("%s: %s" % [currentTest, message])

func assert_true(value, message := "") -> void:
	if not value: fail("expected true. " + message)

func assert_false(value, message := "") -> void:
	if value: fail("expected false. " + message)

func assert_null(value, message := "") -> void:
	if value != null: fail("expected null, got %s. %s" % [value, message])

func assert_eq(got, expected, message := "") -> void:
	if typeof(got) != typeof(expected) && not ((got is int || got is float) && (expected is int || expected is float)):
		fail("expected %s (%s), got %s (%s). %s" % [expected, type_string(typeof(expected)), got, type_string(typeof(got)), message])
	elif got != expected:
		fail("expected %s, got %s. %s" % [expected, got, message])

func assert_ne(got, notExpected, message := "") -> void:
	if typeof(got) == typeof(notExpected) && got == notExpected: fail("expected anything but %s. %s" % [notExpected, message])

## One level per distinct world (grammar, features, terrains, start and landscape): the world tests build
## these instead of all 30, since levels that share a world build the same map
static func worldLevels() -> Array:
	var levels = load("res://scripts/world/levels.gd") #loaded, not named: naming it compiles it before the autoloads exist
	var seen := {}
	var out := []
	for id in levels.ORDER:
		var def = levels.get_def(id)
		var key := var_to_str([def.grammar, def.features, def.baseTerrain, def.accents, def.startPosition, def.landscape])
		if seen.has(key): continue
		seen[key] = true
		out.push_back(id)
	return out

func assert_almost_eq(got, expected, tolerance, message := "") -> void:
	if absf(got - expected) > tolerance: fail("expected %s +/- %s, got %s. %s" % [expected, tolerance, got, message])

func assert_gt(got, than, message := "") -> void:
	if not got > than: fail("expected > %s, got %s. %s" % [than, got, message])

func assert_between(got, low, high, message := "") -> void:
	if got < low || got > high: fail("expected %s..%s, got %s. %s" % [low, high, got, message])

func add_child_autofree(node: Node) -> Node:
	add_child(node)
	autofree.push_back(node)
	return node

func freeAutofree() -> void:
	for node in autofree:
		if is_instance_valid(node): node.queue_free()
	autofree.clear()
