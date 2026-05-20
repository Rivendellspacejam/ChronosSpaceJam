shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 10.0, 0.1) = 3.2;
uniform float rim_strength : hint_range(0.0, 2.0, 0.01) = 0.86;
uniform float scan_strength : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float flicker_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float slide_boost : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered);

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float scan_wave = sin((UV.y * 34.0) - (TIME * 8.0));
	float scan = smoothstep(0.78, 1.0, scan_wave);
	float flicker = 0.5 + 0.5 * sin((UV.x * 41.0) + (UV.y * 23.0) + (TIME * 15.0));

	float center_mask = smoothstep(0.58, 0.08, dist);
	float alpha_edge = smoothstep(0.03, 0.2, tex.a);
	float rim_mask = smoothstep(0.5, 0.18, dist) * alpha_edge;
	float visible_boost = 1.0 + slide_boost * 0.7;

	vec3 color = tex.rgb;
	color += rim_color.rgb * tex.a * rim_mask * (0.34 + pulse * rim_strength) * visible_boost;
	color += core_color.rgb * tex.a * center_mask * scan * scan_strength * visible_boost;
	color += rim_color.rgb * tex.a * flicker * flicker_strength * (0.45 + slide_boost);

	COLOR = vec4(color, tex.a);
}
