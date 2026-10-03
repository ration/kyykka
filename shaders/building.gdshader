shader_type spatial;
// Building facades: the tower mode's city (scripts/landscape/
// tower_landscape.gd) and the winter mode's office park
// (winter_landscape.gd): every building is the same unit box in one MultiMesh,
// scaled per instance, so the windows are drawn here from world position
// rather than from UVs (which would stretch with the scale).
//
// Per instance: COLOR is the facade colour, INSTANCE_CUSTOM is
// (window column width m, floor height m, fraction of windows lit, glassiness
// 0 = punched windows in a concrete wall .. 1 = curtain wall).
//
// The window grid fades to its average colour once a cell gets smaller than
// a few pixels, or distant buildings shimmer.

render_mode diffuse_burley, specular_schlick_ggx;

uniform float street_level = -160.0;  // world y of the street, where floors are counted from
uniform vec3 sky_reflection : source_color = vec3(0.75, 0.70, 0.62);
uniform vec3 lit_window_color : source_color = vec3(1.0, 0.78, 0.48);
uniform float lit_window_energy = 0.6;
uniform float roof_snow : hint_range(0.0, 1.0) = 0.0;  // winter: flat roofs under snow

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 style;
varying vec3 facade;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	style = INSTANCE_CUSTOM;
	facade = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(world_normal);
	if (n.y > 0.5) {
		// Flat roofs: darker, with a little gravel-ish variation.
		float grit = hash12(floor(world_pos.xz * 1.5));
		ALBEDO = mix(facade * (0.42 + grit * 0.08), vec3(0.86, 0.88, 0.92) * (0.96 + grit * 0.04), roof_snow);
		ROUGHNESS = 0.95;
		SPECULAR = 0.2;
	} else {
		// Horizontal position along this face, so each face gets its own columns.
		float along = dot(world_pos.xz, vec2(-n.z, n.x));
		vec2 grid = vec2(along, world_pos.y - street_level) / max(style.xy, vec2(0.5));
		vec2 cell = floor(grid);
		vec2 f = fract(grid);
		float glassy = style.w;
		vec2 half_size = vec2(mix(0.30, 0.47, glassy), mix(0.26, 0.43, glassy));
		float window = step(abs(f.x - 0.5), half_size.x) * step(abs(f.y - 0.55), half_size.y);
		// No windows on the ground floor's lower half (doors and lobbies read as wall at this distance).
		window *= step(2.0, world_pos.y - street_level);
		float coverage = 4.0 * half_size.x * half_size.y;
		vec2 footprint = fwidth(grid);
		float fade = smoothstep(0.35, 0.8, max(footprint.x, footprint.y));
		float glass_amount = mix(window, coverage, fade);

		float seed = hash12(cell + n.xz * 37.0);
		vec3 glass = mix(vec3(0.07, 0.10, 0.14), vec3(0.18, 0.24, 0.30), hash12(cell * 1.7 + 3.1));
		ALBEDO = mix(facade, glass, glass_amount);
		ROUGHNESS = mix(0.85, 0.12, glass_amount);
		SPECULAR = mix(0.25, 0.9, glass_amount);

		// Reflections are off for the whole scene (see Landscape.apply_atmosphere()),
		// so the glass fakes the sky it would mirror, more so at grazing angles.
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		vec3 reflected = sky_reflection * (0.04 + 0.5 * fresnel) * glass_amount;
		float lit = mix(window * step(seed, style.z), coverage * style.z, fade);
		EMISSION = reflected + lit_window_color * lit_window_energy * lit;
	}
}
