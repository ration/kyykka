shader_type spatial;
// Snow ground for winter mode (see scripts/winter_landscape.gd). Sampled in
// world XZ so the court plane and the surrounding snowfield line up
// seamlessly even though they're separate meshes.
//
// Three things keep it reading as snow rather than white paint: soft
// bluish hollows between brighter drifts (two scales of the mottle noise),
// a fine bump normal map so the low sun picks out surface texture, and
// sparse view-dependent glints — random ice-crystal facets that flash only
// when they happen to mirror the sun toward the camera.

render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 snow_color : source_color = vec3(0.93, 0.93, 0.95);
uniform vec3 hollow_color : source_color = vec3(0.78, 0.82, 0.90);
uniform sampler2D mottle_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float mottle_scale = 0.06;  // mottle texture repeats per metre
uniform float mottle_contrast = 1.2;
uniform float detail_scale = 0.5;   // normal map repeats per metre
uniform float normal_depth = 0.55;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);  // world space, pointing toward the sun
uniform float sparkle_cells = 45.0;  // glint candidate cells per metre
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.06;  // fraction of cells holding a facet
uniform float sparkle_sharpness = 250.0;
uniform float sparkle_strength = 5.0;
uniform float sparkle_fade_distance = 22.0;  // metres; tiny glints alias badly further out

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;
	float broad = texture(mottle_noise, uv * mottle_scale).r;
	float fine = texture(mottle_noise, uv * mottle_scale * 4.3 + vec2(0.37, 0.71)).r;
	float drift = clamp((broad * 0.7 + fine * 0.3 - 0.5) * mottle_contrast + 0.5, 0.0, 1.0);
	ALBEDO = mix(hollow_color, snow_color, drift);
	NORMAL_MAP = texture(detail_normal, uv * detail_scale).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;

	vec2 cell = floor(uv * sparkle_cells);
	if (hash12(cell) < sparkle_amount) {
		// Facets lean upward, since the sun and camera are both above the ground.
		vec3 facet = normalize(hash32(cell) * 2.0 - 1.0 + vec3(0.0, 1.2, 0.0));
		vec3 to_camera = CAMERA_POSITION_WORLD - world_pos;
		vec3 half_vector = normalize(normalize(to_camera) + normalize(sun_direction));
		float glint = pow(max(dot(facet, half_vector), 0.0), sparkle_sharpness);
		float fade = 1.0 - smoothstep(sparkle_fade_distance * 0.4, sparkle_fade_distance, length(to_camera));
		EMISSION = vec3(glint * sparkle_strength * fade);
	}
}
