// Based on the skill silhouette shader, clipped by actual foreground alpha.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D occlusion_mask : repeat_disable, filter_nearest;
uniform vec4 mask_rect = vec4(0.0, 0.0, 64.0, 96.0);
uniform vec4 silhouette_color : source_color = vec4(1.0, 0.93, 0.72, 0.65);
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 mask_uv = (world_position - mask_rect.xy) / mask_rect.zw;
	float foreground = texture(occlusion_mask, mask_uv).a;
	COLOR = vec4(silhouette_color.rgb, COLOR.a * silhouette_color.a * foreground);
}
