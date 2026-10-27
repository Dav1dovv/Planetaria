// crew_badge.gdshader
// Накладка поверх карточки-пропуска: голографический блик (наведение) и
// сканирующий луч (выбор карточки). Рисуется аддитивно, поэтому на тёмных
// участках карточки заметнее всего, а прозрачные места остаются прозрачными.
shader_type canvas_item;
render_mode blend_add;

// Положение диагональной полосы блика. -0.3 .. 1.4, вне диапазона не видно.
uniform float sheen : hint_range(-0.5, 1.5) = -0.5;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.22;

// Положение горизонтального луча сканера (0 = верх, 1 = низ).
uniform float scan : hint_range(-0.3, 1.3) = -0.3;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scan_color : source_color = vec4(0.45, 1.0, 0.6, 1.0);

void fragment() {
	// Диагональная координата вдоль карточки (0..~1.1)
	float d = UV.x * 0.75 + UV.y * 0.35;

	// Блик: узкая полоса с радужным оттенком, как на голограмме банковской карты
	float band = smoothstep(0.10, 0.0, abs(d - sheen));
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (d * 2.0 + vec3(0.0, 0.33, 0.67)));
	vec3 glow = mix(vec3(1.0), rainbow, 0.45) * band * sheen_strength;

	// Сканер: яркая линия и затухающий шлейф позади неё
	float line  = smoothstep(0.035, 0.0, abs(UV.y - scan));
	float trail = smoothstep(0.30, 0.0, scan - UV.y) * step(UV.y, scan) * 0.25;
	glow += scan_color.rgb * (line + trail) * scan_strength;

	COLOR = vec4(glow, 1.0);
}
