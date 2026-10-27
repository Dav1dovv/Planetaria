// Starfield shader v5 by Brian Smith (steampunkdemon.itch.io)
// MIT licence
//
// Modified for Planetaria: added nebula clouds, star twinkle, occasional
// comets, and pixel-art motion snapping.

shader_type canvas_item;

// Comment out the following line if you are not applying the shader to a ColorRect:
uniform vec2 dimensions = vec2(1024.0, 600.0); // Resolution of ColorRect in pixels

uniform float small_stars = 50.0; // Number of small stars. Rows for horizontally scrolling stars or columns for vertically scrolling stars.
uniform float small_stars_far_size : hint_range(0.1, 1.0, 0.1) = 0.5;
uniform float small_stars_near_size : hint_range(0.1, 1.0, 0.1) = 1.0;
uniform float large_stars = 8.0; // Number of large stars. Rows for horizontally scrolling stars or columns for vertically scrolling stars.
uniform float large_stars_far_size : hint_range(0.1, 1.0, 0.1) = 0.5;
uniform float large_stars_near_size : hint_range(0.1, 1.0, 0.1) = 1.0;

// Replace the below references to 'source_color' with 'hint_color' if you are using a version of Godot before 4.
uniform vec4 far_stars_color : source_color = vec4(0.50, 0.0, 1.0, 1.0);
uniform vec4 near_stars_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Remove the below references to ': source_color, filter_nearest_mipmap' if you are using a version of Godot before 4.
uniform sampler2D small_stars_texture : source_color, filter_nearest_mipmap;
uniform sampler2D large_stars_texture : source_color, filter_nearest_mipmap;

uniform float base_scroll_speed : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float additional_scroll_speed : hint_range(0.01, 1.0, 0.01) = 0.05;

// --- Pixel-art motion ---
// Snaps scroll movement to a fixed step rate instead of smooth per-frame motion,
// so the stars "jump" like they would on a low-framerate retro system instead
// of drifting continuously — matches a pixel-art look much better.
uniform bool pixel_snap_motion = true;
uniform float pixel_steps_per_second : hint_range(2.0, 60.0, 1.0) = 12.0;

// Hard edges keep stars as crisp blocky dots instead of soft antialiased circles.
uniform bool hard_edge_stars = true;

// --- Twinkle ---
uniform bool twinkle_enabled = true;
uniform float twinkle_speed : hint_range(0.1, 10.0, 0.1) = 2.0;
uniform float twinkle_amount : hint_range(0.0, 1.0, 0.01) = 0.5;

// --- Nebula / cosmic dust clouds ---
uniform bool nebula_enabled = true;
uniform vec4 nebula_color_a : source_color = vec4(0.35, 0.05, 0.55, 1.0);
uniform vec4 nebula_color_b : source_color = vec4(0.05, 0.25, 0.55, 1.0);
uniform float nebula_scale : hint_range(0.5, 10.0, 0.1) = 2.5;
uniform float nebula_speed : hint_range(0.0, 0.1, 0.001) = 0.006;
uniform float nebula_intensity : hint_range(0.0, 1.0, 0.01) = 0.18;

// --- Comets ---
uniform bool comets_enabled = true;
uniform float comet_interval : hint_range(1.0, 30.0, 0.5) = 7.0; // seconds between attempts
uniform float comet_chance : hint_range(0.0, 1.0, 0.01) = 0.4; // fraction of attempts that spawn one
uniform float comet_speed : hint_range(0.2, 3.0, 0.1) = 1.4;
uniform float comet_length : hint_range(0.02, 0.4, 0.01) = 0.14;
uniform vec4 comet_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);

float greater_than(float x, float y) {
	return max(sign(x - y), 0.0);
}

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
// The below line will scroll the stars from right to left or from bottom to top.
// To make the stars scroll in the opposite direction change the line to:
//	float time = 10000.0 - TIME;
// Alternatively you can comment out the below line and add a new uniform above as:
// uniform float time = 10000.0;
// You can then update the time uniform from your _physics_process function by adding or subtracting delta. You can also pause the scrolling by not changing the time uniform.
	float raw_time = TIME;
	if (pixel_snap_motion) {
		raw_time = floor(TIME * pixel_steps_per_second) / pixel_steps_per_second;
	}
	float time = 10000.0 + raw_time;

// Comment out the following two lines if you are not applying the shader to a TextureRect:
//	COLOR = texture(TEXTURE,UV); // This line is only required if you are using a version of Godot before 4.
//	vec2 dimensions = 1.0 / TEXTURE_PIXEL_SIZE;

// --- Nebula clouds (drawn first, stars render on top) ---
	if (nebula_enabled) {
		vec2 nebula_uv = UV * nebula_scale + vec2(raw_time * nebula_speed, raw_time * nebula_speed * 0.4);
		float n = fbm(nebula_uv);
		float n2 = fbm(nebula_uv * 1.8 + 11.3);
		vec3 nebula_col = mix(nebula_color_a.rgb, nebula_color_b.rgb, n2);
		float mask = smoothstep(0.35, 0.8, n);
		COLOR.rgb = mix(COLOR.rgb, nebula_col, mask * nebula_intensity);
	}

// Horizontal scrolling:
	float small_star_rn = fract(sin(floor(UV.y * small_stars)) * dimensions.y);
	float large_star_rn = fract(sin(floor(UV.y * large_stars)) * dimensions.y);
	vec2 small_star_uv = vec2(fract(UV.x + (base_scroll_speed + small_star_rn * additional_scroll_speed) * time) * small_stars * dimensions.x / dimensions.y, fract(UV.y * small_stars)) * 2.0 - 1.0;
	vec2 large_star_uv = vec2(fract(UV.x + (base_scroll_speed + large_star_rn * additional_scroll_speed) * time) * large_stars * dimensions.x / dimensions.y, fract(UV.y * large_stars)) * 2.0 - 1.0;

