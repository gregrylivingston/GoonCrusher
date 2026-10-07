#include "world_gen_native.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <vector>

using namespace godot;

namespace {
// WorldGen constants
constexpr int W = 384;
constexpr int H = 192;
constexpr uint8_t BLOCKED = 1;
constexpr uint8_t CROSSING = 4;
constexpr uint8_t RESERVED = 8;
constexpr uint8_t CROSS_X = 16;
constexpr uint8_t CROSS_Y = 32;
constexpr int WATER = 3;
constexpr int MAX_RUN = 4;
constexpr int MAX_CUT = 4;
constexpr int SHORT_BARRIER = 8;
constexpr int DIAGONAL_RUN = 2;
constexpr int64_t TAG_RUN = 1;

inline int64_t mix(int64_t h) {
	h = h & 0x7FFFFFFF;
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0x7FFFFFFF;
	h = (((h >> 16) ^ h) * 0x45d9f3b) & 0x7FFFFFFF;
	return ((h >> 16) ^ h) & 0x7FFFFFFF;
}

inline int cell_index(int o, int k, bool along_x) {
	return along_x ? k * W + o : o * W + k;
}

// WorldGen.runsChain
inline bool runs_chain(int p0, int p1, int a0, int a1) {
	if (p0 <= a1 && p1 >= a0) {
		return true;
	}
	if (p1 - p0 >= DIAGONAL_RUN || a1 - a0 >= DIAGONAL_RUN) {
		return false;
	}
	return p1 == a0 - 1 || p0 == a1 + 1;
}

// WorldGen.crossingNear
inline bool crossing_near(const uint8_t *flags, int o, int a0, int a1, bool along_x) {
	for (int a = a0 - 1; a <= a1 + 1; a++) {
		for (int d = -1; d <= 1; d++) {
			const int x = along_x ? o + d : a;
			const int y = along_x ? a : o + d;
			if (x < 0 || y < 0 || x >= W || y >= H) {
				continue;
			}
			if ((flags[y * W + x] & CROSSING) != 0) {
				return true;
			}
		}
	}
	return false;
}

struct Run {
	int a0;
	int a1;
	int count;
};
} // namespace

void WorldGenNative::_bind_methods() {
	ClassDB::bind_static_method("WorldGenNative", D_METHOD("ihash", "seed", "tag", "a", "b"), &WorldGenNative::ihash);
	ClassDB::bind_static_method("WorldGenNative", D_METHOD("barrierExtents", "flags"), &WorldGenNative::barrier_extents);
	ClassDB::bind_static_method("WorldGenNative",
			D_METHOD("cutCrossings", "flags", "terrain", "cover", "surf", "shortBarrier", "crossings", "seed", "alongX", "waterCrossing"),
			&WorldGenNative::cut_crossings);
}

// WorldGen.ihash
int64_t WorldGenNative::ihash(int64_t p_seed, int64_t p_tag, int64_t p_a, int64_t p_b) {
	return mix(mix(mix(mix(p_seed ^ 0x2545F491) + p_tag) + p_a) + p_b);
}

// WorldGen.barrierExtents: 1 for every cell of an 8-connected component of blocked, unreserved cells whose
// bounding box is at most SHORT_BARRIER cells on its longer side
PackedByteArray WorldGenNative::barrier_extents(const PackedByteArray &p_flags) {
	const int n = W * H;
	PackedByteArray out;
	out.resize(n);
	out.fill(0);
	if (p_flags.size() < n) {
		return out;
	}
	const uint8_t *flags = p_flags.ptr();
	uint8_t *result = out.ptrw();
	std::vector<uint8_t> seen(n, 0);
	std::vector<int> stack;
	std::vector<int> members;
	static const int DX[8] = { 1, -1, 0, 0, 1, -1, 1, -1 };
	static const int DY[8] = { 0, 0, 1, -1, 1, 1, -1, -1 };
	for (int s = 0; s < n; s++) {
		if (seen[s] != 0 || (flags[s] & (BLOCKED | RESERVED)) != BLOCKED) {
			continue;
		}
		seen[s] = 1;
		stack.push_back(s);
		members.clear();
		int lo_x = s % W, lo_y = s / W, hi_x = lo_x, hi_y = lo_y;
		while (!stack.empty()) {
			const int i = stack.back();
			stack.pop_back();
			members.push_back(i);
			const int x = i % W;
			const int y = i / W;
			lo_x = std::min(lo_x, x);
			lo_y = std::min(lo_y, y);
			hi_x = std::max(hi_x, x);
			hi_y = std::max(hi_y, y);
			for (int d = 0; d < 8; d++) {
				const int nx = x + DX[d];
				const int ny = y + DY[d];
				if (nx < 0 || ny < 0 || nx >= W || ny >= H) {
					continue;
				}
				const int j = ny * W + nx;
				if (seen[j] == 0 && (flags[j] & (BLOCKED | RESERVED)) == BLOCKED) {
					seen[j] = 1;
					stack.push_back(j);
				}
			}
		}
		if (std::max(hi_x - lo_x, hi_y - lo_y) + 1 <= SHORT_BARRIER) {
			for (int i : members) {
				result[i] = 1;
			}
		}
	}
	return out;
}

