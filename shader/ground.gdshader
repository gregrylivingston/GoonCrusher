shader_type canvas_item;

// The run's ground (docs/WORLD.md, "Rendering"). Every ground quad of every chunk shares one material
// (WorldSkin.groundMaterial). It reads the control ring: one RGBA8 texel per 128 px fine cell, addressed by
// world cell modulo the ring's size, written by each chunk as it is applied (ChunkRecipe.control):
//   R  material layer of the cell's surface (water and wall cells carry a neighbour's surface)
//   G  water field, B wall field: 0.5 on the edge, below inside, FIELD_RANGE field units either way
//   A  flags: 1 bridge deck (no water drawn), 2 rotate the material 90 degrees, 4 conveyor belt, 8 belt reversed;
//      high 4 bits the district's tint code (0..15 -> TINT_LOW..TINT_HIGH brightness on the open ground), so
//      district borders read faintly (blended across the warped cells, like the surfaces)
// The fields are interpolated between cell centres, so water and wall edges are smooth and match the
// collision contours (marching squares over the same values).
// gc_ground_quality 0: the nearest cell's material only, no macro noise, no water or belt animation.
// gc_ground_quality 1: organic borders (four cells blended, the blend warped by the macro noise), macro
// variation, moving water and belts.

global uniform int gc_ground_quality;

uniform sampler2D ctl : filter_nearest, repeat_enable;
uniform vec2 ctl_size = vec2(320.0, 160.0);
uniform sampler2DArray materials : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform float water_layer = 0.0;
uniform float wall_layer = 0.0;
uniform vec4 wall_tint : source_color = vec4(1.0);
uniform float organic = 1.0; // how far the borders wander: less on built-up levels (streets, yards)

const float CELL = 128.0;
const float TILE = 1024.0; // world px one 512 texel material tile covers
const float FIELD_RANGE = 1.0;
const float BELT_SPEED = 0.244; // 250 px/s in tile units
const float TINT_LOW = 0.93;
const float TINT_HIGH = 1.05;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec4 cellAt(vec2 c) {
	return texelFetch(ctl, ivec2(mod(c, ctl_size)), 0);
}

int flagsOf(vec4 c) {
	return int(c.a * 255.0 + 0.5) & 15;
}

float tintOf(vec4 c) {
	return mix(TINT_LOW, TINT_HIGH, float(int(c.a * 255.0 + 0.5) >> 4) / 15.0);
}

float layerOf(vec4 c) {
	return floor(c.r * 255.0 + 0.5);
}

vec3 surface(vec4 c, vec2 uv) {
	int f = flagsOf(c);
	if ((f & 2) != 0) uv = uv.yx;
	if ((f & 4) != 0 && gc_ground_quality > 0) uv.x -= TIME * BELT_SPEED * ((f & 8) != 0 ? -1.0 : 1.0);
	return texture(materials, vec3(uv, layerOf(c))).rgb;
}

void fragment() {
	vec2 g = world / CELL - 0.5;
	vec2 c0 = floor(g);
	vec2 f = g - c0;
	vec4 a = cellAt(c0);
	vec4 b = cellAt(c0 + vec2(1.0, 0.0));
	vec4 c = cellAt(c0 + vec2(0.0, 1.0));
	vec4 d = cellAt(c0 + vec2(1.0, 1.0));
	vec2 fld = mix(mix(a.gb, b.gb, f.x), mix(c.gb, d.gb, f.x), f.y);
	float water = (fld.x * 2.0 - 1.0) * FIELD_RANGE;
	float wall = (fld.y * 2.0 - 1.0) * FIELD_RANGE;
	vec2 uv = world / TILE;
	vec4 near = f.y < 0.5 ? (f.x < 0.5 ? a : b) : (f.x < 0.5 ? c : d);
	bool deck = (flagsOf(near) & 1) != 0;
	float aaWater = max(fwidth(water), 0.0015);
	float aaWall = max(fwidth(wall), 0.0015);
	vec3 col = vec3(0.0);

	if (wall > -aaWall && (water > -aaWater || deck)) {
		if (gc_ground_quality == 0 || deck) {
			col = surface(near, uv) * tintOf(near);
		} else {
			// organic borders: the surfaces are looked up at a point pushed about by the macro noise (two
			// scales, up to about half a cell), so the cells' stair-steps wander; the fields stay where they are
			vec2 warp = vec2(texture(macro_noise, world / 420.0).r, texture(macro_noise, world / 420.0 + vec2(0.37, 0.61)).r) - 0.5;
			warp += (vec2(texture(macro_noise, world / 1700.0 + vec2(0.13, 0.71)).r, texture(macro_noise, world / 1700.0 + vec2(0.59, 0.23)).r) - 0.5) * 0.8;
			vec2 gm = g + warp * 1.1 * organic;
			vec2 m0 = floor(gm);
			vec2 w = smoothstep(0.3, 0.7, gm - m0);
			vec4 ma = cellAt(m0);
			vec4 mb = cellAt(m0 + vec2(1.0, 0.0));
			vec4 mc = cellAt(m0 + vec2(0.0, 1.0));
			vec4 md = cellAt(m0 + vec2(1.0, 1.0));
			float la = layerOf(ma);
			if (la == layerOf(mb) && la == layerOf(mc) && la == layerOf(md) && flagsOf(ma) == flagsOf(md)) {
				col = surface(ma, uv);
			} else {
				col = surface(ma, uv) * (1.0 - w.x) * (1.0 - w.y) + surface(mb, uv) * w.x * (1.0 - w.y)
					+ surface(mc, uv) * (1.0 - w.x) * w.y + surface(md, uv) * w.x * w.y;
			}
			col *= tintOf(ma) * (1.0 - w.x) * (1.0 - w.y) + tintOf(mb) * w.x * (1.0 - w.y)
				+ tintOf(mc) * (1.0 - w.x) * w.y + tintOf(md) * w.x * w.y;
			col *= mix(0.9, 1.08, texture(macro_noise, world / 7168.0).r);
		}
		// contact shadow at the foot of walls
		col *= mix(0.7, 1.0, smoothstep(0.0, 0.18, wall));
	}
	if (wall < aaWall) {
		vec3 top = texture(materials, vec3(uv, wall_layer)).rgb * wall_tint.rgb;
		top *= 1.0 + 0.12 * smoothstep(-0.1, 0.0, wall); // a lighter lip
		col = mix(col, top, smoothstep(aaWall, -aaWall, wall));
	}
	if (!deck && water < aaWater && wall > -aaWall) {
		vec2 wuv = uv;
		if (gc_ground_quality > 0) wuv += vec2(sin(TIME * 0.4 + uv.y * 5.0), cos(TIME * 0.33 + uv.x * 4.0)) * 0.006 + vec2(TIME * 0.004, 0.0);
		vec3 deep = texture(materials, vec3(wuv, water_layer)).rgb;
		deep *= mix(1.06, 0.7, clamp(-water / 0.6, 0.0, 1.0));
		col = mix(col, deep, smoothstep(aaWater, -aaWater, water));
	}
	COLOR = vec4(col, 1.0);
}
