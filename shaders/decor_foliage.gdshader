shader_type canvas_item;
render_mode world_vertex_coords;

uniform vec2 atlas_size;
uniform vec2 source_pixel;
uniform vec2 sprite_size;
uniform vec2 uv_axis = vec2(1.0);
uniform float root_pixel;
uniform float motion_gain = 1.0;
uniform float wind_strength = 0.0;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform bool use_test_time = false;
uniform float test_time = 0.0;
#include "res://shaders/grass_actor_bend.gdshaderinc"
varying vec4 foliage_tint;

void vertex() {
	vec2 pixel = UV * atlas_size - source_pixel;
	vec2 to_root = vec2(sprite_size.x * 0.5 - pixel.x, root_pixel - pixel.y) * uv_axis;
	vec2 root = VERTEX + (MODEL_MATRIX * vec4(to_root, 0.0, 0.0)).xy;
	float reach = (root_pixel - pixel.y) / max(16.0, sprite_size.y);
	float time = use_test_time ? test_time : TIME;
	float phase = root.x * 0.071 + root.y * 0.043;
	float breeze = sin(fract(time / 5.0) * TAU + phase)
		+ 0.25 * sin(fract(time / 9.0) * TAU + phase * 0.7);
	vec2 wind = wind_direction / max(length(wind_direction), 0.000001);
	vec2 displacement = wind * wind_strength * breeze + actor_bend(root);
	displacement *= min(1.0, GRASS_MAX_BEND / max(length(displacement), 0.000001));
	VERTEX += displacement * reach * motion_gain;
	foliage_tint = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * foliage_tint;
}
