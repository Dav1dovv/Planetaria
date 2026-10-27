shader_type canvas_item;

// === Ветер ===
uniform float wind_strength : hint_range(0.0, 20.0) = 4.0;
uniform float wind_speed : hint_range(0.0, 10.0) = 1.8;
uniform float wind_frequency : hint_range(0.0, 10.0) = 2.5;
// Смещение по оси X для уникальности каждого дерева (передавай глобальную позицию)
uniform float wind_offset : hint_range(0.0, 100.0) = 0.0;

// === Прозрачность ===
// 1.0 = полностью видим, 0.0 = полностью прозрачен
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// UV.y = 0 — верхушка спрайта, UV.y = 1 — низ (корни)
	// Качание усиливается к верхушке (1.0 - UV.y)
	float sway_factor = pow(1.0 - UV.y, 2.0);

	float time_offset = TIME * wind_speed + wind_offset * 0.3;
	
	// Основная волна + маленькая быстрая рябь для органичности
	float wave = sin(time_offset * wind_frequency) * 0.7
			   + sin(time_offset * wind_frequency * 2.3 + 1.2) * 0.3;

	VERTEX.x += wave * wind_strength * sway_factor;
	
	// Лёгкое сжатие по Y при максимальном отклонении (физичность)
	VERTEX.y += abs(wave) * wind_strength * sway_factor * 0.15;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	// Применяем прозрачность только к непустым пикселям
	tex.a *= fade_alpha;
	
	COLOR = tex;
}
