uniform float wind_strength : hint_range(0.0, 6.0) = 0.85;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform bool animate_frames = true;
uniform int fixed_frame : hint_range(-1, 7) = -1;
uniform bool use_test_time = false;
uniform float test_time = 0.0;
uniform bool debug_anchor_only = false;

#ifdef GRASS_AUTHORED_UV
// Preserve the original atlas's normalized UV interpolation at fractional zoom.
uniform vec4 farm_source_regions[128];
varying vec2 farm_source_uv;
#endif

#ifdef GRASS_TILEMAP
uniform vec2 tile_source_pixel;
uniform vec2 tile_size_pixel = vec2(16.0);
uniform float tile_root_pixel = 14.0;
#endif

#include "res://shaders/grass_actor_bend.gdshaderinc"

varying float strip_row;
varying float ground_pixel;
varying float frame_phase;
varying vec4 vertex_tint;

void vertex() {
	#ifdef GRASS_TILEMAP
	ground_pixel = tile_root_pixel;
	frame_phase = 0.0;
	vec2 tile_uv = (UV * vec2(144.0, 416.0) - tile_source_pixel) / tile_size_pixel;
	vec2 to_root = vec2((0.5 - tile_uv.x) * tile_size_pixel.x, ground_pixel - tile_uv.y * tile_size_pixel.y);
	vec2 root = VERTEX + (MODEL_MATRIX * vec4(to_root, 0.0, 0.0)).xy;
	float reach = (ground_pixel - tile_uv.y * tile_size_pixel.y) / max(16.0, tile_size_pixel.y);
	vertex_tint = COLOR;
	#else
	strip_row = INSTANCE_CUSTOM.r;
	ground_pixel = INSTANCE_CUSTOM.g;
	frame_phase = INSTANCE_CUSTOM.b;
	#ifdef GRASS_AUTHORED_UV
	vec4 region = farm_source_regions[int(strip_row)];
	farm_source_uv = region.xy + UV * region.zw;
	#endif
	vertex_tint = COLOR;
	vec2 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	vec2 local = vec2((UV.x - 0.5) * 16.0, UV.y * 16.0 - ground_pixel);
	VERTEX = (MODEL_MATRIX * vec4(local, 0.0, 1.0)).xy;
	// Unclamped linear shear through transparent bottom padding is intentional.
	// Interpolated displacement is EXACTLY zero at the opaque ground line.
	float reach = (ground_pixel - UV.y * 16.0) / 16.0;
	#endif
	float time = use_test_time ? test_time : TIME;
	float phase = root.x * 0.071 + root.y * 0.043 + frame_phase * TAU;
	// Both periods divide Godot's default 3600s TIME rollover: no hourly jump.
	float breeze = sin(fract(time / 5.0) * TAU + phase)
		+ 0.25 * sin(fract(time / 9.0) * TAU + phase * 0.7);
	float length_squared = dot(wind_direction, wind_direction);
	vec2 direction = length_squared > 0.000001 ? wind_direction * inversesqrt(length_squared) : vec2(0.0);
	vec2 displacement = direction * wind_strength * breeze;
	if (actor_count > 0) {
		displacement += actor_bend(root);
		float magnitude = length(displacement);
		displacement *= min(1.0, GRASS_MAX_BEND / max(0.000001, magnitude));
	}
	VERTEX += displacement * reach;
}

void fragment() {
	#ifdef GRASS_TILEMAP
	COLOR = texture(TEXTURE, UV) * vertex_tint;
	#else
	#ifdef GRASS_AUTHORED_UV
	COLOR = texture(TEXTURE, farm_source_uv) * vertex_tint;
	#else
	float time = use_test_time ? test_time : TIME;
	float frame = fixed_frame >= 0 ? float(fixed_frame)
		: (animate_frames ? mod(floor(time * 8.0 + frame_phase * 8.0), 8.0) : 0.0);
	// Clamp sampling to texel centres within THIS frame, not across its strip.
	vec2 pixel = clamp(UV * 16.0, vec2(0.5), vec2(15.5));
	vec2 atlas_uv = (vec2(frame * 16.0, strip_row * 16.0) + pixel) / vec2(128.0, 288.0);
	COLOR = texture(TEXTURE, atlas_uv) * vertex_tint;
	#endif
	#endif
	if (debug_anchor_only) {
		COLOR = abs(UV.y * 16.0 - ground_pixel) < 0.125 ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(0.0);
	}
}
