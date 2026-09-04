shader_type canvas_item;

// ---------------------------------------------------------
// Stylized tile water shader for Godot 4 (Aleria / Caves & Swords)
// Designed for autotile water sprites (TileMap water layer).
// Works with the transparent-edge autotile look — the alpha edge
// of each tile becomes the foam line.
// ---------------------------------------------------------

// --- Волны / искажение UV ---
uniform float wave_speed : hint_range(0.0, 5.0) = 0.6;
uniform float wave_strength : hint_range(0.0, 0.05) = 0.006;
uniform float wave_scale : hint_range(1.0, 50.0) = 12.0;

// --- Цвет и глубина ---
uniform vec4 shallow_color : source_color = vec4(0.45, 0.75, 0.85, 1.0);
uniform vec4 deep_color : source_color = vec4(0.10, 0.30, 0.55, 1.0);
uniform float color_mix_strength : hint_range(0.0, 1.0) = 0.35;

// --- Блики (скроллящийся слой) ---
uniform float highlight_speed : hint_range(0.0, 2.0) = 0.15;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.18;

// --- Пена по краю тайла (по альфе) ---
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_width : hint_range(0.0, 0.5) = 0.12;
uniform float foam_pulse_speed : hint_range(0.0, 5.0) = 1.2;

// --- Искры ---
uniform float sparkle_amount : hint_range(0.0, 1.0) = 0.25;
uniform float sparkle_speed : hint_range(0.0, 5.0) = 1.0;

// --- Прозрачность ---
uniform float water_alpha : hint_range(0.0, 1.0) = 0.75;
uniform float foam_alpha : hint_range(0.0, 1.0) = 0.95;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;

	// Волновое искажение — две наложенные синусоиды дают "органическую" рябь
	float t = TIME * wave_speed;
	vec2 wave_offset = vec2(
		sin((uv.y * wave_scale) + t) ,
		cos((uv.x * wave_scale) + t * 0.8)
	) * wave_strength;

	vec4 tex_color = texture(TEXTURE, uv + wave_offset);

	// Глубина по альфе исходной текстуры (края тайла — "мельче", центр — "глубже")
	float depth_mask = smoothstep(0.0, 0.6, tex_color.a);
	vec4 water_color = mix(shallow_color, deep_color, depth_mask * color_mix_strength + (1.0 - color_mix_strength));

	vec3 base_col = tex_color.rgb * water_color.rgb;

	// Скроллящийся блик — имитация солнечных дорожек на воде
	vec2 hl_uv = uv * wave_scale * 0.5 + vec2(t * highlight_speed, -t * highlight_speed * 0.6);
	float highlight = pow(0.5 + 0.5 * sin(hl_uv.x + sin(hl_uv.y * 2.0)), 8.0);
	base_col += highlight * highlight_strength;

	// Пена по краю тайла — берём альфа-градиент исходной текстуры
	float edge = 1.0 - smoothstep(0.0, foam_width, tex_color.a);
	edge *= smoothstep(0.02, 0.15, tex_color.a); // не рисуем пену в полностью прозрачных пикселях
	float foam_pulse = 0.75 + 0.25 * sin(TIME * foam_pulse_speed + uv.x * 10.0);
	base_col = mix(base_col, foam_color.rgb, edge * foam_pulse);

	// Искры — редкие яркие точки, мерцающие во времени
	vec2 cell = floor(uv * 40.0);
	float spark_seed = hash21(cell);
	float spark_time = fract(TIME * sparkle_speed * 0.3 + spark_seed);
	float spark = step(0.985, spark_seed) * smoothstep(0.0, 0.1, spark_time) * smoothstep(0.2, 0.1, spark_time);
	base_col += spark * sparkle_amount;

	// Итоговая прозрачность: базовая вода прозрачнее, пена по краю — плотнее
	float final_alpha = mix(water_alpha, foam_alpha, edge) * tex_color.a;

	COLOR = vec4(base_col, final_alpha);
}