shader_type canvas_item;

// World decor (docs/WORLD_ART.md): one MultiMeshInstance2D per decor id per chunk, its texture the id's
// atlas (a row of `cells` square cells). Each instance's custom data x picks its cell.

uniform float cells = 4.0;

void vertex() {
	UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * cells)) / cells;
}
