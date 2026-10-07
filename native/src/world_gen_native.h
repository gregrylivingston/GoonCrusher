#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

// Kernels of the coarse world build (scripts/world/world_gen.gd, docs/WORLD.md) that profile worst in
// GDScript. Static and pure: arrays in, arrays out, no nodes or globals, so they run on the worker that
// builds the map. Each matches the GDScript function it replaces cell for cell (tests/game/test_native.gd);
// the constants are WorldGen's.
class WorldGenNative : public Object {
	GDCLASS(WorldGenNative, Object)

protected:
	static void _bind_methods();

public:
	static int64_t ihash(int64_t p_seed, int64_t p_tag, int64_t p_a, int64_t p_b);
	static PackedByteArray barrier_extents(const PackedByteArray &p_flags);
	static Array cut_crossings(const PackedByteArray &p_flags, const PackedByteArray &p_terrain, const PackedByteArray &p_cover,
			const PackedByteArray &p_surf, const PackedByteArray &p_short_barrier, const PackedInt32Array &p_crossings,
			int64_t p_seed, bool p_along_x, int p_water_crossing);
};

} // namespace godot
