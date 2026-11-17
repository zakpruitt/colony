// Turns a character solid white while `flash` is 1 (a hit, spec 007), keeping its shape.
// Spec 056: `tint` washes it toward a status's colour by `tint_share` (burning, bleeding,
// chilled), and `glow` lights it toward `glow_color` while it winds up an action.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_share : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// COLOR already holds the texture's colour (times modulate); sampling TEXTURE again would
	// square every colour and push the sprite off the palette.
	vec3 shade = mix(COLOR.rgb, tint.rgb, tint_share);
	shade = mix(shade, glow_color.rgb, glow);
	COLOR = vec4(mix(shade, vec3(1.0), flash), COLOR.a);
}
