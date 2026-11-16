// The warm glow of the labyrinth's lamps (spec 012): drawn just after the darkness, it adds a
// share of each lamp's light on top, in the stratum's glow colour, so a dark back wall near a
// torch turns warm instead of only less dark. Strongest near the flame. Underground only. The
// party's light adds no glow, so the heroes keep their true colours.
shader_type canvas_item;
render_mode blend_add, unshaded;

#include "res://game/ambience/light.gdshaderinc"

// How much of the lamps' light is added.
uniform float strength = 0.2;
// The colour the glow takes in each stratum: loam, clay, stone, deep.
uniform vec4 glow_tint[4];

void fragment() {
	vec2 p = floor(world) + 0.5;
	if (p.y < 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 glow = lamps(p, 2.0, share_at(p), false) * glow_tint[stratum_at(p.y)].rgb;
		COLOR = vec4(glow * strength, 1.0);
	}
}