// WorldGen.cutCrossings (with openCell): one pass. Returns [flags, terrain, cover, crossings].
Array WorldGenNative::cut_crossings(const PackedByteArray &p_flags, const PackedByteArray &p_terrain, const PackedByteArray &p_cover,
		const PackedByteArray &p_surf, const PackedByteArray &p_short_barrier, const PackedInt32Array &p_crossings,
		int64_t p_seed, bool p_along_x, int p_water_crossing) {
	PackedByteArray flags_out = p_flags;
	PackedByteArray terrain_out = p_terrain;
	PackedByteArray cover_out = p_cover;
	PackedInt32Array crossings_out = p_crossings;
	Array result;
	const int n = W * H;
	if (p_flags.size() < n || p_terrain.size() < n || p_cover.size() < n || p_surf.size() < n || p_short_barrier.size() < n) {
		result.push_back(flags_out);
		result.push_back(terrain_out);
		result.push_back(cover_out);
		result.push_back(crossings_out);
		return result;
	}
	uint8_t *flags = flags_out.ptrw();
	uint8_t *terrain = terrain_out.ptrw();
	uint8_t *cover = cover_out.ptrw();
	const uint8_t *surf = p_surf.ptr();
	const uint8_t *short_barrier = p_short_barrier.ptr();

	auto is_blocked = [&](int i) { return (flags[i] & BLOCKED) != 0; };
	auto cuttable = [&](int i) { return (flags[i] & (BLOCKED | RESERVED)) == BLOCKED && short_barrier[i] == 0; };
	const uint8_t how = p_along_x ? CROSS_Y : CROSS_X;
	auto open_cell = [&](int i) {
		if (!is_blocked(i)) {
			return;
		}
		const bool was_water = terrain[i] == WATER;
		flags[i] = flags[i] & RESERVED;
		terrain[i] = surf[i];
		cover[i] = 0;
		flags[i] |= CROSSING | how;
		if (was_water) {
			terrain[i] = (uint8_t)p_water_crossing;
		}
		crossings_out.push_back(i);
	};

	const int outer = p_along_x ? W : H;
	const int inner = p_along_x ? H : W;
	std::vector<Run> prev;
	std::vector<Run> cur;
	for (int o = 0; o < outer; o++) {
		cur.clear();
		int k = 0;
		while (k < inner) {
			if (!cuttable(cell_index(o, k, p_along_x))) {
				k++;
				continue;
			}
			const int a0 = k;
			while (k < inner && cuttable(cell_index(o, k, p_along_x))) {
				k++;
			}
			const int a1 = k - 1;
			int count = 0;
			if (!crossing_near(flags, o, a0, a1, p_along_x)) {
				for (const Run &r : prev) {
					if (runs_chain(r.a0, r.a1, a0, a1)) {
						count = std::max(count, r.count);
					}
				}
				count += 1;
			}
			const int64_t limit = MAX_RUN - (ihash(p_seed, TAG_RUN, (int64_t)o * 1024 + a0, p_along_x ? 1 : 0) & 1);
			if (count > limit && a1 - a0 + 1 <= MAX_CUT && a0 > 0 && a1 < inner - 1 && !is_blocked(cell_index(o, a0 - 1, p_along_x)) && !is_blocked(cell_index(o, a1 + 1, p_along_x))) {
				for (int a = a0; a <= a1; a++) {
					open_cell(cell_index(o, a, p_along_x));
				}
				count = 0;
			}
			cur.push_back({ a0, a1, count });
		}
		std::swap(prev, cur);
	}
	result.push_back(flags_out);
	result.push_back(terrain_out);
	result.push_back(cover_out);
	result.push_back(crossings_out);
	return result;
}
