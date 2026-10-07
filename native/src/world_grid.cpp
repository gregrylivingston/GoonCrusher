#include "world_grid.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <cmath>

using namespace godot;

Ref<WorldGrid> WorldGrid::current_grid;

// The GDScript versions do their arithmetic on 64-bit floats (Vector2 components are promoted), so these
// helpers do too: the same floor of the same quotient lands in the same cell.
static inline int64_t floor_div(double p_value, double p_size) {
	return (int64_t)std::floor(p_value / p_size);
}

// WorldHooks.DIRS
static const Vector2 DIRS[8] = { Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071),
	Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071) };
static const double LINE_STEP = 64.0; // WorldHooks.LINE_STEP

void WorldGrid::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setTable", "flags"), &WorldGrid::set_table);
	ClassDB::bind_method(D_METHOD("setCoarse", "terrain", "size", "origin", "cell", "outside"), &WorldGrid::set_coarse);
	ClassDB::bind_method(D_METHOD("setFineLayout", "chunkPx", "fine", "fineSize"), &WorldGrid::set_fine_layout);
	ClassDB::bind_method(D_METHOD("setChunk", "chunk", "raster"), &WorldGrid::set_chunk);
	ClassDB::bind_method(D_METHOD("eraseChunk", "chunk"), &WorldGrid::erase_chunk);
	ClassDB::bind_method(D_METHOD("clearChunks"), &WorldGrid::clear_chunks);
	ClassDB::bind_method(D_METHOD("chunkCount"), &WorldGrid::chunk_count);

	ClassDB::bind_method(D_METHOD("terrainAt", "pos"), &WorldGrid::terrain_at);
	ClassDB::bind_method(D_METHOD("lethalAt", "pos"), &WorldGrid::lethal_at);
	ClassDB::bind_method(D_METHOD("blockedAt", "pos"), &WorldGrid::blocked_at);
	ClassDB::bind_method(D_METHOD("spawnableAt", "pos"), &WorldGrid::spawnable_at);
	ClassDB::bind_method(D_METHOD("wallAt", "pos"), &WorldGrid::wall_at);

	ClassDB::bind_method(D_METHOD("slideStep", "pos", "step"), &WorldGrid::slide_step);
	ClassDB::bind_method(D_METHOD("nearLethal", "pos", "radius"), &WorldGrid::near_lethal);
	ClassDB::bind_method(D_METHOD("lethalAhead", "pos", "dir", "dist"), &WorldGrid::lethal_ahead);
	ClassDB::bind_method(D_METHOD("lineClear", "a", "b"), &WorldGrid::line_clear);
	ClassDB::bind_method(D_METHOD("bounce", "pos", "vel", "delta"), &WorldGrid::bounce);

	ClassDB::bind_static_method("WorldGrid", D_METHOD("setCurrent", "grid"), &WorldGrid::set_current);
	ClassDB::bind_static_method("WorldGrid", D_METHOD("getCurrent"), &WorldGrid::get_current);
}

//--- feeding --------------------------------------------------------------------------------------

void WorldGrid::set_table(const PackedByteArray &p_flags) {
	table = p_flags;
}

void WorldGrid::set_coarse(const PackedByteArray &p_terrain, const Vector2i &p_size, const Vector2 &p_origin, double p_cell, int p_outside) {
	coarse = p_terrain;
	coarse_w = p_size.x;
	coarse_h = p_size.y;
	origin = p_origin;
	cell = p_cell;
	outside = p_outside;
}

void WorldGrid::set_fine_layout(const Vector2 &p_chunk_px, double p_fine, const Vector2i &p_fine_size) {
	chunk_x = p_chunk_px.x;
	chunk_y = p_chunk_px.y;
	fine = p_fine;
	fine_w = p_fine_size.x;
	fine_h = p_fine_size.y;
	clear_chunks();
}

void WorldGrid::set_chunk(const Vector2i &p_chunk, const PackedByteArray &p_raster) {
	last_key = INT64_MIN;
	last_data = nullptr;
	if (p_raster.size() != (int64_t)fine_w * fine_h) {
		chunks.erase(key(p_chunk.x, p_chunk.y));
		return;
	}
	chunks[key(p_chunk.x, p_chunk.y)] = p_raster;
}

void WorldGrid::erase_chunk(const Vector2i &p_chunk) {
	last_key = INT64_MIN;
	last_data = nullptr;
	chunks.erase(key(p_chunk.x, p_chunk.y));
}

