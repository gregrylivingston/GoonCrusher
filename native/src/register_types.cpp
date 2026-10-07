#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "goon_body.h"
#include "goon_native.h"
#include "world_gen_native.h"
#include "world_grid.h"

using namespace godot;

void initialize_gooncrusher_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GoonBody::init_names();
	GDREGISTER_CLASS(GoonNative);
	GDREGISTER_CLASS(WorldGrid);
	GDREGISTER_CLASS(WorldGenNative);
	GDREGISTER_CLASS(GoonBody);
}

void uninitialize_gooncrusher_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	WorldGrid::cleanup();
	GoonBody::free_names();
}

extern "C" {
// Entry point named by entry_symbol in bin/gooncrusher.gdextension.
GDExtensionBool GDE_EXPORT gooncrusher_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_gooncrusher_module);
	init_obj.register_terminator(uninitialize_gooncrusher_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
