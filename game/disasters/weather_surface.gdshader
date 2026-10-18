shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D sky_height : filter_nearest, repeat_disable;
uniform float extent = 72.0;
uniform float snow = 0.0;
uniform float wetness = 0.0;
uniform int melt_count = 0;
uniform vec4 melt_areas[32];
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
	float exposure = step(top - 0.18, world_position.y) * smoothstep(0.45, 0.85, world_normal.y);
	float local_snow = snow;
	for (int i = 0; i < melt_count; i++) {
		float melt_distance = distance(world_position, vec3(melt_areas[i].x, melt_areas[i].y, melt_areas[i].z));
		local_snow *= smoothstep(melt_areas[i].w - 0.25, melt_areas[i].w, melt_distance);
	}
	float ice = step(0.08, local_snow) * (1.0 - step(0.55, local_snow)) * step(0.15, wetness);
	ALBEDO = mix(vec3(0.16, 0.30, 0.34), vec3(0.95, 0.96, 0.91), smoothstep(0.0, 0.55, local_snow));
	ALBEDO = mix(ALBEDO, vec3(0.64, 0.83, 0.88), ice * 0.7);
	ROUGHNESS = mix(0.32, 0.88, smoothstep(0.08, 0.55, local_snow));
	ROUGHNESS = mix(ROUGHNESS, 0.16, ice);
	ALPHA = exposure * max(max(wetness * 0.48, ice * 0.82), smoothstep(0.0, 0.55, local_snow) * 0.88);
}
