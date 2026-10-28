shader_type canvas_item;

// Keep the bubble tint while mirroring the texture; child labels use their own material.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = texture(TEXTURE, vec2(1.0 - UV.x, UV.y)) * tint;
}
