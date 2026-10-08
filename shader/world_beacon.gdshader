shader_type canvas_item;
render_mode blend_add, unshaded;

// A district landmark's beacon (docs/WORLD_ART.md, "Props"): the prop scene's Beacon sprite, a glow baked at
// final brightness (<id>_beacon.png). Added on top and unlit, so the landmark's top reads at night with no
// real light. It breathes slowly with a quick double flash every few seconds; each landmark is out of step
// with the others (the phase comes from its world position). gc_motion (Reduce Motion) calms it to a steady
// glow. By day it fades to DAY_GLOW: Level sets `night` on the shared material (world_beacon.tres) as the
// CanvasModulate fades (Level.setNighttime).

global uniform float gc_motion;
uniform float night : hint_range(0.0, 1.0) = 1.0;
const float DAY_GLOW = 0.15;

varying float phase;

void vertex() {
	phase = fract(dot(MODEL_MATRIX[3].xy, vec2(0.00131, 0.00071)));
}

void fragment() {
	float t = TIME + phase * 7.0;
	float breathe = 0.78 + 0.22 * sin(t * 1.3);
	float cycle = fract(t / 3.4);
	float flash = smoothstep(0.0, 0.02, cycle) * (1.0 - smoothstep(0.04, 0.08, cycle))
		+ smoothstep(0.12, 0.14, cycle) * (1.0 - smoothstep(0.16, 0.2, cycle));
	float k = mix(0.85, breathe + 0.45 * flash, clamp(gc_motion, 0.0, 1.0));
	vec4 glow = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(glow.rgb * k * mix(DAY_GLOW, 1.0, night), glow.a);
}
