shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float noise_strength = 0.08;
uniform float scanline_strength = 0.06;
uniform float scanline_count = 220.0;
uniform float jitter_strength = 0.0015;
uniform float speed = 18.0;
uniform vec4 tint = vec4(0.55, 0.95, 1.0, 1.0);

float static_random(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float time_step = floor(TIME * speed);
	float scan_row = floor(UV.y * scanline_count);
	float row_jitter = (static_random(vec2(scan_row, time_step)) - 0.5) * jitter_strength;
	vec2 screen_uv = SCREEN_UV + vec2(row_jitter, 0.0);

	vec2 chroma_offset = vec2(jitter_strength * 0.45, 0.0);
	vec4 center_sample = texture(screen_texture, screen_uv);
	vec3 sampled_color = center_sample.rgb;
	sampled_color.r = texture(screen_texture, screen_uv + chroma_offset).r;
	sampled_color.b = texture(screen_texture, screen_uv - chroma_offset).b;

	float grain = static_random(floor(UV * 420.0) + vec2(time_step, time_step * 1.37));
	float noise = (grain - 0.5) * noise_strength;
	float scanline = sin(UV.y * scanline_count * 6.2831853) * 0.5 + 0.5;

	vec3 preview_color = sampled_color;
	preview_color += tint.rgb * 0.035;
	preview_color += vec3(noise);
	preview_color -= vec3(scanline * scanline_strength);

	COLOR = vec4(clamp(preview_color, 0.0, 1.0), center_sample.a);
}
