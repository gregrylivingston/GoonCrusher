shader_type canvas_item;
render_mode blend_add, unshaded;

// Additive world decor (streetglow): a warm light pool baked at final brightness. As world_decor.gdshader,
// but added on top and unlit, so it reads at night.

uniform float cells = 4.0;

void vertex() {
	UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * cells)) / cells;
}