// Vertical scrolling:
//	float small_stars_rn = fract(sin(floor(UV.x * small_stars)) * dimensions.x);
//	float large_stars_rn = fract(sin(floor(UV.x * large_stars)) * dimensions.x);
//	vec2 small_stars_uv = vec2(fract(UV.x * small_stars), fract(UV.y + (base_scroll_speed + small_stars_rn * additional_scroll_speed) * time) * small_stars * dimensions.y / dimensions.x) * 2.0 - 1.0;
//	vec2 large_stars_uv = vec2(fract(UV.x * large_stars), fract(UV.y + (base_scroll_speed + large_stars_rn * additional_scroll_speed) * time) * large_stars * dimensions.y / dimensions.x) * 2.0 - 1.0;

	vec4 star_color = mix(far_stars_color, near_stars_color, small_star_rn);
	float star_size = small_stars_far_size + (small_stars_near_size - small_stars_far_size) * small_star_rn;

	float small_twinkle = 1.0;
	if (twinkle_enabled) {
		small_twinkle = 1.0 - twinkle_amount * (0.5 + 0.5 * sin(TIME * twinkle_speed + small_star_rn * 47.0));
	}

// Render small stars as circles, hard or soft edge depending on hard_edge_stars:
	float small_alpha = hard_edge_stars
		? greater_than(star_size, length(small_star_uv))
		: max((star_size - length(small_star_uv)) / star_size, 0.0);
	COLOR.rgb = mix(COLOR.rgb, star_color.rgb, small_alpha * star_color.a * small_twinkle);

// Render small stars using the 'small_stars_texture':
// The 'small_stars_texture' must have a border of blank transparent pixels.
//	vec4 small_stars_texture_pixel = texture(small_stars_texture, (small_star_uv / (small_stars_far_size + (small_stars_near_size - small_stars_far_size) * small_star_rn) + 1.0) / 2.0) * mix(far_stars_color, near_stars_color, small_star_rn);
//	COLOR.rgb = mix(COLOR.rgb, small_stars_texture_pixel.rgb, small_stars_texture_pixel.a);

	star_color = mix(far_stars_color, near_stars_color, large_star_rn);
	star_size = large_stars_far_size + (large_stars_near_size - large_stars_far_size) * large_star_rn;

	float large_twinkle = 1.0;
	if (twinkle_enabled) {
		large_twinkle = 1.0 - twinkle_amount * (0.5 + 0.5 * sin(TIME * twinkle_speed * 0.8 + large_star_rn * 71.0));
	}

// Render large stars: hard cross when hard_edge_stars is on, soft circle+cross blend otherwise.
	float large_alpha;
	if (hard_edge_stars) {
		large_alpha = max(greater_than(star_size / 5.0, abs(large_star_uv.x)) * greater_than(star_size, abs(large_star_uv.y)), greater_than(star_size / 5.0, abs(large_star_uv.y)) * greater_than(star_size, abs(large_star_uv.x)));
	} else {
		large_alpha = max((star_size / 1.7 - length(large_star_uv)) / star_size, 0.0) + max((star_size - length(large_star_uv)) / star_size / 2.0, 0.0) * (max(greater_than(star_size / 10.0, abs(large_star_uv.x)), greater_than(star_size / 10.0, abs(large_star_uv.y))));
	}
	COLOR.rgb = mix(COLOR.rgb, star_color.rgb, large_alpha * star_color.a * large_twinkle);

// Render large stars using the 'large_stars_texture':
// The 'large_stars_texture' must have a border of blank transparent pixels.
//	vec4 large_stars_texture_pixel = texture(large_stars_texture, (large_star_uv / (large_stars_far_size + (large_stars_near_size - large_stars_far_size) * large_star_rn) + 1.0) / 2.0) * mix(far_stars_color, near_stars_color, large_star_rn);
//	COLOR.rgb = mix(COLOR.rgb, large_stars_texture_pixel.rgb, large_stars_texture_pixel.a);

// --- Occasional comet streak ---
	if (comets_enabled) {
		float comet_cycle = TIME / comet_interval;
		float comet_id = floor(comet_cycle);
		float comet_t = fract(comet_cycle);
		float comet_seed = hash11(comet_id * 3.17 + 4.0);
		if (comet_seed < comet_chance) {
			vec2 start = vec2(hash11(comet_id * 7.0 + 1.0) * 0.6 + 0.7, hash11(comet_id * 13.0 + 2.0) * 0.5);
			vec2 dir = normalize(vec2(-1.0, 0.6));
			vec2 head = start + dir * comet_t * comet_speed;
			vec2 tail = head - dir * comet_length;
			vec2 line_dir = tail - head;
			float len_sq = dot(line_dir, line_dir);
			float proj = clamp(dot(UV - head, line_dir) / max(len_sq, 0.0001), 0.0, 1.0);
			vec2 closest = head + line_dir * proj;
			float dist = length(UV - closest);
			float fade_in = smoothstep(0.0, 0.08, comet_t);
			float fade_out = smoothstep(1.0, 0.75, comet_t);
			float trail_fade = 1.0 - proj;
			float glow = smoothstep(0.012, 0.0, dist) * trail_fade * fade_in * fade_out;
			COLOR.rgb = mix(COLOR.rgb, comet_color.rgb, glow * comet_color.a);
		}
	}
}