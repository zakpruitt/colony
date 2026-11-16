// Turns a character solid white while `flash` is 1 (a hit, spec 007), keeping its shape.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// COLOR already holds the texture's colour (times modulate); sampling TEXTURE again would
	// square every colour and push the sprite off the palette.
	COLOR = vec4(mix(COLOR.rgb, vec3(1.0), flash), COLOR.a);
}
