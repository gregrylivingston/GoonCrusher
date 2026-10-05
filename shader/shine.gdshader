shader_type canvas_item;

global uniform int gc_pickup_fx;   // 0 Simple: ring-sampled outline, no shine. 1 Full: as authored.
global uniform float gc_motion;    // 0 = Reduce Motion (no moving shine)

//these three var are shine effect.  Everything else is outline.
uniform vec4 shine_color : source_color = vec4(1.0);
uniform float shine_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float shine_size : hint_range(0.01, 1.0, 0.01) = 0.01;



uniform vec4 color : source_color = vec4(9.25 , .85 , 0.0 , 0.3 );
uniform float width : hint_range(0, 30) = 5.0;
uniform int pattern : hint_range(0, 2) = 0; // diamond, circle, square
uniform bool inside = false;
uniform bool add_margins = true; // only useful when inside is false

void vertex() {
	if (add_margins) {
		VERTEX += (UV * 2.0 - 1.0) * width;
	}
}

bool hasContraryNeighbour(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float x = abs(i) > width ? width * sign(i) : i;
		float offset;
		
		if (pattern == 0) {
			offset = width - abs(x);
		} else if (pattern == 1) {
			offset = floor(sqrt(pow(width + 0.5, 2) - x * x));
		} else if (pattern == 2) {
			offset = width;
		}
		
		for (float j = -ceil(offset); j <= ceil(offset); j++) {
			float y = abs(j) > offset ? offset * sign(j) : j;
			vec2 xy = uv + texture_pixel_size * vec2(x, y);
			
			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || texture(texture, xy).a <= 0.0) == inside) {
				return true;
			}
		}
	}
	
	return false;
}

// Simple outline: two fixed rings of samples at the full and half outline width instead of every
// texel inside the diamond (24 taps instead of up to 61). The outline keeps its width.
bool hasContraryNeighbourFast(vec2 uv, vec2 texture_pixel_size, sampler2D texture) {
	for (int k = 0; k < 16; k++) {
		float a = float(k) * 0.39269908; // TAU / 16
		vec2 dir = vec2(cos(a), sin(a));
		float r = width / (abs(dir.x) + abs(dir.y)); // on the diamond's edge, matching pattern 0
		for (int ring = 0; ring < 2; ring++) {
			if (ring == 1 && (k & 1) == 1) continue;
			vec2 xy = uv + texture_pixel_size * dir * (ring == 0 ? r : r * 0.5);
			if ((xy != clamp(xy, vec2(0.0), vec2(1.0)) || textureLod(texture, xy, 0.0).a <= 0.0) == inside) {
				return true;
			}
		}
	}
	return false;
}

void fragment() {
	vec2 uv = UV;
	
	if (add_margins) {
		vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0));
		
		uv = (uv - texture_pixel_size * width) * TEXTURE_PIXEL_SIZE / texture_pixel_size;
		
		if (uv != clamp(uv, vec2(0.0), vec2(1.0))) {
			COLOR.a = 0.0;
		} else {
			COLOR = texture(TEXTURE, uv);
		}
	} else {
		COLOR = texture(TEXTURE, uv);
	}
	
	bool edge = (COLOR.a > 0.0) == inside && (gc_pickup_fx == 0 ? hasContraryNeighbourFast(uv, TEXTURE_PIXEL_SIZE, TEXTURE) : hasContraryNeighbour(uv, TEXTURE_PIXEL_SIZE, TEXTURE));
	if (edge) {
		COLOR.rgb = inside ? mix(COLOR.rgb, color.rgb, color.a) : color.rgb;
		COLOR.a += (1.0 - COLOR.a) * color.a;
	}

	//this part adds the shine effects.  The code above is all outline	
	if (gc_pickup_fx != 0 && gc_motion >= 0.5) {
		float shine = step(1.0 - shine_size * 0.5, 0.5 + 0.5 * sin(UV.x - UV.y + TIME * shine_speed));
		COLOR.rgb = mix(COLOR.rgb, shine_color.rgb, shine * shine_color.a ) ;
	}
  	
}