// The darkness of the labyrinth (spec 012): the world under it is multiplied by the light at each
// world pixel. The same formula is AmbienceMood.light_at in GDScript; change both together.
shader_type canvas_item;
render_mode blend_mul, unshaded;

#include "res://game/ambience/light.gdshaderinc"

// The ambient light of each stratum: loam, clay, stone, deep.
uniform vec4 ambient[4];
// How much brighter solid earth is than open space when no lamp reaches it.
uniform float earth_lift = 0.12;
// Each ring's strength is raised to this (AmbienceMood.RING_POWER).
uniform float ring_power = 1.5;
// Daylight in the first rows of earth: how far down each band reaches, and how much it adds.
uniform vec3 daylight_depths = vec3(12.0, 28.0, 48.0);
uniform vec3 daylight_levels = vec3(0.35, 0.2, 0.1);

void fragment() {
	vec2 p = floor(world) + 0.5;
	if (p.y < 0.0) {
		COLOR = vec4(1.0);
	} else {
		float share = share_at(p);
		vec3 total = ambient[stratum_at(p.y)].rgb + vec3(earth_lift * (1.0 - share));
		if (p.y < daylight_depths.x) {
			total += vec3(daylight_levels.x);
		} else if (p.y < daylight_depths.y) {
			total += vec3(daylight_levels.y);
		} else if (p.y < daylight_depths.z) {
			total += vec3(daylight_levels.z);
		}
		total += lamps(p, ring_power) * share;
		COLOR = vec4(min(total, vec3(1.0)), 1.0);
	}
}
