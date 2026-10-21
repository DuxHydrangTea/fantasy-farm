shader_type canvas_item;
render_mode unshaded;
uniform vec4 outline_color : source_color = vec4(1.0, 0.90, 0.48, 0.85);
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
bool in_frame(vec2 uv) {
	return uv.x >= frame_uv.x && uv.y >= frame_uv.y && uv.x <= frame_uv.z && uv.y <= frame_uv.w;
}
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE;
	float edge = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 sample_uv = UV + vec2(float(x),float(y)) * step_uv;
			edge = max(edge, in_frame(sample_uv) ? texture(TEXTURE, sample_uv).a : 0.0);
		}
	}
	float original = in_frame(UV) ? texture(TEXTURE, UV).a : 0.0;
	COLOR = vec4(outline_color.rgb, max(0.0, edge - original) * outline_color.a);
}
