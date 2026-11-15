shader_type canvas_item;

void fragment() {
	// The source sheets use the top-left texel as their solid water backdrop.
	vec3 backdrop = texelFetch(TEXTURE, ivec2(0), 0).rgb;
	vec3 pixel = texture(TEXTURE, UV).rgb;
	if (distance(pixel, backdrop) < 0.001) {
		discard;
	}
}
