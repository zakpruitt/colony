// The stepped light of the labyrinth (spec 012), shared by darkness.gdshader (which multiplies
// the world by it) and glow.gdshader (which adds a little of the lamps' colour on top, so dark
// back walls look lit). The same formula is AmbienceMood.light_at in GDScript; change both.

const int MAX_LIGHTS = 32;

// x, y: where the light is in world pixels; z: how far it reaches.
uniform vec4 light_shape[MAX_LIGHTS];
// rgb: the light's colour times its strength.
uniform vec4 light_color[MAX_LIGHTS];
uniform int light_count = 0;
uniform float steps = 3.0;
// How much light reaches each tile of the built levels (red, one pixel per tile), from tile row
// exposure_origin.y down, exposure_size tiles; earth_exposure outside it. Blended between tile
// centres, then cut into exposure_steps steps.
uniform sampler2D exposure : filter_linear, repeat_disable;
uniform float exposure_steps = 4.0;
uniform vec2 exposure_origin = vec2(0.0);
uniform vec2 exposure_size = vec2(1.0);
uniform float earth_exposure = 0.0;
uniform float tile_size = 16.0;
uniform float level_pixels = 256.0;
uniform float levels_per_stratum = 5.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// The earth stratum (0 loam, 1 clay, 2 stone, 3 deep) at world row y, as the earth is drawn.
int stratum_at(float y) {
	return int(mod(floor(floor(y / level_pixels) / levels_per_stratum), 4.0));
}

// The share of the lamps' light that reaches pixel centre p.
float share_at(vec2 p) {
	vec2 cell = (p / tile_size - exposure_origin) / exposure_size;
	if (cell.x >= 0.0 && cell.y >= 0.0 && cell.x <= 1.0 && cell.y <= 1.0) {
		return round(texture(exposure, cell).r * exposure_steps) / exposure_steps;
	}
	return earth_exposure;
}

// The lamps' light at pixel centre p, in rings, each ring's strength raised to power.
vec3 lamps(vec2 p, float power) {
	vec3 total = vec3(0.0);
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		float reach = light_shape[i].z;
		float d = distance(p, light_shape[i].xy);
		if (d < reach) {
			total += light_color[i].rgb * pow(ceil((1.0 - d / reach) * steps) / steps, power);
		}
	}
	return total;
}
