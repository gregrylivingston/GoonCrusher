#pragma once

#include <godot_cpp/classes/object.hpp>

namespace godot {

// Static helpers for GDScript. Nothing calls it yet; it proves the library loads
// (tests/game/test_native.gd). Put hot loops that profile badly in GDScript here.
class GoonNative : public Object {
	GDCLASS(GoonNative, Object)

protected:
	static void _bind_methods();

public:
	static String version();
};

} // namespace godot
