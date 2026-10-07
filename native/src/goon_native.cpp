#include "goon_native.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

// Bump when GDScript starts depending on something new, so a stale DLL is caught by the test.
static const char *NATIVE_VERSION = "1";

void GoonNative::_bind_methods() {
	ClassDB::bind_static_method("GoonNative", D_METHOD("version"), &GoonNative::version);
}

String GoonNative::version() {
	return NATIVE_VERSION;
}
