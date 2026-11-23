// The black over what the party has not seen: drawn over the darkness and the glow, it covers
// every world pixel by how far that pixel is from anything seen (AmbienceSeen's map, a tile a
// pixel, blended between tiles and cut into the darkness's steps). The party's own light is
// not covered. The same formula is AmbienceMood.unveiled in GDScript; change both together.
shader_type canvas_item;
render_mode unshaded;

// How near each tile is to something seen (red), from world tile seen_origin, seen_size tiles.
uniform sampler2D seen : filter_linear, repeat_disable;
uniform vec2 seen_origin = vec2(0.0);
uniform vec2 seen_size = vec2(1.0);
uniform float tile_size = 16.0;
uniform float steps = 3.0;
// Each ring of the party's light is raised to this (AmbienceMood.RING_POWER).
uniform float ring_power = 1.5;
// The party's light: x, y in world pixels; z: how far it reaches; w: its full-strength core.
uniform vec4 party = vec4(0.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(world) + 0.5;
	vec2 cell = (p / tile_size - seen_origin) / seen_size;
	float near = 0.0;
	if (cell.x >= 0.0 && cell.y >= 0.0 && cell.x <= 1.0 && cell.y <= 1.0) {
		near = texture(seen, cell).r;
	}
	float shown = floor(near * steps + 0.5) / steps;
	float lit = 0.0;
	float d = distance(p, party.xy);
	if (d < party.z) {
		float out_of_core = max(d - party.w, 0.0) / (party.z - party.w);
		lit = pow(ceil((1.0 - out_of_core) * steps) / steps, ring_power);
	}
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - shown) * (1.0 - lit));
}
