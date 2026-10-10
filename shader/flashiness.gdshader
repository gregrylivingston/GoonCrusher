shader_type canvas_item;



//Giant marker. The color and style come from Accessibility settings through global uniforms;
//the default (red, pulse) is the authored look.
global uniform int gc_giant_style;   // 0 pulse, 1 steady, 2 steady + ground ring (drawn by walker.gd)
global uniform vec4 gc_giant_color;  // tint, may be HDR so giants glow under headlights
global uniform float gc_flash;       // 1 normal, lower with Reduce Flashing (slower pulse)

uniform float speed = 1.;

uniform vec4 tint : source_color = vec4(1., 1., 0., 1.); //unused; gc_giant_color replaces it

uniform float span : hint_range(0.1, 1.) = .3;

float luminance(vec4 color) {
	return 1.0 - sqrt(0.299*color.r*color.r + 0.587*color.g*color.g + 0.114*color.b*color.b);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float target = gc_giant_style == 0 ? abs(sin(TIME * PI * speed * gc_flash) * (1. + span)) : 0.5;
	vec4 giant_tint = gc_giant_color;
	if(color.a > 0.) {
		float lum = luminance(color);
		float diff = abs(lum - target);
		float mx = clamp(1. - diff / span, 0., 1.);
		color = mix(color, giant_tint, mx);
	}
	
	COLOR = color;
}