void WorldGrid::clear_chunks() {
	last_key = INT64_MIN;
	last_data = nullptr;
	chunks.clear();
}

int WorldGrid::chunk_count() const {
	return (int)chunks.size();
}

//--- queries (WorldMap.terrainAt) -----------------------------------------------------------------

int WorldGrid::terrain_at(const Vector2 &p_pos) {
	const double x = p_pos.x;
	const double y = p_pos.y;
	const int64_t cx = floor_div(x, chunk_x);
	const int64_t cy = floor_div(y, chunk_y);
	const int64_t k = key(cx, cy);
	if (k != last_key) {
		last_key = k;
		auto found = chunks.find(k);
		last_data = found == chunks.end() ? nullptr : found->second.ptr();
	}
	if (last_data != nullptr) {
		const int64_t fx = floor_div(x, fine) - cx * fine_w;
		const int64_t fy = floor_div(y, fine) - cy * fine_h;
		// a quotient that rounds onto a chunk edge can land one cell out; the coarse cell answers it
		if (fx >= 0 && fy >= 0 && fx < fine_w && fy < fine_h) {
			return last_data[fy * fine_w + fx];
		}
	}
	const int64_t gx = floor_div(x - origin.x, cell);
	const int64_t gy = floor_div(y - origin.y, cell);
	if (gx < 0 || gy < 0 || gx >= coarse_w || gy >= coarse_h) {
		return outside;
	}
	return coarse.ptr()[gy * coarse_w + gx];
}

//--- WorldHooks ----------------------------------------------------------------------------------

Vector2 WorldGrid::slide_step(const Vector2 &p_pos, const Vector2 &p_step) {
	const Vector2 to = p_pos + p_step;
	if (!blocked_at(to) || blocked_at(p_pos)) {
		return to;
	}
	const Vector2 along_x = p_pos + Vector2(p_step.x, 0.0);
	const Vector2 along_y = p_pos + Vector2(0.0, p_step.y);
	const bool x_first = std::abs(p_step.x) >= std::abs(p_step.y);
	const Vector2 first = x_first ? along_x : along_y;
	const Vector2 second = x_first ? along_y : along_x;
	if (first != p_pos && !blocked_at(first)) {
		return first;
	}
	if (second != p_pos && !blocked_at(second)) {
		return second;
	}
	return p_pos;
}

bool WorldGrid::near_lethal(const Vector2 &p_pos, double p_radius) {
	if (lethal_at(p_pos)) {
		return true;
	}
	for (const Vector2 &dir : DIRS) {
		const Vector2 out = dir * p_radius;
		if (lethal_at(p_pos + out) || lethal_at(p_pos + out * 0.5)) {
			return true;
		}
	}
	return false;
}

double WorldGrid::lethal_ahead(const Vector2 &p_pos, const Vector2 &p_dir, double p_dist) {
	for (double d = fine; d <= p_dist; d += fine) {
		if (lethal_at(p_pos + p_dir * d)) {
			return d;
		}
	}
	return INFINITY;
}

bool WorldGrid::line_clear(const Vector2 &p_a, const Vector2 &p_b) {
	const double length = p_a.distance_to(p_b);
	const int64_t steps = (int64_t)std::ceil(length / LINE_STEP);
	for (int64_t i = 1; i <= steps; i++) {
		if (wall_at(p_a.lerp(p_b, (double)i / steps))) {
			return false;
		}
	}
	return true;
}

Vector2 WorldGrid::bounce(const Vector2 &p_pos, const Vector2 &p_vel, double p_delta) {
	const Vector2 step = p_vel * p_delta;
	if (!wall_at(p_pos + step)) {
		return p_vel;
	}
	Vector2 out = p_vel;
	if (wall_at(p_pos + Vector2(step.x, 0.0))) {
		out.x = -out.x;
	}
	if (wall_at(p_pos + Vector2(0.0, step.y))) {
		out.y = -out.y;
	}
	if (out == p_vel) {
		out = -p_vel;
	}
	return out;
}

//--- the live grid ---------------------------------------------------------------------------------

void WorldGrid::set_current(const Ref<WorldGrid> &p_grid) {
	current_grid = p_grid;
}

Ref<WorldGrid> WorldGrid::get_current() {
	return current_grid;
}
