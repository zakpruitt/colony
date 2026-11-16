// Turns a character solid white while `flash` is 1 (a hit, spec 007), keeping its shape.
shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 drawn = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(drawn.rgb, vec3(1.0), flash), drawn.a);
}
