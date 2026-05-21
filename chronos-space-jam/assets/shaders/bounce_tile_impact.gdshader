shader_type canvas_item;

uniform vec2 impact_direction = vec2(0.0, 0.0);
uniform float impact_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float squash_strength : hint_range(0.0, 0.50, 0.005) = 0.18;
uniform float squash_width : hint_range(0.05, 1.0, 0.01) = 0.82;
uniform vec4 impact_color : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float impact_glow : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform vec4 pressure_shadow : source_color = vec4(0.02, 0.10, 0.14, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.38;

float pressure_profile(float cross_axis) {
	float centered = 1.0 - abs(cross_axis * 2.0 - 1.0);
	return pow(clamp(centered, 0.0, 1.0), 1.55);
}

void fragment() {
	vec2 uv = UV;
	float amount = clamp(impact_amount, 0.0, 1.0);
	float pressure = 0.0;
	float contact_line = 0.0;
	bool outside_dent = false;

	if (impact_direction.x > 0.5) {
		float profile = pressure_profile(uv.y);
		float dent = squash_strength * amount * profile;
		float scale = max(0.001, 1.0 - dent);
		outside_dent = uv.x < dent;
		uv.x = (uv.x - dent) / scale;
		pressure = profile * (1.0 - smoothstep(0.0, squash_width, uv.x));
		contact_line = profile * (1.0 - smoothstep(0.0, 0.025, abs(UV.x - dent)));
	} else if (impact_direction.x < -0.5) {
		float profile = pressure_profile(uv.y);
		float dent = squash_strength * amount * profile;
		float scale = max(0.001, 1.0 - dent);
		outside_dent = uv.x > scale;
		uv.x = uv.x / scale;
		pressure = profile * (1.0 - smoothstep(0.0, squash_width, 1.0 - uv.x));
		contact_line = profile * (1.0 - smoothstep(0.0, 0.025, abs(UV.x - scale)));
	} else if (impact_direction.y > 0.5) {
		float profile = pressure_profile(uv.x);
		float dent = squash_strength * amount * profile;
		float scale = max(0.001, 1.0 - dent);
		outside_dent = uv.y < dent;
		uv.y = (uv.y - dent) / scale;
		pressure = profile * (1.0 - smoothstep(0.0, squash_width, uv.y));
		contact_line = profile * (1.0 - smoothstep(0.0, 0.025, abs(UV.y - dent)));
	} else if (impact_direction.y < -0.5) {
		float profile = pressure_profile(uv.x);
		float dent = squash_strength * amount * profile;
		float scale = max(0.001, 1.0 - dent);
		outside_dent = uv.y > scale;
		uv.y = uv.y / scale;
		pressure = profile * (1.0 - smoothstep(0.0, squash_width, 1.0 - uv.y));
		contact_line = profile * (1.0 - smoothstep(0.0, 0.025, abs(UV.y - scale)));
	}

	if (outside_dent || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 tex = texture(TEXTURE, uv);
		float pressure_shadow_amount = pressure * amount * shadow_strength * tex.a;
		float flash = (pressure * impact_glow + contact_line * 0.26) * amount * tex.a;
		vec3 color = mix(tex.rgb, pressure_shadow.rgb, pressure_shadow_amount);
		color += impact_color.rgb * flash;
		COLOR = vec4(color, tex.a);
	}
}
