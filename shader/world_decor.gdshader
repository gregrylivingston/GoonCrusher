shader_type canvas_item;

// World decor (docs/WORLD_ART.md): one MultiMeshInstance2D per decor id per chunk, its texture the id's
// atlas (a row of `cells` square cells). Each instance's custom data x picks its cell.
// Bending decor (tufts, reeds: WorldSkin.BEND_DECOR, `bend` > 0) is pushed away from the player's car
// (gc_car_pos, set each frame by PropReactions): each corner by how close it is, so the near side flattens
// against the far one and springs back as the car leaves. Off at Ground Detail Simple (gc_ground_quality 0).

uniform float cells = 4.0;
uniform float bend = 0.0;          // world px a corner moves right under the car
uniform float bend_radius = 110.0; // world px from the car's centre where the push fades out
global uniform vec2 gc_car_pos;
global uniform int gc_ground_quality;

void vertex() {
	UV.x = (UV.x + floor(INSTANCE_CUSTOM.x * cells)) / cells;
	if (bend > 0.0 && gc_ground_quality > 0) {
		vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		vec2 away = world - gc_car_pos;
		float d = length(away);
		if (d < bend_radius && d > 0.001) {
			float push = bend * (1.0 - d / bend_radius);
			VERTEX += (inverse(MODEL_MATRIX) * vec4(away / d * push, 0.0, 0.0)).xy;
		}
	}
}
