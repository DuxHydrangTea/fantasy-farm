// Adapted from the Godot skill wave template. Vertex deformation keeps AtlasTexture
// sampling inside its original tile and pins the bottom edge to the ground.
shader_type canvas_item;

uniform float plant_height = 32.0;
uniform float amplitude = 0.7;
uniform float speed = 1.4;

void vertex() {
	vec2 root = (MODEL_MATRIX * vec4(0.0, plant_height * 0.5, 0.0, 1.0)).xy;
	float phase = root.x * 0.071 + root.y * 0.043;
	float reach = clamp((plant_height * 0.5 - VERTEX.y) / (plant_height * 0.7), 0.0, 1.0);
	float breeze = sin(TIME * speed + phase) + 0.25 * sin(TIME * speed * 0.63 + phase * 0.7);
	VERTEX.x += breeze * amplitude * reach;
}
