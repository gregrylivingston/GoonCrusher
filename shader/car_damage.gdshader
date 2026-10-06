shader_type canvas_item;

// Car damage (docs/CAR_ART.md). TEXTURE is the like-new sheet. Each pixel belongs to one system
// (zone mask R) and sits some distance from that system's impact point (zone mask G); as the system's
// damage rises, the dented sheet spreads out from the impact point, then the wrecked sheet follows.
// One draw call, four texture reads.

uniform sampler2D dented_tex : filter_linear_mipmap;
uniform sampler2D wrecked_tex : filter_linear_mipmap;
uniform sampler2D zone_mask : filter_nearest;
uniform float damage[6]; // hull, lights, engine, steering, tires, tank: 0 = like new, 1 = wrecked

varying vec4 tint;

void vertex() {
	tint = COLOR; // modulate
}

void fragment() {
	vec2 m = texture(zone_mask, UV).rg;
	float d = damage[clamp(int(m.r * 5.0 + 0.5), 0, 5)];
	vec4 col = texture(TEXTURE, UV);
	col = mix(col, texture(dented_tex, UV), step(m.g, d * 1.6 - 0.001));
	col = mix(col, texture(wrecked_tex, UV), step(m.g, (d - 0.35) * 1.55));
	COLOR = col * tint;
}
