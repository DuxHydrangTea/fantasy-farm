// G3 bounded uniform baseline: 2 vec4 arrays, no compute or readback.
uniform int actor_count = 0;
uniform vec4 actor_segments[96]; // previous.xy, current.zw, WORLD coordinates
uniform vec4 actor_parameters[96]; // radius, strength, motion time, fallback angle
uniform float interaction_clock = 0.0; // manager simulation seconds, NOT TIME/Unix
const float GRASS_MAX_BEND = 12.0;

vec2 actor_bend(vec2 root) {
	vec2 pressure = vec2(0.0);
	for (int i = 0; i < 96; i++) {
		if (i >= actor_count) { break; }
		vec4 data = actor_parameters[i];
		vec2 head = actor_segments[i].zw;
		float age = max(0.0, interaction_clock - data.z);
		vec2 tail = mix(actor_segments[i].xy, head, smoothstep(0.0, 0.18, age));
		vec2 path = head - tail;
		float length_sq = dot(path, path);
		float t = length_sq > 0.000001 ? clamp(dot(root - tail, path) / length_sq, 0.0, 1.0) : 0.0;
		vec2 away = root - (tail + t * path);
		float distance_sq = dot(away, away);
		float radius = max(0.001, data.x);
		if (distance_sq < radius * radius) {
			float distance_to_path = sqrt(max(0.0, distance_sq));
			vec2 direction = distance_sq > 0.000001 ? away / max(0.000001, distance_to_path) : vec2(cos(data.w), sin(data.w));
			float weight = 1.0 - smoothstep(radius * 0.15, radius, distance_to_path);
			pressure += direction * data.y * weight;
		}
	}
	return pressure;
}
