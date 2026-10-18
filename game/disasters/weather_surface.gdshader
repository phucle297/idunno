shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D sky_height : filter_nearest, repeat_disable;
uniform sampler2D residual_surface : filter_nearest, repeat_disable;
uniform float extent = 72.0;
uniform float snow = 0.0;
uniform float wetness = 0.0;
uniform float wash_level = -100.0;
uniform float wash_wetness = 0.0;
uniform float washed_snow = 0.0;
uniform int melt_count = 0;
uniform vec4 melt_areas[32];
uniform float melt_amounts[32];
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 uv = (world_position.xz + vec2(extent + 0.5)) / (2.0 * extent + 1.0);
	float top = texture(sky_height, uv).r;
	// Overlay actual geometry, including slopes/roofs/props, never a floating disc.
	// Compensate for the height texel's half-metre slope offset, not for roofs.
	float slope_margin = 0.18 + 0.71 * length(world_normal.xz) / max(world_normal.y, 0.45);
	float exposure = step(top - slope_margin, world_position.y);
	vec4 residual = texture(residual_surface, uv);
	float retained = residual.a * (1.0 - step(0.3, abs(residual.b - world_position.y)));
	float local_snow = mix(residual.r * retained, snow, exposure);
	float local_wetness = mix(residual.g * retained, wetness, exposure);
	if (world_position.y <= wash_level) {
		local_snow = min(local_snow, washed_snow);
		local_wetness = max(local_wetness, wash_wetness);
	}
	for (int i = 0; i < melt_count; i++) {
		if (abs(world_position.y - melt_areas[i].y) <= 1.0) {
			float melt_distance = distance(world_position.xz, melt_areas[i].xz);
			float melted = min(local_snow, melt_amounts[i] * (1.0 - smoothstep(melt_areas[i].w - 0.25, melt_areas[i].w, melt_distance)));
			local_snow -= melted;
			local_wetness = min(1.0, local_wetness + melted);
		}
	}
	float ice = step(0.08, local_snow) * (1.0 - step(0.55, local_snow)) * step(0.15, local_wetness);
	ALBEDO = mix(vec3(0.16, 0.30, 0.34), vec3(0.95, 0.96, 0.91), smoothstep(0.0, 0.55, local_snow));
	ALBEDO = mix(ALBEDO, vec3(0.64, 0.83, 0.88), ice * 0.7);
	ROUGHNESS = mix(0.32, 0.88, smoothstep(0.08, 0.55, local_snow));
	ROUGHNESS = mix(ROUGHNESS, 0.16, ice);
	ALPHA = smoothstep(0.45, 0.85, world_normal.y) * max(max(local_wetness * 0.72, ice * 0.88), smoothstep(0.0, 0.55, local_snow) * 0.92);
}
