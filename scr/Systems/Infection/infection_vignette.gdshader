shader_type canvas_item;

// Экранная винетка заражения — GDD 3.3, таблица "Экранная обратная связь":
//   10-49%  слабая (weak)
//   50-79%  средняя (medium, ~65%)
//   80-100% сильная (strong, ~85%)
// Значение приходит из InfectionVignette.gd через strength.

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.45, 0.05, 0.65, 1.0);
uniform float radius : hint_range(0.0, 1.5) = 0.75;
uniform float softness : hint_range(0.01, 1.5) = 0.6;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	// компенсация соотношения сторон, чтобы винетка была круглой, а не овальной
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(uv);

	float vignette = smoothstep(radius, radius - softness, dist);
	float alpha = (1.0 - vignette) * strength;

	COLOR = vec4(vignette_color.rgb, alpha);
}
