shader_type canvas_item;

uniform vec2 capture_direction = vec2(0.0, 0.0);
uniform float capture_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 capture_color : source_color = vec4(0.42, 1.0, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float ring_width : hint_range(0.01, 0.25, 0.005) = 0.055;
uniform float streak_strength : hint_range(0.0, 1.0, 0.01) = 0.50;
uniform float glow_strength : hint_range(0.0, 1.0, 0.01) = 0.44;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	vec2 dir = capture_direction;
	if (length(dir) < 0.001) {
		dir = vec2(0.0, -1.0);
	}
	dir = normalize(dir);

	float amount = clamp(capture_amount, 0.0, 1.0);
	vec2 side_axis = vec2(-dir.y, dir.x);
	float side_lane = 1.0 - smoothstep(0.025, 0.20, abs(dot(centered, side_axis)));
	float incoming_side = max(dot(centered, -dir) + 0.26, 0.0) * 1.35;
	float inward_band = 1.0 - smoothstep(0.12, 0.52, dist + (1.0 - amount) * 0.22);
	float streak = side_lane * incoming_side * inward_band * amount;

	float collapsing_radius = mix(0.10, 0.46, amount);
	float ring = 1.0 - smoothstep(ring_width, ring_width + 0.018, abs(dist - collapsing_radius));
	ring *= amount;

	float flash = smoothstep(0.18, 0.0, dist) * pow(amount, 1.7);
	float edge_lift = tex.a * amount * (0.5 + 0.5 * sin(TIME * 18.0)) * 0.08;

	vec3 color = tex.rgb;
	color += capture_color.rgb * (ring * glow_strength + streak * streak_strength + edge_lift);
	color = mix(color, core_color.rgb, flash * 0.32);

	COLOR = vec4(color, tex.a);
}
