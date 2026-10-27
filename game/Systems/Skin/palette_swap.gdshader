// palette_swap.gdshader
// Перекраска пиксель-арта по ключевым оттенкам (palette swap).
//
// Как это работает: художник рисует деталь (шлем, костюм…) ШАБЛОННЫМИ цветами –
// теми, что лежат в `keys`. Шейдер находит пиксели этих цветов и подменяет их на
// `targets` с тем же индексом. Все остальные цвета (контур, готовые скины) проходят
// без изменений. Новую форму шлема можно рисовать сколько угодно: цвет игрока
// хранится в материале, а не в текстуре, и от смены спрайта не теряется.
//
// Цвета передаются «как есть» (sRGB 0..1), без source_color: ровно в том виде,
// в каком они лежат в текстуре, поэтому сравнение точное.
shader_type canvas_item;

const int MAX_KEYS = 8;

uniform vec4 keys[MAX_KEYS];
uniform vec4 targets[MAX_KEYS];
uniform int key_count = 0;
// Допуск на сравнение цветов. 8-битный пиксель-арт: 2/255 с запасом
uniform float tolerance = 0.012;

// modulate узла (вспышка урона, прозрачность) берём в вершинной функции:
// на входе fragment() COLOR уже умножен на текстуру, и повторное умножение дало бы тёмные цвета.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb;
	for (int i = 0; i < MAX_KEYS; i++) {
		if (i >= key_count) {
			break;
		}
		if (distance(tex.rgb, keys[i].rgb) < tolerance) {
			rgb = targets[i].rgb;
			break;
		}
	}
	COLOR = vec4(rgb, tex.a) * node_modulate;
}
