#pragma once

#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstdint>
#include <unordered_map>

namespace godot {

// The live world's terrain grid (docs/WORLD.md, docs/NATIVE.md): the coarse map plus the fine raster of every
// cached chunk, and the grid rules built on it (WorldHooks: slideStep, nearLethal, lethalAhead, lineClear,
// bounce). WorldMap feeds it; World and WorldHooks delegate to it while it is current (Root.worldMap's setter).
// Main thread only. Queries never allocate, and match the GDScript versions they replace exactly.
class WorldGrid : public RefCounted {
	GDCLASS(WorldGrid, RefCounted)

	// World.FLAG_* bits per terrain id
	static constexpr uint8_t FLAG_PASSABLE = 1;
	static constexpr uint8_t FLAG_LETHAL = 2;
	static constexpr uint8_t FLAG_WALL = 4;
	static constexpr uint8_t FLAG_SPAWNABLE = 8;

	PackedByteArray table; // flags per terrain id (World._flags)

	PackedByteArray coarse;
	int coarse_w = 0;
	int coarse_h = 0;
	Vector2 origin;
	double cell = 1280.0;
	int outside = 3; // WATER

	double chunk_x = 5120.0;
	double chunk_y = 2560.0;
	double fine = 128.0;
	int fine_w = 40;
	int fine_h = 20;

	std::unordered_map<int64_t, PackedByteArray> chunks;
	// the last chunk read, so a run of queries in one chunk skips the hash lookup
	int64_t last_key = INT64_MIN;
	const uint8_t *last_data = nullptr;

	static Ref<WorldGrid> current_grid;

	static int64_t key(int64_t x, int64_t y) { return (x << 32) ^ (y & 0xffffffff); }
	bool flag(int t, uint8_t f) const { return t >= 0 && t < table.size() && (table[t] & f) != 0; }

protected:
	static void _bind_methods();

public:
	void set_table(const PackedByteArray &p_flags);
	void set_coarse(const PackedByteArray &p_terrain, const Vector2i &p_size, const Vector2 &p_origin, double p_cell, int p_outside);
	void set_fine_layout(const Vector2 &p_chunk_px, double p_fine, const Vector2i &p_fine_size);
	void set_chunk(const Vector2i &p_chunk, const PackedByteArray &p_raster);
	void erase_chunk(const Vector2i &p_chunk);
	void clear_chunks();
	int chunk_count() const;

	int terrain_at(const Vector2 &p_pos);
	bool lethal_at(const Vector2 &p_pos) { return flag(terrain_at(p_pos), FLAG_LETHAL); }
	bool blocked_at(const Vector2 &p_pos) {
		int t = terrain_at(p_pos);
		return t >= 0 && t < table.size() && (table[t] & FLAG_PASSABLE) == 0;
	}
	bool spawnable_at(const Vector2 &p_pos) { return flag(terrain_at(p_pos), FLAG_SPAWNABLE); }
	bool wall_at(const Vector2 &p_pos) { return flag(terrain_at(p_pos), FLAG_WALL); }

	Vector2 slide_step(const Vector2 &p_pos, const Vector2 &p_step);
	bool near_lethal(const Vector2 &p_pos, double p_radius);
	double lethal_ahead(const Vector2 &p_pos, const Vector2 &p_dir, double p_dist);
	bool line_clear(const Vector2 &p_a, const Vector2 &p_b);
	Vector2 bounce(const Vector2 &p_pos, const Vector2 &p_vel, double p_delta);

	static void set_current(const Ref<WorldGrid> &p_grid);
	static Ref<WorldGrid> get_current();
	static WorldGrid *current() { return current_grid.ptr(); }
	static void cleanup() { current_grid.unref(); }
};

} // namespace godot
