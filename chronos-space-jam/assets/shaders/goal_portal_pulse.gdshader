shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.18, 1.0, 0.92, 1.0);
uniform float pulse_speed : hint_range(0.1, 8.0, 0.1) = 1.8;
uniform float pulse_strength : hint_range(0.0, 1.0, 0.01) = 0.36;
uniform float scan_speed : hint_range(0.1, 8.0, 0.1) = 2.5;
uniform float scan_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float ring_focus : hint_range(0.0, 2.0, 0.01) = 1.18;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);
	float angle = atan(centered.y, centered.x);

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float ring_mask = 1.0 - smoothstep(0.10, 0.27, abs(dist - 0.31));
	float scan = smoothstep(0.91, 1.0, sin(angle * 6.0 + TIME * scan_speed));
	float inner_mask = 1.0 - smoothstep(0.23, 0.38, dist);
	float inner_shimmer = (0.5 + 0.5 * sin(dist * 48.0 - TIME * 3.2)) * inner_mask;
	float edge_charge = tex.a * smoothstep(0.16, 0.42, dist) * (0.45 + 0.55 * pulse);

	float energy = tex.a * ring_mask;
	float glow = energy * (pulse * pulse_strength + scan * scan_strength + inner_shimmer * 0.12) + edge_charge * 0.11;
	vec3 color = tex.rgb + glow_color.rgb * glow * ring_focus;

	COLOR = vec4(color, tex.a);
}
