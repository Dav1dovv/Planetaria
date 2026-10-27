// crew_seal.gdshader
// Маленькая голографическая печать на фото пропуска.
// Пиксельная сетка: UV квантуется, чтобы печать выглядела как пиксель-арт.
shader_type canvas_item;

uniform float cells = 12.0;
// 0..1: усиливает переливы, пока карточка под курсором
uniform float hot : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 q = (floor(UV * cells) + 0.5) / cells;
	vec2 p = q * 2.0 - 1.0;
	float r = length(p);

	float disc    = step(r, 1.0);
	float ring    = step(0.68, r) * disc;
	float diamond = step(abs(p.x) + abs(p.y), 0.46);

	float t = TIME * (0.25 + hot * 0.9) + p.x * 0.55 + p.y * 0.35;
	vec3 hue = 0.55 + 0.45 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));

	float emblem = clamp(ring + diamond, 0.0, 1.0);
	vec3 col = mix(hue * 0.45, hue, emblem);
	COLOR = vec4(col, disc * 0.88);
}
