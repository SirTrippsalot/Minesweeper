shader_type canvas_item;

// Ocean background shader
// Simple animated gradient with subtle wave effect

uniform vec4 color_deep: source_color = vec4(0.05, 0.1, 0.2, 1.0);
uniform vec4 color_shallow: source_color = vec4(0.1, 0.2, 0.35, 1.0);
uniform float wave_speed: hint_range(0.0, 2.0) = 0.3;
uniform float wave_scale: hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// Calculate position with time-based animation
	vec2 pos = UV * wave_scale;
	float time_offset = TIME * wave_speed;

	// Simple wave pattern
	float wave1 = sin(pos.x + time_offset) * 0.5 + 0.5;
	float wave2 = sin(pos.y + time_offset * 0.7) * 0.5 + 0.5;
	float wave = (wave1 + wave2) * 0.5;

	// Mix colors based on wave
	vec4 color = mix(color_deep, color_shallow, wave);

	COLOR = color;
}
